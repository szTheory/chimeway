defmodule Chimeway.Test.TargetRecoveryAdapter do
  @behaviour Chimeway.TargetAdapter

  @impl true
  def deliver(%Chimeway.TargetAdapter.TargetEnvelope{target: target}, _opts) do
    send(
      Application.fetch_env!(:chimeway, :target_recovery_adapter_pid),
      {:recovered_target, target.id}
    )

    {:ok, %{provider_code: "accepted"}}
  end
end

defmodule Chimeway.Orchestration.TargetRecoveryTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query
  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{DeliveryTarget, DeliveryTargetAttempt, Repo, TargetRecovery}

  test "discovers tenant-qualified targets in bounded durable-ID pages" do
    %{delivery: delivery} = create_pending_delivery(channel: :push, tenant_id: "recovery-a")

    targets =
      for suffix <- ["001", "002", "003"] do
        Repo.insert!(%DeliveryTarget{
          tenant_id: delivery.tenant_id,
          delivery_id: delivery.id,
          binding_revision_ref: "cw_recovery_binding_#{suffix}",
          status: :pending
        })
      end

    %{delivery: foreign_delivery} =
      create_pending_delivery(channel: :push, tenant_id: "recovery-b")

    Repo.insert!(%DeliveryTarget{
      tenant_id: foreign_delivery.tenant_id,
      delivery_id: foreign_delivery.id,
      binding_revision_ref: "cw_recovery_binding_foreign",
      status: :pending
    })

    assert %{target_ids: first_page, cursor: cursor, reason: :resumed_target} =
             TargetRecovery.discover_target_work("recovery-a", batch_size: 2)

    assert first_page == targets |> Enum.map(& &1.id) |> Enum.sort() |> Enum.take(2)
    assert is_binary(cursor)

    assert %{target_ids: second_page, cursor: second_cursor, reason: :resumed_target} =
             TargetRecovery.discover_target_work("recovery-a", batch_size: 100, cursor: cursor)

    assert second_page == targets |> Enum.map(& &1.id) |> Enum.sort() |> Enum.drop(2)
    assert second_cursor == List.last(second_page)

    assert %{target_ids: [], cursor: nil, reason: :skipped_terminal} =
             TargetRecovery.discover_target_work("recovery-a",
               batch_size: 100,
               cursor: second_cursor
             )

    assert %{target_ids: foreign_page, reason: :resumed_target} =
             TargetRecovery.discover_target_work("recovery-b", batch_size: 0)

    assert length(foreign_page) == 1
  end

  test "recovery closes stale attempts as ambiguous before selecting actionable targets" do
    %{delivery: delivery} = create_pending_delivery(channel: :push, tenant_id: "recovery-stale")
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    target =
      Repo.insert!(%DeliveryTarget{
        tenant_id: delivery.tenant_id,
        delivery_id: delivery.id,
        binding_revision_ref: "cw_recovery_binding_stale",
        status: :claimed,
        claimed_at: DateTime.add(now, -120, :second),
        lease_expires_at: DateTime.add(now, -60, :second)
      })

    Repo.insert!(%DeliveryTargetAttempt{
      tenant_id: delivery.tenant_id,
      delivery_target_id: target.id,
      attempt_number: 1,
      outcome: :attempt_started,
      started_at: DateTime.add(now, -120, :second),
      source: "target_recovery",
      safe_facts: %{}
    })

    assert %{target_ids: [], counts: %{left_ambiguous: 1}, reasons: [:left_ambiguous]} =
             TargetRecovery.recover_tenant("recovery-stale")

    assert :ambiguous_handoff ==
             Repo.one!(from(t in DeliveryTarget, where: t.id == ^target.id)).status
  end

  test "concurrent recovery workers converge on one target claim and adapter handoff" do
    previous_adapter = Application.get_env(:chimeway, :target_adapter)
    Application.put_env(:chimeway, :target_adapter, Chimeway.Test.TargetRecoveryAdapter)
    Application.put_env(:chimeway, :target_recovery_adapter_pid, self())

    on_exit(fn ->
      if previous_adapter,
        do: Application.put_env(:chimeway, :target_adapter, previous_adapter),
        else: Application.delete_env(:chimeway, :target_adapter)

      Application.delete_env(:chimeway, :target_recovery_adapter_pid)
    end)

    %{delivery: delivery} = create_pending_delivery(channel: :push, tenant_id: "recovery-race")

    target =
      Repo.insert!(%DeliveryTarget{
        tenant_id: delivery.tenant_id,
        delivery_id: delivery.id,
        binding_revision_ref: "cw_recovery_binding_race",
        status: :pending
      })

    [first, second] =
      [
        Task.async(fn -> TargetRecovery.recover_tenant("recovery-race") end),
        Task.async(fn -> TargetRecovery.recover_tenant("recovery-race") end)
      ]
      |> Enum.map(&Task.await(&1, 5_000))

    assert first.counts.resumed_target + second.counts.resumed_target == 1
    assert_receive {:recovered_target, target_id}
    assert target_id == target.id
    refute_receive {:recovered_target, _}, 50

    assert 1 ==
             Repo.aggregate(
               from(a in DeliveryTargetAttempt, where: a.delivery_target_id == ^target.id),
               :count,
               :id
             )
  end

  test "wrong tenants and absent tenant input return the same non-disclosing recovery shape" do
    assert %{event_ids: [], target_ids: [], cursor: nil, reason: :skipped_terminal} =
             TargetRecovery.recover_tenant("missing-tenant")

    assert %{event_ids: [], target_ids: [], cursor: nil, reason: :skipped_terminal} =
             TargetRecovery.recover_tenant(nil)
  end
end
