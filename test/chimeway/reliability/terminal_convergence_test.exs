defmodule Chimeway.Reliability.TerminalConvergenceTest.PermanentAdapter do
  @moduledoc false
  @behaviour Chimeway.Adapter
  @impl true
  def deliver(_delivery, _config), do: {:error, :permanent, %{reason: "invalid_address"}}
end

defmodule Chimeway.Reliability.TerminalConvergenceTest.BouncedAdapter do
  @moduledoc false
  @behaviour Chimeway.Adapter
  @impl true
  def deliver(_delivery, _config), do: {:error, :bounced, %{reason: "hard_bounce"}}
end

defmodule Chimeway.Reliability.TerminalConvergenceTest.TemporaryAdapter do
  @moduledoc """
  Local always-failing temporary adapter. Defined locally so this file does not depend
  on retry_exhaustion_test.exs being loaded — `mix test path/to/this_file` works in
  isolation.
  """
  @behaviour Chimeway.Adapter
  @impl true
  def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "test_failure"}}
end

defmodule Chimeway.Reliability.TerminalConvergenceTest do
  @moduledoc """
  REL-03 D-12 — every delivery converges to a state in `Deliveries.terminal_states/0`.

  Six terminal paths covered:
  1. :succeeded (success)
  2. :cancelled with reason "retries_exhausted" (Oban gave up)
  3. :cancelled with reason "permanent_failure" (adapter said don't retry)
  4. :cancelled with reason "bounced" (adapter said hard bounce)
  5. :suppressed (policy)
  6. :cancelled (manual)
  """

  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.Deliveries
  alias Chimeway.Dispatch.ObanWorker

  alias Chimeway.Reliability.TerminalConvergenceTest.{
    BouncedAdapter,
    PermanentAdapter,
    TemporaryAdapter
  }

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    end)

    :ok
  end

  describe "succeeded path (D-12)" do
    test "delivery converges to :succeeded after adapter ok and lands in terminal_states/0" do
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1)

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :succeeded
      assert updated.status in Deliveries.terminal_states()
    end
  end

  describe "retries_exhausted path (D-12)" do
    test "delivery converges to :cancelled / retries_exhausted after Oban gives up" do
      Application.put_env(:chimeway, :adapter, TemporaryAdapter)

      %{delivery: delivery} = create_pending_delivery()

      for n <- 1..4,
          do:
            assert({:error, _} = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: n))

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 5)

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :cancelled
      assert updated.suppression_reason == "retries_exhausted"
      assert updated.status in Deliveries.terminal_states()
    end
  end

  describe "permanent_failure path (D-12)" do
    test "delivery converges to :cancelled / permanent_failure on permanent adapter error" do
      Application.put_env(:chimeway, :adapter, PermanentAdapter)

      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1)

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :cancelled
      assert updated.suppression_reason == "permanent_failure"
      assert updated.status in Deliveries.terminal_states()
    end
  end

  describe "bounced path (D-12)" do
    test "delivery converges to :cancelled / bounced on bounced adapter error" do
      Application.put_env(:chimeway, :adapter, BouncedAdapter)

      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1)

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :cancelled
      assert updated.suppression_reason == "bounced"
      assert updated.status in Deliveries.terminal_states()
    end
  end

  describe "suppressed path (D-12)" do
    test "policy-suppressed delivery converges to :suppressed and lands in terminal_states/0" do
      %{delivery: delivery} = create_pending_delivery()

      {:ok, suppressed} =
        Deliveries.suppress_delivery(delivery, :channel_disabled, checkpoint: :perform)

      assert suppressed.status == :suppressed
      assert suppressed.suppression_reason == "channel_disabled"
      assert suppressed.status in Deliveries.terminal_states()
    end
  end

  describe "manual cancelled path (D-12)" do
    test "manual transition_status to :cancelled lands in terminal_states/0" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, cancelled} = Deliveries.transition_status(delivery, :cancelled)

      assert cancelled.status == :cancelled
      assert cancelled.suppression_reason == nil
      assert cancelled.status in Deliveries.terminal_states()
    end
  end
end
