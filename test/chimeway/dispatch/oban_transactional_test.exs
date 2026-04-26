defmodule Chimeway.Dispatch.ObanTransactionalTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban
  @moduletag :integration

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{
    Delivery,
    DeliveryPlanning,
    Dispatch.Oban,
    Dispatch.ObanWorker,
    Dispatch.Sync,
    Repo
  }

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
      Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    end)

    :ok
  end

  describe "transactional enqueue commit path" do
    test "committed multi leaves delivery and Oban job visible" do
      ctx = create_pending_delivery()

      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:marker, fn _repo, _changes -> {:ok, :success} end)

      assert {:ok, _deliveries} = Oban.dispatch([ctx.notification], multi: multi)
      assert_enqueued(worker: ObanWorker, args: %{delivery_id: ctx.delivery.id})
    end
  end

  describe "transactional enqueue rollback path" do
    test "rolled-back multi leaves no job enqueued" do
      ctx = create_pending_delivery()

      failing_multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:fail, fn _repo, _changes -> {:error, :forced_failure} end)

      assert {:error, :forced_failure} = Oban.dispatch([ctx.notification], multi: failing_multi)
      refute_enqueued(worker: ObanWorker, args: %{delivery_id: ctx.delivery.id})
    end

    test "rolled-back multi with fresh notification leaves no planned deliveries" do
      ctx = create_notification()

      failing_multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:fail, fn _repo, _changes -> {:error, :forced_failure} end)

      assert {:error, :forced_failure} = Oban.dispatch([ctx.notification], multi: failing_multi)

      delivery_count =
        Repo.aggregate(
          from(delivery in Delivery, where: delivery.notification_id == ^ctx.notification.id),
          :count
        )

      assert delivery_count == 0
      refute_enqueued(worker: ObanWorker)
    end
  end

  describe "atomicity guarantee" do
    # REQ: INTG-03 — planning rows roll back when enqueue path fails.
    test "enqueue failure rolls back planning rows created in same transaction" do
      ctx = create_notification()

      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:plan_notifications, fn _repo, _changes ->
          DeliveryPlanning.plan_notifications([ctx.notification], [])
        end)
        |> Ecto.Multi.run(:fail_enqueue, fn _repo, %{plan_notifications: deliveries} ->
          case Enum.any?(deliveries, fn delivery -> delivery.status == :pending end) do
            true -> {:error, :simulated_enqueue_failure}
            false -> {:error, :expected_pending_delivery}
          end
        end)

      assert {:error, :fail_enqueue, :simulated_enqueue_failure, _changes} =
               Repo.transaction(multi)

      delivery_count =
        Repo.aggregate(
          from(delivery in Delivery, where: delivery.notification_id == ^ctx.notification.id),
          :count
        )

      assert delivery_count == 0
      refute_enqueued(worker: ObanWorker)
    end
  end

  describe "duplicate dispatch idempotency" do
    test "dispatching the same notification twice keeps one delivery and one job" do
      ctx = create_pending_delivery()

      assert {:ok, _} = Oban.dispatch([ctx.notification], [])
      assert {:ok, _} = Oban.dispatch([ctx.notification], [])

      delivery_count =
        Repo.aggregate(
          from(delivery in Delivery, where: delivery.notification_id == ^ctx.notification.id),
          :count
        )

      assert delivery_count == 1
      assert length(all_enqueued(worker: ObanWorker, args: %{delivery_id: ctx.delivery.id})) == 1
    end
  end

  describe "sync dispatcher bypasses Oban jobs" do
    test "sync dispatch does not enqueue background jobs" do
      ctx = create_pending_delivery()
      Chimeway.Adapters.Test.clear()

      assert {:ok, _results} = Sync.dispatch([ctx.notification], [])
      assert all_enqueued(worker: ObanWorker) == []
    end
  end
end
