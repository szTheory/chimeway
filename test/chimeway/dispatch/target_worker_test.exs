defmodule Chimeway.Test.TargetWorkerAdapter do
  @behaviour Chimeway.TargetAdapter

  @impl true
  def deliver(%Chimeway.TargetAdapter.TargetEnvelope{target: target}, _opts) do
    if pid = Application.get_env(:chimeway, :target_worker_adapter_pid),
      do: send(pid, {:target_adapter_called, target.id})

    case Application.get_env(:chimeway, :target_worker_adapter_result, {:ok, %{provider_code: "accepted"}}) do
      :raise -> raise "raw-adapter-reason"
      :throw -> throw(:raw_adapter_reason)
      result -> result
    end
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
      Application.delete_env(:chimeway, :target_worker_adapter_result)
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

  test "explicit pre-handoff failure closes a retryable attempt without retaining adapter evidence" do
    %{delivery: delivery} = create_pending_delivery(channel: :push, tenant_id: "target-worker-pre-handoff")
    target = insert_target(delivery, "cw_binding_revision_pre_handoff_001")
    target_id = target.id
    Application.put_env(:chimeway, :target_worker_adapter_result, {:error, :pre_handoff, "raw-token-sentinel"})

    assert {:error, :pre_handoff_retryable} = Executor.run_target(delivery, target_id: target_id)
    assert_receive {:target_adapter_called, ^target_id}

    target = Repo.get!(DeliveryTarget, target.id)
    [attempt] = attempts_for(target)

    assert target.status == :pending
    assert target.lease_expires_at == nil
    assert attempt.outcome == :failed
    assert attempt.finished_at
    assert attempt.safe_facts == %{"provider_code" => "adapter_pre_handoff_failure"}
    refute inspect({target, attempt}) =~ "raw-token-sentinel"

    assert {:ok, %{attempt: retry_attempt}} = Executor.run_target(delivery, target_id: target_id)
    assert retry_attempt.attempt_number == 2
  end

  test "possible and unknown callback outcomes close as ambiguity and cannot automatically resend" do
    %{delivery: delivery} = create_pending_delivery(channel: :push, tenant_id: "target-worker-ambiguity")

    for {suffix, callback_result} <- [
          {"possible", {:error, :possible_handoff, "raw-token-sentinel"}},
          {"legacy", {:error, "raw-token-sentinel"}},
          {"unexpected", :not_an_adapter_result},
          {"raised", :raise},
          {"thrown", :throw}
        ] do
      target = insert_target(delivery, "cw_binding_revision_ambiguity_#{suffix}")
      target_id = target.id
      Application.put_env(:chimeway, :target_worker_adapter_result, callback_result)

      assert {:error, :ambiguous_handoff} = Executor.run_target(delivery, target_id: target_id)
      assert_receive {:target_adapter_called, ^target_id}

      target = Repo.get!(DeliveryTarget, target.id)
      [attempt] = attempts_for(target)

      assert target.status == :ambiguous_handoff
      assert target.lease_expires_at == nil
      assert attempt.outcome == :ambiguous_handoff
      assert attempt.finished_at
      assert attempt.safe_facts == %{"provider_code" => "possible_provider_handoff"}
      refute inspect({target, attempt}) =~ "raw-token-sentinel"

      assert {:noop, :no_eligible_target} = Executor.run_target(delivery, target_id: target_id)
      refute_receive {:target_adapter_called, ^target_id}, 50
      assert [^attempt] = attempts_for(target)
    end
  end

  test "concurrent duplicate target execution enters the adapter once and finalizes its exact started attempt" do
    %{delivery: delivery} = create_pending_delivery(channel: :push, tenant_id: "target-worker-duplicate")
    target = insert_target(delivery, "cw_binding_revision_duplicate_001")
    target_id = target.id

    first = Task.async(fn -> Executor.run_target(delivery, target_id: target_id) end)
    assert_receive {:target_adapter_called, ^target_id}
    second = Task.async(fn -> Executor.run_target(delivery, target_id: target_id) end)

    assert {:ok, %{attempt: attempt}} = Task.await(first)
    assert {:noop, :no_eligible_target} = Task.await(second)
    refute_receive {:target_adapter_called, ^target_id}, 50

    [stored_attempt] = attempts_for(target)
    assert stored_attempt.id == attempt.id
    assert stored_attempt.outcome == :provider_accepted
    assert stored_attempt.finished_at
  end

  defp insert_target(delivery, binding_revision_ref) do
    Repo.insert!(%DeliveryTarget{
      tenant_id: delivery.tenant_id,
      delivery_id: delivery.id,
      binding_revision_ref: binding_revision_ref,
      status: :pending
    })
  end

  defp attempts_for(target) do
    Repo.all(
      from(a in DeliveryTargetAttempt,
        where: a.delivery_target_id == ^target.id,
        order_by: [asc: a.attempt_number]
      )
    )
  end

  defp restore(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore(key, value), do: Application.put_env(:chimeway, key, value)
end
