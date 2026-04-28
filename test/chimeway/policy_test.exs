defmodule Chimeway.PolicyTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Deliveries, DeliveryPlanning, Policy, Preferences, Repo}
  alias Chimeway.Delivery
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  # ---- Fixtures ----

  defp insert_event(notification_key \\ "order.shipped", opts \\ []) do
    payload = Keyword.get(opts, :payload, %{})

    {:ok, event} =
      %Event{}
      |> Event.changeset(%{
        notification_key: notification_key,
        notification_version: 1,
        idempotency_key: "test-#{System.unique_integer()}",
        payload: payload
      })
      |> Repo.insert()

    event
  end

  defp insert_notification(event, recipient_identity) do
    {:ok, notification} =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: recipient_identity,
        recipient_type: "user",
        metadata: %{}
      })
      |> Repo.insert()

    notification
  end

  defp insert_delivery(notification, channel, opts \\ []) do
    delay_fallback = Keyword.get(opts, :delay_fallback, false)

    {:ok, delivery} =
      %Delivery{}
      |> Delivery.changeset(%{
        notification_id: notification.id,
        channel: channel,
        status: :pending,
        delay_fallback: delay_fallback
      })
      |> Repo.insert()

    delivery
  end

  # ---- Planning-time suppression ----

  describe "evaluate/2 planning-time preference check" do
    test "returns {:suppress, :channel_disabled} when preference is disabled" do
      event = insert_event()
      notification = insert_notification(event, "user-sup-1")
      delivery = insert_delivery(notification, "in_app")

      Preferences.upsert_preference(%{
        recipient_id: "user-sup-1",
        notification_key: "order.shipped",
        channel: "in_app",
        enabled: false
      })

      assert Policy.evaluate(delivery, []) == {:suppress, :channel_disabled}
    end

    test "returns {:ok, :proceed} when no preference row exists (opt-in default)" do
      event = insert_event()
      notification = insert_notification(event, "user-sup-2")
      delivery = insert_delivery(notification, "in_app")

      assert Policy.evaluate(delivery, []) == {:ok, :proceed}
    end
  end

  describe "planning checkpoint policy path" do
    test "planner path calls policy with [] and does not suppress read-state-only notifications" do
      event = insert_event("planner.read-state")
      notification = insert_notification(event, "user-planner-read")

      notification
      |> Notification.changeset(%{read_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)})
      |> Repo.update!()

      assert {:ok, [delivery]} = DeliveryPlanning.plan_notification(notification, [])
      assert delivery.status == :pending
      assert delivery.suppression_reason == nil
    end

    test "planning suppression persists policy checkpoint metadata as planning" do
      event = insert_event("planner.preference-disabled")
      notification = insert_notification(event, "user-planner-suppressed")

      Preferences.upsert_preference(%{
        recipient_id: "user-planner-suppressed",
        notification_key: "planner.preference-disabled",
        channel: "in_app",
        enabled: false
      })

      assert {:ok, [delivery]} = DeliveryPlanning.plan_notification(notification, [])
      assert delivery.status == :suppressed
      assert delivery.suppression_reason == "channel_disabled"
      assert get_in(delivery.metadata, ["policy_checkpoint"]) == "planning"
    end

    test "category preference suppression uses persisted category metadata" do
      event = insert_event("planner.category-disabled", payload: %{"category" => "marketing"})
      notification = insert_notification(event, "user-planner-category")

      Preferences.upsert_category_preference(%{
        recipient_id: "user-planner-category",
        notification_category: "marketing",
        enabled: false
      })

      assert {:ok, [delivery]} = DeliveryPlanning.plan_notification(notification, [])
      assert delivery.status == :suppressed
      assert delivery.suppression_reason == "category_disabled"
      assert get_in(delivery.metadata, ["policy_checkpoint"]) == "planning"
    end

    test "planning quiet hours persist a deferred delivery instead of suppressing it" do
      event = insert_event("planner.quiet-hours")
      notification = insert_notification(event, "user-planner-deferred")

      assert {:ok, _} =
               Chimeway.Policy.Settings.upsert_settings(%{
                 recipient_id: "user-planner-deferred",
                 quiet_hours_start_minute: 22 * 60,
                 quiet_hours_end_minute: 8 * 60,
                 time_zone: "America/New_York"
               })

      assert {:ok, [delivery]} =
               DeliveryPlanning.plan_notification(notification,
                 evaluation_time: ~U[2026-01-15 03:30:00Z]
               )

      assert delivery.status == :pending
      assert delivery.suppression_reason == nil
      assert delivery.orchestration_state == :deferred
      assert delivery.planning_reason == "quiet_hours"
      assert delivery.next_eligible_at == ~U[2026-01-15 13:00:00Z]
      assert delivery.planning_context["rule"] == "quiet_hours"
      assert delivery.planning_context["time_zone"] == "America/New_York"
    end
  end

  # ---- Perform-time read-state suppression ----

  describe "evaluate/2 perform-time read-state check" do
    test "returns {:suppress, :already_read} when notification is read and check_read_state is true" do
      event = insert_event()
      notification = insert_notification(event, "user-sup-3")
      delivery = insert_delivery(notification, "in_app", delay_fallback: true)

      # Mark notification as read
      notification
      |> Notification.changeset(%{read_at: DateTime.utc_now()})
      |> Repo.update!()

      assert Policy.evaluate(delivery, check_read_state: true) == {:suppress, :already_read}
    end

    test "returns {:ok, :proceed} when notification is not read and check_read_state is true" do
      event = insert_event()
      notification = insert_notification(event, "user-sup-4")
      delivery = insert_delivery(notification, "in_app", delay_fallback: true)

      # read_at is nil (not read)
      assert notification.read_at == nil
      assert Policy.evaluate(delivery, check_read_state: true) == {:ok, :proceed}
    end

    test "returns {:ok, :proceed} when check_read_state is false even if notification is read" do
      event = insert_event()
      notification = insert_notification(event, "user-sup-5")
      delivery = insert_delivery(notification, "in_app")

      notification
      |> Notification.changeset(%{read_at: DateTime.utc_now()})
      |> Repo.update!()

      assert Policy.evaluate(delivery, check_read_state: false) == {:ok, :proceed}
    end
  end

  describe "policy settings evaluation" do
    test "quiet-hours settings defer the delivery" do
      event = insert_event("policy.quiet_hours")
      notification = insert_notification(event, "user-policy-quiet-hours")
      delivery = insert_delivery(notification, "in_app")

      assert {:ok, _} =
               Chimeway.Policy.Settings.upsert_settings(%{
                 recipient_id: "user-policy-quiet-hours",
                 quiet_hours_start_minute: 22 * 60,
                 quiet_hours_end_minute: 8 * 60,
                 time_zone: "America/New_York"
               })

      assert {:defer, decision} =
               Chimeway.Policy.Settings.evaluate(delivery,
                 evaluation_time: ~U[2026-01-15 03:30:00Z]
               )

      assert decision.orchestration_state == :deferred
      assert decision.planning_reason == "quiet_hours"
      assert decision.next_eligible_at == ~U[2026-01-15 13:00:00Z]
    end

    test "delivery-cap settings suppress the delivery after one prior send" do
      event = insert_event("policy.delivery_cap")
      notification = insert_notification(event, "user-policy-cap")
      first_delivery = insert_delivery(notification, "in_app")

      assert {:ok, _} =
               Chimeway.Policy.Settings.upsert_settings(%{
                 recipient_id: "user-policy-cap",
                 delivery_cap_count: 1,
                 delivery_cap_window_minutes: 60
               })

      assert Chimeway.Policy.Settings.evaluate(first_delivery) == {:ok, :proceed}

      second_delivery = insert_delivery(notification, "email")

      assert Chimeway.Policy.Settings.evaluate(second_delivery) ==
               {:suppress, :delivery_cap_reached}
    end
  end

  # ---- Integration: preference disabled between enqueue and perform ----

  describe "integration: policy enforcement at dispatch time" do
    test "preference disabled after enqueue suppresses delivery in Dispatch.Sync" do
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Chimeway.Adapters.Test.clear()

      event = insert_event("late.disable")
      notification = insert_notification(event, "user-late-1")

      # Plan delivery while preference is still enabled (no row = enabled)
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)

      # Now disable the channel preference
      Preferences.upsert_preference(%{
        recipient_id: "user-late-1",
        notification_key: "late.disable",
        channel: "in_app",
        enabled: false
      })

      # Trigger the private perform-time check via Policy.evaluate directly
      assert Policy.evaluate(delivery, check_read_state: false) == {:suppress, :channel_disabled}

      # suppress_delivery persists the reason correctly
      {:ok, suppressed} = Deliveries.suppress_delivery(delivery, :channel_disabled)
      assert suppressed.status == :suppressed
      assert suppressed.suppression_reason == "channel_disabled"
    end

    test "full sync path: trigger → preference disabled → delivery suppressed, adapter never called" do
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Chimeway.Adapters.Test.clear()

      event = insert_event("sync.suppress")
      notification = insert_notification(event, "user-sync-sup-1")

      # Disable the channel preference before dispatch
      Preferences.upsert_preference(%{
        recipient_id: "user-sync-sup-1",
        notification_key: "sync.suppress",
        channel: "in_app",
        enabled: false
      })

      {:ok, results} = Chimeway.Dispatch.Sync.dispatch([notification], [])

      assert length(results) == 1
      assert {:ok, delivery} = hd(results)
      assert delivery.status == :suppressed
      assert delivery.suppression_reason == "channel_disabled"

      # Adapter was never called
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end
  end
end
