defmodule Chimeway.Test.ObanWorkerFailingAdapter do
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "test_failure"}}
end

defmodule Chimeway.Dispatch.ObanWorkerTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{Deliveries, DeliveryAttempt, Dispatch.ObanWorker, Repo}

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    end)

    :ok
  end

  describe "perform/1 success path" do
    test "records one attempt and transitions delivery to :succeeded" do
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :succeeded

      attempts = Repo.all(from attempt in DeliveryAttempt, where: attempt.delivery_id == ^delivery.id)
      assert length(attempts) == 1
      assert hd(attempts).outcome == :succeeded
    end
  end

  describe "perform/1 idempotency" do
    test "running perform twice creates exactly one attempt row" do
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      attempts = Repo.all(from attempt in DeliveryAttempt, where: attempt.delivery_id == ^delivery.id)
      assert length(attempts) == 1
    end
  end

  describe "terminal state short-circuit" do
    test "returns :ok for :succeeded delivery without adapter call" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, _result} = Deliveries.record_attempt(dispatched, %{outcome: :succeeded, provider_response: %{}})
      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "returns :ok for :suppressed delivery without adapter call" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, _suppressed} = Deliveries.suppress_delivery(delivery, :channel_disabled)
      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "returns :ok for :cancelled delivery without adapter call" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, _cancelled} = Deliveries.transition_status(delivery, :cancelled)
      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end
  end

  describe "adapter error path and retry" do
    test "transitions delivery to :failed when adapter returns temporary error" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :failed

      attempts = Repo.all(from attempt in DeliveryAttempt, where: attempt.delivery_id == ^delivery.id)
      assert length(attempts) == 1
      assert hd(attempts).outcome == :failed
    after
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    end

    test "retries failed delivery and succeeds with two attempts" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Deliveries.get_delivery!(delivery.id).status == :failed

      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :succeeded

      attempt_count =
        Repo.aggregate(
          from(attempt in DeliveryAttempt, where: attempt.delivery_id == ^delivery.id),
          :count
        )

      assert attempt_count == 2
    after
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    end
  end
end
