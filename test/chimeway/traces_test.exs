defmodule Chimeway.TracesTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Deliveries, Delivery, Repo, Traces}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Traces.Explanation

  # --- Helpers ---

  defp insert_event(attrs \\ %{}) do
    {:ok, event} =
      Repo.insert(%Event{
        notification_key: Map.get(attrs, :notification_key, "test_notifier"),
        notification_version: 1,
        idempotency_key: Map.get(attrs, :idempotency_key, "key-#{System.unique_integer()}"),
        payload: %{},
        correlation_id: Map.get(attrs, :correlation_id)
      })

    event
  end

  defp insert_notification(event, recipient \\ nil) do
    {:ok, notification} =
      Repo.insert(%Notification{
        event_id: event.id,
        recipient_identity: recipient || "user:#{System.unique_integer()}",
        recipient_type: "user",
        metadata: %{}
      })

    notification
  end

  defp plan_delivery(notification, channel \\ :in_app) do
    {:ok, delivery} = Deliveries.plan_delivery(notification.id, channel)
    delivery
  end

  defp succeed_delivery(delivery) do
    {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

    {:ok, %{delivery: updated}} =
      Deliveries.record_attempt(dispatched, %{outcome: :succeeded, provider_response: %{}})

    updated
  end

  defp fail_delivery(delivery) do
    {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

    {:ok, %{delivery: updated}} =
      Deliveries.record_attempt(dispatched, %{outcome: :failed, provider_response: %{}})

    updated
  end

  defp suppress_delivery(delivery, reason) do
    {:ok, suppressed} = Deliveries.suppress_delivery(delivery, reason)
    suppressed
  end

  # --- get_trace/1 ---

  describe "get_trace/1" do
    test "returns {:ok, event} with preloaded associations" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _succeeded = succeed_delivery(delivery)

      assert {:ok, loaded} = Traces.get_trace(event.id)
      assert loaded.id == event.id
      assert [loaded_notification] = loaded.notifications
      assert loaded_notification.id == notification.id
      assert [loaded_delivery] = loaded_notification.deliveries
      assert loaded_delivery.id == delivery.id
      assert length(loaded_delivery.attempts) == 1
    end

    test "returns {:error, :not_found} for unknown event_id" do
      assert {:error, :not_found} = Traces.get_trace(Ecto.UUID.generate())
    end

    test "includes correlation_id on event" do
      event = insert_event(%{correlation_id: "req-abc-123"})

      assert {:ok, loaded} = Traces.get_trace(event.id)
      assert loaded.correlation_id == "req-abc-123"
    end
  end

  # --- find_traces_for_recipient/2 ---

  describe "find_traces_for_recipient/2" do
    test "returns notifications for the given recipient" do
      event = insert_event()
      notification = insert_notification(event, "user:42")

      results = Traces.find_traces_for_recipient("user:42")

      assert Enum.any?(results, &(&1.id == notification.id))
    end

    test "filters by notification_key option" do
      event_a = insert_event(%{notification_key: "order_shipped"})
      event_b = insert_event(%{notification_key: "password_reset"})
      notification_a = insert_notification(event_a, "user:99")
      _notification_b = insert_notification(event_b, "user:99")

      results = Traces.find_traces_for_recipient("user:99", notification_key: "order_shipped")

      assert length(results) == 1
      assert hd(results).id == notification_a.id
    end

    test "respects limit option" do
      for _ <- 1..5 do
        e = insert_event()
        insert_notification(e, "user:limited")
      end

      results = Traces.find_traces_for_recipient("user:limited", limit: 3)
      assert length(results) == 3
    end

    test "returns [] for unknown recipient" do
      assert [] = Traces.find_traces_for_recipient("user:nonexistent")
    end
  end

  # --- find_traces_by_correlation_id/1 ---

  describe "find_traces_by_correlation_id/1" do
    test "returns matching events preloaded" do
      event = insert_event(%{correlation_id: "req-xyz"})
      _notification = insert_notification(event)

      results = Traces.find_traces_by_correlation_id("req-xyz")

      assert Enum.any?(results, &(&1.id == event.id))
      assert [loaded] = Enum.filter(results, &(&1.id == event.id))
      assert is_list(loaded.notifications)
    end

    test "returns [] for unknown correlation_id" do
      assert [] = Traces.find_traces_by_correlation_id("nonexistent-correlation")
    end

    test "OPS-01: get_trace and correlation lookup recover the same event identity" do
      # OPS-01: trigger-facing correlation pointers must map to the same durable event identity.
      event = insert_event(%{correlation_id: "req-ops-01-link"})
      _notification = insert_notification(event, "user:ops-01")

      assert {:ok, loaded} = Traces.get_trace(event.id)

      events = Traces.find_traces_by_correlation_id("req-ops-01-link")
      assert Enum.any?(events, &(&1.id == loaded.id))
    end
  end

  describe "trace delivery id contract for trigger outcomes" do
    test "OPS-01: trace preloads expose delivery ids as UUID lists suitable for equality checks" do
      # OPS-01: trace delivery ids should be directly comparable to trigger trace.delivery_ids.
      event = insert_event(%{correlation_id: "req-delivery-id-contract"})
      notification = insert_notification(event, "user:delivery-ids")
      delivery_one = plan_delivery(notification, :in_app)
      delivery_two = plan_delivery(notification, :email)

      assert {:ok, loaded} = Traces.get_trace(event.id)

      trace_delivery_ids =
        loaded.notifications
        |> Enum.flat_map(fn loaded_notification ->
          Enum.map(loaded_notification.deliveries, & &1.id)
        end)
        |> Enum.sort()

      durable_delivery_ids =
        Repo.all(
          from(d in Delivery,
            join: n in Notification,
            on: d.notification_id == n.id,
            where: n.event_id == ^event.id,
            select: d.id
          )
        )
        |> Enum.sort()

      assert MapSet.new(trace_delivery_ids) == MapSet.new([delivery_one.id, delivery_two.id])
      assert MapSet.new(trace_delivery_ids) == MapSet.new(durable_delivery_ids)

      assert Enum.all?(trace_delivery_ids, &is_binary/1)
    end
  end

  # --- explain_delivery/1 ---

  describe "explain_delivery/1 — succeeded delivery" do
    test "returns correct explanation struct" do
      event = insert_event(%{correlation_id: "req-success"})
      notification = insert_notification(event, "user:success")
      delivery = plan_delivery(notification)
      _succeeded = succeed_delivery(delivery)

      assert {:ok, %Explanation{} = exp} = Traces.explain_delivery(delivery.id)
      assert exp.delivery_id == delivery.id
      assert exp.event_id == event.id
      assert exp.correlation_id == "req-success"
      assert exp.notification_key == "test_notifier"
      assert exp.recipient_id == "user:success"
      assert exp.channel == "in_app"
      assert exp.status == :succeeded
      assert exp.suppression_reason == nil
      assert %{outcome: :succeeded} = exp.last_attempt
      assert is_list(exp.timeline)
    end

    test "timeline contains :event_created, :notification_created, :delivery_planned, :attempt_recorded" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _succeeded = succeed_delivery(delivery)

      assert {:ok, exp} = Traces.explain_delivery(delivery.id)
      event_names = Enum.map(exp.timeline, & &1.event)

      assert :event_created in event_names
      assert :notification_created in event_names
      assert :delivery_planned in event_names
      assert :attempt_recorded in event_names
    end

    test "timeline is sorted ascending by timestamp" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _succeeded = succeed_delivery(delivery)

      assert {:ok, exp} = Traces.explain_delivery(delivery.id)
      timestamps = Enum.map(exp.timeline, & &1.at)
      assert timestamps == Enum.sort(timestamps, DateTime)
    end
  end

  describe "explain_delivery/1 — suppressed delivery" do
    test "returns suppressed status with reason, no last_attempt" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _suppressed = suppress_delivery(delivery, :channel_disabled)

      assert {:ok, %Explanation{} = exp} = Traces.explain_delivery(delivery.id)
      assert exp.status == :suppressed
      assert exp.suppression_reason == "channel_disabled"
      assert exp.last_attempt == nil
    end

    test "timeline includes :suppressed entry" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _suppressed = suppress_delivery(delivery, :channel_disabled)

      assert {:ok, exp} = Traces.explain_delivery(delivery.id)
      event_names = Enum.map(exp.timeline, & &1.event)
      assert :suppressed in event_names
    end
  end

  describe "explain_delivery/1 — failed delivery" do
    test "returns failed status with last_attempt outcome" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _failed = fail_delivery(delivery)

      assert {:ok, %Explanation{} = exp} = Traces.explain_delivery(delivery.id)
      assert exp.status == :failed
      assert exp.suppression_reason == nil
      assert %{outcome: :failed} = exp.last_attempt
    end
  end

  describe "explain_delivery/1 — custom channel safety" do
    test "OPS-01: returns explanation for custom string channel without raising" do
      # OPS-01: operator explainability must remain available for valid custom channels.
      event = insert_event(%{correlation_id: "req-custom-channel"})
      notification = insert_notification(event, "user:webhook")
      delivery = plan_delivery(notification, "webhook_partner")

      assert {:ok, %Explanation{channel: "webhook_partner"}} =
               Traces.explain_delivery(delivery.id)
    end

    test "OPS-01: timeline keeps :delivery_planned for custom string channel explanations" do
      # OPS-01: timeline event coverage must include planning for custom channels.
      event = insert_event()
      notification = insert_notification(event, "user:webhook-timeline")
      delivery = plan_delivery(notification, "webhook_partner")

      assert {:ok, %Explanation{channel: "webhook_partner", timeline: timeline}} =
               Traces.explain_delivery(delivery.id)

      assert :delivery_planned in Enum.map(timeline, & &1.event)
    end
  end

  describe "explain_delivery/1 — not found" do
    test "returns {:error, :not_found} for unknown delivery_id" do
      assert {:error, :not_found} = Traces.explain_delivery(Ecto.UUID.generate())
    end
  end

  describe "explain_delivery/1 — REL-02 D-07 attempt_number and error_class fields" do
    test "last_attempt surfaces attempt_number and error_class on a temporary failure" do
      ctx = create_pending_delivery_for_traces()

      {:ok, dispatched} = Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: failed}} =
        Deliveries.record_attempt(dispatched, %{
          outcome: :failed,
          error_class: "temporary",
          provider_response: %{reason: "x"}
        })

      assert {:ok, %Chimeway.Traces.Explanation{last_attempt: last_attempt, timeline: timeline}} =
               Chimeway.Traces.explain_delivery(failed.id)

      assert last_attempt.outcome == :failed
      assert last_attempt.attempt_number == 1
      assert last_attempt.error_class == "temporary"

      attempt_entries = Enum.filter(timeline, fn entry -> entry.event == :attempt_recorded end)
      assert length(attempt_entries) == 1
      [%{detail: detail}] = attempt_entries
      assert detail.outcome == :failed
      assert detail.attempt_number == 1
      assert detail.error_class == "temporary"
    end

    test "last_attempt has nil error_class on a succeeded delivery" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: succeeded}} =
        Deliveries.record_attempt(dispatched, %{
          outcome: :succeeded,
          error_class: nil,
          provider_response: %{}
        })

      assert {:ok, %Chimeway.Traces.Explanation{last_attempt: last_attempt}} =
               Chimeway.Traces.explain_delivery(succeeded.id)

      assert last_attempt.outcome == :succeeded
      assert last_attempt.error_class == nil
      assert last_attempt.attempt_number == 1
    end

    test "last_attempt reflects the most recent attempt across multiple records" do
      ctx = create_pending_delivery_for_traces()

      # Record three attempts: failed temporary, failed temporary, succeeded.
      {:ok, dispatched_a} = Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: failed_a}} =
        Deliveries.record_attempt(dispatched_a, %{
          outcome: :failed,
          error_class: "temporary",
          provider_response: %{seq: 1}
        })

      {:ok, dispatched_b} = Deliveries.transition_status(failed_a, :dispatched)

      {:ok, %{delivery: failed_b}} =
        Deliveries.record_attempt(dispatched_b, %{
          outcome: :failed,
          error_class: "temporary",
          provider_response: %{seq: 2}
        })

      {:ok, dispatched_c} = Deliveries.transition_status(failed_b, :dispatched)

      {:ok, %{delivery: succeeded}} =
        Deliveries.record_attempt(dispatched_c, %{
          outcome: :succeeded,
          error_class: nil,
          provider_response: %{seq: 3}
        })

      assert {:ok, %Chimeway.Traces.Explanation{last_attempt: last_attempt}} =
               Chimeway.Traces.explain_delivery(succeeded.id)

      assert last_attempt.outcome == :succeeded
      assert last_attempt.attempt_number == 3
      assert last_attempt.error_class == nil
    end
  end

  describe "explain_delivery/1 — Phase 14 trace surface drift fixes (WR-05, WR-06)" do
    test "WR-05 regression: last_attempt_summary selects by attempt_number when inserted_at ties" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Chimeway.Deliveries.transition_status(ctx.delivery, :dispatched)

      # B1 fix: insert two attempts with the SAME inserted_at value. The schema field
      # type is :utc_datetime_usec (lib/chimeway/delivery_attempt.ex:43), which requires
      # microsecond precision ({microseconds, scale} where scale == 6). We truncate to
      # second then set microsecond: {0, 6} — both rows store the same bytewise-identical
      # timestamp with zero microseconds at usec scale. There is NO :updated_at field on
      # DeliveryAttempt (moduledoc line 4: "No updated_at — attempts are never mutated.")
      # — do NOT try to put_change/3 it.
      #
      # The changeset's put_inserted_at/1 helper (lib/chimeway/delivery_attempt.ex:71-77)
      # preserves an explicitly-set :inserted_at via get_field check, so
      # `|> Ecto.Changeset.put_change(:inserted_at, shared_at)` is the right wedge.
      shared_at =
        DateTime.utc_now()
        |> DateTime.truncate(:second)
        |> then(fn dt -> %{dt | microsecond: {0, 6}} end)

      {:ok, %Chimeway.DeliveryAttempt{} = first} =
        %Chimeway.DeliveryAttempt{}
        |> Chimeway.DeliveryAttempt.changeset(%{
          delivery_id: dispatched.id,
          outcome: :failed,
          error_class: "temporary",
          attempt_number: 1,
          provider_response: %{seq: 1}
        })
        |> Ecto.Changeset.put_change(:inserted_at, shared_at)
        |> Chimeway.Repo.insert()

      {:ok, %Chimeway.DeliveryAttempt{} = second} =
        %Chimeway.DeliveryAttempt{}
        |> Chimeway.DeliveryAttempt.changeset(%{
          delivery_id: dispatched.id,
          outcome: :succeeded,
          error_class: nil,
          attempt_number: 2,
          provider_response: %{seq: 2}
        })
        |> Ecto.Changeset.put_change(:inserted_at, shared_at)
        |> Chimeway.Repo.insert()

      # Sanity: tied inserted_at would make Enum.max_by(_, & &1.inserted_at) non-deterministic.
      # Both rows store the same %DateTime{} value (microseconds {0, 6} on both).
      assert first.inserted_at == second.inserted_at,
             "test setup invariant: both attempts must share inserted_at to exercise the tie-break. " <>
               "first=#{inspect(first.inserted_at)} second=#{inspect(second.inserted_at)}"

      assert {:ok, %Chimeway.Traces.Explanation{last_attempt: last_attempt}} =
               Chimeway.Traces.explain_delivery(dispatched.id)

      # Post-fix: max_by attempt_number wins. attempt 2 (succeeded) is "last".
      # Pre-fix: max_by inserted_at ties; result depends on list ordering.
      assert last_attempt.attempt_number == 2
      assert last_attempt.outcome == :succeeded
    end

    test "WR-06 regression: :cancelled with retries_exhausted emits a :cancelled timeline entry" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Chimeway.Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: failed}} =
        Chimeway.Deliveries.record_attempt(dispatched, %{
          outcome: :failed,
          error_class: "temporary",
          provider_response: %{}
        })

      {:ok, exhausted} = Chimeway.Deliveries.exhaust_delivery(failed)
      assert exhausted.status == :cancelled
      assert exhausted.suppression_reason == "retries_exhausted"

      assert {:ok, %Chimeway.Traces.Explanation{timeline: timeline}} =
               Chimeway.Traces.explain_delivery(exhausted.id)

      cancelled_entries = Enum.filter(timeline, fn entry -> entry.event == :cancelled end)
      assert length(cancelled_entries) == 1
      [%{at: at, detail: detail}] = cancelled_entries
      assert detail.reason == "retries_exhausted"
      assert at == exhausted.updated_at
    end

    test "WR-06 regression: :cancelled with permanent_failure emits a :cancelled timeline entry" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Chimeway.Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: cancelled}} =
        Chimeway.Deliveries.record_attempt(dispatched, %{
          outcome: :rejected,
          error_class: "permanent",
          provider_response: %{}
        })

      assert cancelled.status == :cancelled
      assert cancelled.suppression_reason == "permanent_failure"

      assert {:ok, %Chimeway.Traces.Explanation{timeline: timeline}} =
               Chimeway.Traces.explain_delivery(cancelled.id)

      cancelled_entries = Enum.filter(timeline, fn entry -> entry.event == :cancelled end)
      assert length(cancelled_entries) == 1
      [%{detail: detail}] = cancelled_entries
      assert detail.reason == "permanent_failure"
    end

    test "WR-06 regression: :cancelled with bounced emits a :cancelled timeline entry" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Chimeway.Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: cancelled}} =
        Chimeway.Deliveries.record_attempt(dispatched, %{
          outcome: :bounced,
          error_class: "bounced",
          provider_response: %{}
        })

      assert cancelled.status == :cancelled
      assert cancelled.suppression_reason == "bounced"

      assert {:ok, %Chimeway.Traces.Explanation{timeline: timeline}} =
               Chimeway.Traces.explain_delivery(cancelled.id)

      cancelled_entries = Enum.filter(timeline, fn entry -> entry.event == :cancelled end)
      assert length(cancelled_entries) == 1
      [%{detail: detail}] = cancelled_entries
      assert detail.reason == "bounced"
    end

    test "WR-06 regression: :suppressed deliveries do NOT emit a :cancelled timeline entry (no double-counting)" do
      ctx = create_pending_delivery_for_traces()

      {:ok, suppressed} =
        Chimeway.Deliveries.suppress_delivery(ctx.delivery, :channel_disabled,
          checkpoint: :perform
        )

      assert suppressed.status == :suppressed

      assert {:ok, %Chimeway.Traces.Explanation{timeline: timeline}} =
               Chimeway.Traces.explain_delivery(suppressed.id)

      cancelled_entries = Enum.filter(timeline, fn entry -> entry.event == :cancelled end)

      assert cancelled_entries == [],
             "expected no :cancelled entries for a :suppressed delivery; got #{inspect(cancelled_entries)}"

      suppressed_entries = Enum.filter(timeline, fn entry -> entry.event == :suppressed end)
      assert length(suppressed_entries) == 1
    end
  end

  describe "opts propagation" do
    test "get_trace/2 passes opts to Repo" do
      assert_raise Postgrex.Error,
                   ~r/relation "nonexistent_schema.chimeway_events" does not exist/,
                   fn ->
                     Traces.get_trace(Ecto.UUID.generate(), prefix: "nonexistent_schema")
                   end
    end

    test "find_traces_for_recipient/2 passes opts to Repo" do
      assert_raise Postgrex.Error,
                   ~r/relation "nonexistent_schema.chimeway_notifications" does not exist/,
                   fn ->
                     Traces.find_traces_for_recipient("user:123", prefix: "nonexistent_schema")
                   end
    end

    test "find_traces_by_correlation_id/2 passes opts to Repo" do
      assert_raise Postgrex.Error,
                   ~r/relation "nonexistent_schema.chimeway_events" does not exist/,
                   fn ->
                     Traces.find_traces_by_correlation_id("req-xyz", prefix: "nonexistent_schema")
                   end
    end

    test "explain_delivery/2 passes opts to Repo" do
      assert_raise Postgrex.Error,
                   ~r/relation "nonexistent_schema.chimeway_deliveries" does not exist/,
                   fn ->
                     Traces.explain_delivery(Ecto.UUID.generate(), prefix: "nonexistent_schema")
                   end
    end
  end

  describe "Phase 22 recovery explainability and outcome analytics" do
    test "explain_delivery surfaces durable recovery facts after a delivery is claimed for recovery" do
      ctx = create_pending_delivery_for_traces()
      recovered_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      assert {:ok, recovered} =
               Deliveries.begin_recovery(ctx.delivery,
                 now: recovered_at,
                 older_than: 0,
                 source: "ops_console",
                 reason: "worker_missed"
               )

      assert {:ok, %Explanation{} = explanation} = Traces.explain_delivery(recovered.id)

      recovered_entries = Enum.filter(explanation.timeline, &(&1.event == :recovered))
      assert length(recovered_entries) == 1

      [%{at: timeline_recovered_at, detail: recovery_detail}] = recovered_entries

      assert DateTime.compare(timeline_recovered_at, recovered_at) == :eq
      assert recovery_detail.recovery_source == "ops_console"
      assert recovery_detail.recovery_reason == "worker_missed"
      assert DateTime.compare(recovery_detail.recovered_at, recovered_at) == :eq
      refute Map.has_key?(recovery_detail, :payload)
      refute Map.has_key?(recovery_detail, :provider_response)
    end

    test "aggregate_outcomes groups counts by notification_key, channel, and lifecycle bucket" do
      _base = create_outcome_fixture("ops.analytics", "email")

      assert outcome_rows(notification_key: "ops.analytics", channel: "email") == [
               %{
                 notification_key: "ops.analytics",
                 channel: "email",
                 outcome: "delayed",
                 count: 1
               },
               %{
                 notification_key: "ops.analytics",
                 channel: "email",
                 outcome: "digested",
                 count: 1
               },
               %{
                 notification_key: "ops.analytics",
                 channel: "email",
                 outcome: "exhausted",
                 count: 1
               },
               %{notification_key: "ops.analytics", channel: "email", outcome: "failed", count: 1},
               %{notification_key: "ops.analytics", channel: "email", outcome: "sent", count: 1},
               %{
                 notification_key: "ops.analytics",
                 channel: "email",
                 outcome: "suppressed",
                 count: 1
               }
             ]
    end

    test "aggregate_outcomes keeps exhausted distinct from other cancelled outcomes" do
      _base = create_outcome_fixture("ops.cancelled", "email")

      exhausted =
        Traces.aggregate_outcomes(notification_key: "ops.cancelled", channel: "email")
        |> Enum.find(&(&1.outcome == "exhausted"))

      assert exhausted.count == 1

      refute Enum.any?(
               Traces.aggregate_outcomes(notification_key: "ops.cancelled", channel: "email"),
               &(&1.outcome == "cancelled")
             )
    end

    test "aggregate_outcomes counts delayed only while rows remain pending and deferred" do
      _base = create_outcome_fixture("ops.delayed", "email")

      assert [
               %{notification_key: "ops.delayed", channel: "email", outcome: "delayed", count: 1}
             ] =
               Traces.aggregate_outcomes(
                 notification_key: "ops.delayed",
                 channel: "email",
                 outcomes: ["delayed"]
               )
    end

    test "aggregate_outcomes returns payload-safe identifiers and counts only" do
      _base = create_outcome_fixture("ops.safe-surface", "email")

      rows = Traces.aggregate_outcomes(notification_key: "ops.safe-surface", channel: "email")

      assert Enum.all?(rows, fn row ->
               Map.keys(row) == [:channel, :count, :notification_key, :outcome]
             end)

      refute inspect(rows) =~ "provider_response"
      refute inspect(rows) =~ "secret"
      refute inspect(rows) =~ "payload"
    end
  end

  defp create_pending_delivery_for_traces do
    {:ok, event} =
      Chimeway.Repo.insert(%Chimeway.Events.Event{
        notification_key: "traces.attempt.fields.test",
        notification_version: 1,
        idempotency_key: "traces-#{System.unique_integer()}",
        payload: %{}
      })

    {:ok, notification} =
      Chimeway.Repo.insert(%Chimeway.Notifications.Notification{
        event_id: event.id,
        recipient_identity: "user:#{System.unique_integer()}",
        recipient_type: "user",
        metadata: %{}
      })

    {:ok, delivery} =
      %Chimeway.Delivery{}
      |> Chimeway.Delivery.changeset(%{
        notification_id: notification.id,
        channel: "in_app",
        status: :pending
      })
      |> Chimeway.Repo.insert()

    %{event: event, notification: notification, delivery: delivery}
  end

  defp create_outcome_fixture(notification_key, channel) do
    sent = insert_notification(insert_event(%{notification_key: notification_key}), "user:sent")

    suppressed =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:suppressed")

    delayed = insert_notification(insert_event(%{notification_key: notification_key}), "user:delayed")
    resumed = insert_notification(insert_event(%{notification_key: notification_key}), "user:resumed")

    digested =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:digested")

    failed = insert_notification(insert_event(%{notification_key: notification_key}), "user:failed")

    exhausted =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:exhausted")

    cancelled =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:cancelled")

    sent_delivery =
      sent
      |> plan_delivery(channel)
      |> succeed_delivery()

    _suppressed_delivery =
      suppressed
      |> plan_delivery(channel)
      |> suppress_delivery(:channel_disabled)

    delayed_delivery =
      delayed
      |> plan_delivery(channel)
      |> defer_delivery()

    resumed
    |> plan_delivery(channel)
    |> defer_delivery()
    |> resume_delivery()
    |> succeed_delivery()

    digested_delivery =
      digested
      |> plan_delivery(channel)
      |> digest_delivery()

    failed_delivery =
      failed
      |> plan_delivery(channel)
      |> fail_delivery()

    exhausted_delivery =
      exhausted
      |> plan_delivery(channel)
      |> fail_delivery()
      |> exhaust_delivery()

    _other_cancelled_delivery =
      cancelled
      |> plan_delivery(channel)
      |> cancel_delivery("manual")

    %{
      notification_key: notification_key,
      channel: channel,
      sent_delivery: sent_delivery,
      delayed_delivery: delayed_delivery,
      digested_delivery: digested_delivery,
      failed_delivery: failed_delivery,
      exhausted_delivery: exhausted_delivery
    }
  end

  defp defer_delivery(delivery) do
    {:ok, updated} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :deferred,
        planning_reason: "quiet_hours",
        planning_context: %{
          "rule_identity" => "quiet_hours",
          "time_zone" => "America/New_York",
          "payload" => %{"secret" => "ignored"}
        },
        next_eligible_at: ~U[2026-01-15 13:00:00.000000Z]
      })

    updated
  end

  defp resume_delivery(delivery) do
    {:ok, resumed} =
      Deliveries.resume_deferred_delivery(delivery.id,
        now: ~U[2026-01-15 13:05:00.000000Z],
        source: "scheduled_resume"
      )

    resumed
  end

  defp digest_delivery(delivery) do
    {:ok, held} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :digest_held,
        planning_reason: "digest_rule",
        planning_context: %{"rule_identity" => "digest_rule", "channel" => delivery.channel}
      })

    digest_delivery_id =
      held.channel
      |> insert_digest_delivery()
      |> Map.fetch!(:id)

    {:ok, digested} =
      Deliveries.mark_digested(held, digest_delivery_id, "digest_window_closed")

    digested
  end

  defp exhaust_delivery(delivery) do
    {:ok, exhausted} = Deliveries.exhaust_delivery(delivery)
    exhausted
  end

  defp cancel_delivery(delivery, reason) do
    {:ok, cancelled} =
      delivery
      |> Ecto.Changeset.change(%{status: :cancelled, suppression_reason: reason})
      |> Repo.update()

    cancelled
  end

  defp insert_digest_delivery(channel) do
    digest_event = insert_event(%{notification_key: "ops.digest.summary"})
    digest_notification = insert_notification(digest_event, "user:digest-summary")
    plan_delivery(digest_notification, channel)
  end

  defp outcome_rows(opts) do
    opts
    |> Traces.aggregate_outcomes()
    |> Enum.sort_by(&{&1.notification_key, &1.channel, &1.outcome})
  end
end
