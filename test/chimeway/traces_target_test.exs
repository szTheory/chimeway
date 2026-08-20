defmodule Chimeway.TracesTargetTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{DeliveryTarget, DeliveryTargetAttempt, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  test "orders tenant-scoped target histories and excludes foreign attempt evidence" do
    event = insert_event("tenant-a", "trace-target-correlation")
    notification = insert_notification(event, "tenant-a")

    delivery =
      insert_delivery(notification, "tenant-a")
      |> put_target_aggregate()

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
    refute_sensitive_sentinels(trace)
  end

  test "projects closed target histories through recipient, correlation, and explanation traces" do
    event = insert_event("tenant-a", "trace-target-projection")
    notification = insert_notification(event, "tenant-a")

    delivery =
      insert_delivery(notification, "tenant-a")
      |> put_target_aggregate()

    target_b = insert_target(delivery, "tenant-a", "cw_binding_revision_b")
    target_a = insert_target(delivery, "tenant-a", "cw_binding_revision_a")

    insert_attempt(target_a, "tenant-a", 2)
    insert_attempt(target_a, "tenant-a", 1)
    insert_attempt(target_b, "tenant-b", 1)

    assert {:ok, full_trace} = Chimeway.Traces.get_trace(event.id, tenant_id: "tenant-a")

    full_delivery =
      full_trace.notifications
      |> hd()
      |> Map.fetch!(:deliveries)
      |> hd()

    recipient_delivery =
      notification.recipient_identity
      |> Chimeway.Traces.find_traces_for_recipient(tenant_id: "tenant-a")
      |> hd()
      |> Map.fetch!(:deliveries)
      |> hd()

    correlation_delivery =
      "trace-target-projection"
      |> Chimeway.Traces.find_traces_by_correlation_id(tenant_id: "tenant-a")
      |> hd()
      |> Map.fetch!(:notifications)
      |> hd()
      |> Map.fetch!(:deliveries)
      |> hd()

    assert {:ok, explanation} =
             Chimeway.Traces.explain_delivery(delivery.id, tenant_id: "tenant-a")

    for {name, projection} <- [
          recipient: recipient_delivery,
          correlation: correlation_delivery,
          explanation: explanation
        ] do
      assert projection.target_aggregate.target_count == 2

      assert Enum.map(projection.targets, & &1.binding_revision_ref) ==
               Enum.map(full_delivery.targets, & &1.binding_revision_ref),
             "#{name} projection: #{inspect(projection)}"

      assert Enum.map(hd(projection.targets).attempts, & &1.attempt_number) == [1, 2]
      assert [] = Enum.at(projection.targets, 1).attempts
      refute_sensitive_sentinels(projection)
    end

    assert [] =
             Chimeway.Traces.find_traces_for_recipient(notification.recipient_identity,
               tenant_id: "tenant-b"
             )

    assert [] =
             Chimeway.Traces.find_traces_by_correlation_id("trace-target-projection",
               tenant_id: "tenant-b"
             )

    assert {:error, :not_found} =
             Chimeway.Traces.explain_delivery(delivery.id, tenant_id: "tenant-b")
  end

  defp insert_event(tenant_id, correlation_id) do
    Repo.insert!(%Event{
      notification_key: "traces.target",
      notification_version: 1,
      idempotency_key: "traces-target-#{System.unique_integer([:positive])}",
      tenant_id: tenant_id,
      correlation_id: correlation_id,
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
      safe_facts: %{
        "raw_token" => "raw-token-sentinel",
        "endpoint" => "raw-endpoint-sentinel",
        "credential" => "raw-credential-sentinel",
        "provider_body" => "raw-provider-body-sentinel",
        "uncontrolled" => "uncontrolled-attempt-fact-sentinel"
      }
    })
  end

  defp refute_sensitive_sentinels(projection) do
    for sentinel <- [
          "raw-token-sentinel",
          "raw-endpoint-sentinel",
          "raw-credential-sentinel",
          "raw-provider-body-sentinel",
          "uncontrolled-attempt-fact-sentinel"
        ] do
      refute inspect(projection) =~ sentinel
    end
  end

  defp put_target_aggregate(delivery) do
    delivery
    |> Ecto.Changeset.change(%{
      metadata: %{
        "target_aggregate" => %{
          "target_count" => 2,
          "terminal_target_count" => 0,
          "provider_accepted_count" => 0,
          "terminal_failure_count" => 0,
          "partial_failure" => false,
          "all_targets_terminal" => false
        }
      }
    })
    |> Repo.update!()
  end
end
