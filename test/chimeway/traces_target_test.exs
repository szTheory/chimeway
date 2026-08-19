defmodule Chimeway.TracesTargetTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{DeliveryTarget, DeliveryTargetAttempt, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  test "orders tenant-scoped target histories and excludes foreign attempt evidence" do
    event = insert_event("tenant-a")
    notification = insert_notification(event, "tenant-a")
    delivery = insert_delivery(notification, "tenant-a")
    target_b = insert_target(delivery, "tenant-a", "cw_binding_revision_b")
    target_a = insert_target(delivery, "tenant-a", "cw_binding_revision_a")

    insert_attempt(target_a, "tenant-a", 2)
    insert_attempt(target_a, "tenant-a", 1)
    insert_attempt(target_b, "tenant-b", 1)

    assert {:ok, trace} = Chimeway.Traces.get_trace(event.id, tenant_id: "tenant-a")
    [loaded_delivery] = trace.notifications |> hd() |> Map.fetch!(:deliveries)

    assert Enum.map(loaded_delivery.targets, & &1.binding_revision_ref) ==
             Enum.sort(Enum.map(loaded_delivery.targets, & &1.binding_revision_ref))

    [first | _] = loaded_delivery.targets
    assert Enum.map(first.attempts, & &1.attempt_number) == [1, 2]
    assert [] = Enum.at(loaded_delivery.targets, 1).attempts
    assert {:error, :not_found} = Chimeway.Traces.get_trace(event.id, tenant_id: "tenant-b")
    refute inspect(trace) =~ "raw-token-sentinel"
  end

  defp insert_event(tenant_id) do
    Repo.insert!(%Event{
      notification_key: "traces.target",
      notification_version: 1,
      idempotency_key: "traces-target-#{System.unique_integer([:positive])}",
      tenant_id: tenant_id,
      payload: %{}
    })
  end

  defp insert_notification(event, tenant_id) do
    Repo.insert!(%Notification{
      event_id: event.id,
      tenant_id: tenant_id,
      recipient_identity: "user-target",
      recipient_type: "user",
      metadata: %{},
      render_channels: %{}
    })
  end

  defp insert_delivery(notification, tenant_id) do
    {:ok, delivery} =
      Chimeway.Deliveries.plan_delivery(notification.id, :push,
        tenant_id: tenant_id,
        actor_id: "target-trace"
      )

    delivery
  end

  defp insert_target(delivery, tenant_id, ref) do
    Repo.insert!(%DeliveryTarget{
      delivery_id: delivery.id,
      tenant_id: tenant_id,
      binding_revision_ref: ref,
      status: :pending
    })
  end

  defp insert_attempt(target, tenant_id, number) do
    Repo.insert!(%DeliveryTargetAttempt{
      delivery_target_id: target.id,
      tenant_id: tenant_id,
      attempt_number: number,
      outcome: :attempt_started,
      started_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      source: "test",
      safe_facts: %{"raw_token" => "raw-token-sentinel"}
    })
  end
end
