defmodule Chimeway.Test.TargetWorkerAdapter do
  @behaviour Chimeway.TargetAdapter

  @impl true
  def deliver(%Chimeway.TargetAdapter.TargetEnvelope{target: target}, _opts) do
    if pid = Application.get_env(:chimeway, :target_worker_adapter_pid),
      do: send(pid, {:target_adapter_called, target.id})

    {:ok, %{provider_code: "accepted"}}
  end
end

defmodule Chimeway.Dispatch.TargetWorkerTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{DeliveryTarget, DeliveryTargetAttempt, DeliveryTargets, Repo}
  alias Chimeway.Dispatch.{Executor, ObanWorker}

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
    %{delivery: delivery} =
      create_pending_delivery(channel: :push, tenant_id: "target-worker-tenant")

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

  test "stale started target work closes as ambiguous instead of becoming eligible for resend" do
    %{delivery: delivery} =
      create_pending_delivery(channel: :push, tenant_id: "target-worker-stale-tenant")

    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    target =
      Repo.insert!(%DeliveryTarget{
        tenant_id: delivery.tenant_id,
        delivery_id: delivery.id,
        binding_revision_ref: "cw_binding_revision_stale_001",
        status: :claimed,
        claimed_at: DateTime.add(now, -120, :second),
        lease_expires_at: DateTime.add(now, -60, :second)
      })

    started =
      Repo.insert!(%DeliveryTargetAttempt{
        tenant_id: delivery.tenant_id,
        delivery_target_id: target.id,
        attempt_number: 1,
        outcome: :attempt_started,
        started_at: DateTime.add(now, -120, :second),
        source: "oban",
        safe_facts: %{}
      })

    assert :ok =
             perform_job(ObanWorker, %{
               delivery_target_id: target.id,
               tenant_id: delivery.tenant_id
             })

    target_id = target.id
    refute_receive {:target_adapter_called, ^target_id}, 50

    assert {:ok, %{target: closed_target, attempt: closed_attempt}} =
             DeliveryTargets.close_stale_started_attempt(target.id, delivery.tenant_id)

    assert closed_target.status == :ambiguous_handoff
    assert closed_target.lease_expires_at == nil
    assert closed_attempt.id == started.id
    assert closed_attempt.outcome == :ambiguous_handoff
    assert closed_attempt.safe_facts == %{"provider_code" => "possible_provider_handoff"}

    assert {:ok, %{target: redriven_target}} =
             DeliveryTargets.authorize_target_redrive(
               target.id,
               delivery.tenant_id,
               "policy_authorized"
             )

    assert redriven_target.status == :pending

    assert {:ok, %{attempt: redrive_attempt}} =
             Executor.run_target(delivery, target_id: target.id, source: "recovery")

    assert redrive_attempt.outcome == :provider_accepted
    assert redrive_attempt.attempt_number == 2
    assert redrive_attempt.prior_attempt_id == started.id
    assert redrive_attempt.duplicate_risk
  end

  defp restore(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore(key, value), do: Application.put_env(:chimeway, key, value)
end
