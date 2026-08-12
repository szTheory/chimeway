defmodule Chimeway.Orchestration.TracesDeferralTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Deliveries, Repo, Traces}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Traces.Explanation

  test "explain_delivery surfaces deferred planning facts without conflating them with suppression" do
    delivery = insert_deferred_delivery()

    assert {:ok, %Explanation{} = explanation} =
             Traces.explain_delivery(delivery.id, tenant_id: delivery.tenant_id)

    assert explanation.status == :pending
    assert explanation.suppression_reason == nil
    assert explanation.planning_reason == "quiet_hours"
    assert DateTime.compare(explanation.next_eligible_at, ~U[2026-01-15 13:00:00Z]) == :eq
    assert explanation.planning_context["time_zone"] == "America/New_York"

    assert explanation.planning_context["rule_identity"] == "quiet_hours"
    refute Map.has_key?(explanation.planning_context, "payload")
    refute Map.has_key?(explanation.planning_context, "provider_response")

    deferred_entries = Enum.filter(explanation.timeline, &(&1.event == :deferred))
    assert length(deferred_entries) == 1

    [%{at: at, detail: detail}] = deferred_entries

    assert at == delivery.updated_at
    assert detail.reason == "quiet_hours"
    assert detail.time_zone == "America/New_York"
    assert detail.rule_identity == "quiet_hours"
    assert DateTime.compare(detail.next_eligible_at, ~U[2026-01-15 13:00:00Z]) == :eq
    refute Map.has_key?(detail, :payload)
    refute Map.has_key?(detail, :provider_response)
  end

  test "digest-held explanations keep hold facts separate from suppression" do
    delivery = insert_digest_held_delivery()

    assert {:ok, %Explanation{} = explanation} =
             Traces.explain_delivery(delivery.id, tenant_id: delivery.tenant_id)

    assert explanation.status == :pending
    assert explanation.suppression_reason == nil
    assert explanation.planning_reason == "digest_rule"
    assert explanation.next_eligible_at == nil
    assert explanation.planning_context["rule_identity"] == "digest_rule"
    assert explanation.planning_context["channel"] == "email"

    deferred_entries = Enum.filter(explanation.timeline, &(&1.event == :deferred))
    assert deferred_entries == []
  end

  test "explain_delivery preserves deferral facts and surfaces durable resume audit fields" do
    delivery =
      insert_deferred_delivery()
      |> resume_delivery(~U[2026-01-15 13:05:00Z], "scheduled_resume")

    assert {:ok, %Explanation{} = explanation} =
             Traces.explain_delivery(delivery.id, tenant_id: delivery.tenant_id)

    assert explanation.status == :pending
    assert explanation.planning_reason == "quiet_hours"
    assert explanation.planning_context["time_zone"] == "America/New_York"
    assert DateTime.compare(explanation.next_eligible_at, ~U[2026-01-15 13:00:00Z]) == :eq
    assert Map.get(explanation, :resume_source) == "scheduled_resume"

    assert DateTime.compare(Map.get(explanation, :resume_scheduled_at), ~U[2026-01-15 13:00:00Z]) ==
             :eq

    assert DateTime.compare(Map.get(explanation, :resumed_at), ~U[2026-01-15 13:05:00Z]) == :eq

    assert Enum.map(explanation.timeline, & &1.event) == [
             :event_created,
             :notification_created,
             :delivery_planned,
             :deferred,
             :resumed
           ]

    resumed_entries = Enum.filter(explanation.timeline, &(&1.event == :resumed))
    assert length(resumed_entries) == 1

    [%{at: resumed_at, detail: resumed_detail}] = resumed_entries

    assert DateTime.compare(resumed_at, ~U[2026-01-15 13:05:00Z]) == :eq
    assert resumed_detail.resume_source == "scheduled_resume"
    assert DateTime.compare(resumed_detail.resume_scheduled_at, ~U[2026-01-15 13:00:00Z]) == :eq
  end

  defp insert_deferred_delivery do
    notification = insert_notification("user:trace-deferred")

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, :email, tenant_id: "default", actor_id: "system")

    {:ok, updated} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :deferred,
        planning_reason: "quiet_hours",
        planning_context: %{
          "rule" => "quiet_hours",
          "time_zone" => "America/New_York",
          "quiet_hours_start_minute" => 1320,
          "quiet_hours_end_minute" => 480,
          "payload" => %{"secret" => "ignored"},
          "provider_response" => %{"token" => "ignored"}
        },
        next_eligible_at: ~U[2026-01-15 13:00:00Z]
      })

    updated
  end

  defp insert_digest_held_delivery do
    notification = insert_notification("user:trace-digest")

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, :email, tenant_id: "default", actor_id: "system")

    {:ok, updated} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :digest_held,
        planning_reason: "digest_rule",
        planning_context: %{
          "channel" => "email",
          "source" => "notifier"
        },
        next_eligible_at: nil
      })

    updated
  end

  defp insert_notification(recipient_identity) do
    {:ok, event} =
      Repo.insert(%Event{
        notification_key: "trace-deferral.test",
        notification_version: 1,
        idempotency_key: "trace-deferral-#{System.unique_integer()}",
        tenant_id: "default",
        payload: %{"secret" => "not-for-traces"}
      })

    {:ok, notification} =
      Repo.insert(%Notification{
        event_id: event.id,
        tenant_id: event.tenant_id,
        recipient_identity: recipient_identity,
        recipient_type: "user",
        metadata: %{}
      })

    notification
  end

  defp resume_delivery(delivery, now, source) do
    {:ok, resumed_delivery} =
      Deliveries.resume_deferred_delivery(
        delivery.id,
        now: now,
        source: source
      )

    resumed_delivery
  end
end
