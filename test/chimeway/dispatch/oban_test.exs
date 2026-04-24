defmodule Chimeway.FailingTestAdapter do
  @moduledoc false
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(%Chimeway.Delivery{}, _config), do: {:error, :temporary, %{reason: "test_failure"}}
end

defmodule Chimeway.Dispatch.ObanTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban

  alias Chimeway.{Deliveries, Dispatch.Oban, Dispatch.ObanWorker}

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
      Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    end)

    :ok
  end

  describe "Chimeway.Dispatch.Oban.dispatch/2" do
    test "enqueues one ObanWorker job per delivery" do
      notification = insert_notification()
      {:ok, _deliveries} = Oban.dispatch([notification], [])
      assert_enqueued(worker: ObanWorker)
    end

    test "returns {:ok, deliveries} with the planned delivery structs" do
      notification = insert_notification()
      {:ok, deliveries} = Oban.dispatch([notification], [])
      assert length(deliveries) == 1
      assert hd(deliveries).status == :pending
    end

    test "transactional rollback prevents job from being enqueued" do
      notification = insert_notification()
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)

      failing_multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:fail, fn _repo, _changes -> {:error, :forced_failure} end)

      Oban.dispatch([notification], multi: failing_multi)

      refute_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})
    end
  end

  describe "Chimeway.Dispatch.ObanWorker.perform/1" do
    test "calls adapter and records attempt on success" do
      notification = insert_notification()
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :succeeded

      attempts =
        Chimeway.Repo.all(
          from(a in Chimeway.DeliveryAttempt, where: a.delivery_id == ^delivery.id)
        )

      assert length(attempts) == 1
    end

    test "returns :ok immediately for terminal delivery without adapter call" do
      Chimeway.Adapters.Test.clear()
      notification = insert_notification()
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      Deliveries.record_attempt(dispatched, %{outcome: :succeeded, provider_response: %{}})

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "records :failed attempt when adapter returns temporary error" do
      Application.put_env(:chimeway, :adapter, Chimeway.FailingTestAdapter)
      notification = insert_notification()
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)

      perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :failed
    after
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    end
  end

  # --- helpers ---

  defp insert_notification do
    {:ok, event} =
      Chimeway.Repo.insert(%Chimeway.Events.Event{
        notification_key: "test_notifier",
        notification_version: 1,
        idempotency_key: "test-#{System.unique_integer()}",
        payload: %{}
      })

    {:ok, notification} =
      Chimeway.Repo.insert(%Chimeway.Notifications.Notification{
        event_id: event.id,
        recipient_identity: "user:#{System.unique_integer()}",
        recipient_type: "user",
        metadata: %{}
      })

    notification
  end
end
