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
end
