defmodule Chimeway.Test.RetryFailingAdapter do
  @moduledoc """
  Test adapter that always returns {:error, :temporary, _}. Used by retry_exhaustion_test.exs.
  Defined at file top-level so it compiles before the test module references it.
  """
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "test_failure"}}
end

defmodule Chimeway.Reliability.RetryExhaustionTest do
  @moduledoc """
  REL-02 D-04 / D-10 / D-11 — Oban-driven retry contract.

  - Transient failure on attempt 1..n-1 returns {:error, _} so Oban schedules retry.
  - Final attempt (job.attempt == job.max_attempts) writes :cancelled retries_exhausted
    via Deliveries.exhaust_delivery/1, then perform/1 returns :ok (RESEARCH Pitfall 1
    keeps Oban telemetry clean — :completed instead of :discarded).
  - drain_queue end-to-end: queue progresses AND delivery converges to terminal AND
    attempt history accumulates (B5 robust contract assertion — does not hard-code
    drain_queue success/failure counts because Oban's drain semantics for retryable
    jobs are version-dependent; RESEARCH Open Question 2 RESOLVED).
  """

  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban

  import Chimeway.Test.DispatchHelpers
  import Ecto.Query, only: [from: 2]

  alias Chimeway.{Deliveries, DeliveryAttempt, Repo}
  alias Chimeway.Dispatch.ObanWorker

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    end)

    :ok
  end

  describe "transient failure on attempts 1..n-1 (REL-02 D-04)" do
    test "perform_job/3 with attempt: 1 returns {:error, _} when adapter is :temporary" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.RetryFailingAdapter)

      %{delivery: delivery} = create_pending_delivery()

      assert {:error, _reason} =
               perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1)

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :failed
      assert updated.suppression_reason == nil
      refute updated.status in Deliveries.terminal_states()
    end

    test "intermediate attempts produce attempt rows with error_class \"temporary\"" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.RetryFailingAdapter)

      %{delivery: delivery} = create_pending_delivery()

      assert {:error, _} = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1)

      [attempt] =
        Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))

      assert attempt.outcome == :failed
      assert attempt.error_class == "temporary"
      assert attempt.attempt_number == 1
    end
  end

  describe "exhaustion on final attempt (REL-02 D-10 / D-11)" do
    test "perform_job/3 with attempt: max_attempts writes :cancelled retries_exhausted and returns :ok" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.RetryFailingAdapter)

      %{delivery: delivery} = create_pending_delivery()

      # Run attempts 1..4 to build up the failed status (each one returns {:error, _}).
      for n <- 1..4 do
        assert {:error, _} = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: n)
      end

      # Attempt 5 == max_attempts: worker writes :cancelled retries_exhausted then returns :ok.
      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 5)

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :cancelled
      assert updated.suppression_reason == "retries_exhausted"
      assert updated.status in Deliveries.terminal_states()

      attempts =
        Repo.all(
          from(a in DeliveryAttempt,
            where: a.delivery_id == ^delivery.id,
            order_by: a.attempt_number
          )
        )

      assert length(attempts) == 5
      assert Enum.map(attempts, & &1.attempt_number) == [1, 2, 3, 4, 5]
      assert Enum.all?(attempts, &(&1.error_class == "temporary"))
    end

    test "exhaustion sets suppression_reason to \"retries_exhausted\" exactly" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.RetryFailingAdapter)

      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 5)

      assert Deliveries.get_delivery!(delivery.id).suppression_reason == "retries_exhausted"
    end
  end

  describe "drain_queue end-to-end exhaustion (REL-02 integration — B5 robust contract)" do
    @tag :integration
    test "always-failing adapter drains queue with delivery converging to terminal :cancelled retries_exhausted" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.RetryFailingAdapter)

      %{delivery: delivery} = create_pending_delivery()

      {:ok, _job} = ObanWorker.new(%{delivery_id: delivery.id}) |> Oban.insert()
      assert_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})

      result =
        Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true, with_recursion: true)

      # B5 robust assertion: verify the queue made progress AND the delivery converged
      # terminally AND attempt history accumulated. Do NOT hard-code drain_queue success
      # vs failure counts — RESEARCH Open Question 2 (RESOLVED) flagged that drain_queue
      # retryable-job semantics are version-dependent. The contract we care about is the
      # observable outcome state, not the drain result shape.
      total_executed =
        Map.get(result, :success, 0) + Map.get(result, :failure, 0) + Map.get(result, :discard, 0)

      assert total_executed >= 1, "drain_queue must execute at least one job"

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :cancelled
      assert updated.suppression_reason == "retries_exhausted"
      assert updated.status in Deliveries.terminal_states()

      # Attempt history accumulated to max_attempts rows.
      attempt_count =
        Repo.aggregate(
          from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id),
          :count,
          :id
        )

      assert attempt_count == 5, "expected 5 attempt rows (max_attempts), got #{attempt_count}"
    end
  end
end
