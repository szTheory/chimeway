defmodule Chimeway.Dispatch.ObanTransactionalTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban
  @moduletag :integration

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{Delivery, Dispatch.Oban, Dispatch.ObanWorker, Dispatch.Sync, Repo}

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
