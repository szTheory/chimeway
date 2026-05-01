defmodule Chimeway.DeliveriesTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Deliveries, Delivery, DeliveryAttempt, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  import Ecto.Query, only: [from: 2]

  # ---- Fixtures ----

  defp insert_notification(_ctx \\ %{}) do
    {:ok, event} =
      %Event{}
      |> Event.changeset(%{
        notification_key: "test.notification",
        notification_version: 1,
        idempotency_key: "test-#{System.unique_integer()}",
        payload: %{}
      })
      |> Repo.insert()

    {:ok, notification} =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: "user-1",
        recipient_type: "user",
        metadata: %{}
      })
      |> Repo.insert()

    %{notification: notification}
  end

  defp insert_event(attrs \\ %{})

  defp insert_event(attrs) when is_list(attrs) do
    attrs
    |> Enum.into(%{})
    |> insert_event()
  end

  defp insert_event(attrs) when is_map(attrs) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    inserted_at = attrs |> Map.get(:inserted_at, timestamp) |> normalize_datetime()
    updated_at = attrs |> Map.get(:updated_at, inserted_at) |> normalize_datetime()

    {:ok, event} =
      %Event{}
      |> Event.changeset(%{
        notification_key: Map.get(attrs, :notification_key, "test.notification"),
        notification_version: Map.get(attrs, :notification_version, 1),
        idempotency_key: Map.get(attrs, :idempotency_key, "event-#{System.unique_integer()}"),
        payload: Map.get(attrs, :payload, %{}),
        correlation_id: Map.get(attrs, :correlation_id)
      })
      |> Repo.insert()

    event
    |> Ecto.Changeset.change(%{
      inserted_at: inserted_at,
      updated_at: updated_at
    })
    |> Repo.update!()
  end

  defp insert_notification_for_event(event, attrs \\ %{})

  defp insert_notification_for_event(event, attrs) when is_list(attrs) do
    insert_notification_for_event(event, Enum.into(attrs, %{}))
  end

  defp insert_notification_for_event(event, attrs) when is_map(attrs) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    inserted_at = attrs |> Map.get(:inserted_at, timestamp) |> normalize_datetime()
    updated_at = attrs |> Map.get(:updated_at, inserted_at) |> normalize_datetime()

    {:ok, notification} =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity:
          Map.get(attrs, :recipient_identity, "user-#{System.unique_integer([:positive])}"),
        recipient_type: Map.get(attrs, :recipient_type, "user"),
        metadata: Map.get(attrs, :metadata, %{}),
        render_assigns: Map.get(attrs, :render_assigns, %{}),
        render_channels: Map.get(attrs, :render_channels, %{})
      })
      |> Repo.insert()

    notification
    |> Ecto.Changeset.change(%{
      inserted_at: inserted_at,
      updated_at: updated_at
    })
    |> Repo.update!()
  end

  defp insert_delivery(attrs) when is_list(attrs) do
    attrs
    |> Enum.into(%{})
    |> insert_delivery()
  end

  defp insert_delivery(attrs) when is_map(attrs) do
    notification =
      Map.get_lazy(attrs, :notification, fn ->
        insert_event()
        |> insert_notification_for_event()
      end)

    metadata = Map.get(attrs, :metadata, %{})
    inserted_at = attrs |> Map.get(:inserted_at) |> normalize_datetime()
    updated_at = attrs |> Map.get(:updated_at) |> normalize_datetime()
    next_eligible_at = attrs |> Map.get(:next_eligible_at) |> normalize_datetime()

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, Map.get(attrs, :channel, :in_app),
        metadata: metadata,
        tenant_id: Map.get(attrs, :tenant_id, "default"),
        actor_id: Map.get(attrs, :actor_id, "system")
      )

    delivery
    |> Ecto.Changeset.change(%{
      status: Map.get(attrs, :status, delivery.status),
      orchestration_state: Map.get(attrs, :orchestration_state, delivery.orchestration_state),
      next_eligible_at: next_eligible_at || delivery.next_eligible_at,
      suppression_reason: Map.get(attrs, :suppression_reason, delivery.suppression_reason),
      metadata: metadata,
      inserted_at: inserted_at || delivery.inserted_at,
      updated_at: updated_at || delivery.updated_at
    })
    |> Repo.update!()
  end

  defp normalize_datetime(nil), do: nil

  defp normalize_datetime(%DateTime{} = value) do
    %{DateTime.truncate(value, :microsecond) | microsecond: {elem(value.microsecond, 0), 6}}
  end

  # ---- plan_delivery/2 ----

  describe "plan_delivery/2" do
    test "creates a delivery row with status :pending" do
      %{notification: notification} = insert_notification()

      assert {:ok, %Delivery{} = delivery} =
               Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")

      assert delivery.channel == "in_app"
      assert delivery.status == :pending
      assert delivery.notification_id == notification.id
    end

    test "creates a ready orchestration row with explicit planning fields" do
      %{notification: notification} = insert_notification()

      assert {:ok, %Delivery{} = delivery} =
               Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")

      assert delivery.orchestration_state == :ready
      assert delivery.planning_reason == nil
      assert delivery.planning_context == nil
      assert delivery.next_eligible_at == nil
    end

    test "is idempotent: duplicate calls create exactly one row" do
      %{notification: notification} = insert_notification()

      assert {:ok, _} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      assert {:ok, _} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")

      count =
        Repo.aggregate(
          from(d in Delivery, where: d.notification_id == ^notification.id),
          :count,
          :id
        )

      assert count == 1
    end

    test "accepts channel as string" do
      %{notification: notification} = insert_notification()

      assert {:ok, %Delivery{channel: "email"}} =
               Deliveries.plan_delivery(notification.id, "email", tenant_id: "default", actor_id: "system")
    end

    test "allows different channels for same notification" do
      %{notification: notification} = insert_notification()

      assert {:ok, _} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      assert {:ok, _} = Deliveries.plan_delivery(notification.id, :email, tenant_id: "default", actor_id: "system")

      count =
        Repo.aggregate(
          from(d in Delivery, where: d.notification_id == ^notification.id),
          :count,
          :id
        )

      assert count == 2
    end
  end

  # ---- get_delivery!/1 ----

  describe "get_delivery!/1" do
    test "fetches delivery by id" do
      %{notification: notification} = insert_notification()
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")

      fetched = Deliveries.get_delivery!(delivery.id)
      assert fetched.id == delivery.id
    end

    test "raises if not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Deliveries.get_delivery!(Ecto.UUID.generate())
      end
    end
  end

  # ---- transition_status/2 ----

  describe "transition_status/2" do
    setup :insert_notification

    test "transitions pending → dispatched", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      assert {:ok, updated} = Deliveries.transition_status(delivery, :dispatched)
      assert updated.status == :dispatched
    end

    test "transitions pending → suppressed", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      assert {:ok, updated} = Deliveries.transition_status(delivery, :suppressed)
      assert updated.status == :suppressed
    end

    test "transitions pending → cancelled", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      assert {:ok, updated} = Deliveries.transition_status(delivery, :cancelled)
      assert updated.status == :cancelled
    end

    test "transitions dispatched → succeeded", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      assert {:ok, updated} = Deliveries.transition_status(dispatched, :succeeded)
      assert updated.status == :succeeded
    end

    test "transitions dispatched → failed", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      assert {:ok, updated} = Deliveries.transition_status(dispatched, :failed)
      assert updated.status == :failed
    end

    test "transitions failed → dispatched (retry)", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, failed} = Deliveries.transition_status(dispatched, :failed)
      assert {:ok, updated} = Deliveries.transition_status(failed, :dispatched)
      assert updated.status == :dispatched
    end

    test "rejects invalid transition: pending → succeeded", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")

      assert {:error, {:invalid_transition, from: :pending, to: :succeeded}} =
               Deliveries.transition_status(delivery, :succeeded)
    end

    test "rejects invalid transition: succeeded → dispatched", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, succeeded} = Deliveries.transition_status(dispatched, :succeeded)

      assert {:error, {:invalid_transition, from: :succeeded, to: :dispatched}} =
               Deliveries.transition_status(succeeded, :dispatched)
    end

    test "rejects general-path failed → cancelled (reserved for exhaust_delivery/1)", %{
      notification: notification
    } do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, failed} = Deliveries.transition_status(dispatched, :failed)

      assert {:error, {:invalid_transition, from: :failed, to: :cancelled}} =
               Deliveries.transition_status(failed, :cancelled)
    end
  end

  # ---- terminal_states/0 ----

  describe "terminal_states/0" do
    test "returns the canonical terminal-state list" do
      assert Deliveries.terminal_states() == [:succeeded, :suppressed, :cancelled, :digested]
    end
  end

  # ---- exhaust_delivery/1 ----

  describe "exhaust_delivery/1" do
    setup :insert_notification

    test "transitions :failed → :cancelled with retries_exhausted suppression_reason", %{
      notification: notification
    } do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, failed} = Deliveries.transition_status(dispatched, :failed)

      assert {:ok, exhausted} = Deliveries.exhaust_delivery(failed)
      assert exhausted.status == :cancelled
      assert exhausted.suppression_reason == "retries_exhausted"
    end

    test "records policy_checkpoint=\"perform\" in metadata", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, failed} = Deliveries.transition_status(dispatched, :failed)

      {:ok, exhausted} = Deliveries.exhaust_delivery(failed)
      assert exhausted.metadata["policy_checkpoint"] == "perform"
    end

    test "rejects exhaust from :pending", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")

      assert {:error, {:invalid_exhaust_from, :pending}} =
               Deliveries.exhaust_delivery(delivery)
    end

    test "rejects exhaust from :succeeded", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, succeeded} = Deliveries.transition_status(dispatched, :succeeded)

      assert {:error, {:invalid_exhaust_from, :succeeded}} =
               Deliveries.exhaust_delivery(succeeded)
    end

    test "rejects exhaust from :dispatched", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:error, {:invalid_exhaust_from, :dispatched}} =
               Deliveries.exhaust_delivery(dispatched)
    end

    test "preserves prior metadata keys (Phase 10 correlation_id/event_id)", %{
      notification: notification
    } do
      {:ok, delivery} =
        Deliveries.plan_delivery(notification.id, :in_app,
          correlation_id: "corr-123",
          event_id: "evt-456",
          notification_key: "test.notification",
          tenant_id: "default",
          actor_id: "system"
        )

      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, failed} = Deliveries.transition_status(dispatched, :failed)

      {:ok, exhausted} = Deliveries.exhaust_delivery(failed)
      assert exhausted.metadata["correlation_id"] == "corr-123"
      assert exhausted.metadata["event_id"] == "evt-456"
      assert exhausted.metadata["notification_key"] == "test.notification"
      assert exhausted.metadata["policy_checkpoint"] == "perform"
    end
  end

  describe "Phase 22 recovery queries" do
    test "list_recoverable_events/1 returns only aged events with notifications and zero deliveries" do
      now = ~U[2026-04-28 18:00:00Z]
      old_time = ~U[2026-04-28 17:45:00Z]
      recent_time = ~U[2026-04-28 17:59:30Z]

      recoverable_event =
        insert_event(
          notification_key: "ops.recoverable.event",
          idempotency_key: "event-gap-#{System.unique_integer()}",
          inserted_at: old_time,
          updated_at: old_time
        )

      _recoverable_notification =
        insert_notification_for_event(recoverable_event,
          recipient_identity: "user:event-gap",
          inserted_at: old_time,
          updated_at: old_time
        )

      recent_event =
        insert_event(
          notification_key: "ops.recent.event",
          idempotency_key: "recent-gap-#{System.unique_integer()}",
          inserted_at: recent_time,
          updated_at: recent_time
        )

      _recent_notification =
        insert_notification_for_event(recent_event,
          recipient_identity: "user:event-gap-recent",
          inserted_at: recent_time,
          updated_at: recent_time
        )

      planned_event =
        insert_event(
          notification_key: "ops.planned.event",
          idempotency_key: "planned-gap-#{System.unique_integer()}",
          inserted_at: old_time,
          updated_at: old_time
        )

      planned_notification =
        insert_notification_for_event(planned_event,
          recipient_identity: "user:event-has-delivery",
          inserted_at: old_time,
          updated_at: old_time
        )

      _planned_delivery =
        insert_delivery(
          notification: planned_notification,
          updated_at: old_time,
          inserted_at: old_time
        )

      recoverable_ids =
        Deliveries.list_recoverable_events(now: now, older_than: 60)
        |> Enum.map(& &1.id)

      assert recoverable_event.id in recoverable_ids
      refute recent_event.id in recoverable_ids
      refute planned_event.id in recoverable_ids
    end

    test "list_recoverable_deliveries/1 returns only aged pending ready rows" do
      now = ~U[2026-04-28 18:00:00Z]
      old_time = ~U[2026-04-28 17:45:00Z]
      recent_time = ~U[2026-04-28 17:59:30Z]

      recoverable_delivery =
        insert_delivery(
          updated_at: old_time,
          inserted_at: old_time,
          status: :pending,
          orchestration_state: :ready
        )

      recent_delivery =
        insert_delivery(
          updated_at: recent_time,
          inserted_at: recent_time,
          status: :pending,
          orchestration_state: :ready
        )

      recoverable_ids =
        Deliveries.list_recoverable_deliveries(now: now, older_than: 60)
        |> Enum.map(& &1.id)

      assert recoverable_delivery.id in recoverable_ids
      refute recent_delivery.id in recoverable_ids
    end

    test "list_recoverable_deliveries/1 excludes terminal, dispatched, and deferred rows" do
      now = ~U[2026-04-28 18:00:00Z]
      old_time = ~U[2026-04-28 17:45:00Z]

      recoverable_delivery =
        insert_delivery(
          updated_at: old_time,
          inserted_at: old_time,
          status: :pending,
          orchestration_state: :ready
        )

      dispatched_delivery =
        insert_delivery(
          updated_at: old_time,
          inserted_at: old_time,
          status: :dispatched,
          orchestration_state: :ready
        )

      deferred_delivery =
        insert_delivery(
          updated_at: old_time,
          inserted_at: old_time,
          status: :pending,
          orchestration_state: :deferred,
          next_eligible_at: ~U[2026-04-28 17:50:00Z]
        )

      succeeded_delivery =
        insert_delivery(
          updated_at: old_time,
          inserted_at: old_time,
          status: :succeeded,
          orchestration_state: :ready
        )

      suppressed_delivery =
        insert_delivery(
          updated_at: old_time,
          inserted_at: old_time,
          status: :suppressed,
          orchestration_state: :ready,
          suppression_reason: "policy_blocked"
        )

      cancelled_delivery =
        insert_delivery(
          updated_at: old_time,
          inserted_at: old_time,
          status: :cancelled,
          orchestration_state: :ready,
          suppression_reason: "superseded"
        )

      digested_delivery =
        insert_delivery(
          updated_at: old_time,
          inserted_at: old_time,
          status: :digested,
          orchestration_state: :ready
        )

      recoverable_ids =
        Deliveries.list_recoverable_deliveries(now: now, older_than: 60)
        |> Enum.map(& &1.id)

      assert recoverable_delivery.id in recoverable_ids
      refute dispatched_delivery.id in recoverable_ids
      refute deferred_delivery.id in recoverable_ids
      refute succeeded_delivery.id in recoverable_ids
      refute suppressed_delivery.id in recoverable_ids
      refute cancelled_delivery.id in recoverable_ids
      refute digested_delivery.id in recoverable_ids
    end
  end

  describe "Phase 22 recovery guards" do
    test "begin_recovery/2 stamps recovery metadata on the canonical row" do
      recovered_at = ~U[2026-04-28 18:00:00Z]

      delivery =
        insert_delivery(
          updated_at: ~U[2026-04-28 17:45:00Z],
          inserted_at: ~U[2026-04-28 17:45:00Z],
          status: :pending,
          orchestration_state: :ready,
          metadata: %{"notification_key" => "ops.recovery.delivery"}
        )

      assert {:ok, recovered_delivery} =
               Deliveries.begin_recovery(delivery,
                 now: recovered_at,
                 older_than: 60,
                 source: "operator_console",
                 reason: "dispatch_stuck"
               )

      assert recovered_delivery.id == delivery.id
      assert recovered_delivery.metadata["notification_key"] == "ops.recovery.delivery"
      assert recovered_delivery.metadata["recovery_source"] == "operator_console"
      assert recovered_delivery.metadata["recovery_reason"] == "dispatch_stuck"
      assert recovered_delivery.metadata["recovered_at"] == "2026-04-28T18:00:00.000000Z"
    end

    test "begin_recovery/2 returns {:noop, delivery} after recovery metadata already exists" do
      recovered_at = ~U[2026-04-28 18:00:00Z]

      delivery =
        insert_delivery(
          updated_at: ~U[2026-04-28 17:45:00Z],
          inserted_at: ~U[2026-04-28 17:45:00Z],
          status: :pending,
          orchestration_state: :ready
        )

      assert {:ok, recovered_delivery} =
               Deliveries.begin_recovery(delivery,
                 now: recovered_at,
                 older_than: 60,
                 source: "operator_console",
                 reason: "dispatch_stuck"
               )

      assert {:noop, noop_delivery} =
               Deliveries.begin_recovery(delivery.id,
                 now: ~U[2026-04-28 18:01:00Z],
                 older_than: 60,
                 source: "operator_console",
                 reason: "dispatch_stuck"
               )

      assert noop_delivery.id == delivery.id
      assert noop_delivery.metadata["recovery_source"] == "operator_console"
      assert noop_delivery.metadata["recovery_reason"] == "dispatch_stuck"
      assert noop_delivery.metadata["recovered_at"] == "2026-04-28T18:00:00.000000Z"
      assert recovered_delivery.metadata == noop_delivery.metadata
    end
  end

  # ---- record_attempt/2 ----

  describe "record_attempt/2" do
    setup :insert_notification

    test "atomically creates attempt row and updates delivery status to :succeeded", %{
      notification: notification
    } do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:ok, %{delivery: updated_delivery, attempt: attempt}} =
               Deliveries.record_attempt(dispatched, %{outcome: :succeeded})

      assert updated_delivery.status == :succeeded
      assert attempt.outcome == :succeeded
      assert attempt.delivery_id == dispatched.id

      # Verify attempt row exists in DB
      assert Repo.get(DeliveryAttempt, attempt.id) != nil
    end

    test "atomically creates attempt row and updates delivery status to :failed", %{
      notification: notification
    } do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:ok, %{delivery: updated_delivery, attempt: attempt}} =
               Deliveries.record_attempt(dispatched, %{outcome: :failed})

      assert updated_delivery.status == :failed
      assert attempt.outcome == :failed
    end

    test "rolls back attempt insert if status transition fails", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")

      # Attempt to record from :pending status with outcome :succeeded;
      # transition pending → succeeded is invalid, forcing a rollback.
      result = Deliveries.record_attempt(delivery, %{outcome: :succeeded})

      assert {:error, :delivery, {:invalid_transition, from: :pending, to: :succeeded}, _} =
               result

      # No attempt row should have been persisted
      assert Repo.aggregate(
               from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id),
               :count,
               :id
             ) == 0
    end

    test "stores provider_response in attempt row", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      {:ok, %{attempt: attempt}} =
        Deliveries.record_attempt(dispatched, %{
          outcome: :succeeded,
          provider_response: %{"message_id" => "abc123"}
        })

      assert attempt.provider_response == %{"message_id" => "abc123"}
    end
  end
end
