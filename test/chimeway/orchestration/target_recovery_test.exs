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
  alias Chimeway.Dispatch.RecoveryWorker
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

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

  test "discovers both trigger-commit gaps with an independent event cursor" do
    now = ~U[2026-08-19 12:00:00.000000Z]
    event_only = insert_event!("recovery-event-gaps", "event-only", now)
    notification_gap = insert_event!("recovery-event-gaps", "notification-gap", now)
    complete = insert_event!("recovery-event-gaps", "complete", now)
    foreign = insert_event!("recovery-event-foreign", "foreign", now)

    _notification = insert_notification!(notification_gap, "recovery-event-gaps")
    complete_notification = insert_notification!(complete, "recovery-event-gaps")
    foreign_notification = insert_notification!(foreign, "recovery-event-foreign")

    create_pending_delivery(notification: complete_notification, tenant_id: "recovery-event-gaps")

    create_pending_delivery(
      notification: foreign_notification,
      tenant_id: "recovery-event-foreign"
    )

    assert %{event_ids: ids, cursor: cursor, reason: :resumed_planning} =
             TargetRecovery.discover_stranded_events("recovery-event-gaps",
               now: DateTime.add(now, 120, :second),
               older_than: 60,
               batch_size: 100
             )

    assert ids == Enum.sort([event_only.id, notification_gap.id])
    assert cursor == List.last(ids)

    assert %{event_ids: [], cursor: nil, reason: :skipped_terminal} =
             TargetRecovery.discover_stranded_events("recovery-event-gaps",
               now: DateTime.add(now, 120, :second),
               older_than: 60,
               event_cursor: cursor
             )
  end

  test "recovery keeps typed continuations independent and caps each stream" do
    %{delivery: delivery} = create_pending_delivery(channel: :push, tenant_id: "recovery-pages")
    now = ~U[2026-08-19 12:00:00.000000Z]

    events =
      for suffix <- ["001", "002", "003"] do
        insert_event!("recovery-pages", "event-#{suffix}", now)
      end

    targets =
      for suffix <- ["001", "002", "003"] do
        Repo.insert!(%DeliveryTarget{
          tenant_id: delivery.tenant_id,
          delivery_id: delivery.id,
          binding_revision_ref: "cw_recovery_pages_#{suffix}",
          status: :pending
        })
      end

    first =
      TargetRecovery.recover_tenant("recovery-pages",
        now: DateTime.add(now, 120, :second),
        older_than: 60,
        batch_size: 2
      )

    assert %{continuations: %{event: event_cursor, target: target_cursor, stale_attempt: nil}} =
             first

    assert is_binary(event_cursor)
    assert is_binary(target_cursor)
    assert length(first.event_ids) == 2
    assert length(first.target_ids) == 2

    second =
      TargetRecovery.recover_tenant("recovery-pages",
        now: DateTime.add(now, 120, :second),
        older_than: 60,
        batch_size: 2,
        event_cursor: event_cursor,
        target_cursor: target_cursor
      )

    assert second.event_ids == [events |> Enum.map(& &1.id) |> Enum.sort() |> List.last()]
    assert second.target_ids == [targets |> Enum.map(& &1.id) |> Enum.sort() |> List.last()]
    refute Map.get(second.continuations, :event) == event_cursor
    refute Map.get(second.continuations, :target) == target_cursor
  end

  test "worker returns and emits only the closed recovery summary" do
    handler = "recovery-summary-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler,
        [:chimeway, :recovery, :completed],
        fn _event, measurements, meta, _config ->
          send(parent, {:recovery_completed, measurements, meta})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    assert {:ok, %{continuations: %{event: nil, target: nil, stale_attempt: nil}} = summary} =
             RecoveryWorker.perform(%Oban.Job{
               args: %{"tenant_id" => "recovery-worker", "batch_size" => 1}
             })

    assert_receive {:recovery_completed, measurements, metadata}
    assert measurements == summary.counts

    assert metadata == %{
             reason: summary.reason,
             reasons: summary.reasons,
             continuations: summary.continuations
           }

    refute inspect(metadata) =~ "tenant"
  end

  defp insert_event!(tenant_id, suffix, updated_at) do
    Repo.insert!(%Event{
      notification_key: "recovery.#{suffix}",
      notification_version: 1,
      idempotency_key: "recovery-#{tenant_id}-#{suffix}",
      tenant_id: tenant_id,
      payload: %{},
      inserted_at: updated_at,
      updated_at: updated_at
    })
  end

  defp insert_notification!(event, tenant_id) do
    Repo.insert!(%Notification{
      event_id: event.id,
      tenant_id: tenant_id,
      recipient_identity: "recovery-user",
      recipient_type: "user",
      metadata: %{},
      render_assigns: %{},
      render_channels: %{}
    })
  end
end
