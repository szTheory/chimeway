defmodule Mix.Tasks.Chimeway.ReconcileTenantsTest do
  use Chimeway.DataCase, async: false

  import ExUnit.CaptureIO

  alias Chimeway.Repo
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  test "--report emits exactly one JSON reconciliation report" do
    event = insert_legacy_event!()
    notification = insert_legacy_notification!(event)

    report = run_task!(["--report"]) |> Jason.decode!()

    assert report["schema_version"] == 1
    assert report["status"] == "ambiguous_tenant_ownership"
    assert report["counts"] == %{"events" => 1, "notifications" => 1, "deliveries" => 0}

    assert report["events"] == [
             %{
               "id" => event.id,
               "notification_ids" => [notification.id],
               "delivery_ids" => [],
               "tenant_id" => nil
             }
           ]
  end

  test "assignment flags emit a JSON result delegated to reconciliation" do
    event = insert_legacy_event!()
    notification = insert_legacy_notification!(event)

    result = run_task!(["--event-id", event.id, "--tenant-id", "tenant-a"]) |> Jason.decode!()

    assert result["status"] == "assigned"
    assert result["event_id"] == event.id
    assert result["tenant_id"] == "tenant-a"
    assert result["counts"] == %{"events" => 1, "notifications" => 1, "deliveries" => 0}
    assert Repo.get!(Event, event.id).tenant_id == "tenant-a"
    assert Repo.get!(Notification, notification.id).tenant_id == "tenant-a"
  end

  test "invalid or ambiguous invocations fail before mutation" do
    event = insert_legacy_event!()
    notification = insert_legacy_notification!(event)

    for argv <- [
          [],
          ["--report", "--event-id", event.id, "--tenant-id", "tenant-a"],
          ["--event-id", event.id],
          ["--event-id", "invalid", "--tenant-id", "tenant-a"],
          ["--tenant-id", "tenant-a"],
          ["--tenant-prefix", "tenant-a"]
        ] do
      assert_raise Mix.Error, ~r/Tenant reconciliation/, fn -> run_task!(argv) end
    end

    assert Repo.get!(Event, event.id).tenant_id == nil
    assert Repo.get!(Notification, notification.id).tenant_id == nil
  end

  defp run_task!(argv) do
    Mix.Task.reenable("chimeway.reconcile_tenants")

    capture_io(fn ->
      Mix.Task.run("chimeway.reconcile_tenants", argv)
    end)
    |> String.trim()
  end

  defp insert_legacy_event! do
    event =
      %Event{}
      |> Event.changeset(%{
        notification_key: "reconciliation.mix",
        notification_version: 1,
        idempotency_key: Ecto.UUID.generate(),
        payload: %{},
        tenant_id: "seed-tenant"
      })
      |> Repo.insert!()

    {1, _} = Repo.update_all(from(e in Event, where: e.id == ^event.id), set: [tenant_id: nil])
    Repo.get!(Event, event.id)
  end

  defp insert_legacy_notification!(event) do
    notification =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: "user:mix",
        recipient_type: "user",
        tenant_id: "seed-tenant",
        metadata: %{},
        render_assigns: %{},
        render_channels: %{}
      })
      |> Repo.insert!()

    {1, _} =
      Repo.update_all(from(n in Notification, where: n.id == ^notification.id),
        set: [tenant_id: nil]
      )

    Repo.get!(Notification, notification.id)
  end
end
