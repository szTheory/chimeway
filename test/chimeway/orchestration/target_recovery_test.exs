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

    assert %{target_ids: second_page, cursor: nil, reason: :resumed_target} =
             TargetRecovery.discover_target_work("recovery-a", batch_size: 100, cursor: cursor)

    assert second_page == targets |> Enum.map(& &1.id) |> Enum.sort() |> Enum.drop(2)
    assert %{target_ids: [], reason: :skipped_terminal} =
             TargetRecovery.discover_target_work("recovery-b", batch_size: 0)
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

  test "wrong tenants and absent tenant input return the same non-disclosing recovery shape" do
    assert %{event_ids: [], target_ids: [], cursor: nil, reason: :skipped_invalidated} =
             TargetRecovery.recover_tenant("missing-tenant")

    assert %{event_ids: [], target_ids: [], cursor: nil, reason: :skipped_invalidated} =
             TargetRecovery.recover_tenant(nil)
  end
end
