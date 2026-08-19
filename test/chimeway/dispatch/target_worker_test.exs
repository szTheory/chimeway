defmodule Chimeway.Test.TargetWorkerAdapter do
  @behaviour Chimeway.TargetAdapter

  @impl true
  def deliver(%Chimeway.TargetAdapter.TargetEnvelope{target: target}, _opts) do
    if pid = Application.get_env(:chimeway, :target_worker_adapter_pid), do: send(pid, {:target_adapter_called, target.id})
    {:ok, %{provider_code: "accepted"}}
  end
end

defmodule Chimeway.Dispatch.TargetWorkerTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{DeliveryTarget, DeliveryTargetAttempt, Repo}
  alias Chimeway.Dispatch.ObanWorker

  setup do
    previous_adapter = Application.get_env(:chimeway, :target_adapter)
    Application.put_env(:chimeway, :target_adapter, Chimeway.Test.TargetWorkerAdapter)
    Application.put_env(:chimeway, :target_worker_adapter_pid, self())

    on_exit(fn ->
      restore(:target_adapter, previous_adapter)
      Application.delete_env(:chimeway, :target_worker_adapter_pid)
    end)

    :ok
  end

  test "target-id Oban jobs start the durable target attempt before adapter handoff" do
    %{delivery: delivery} = create_pending_delivery(channel: :push, tenant_id: "target-worker-tenant")

    target =
      Repo.insert!(%DeliveryTarget{
        tenant_id: delivery.tenant_id,
        delivery_id: delivery.id,
        binding_revision_ref: "cw_binding_revision_worker_001",
        status: :pending
      })

    assert :ok =
             perform_job(ObanWorker, %{
               delivery_target_id: target.id,
               tenant_id: delivery.tenant_id
             })

    target_id = target.id
    assert_receive {:target_adapter_called, ^target_id}

    [attempt] =
      Repo.all(
        from(a in DeliveryTargetAttempt,
          where: a.delivery_target_id == ^target.id,
          order_by: [asc: a.attempt_number]
        )
      )

    assert attempt.source == "oban"
    assert attempt.outcome == :provider_accepted
  end

  defp restore(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore(key, value), do: Application.put_env(:chimeway, key, value)
end
