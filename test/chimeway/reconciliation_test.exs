defmodule Chimeway.ReconciliationTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{Delivery, Reconciliation, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  test "reports NULL-owned event trees deterministically without lifecycle details" do
    event_b = insert_legacy_event!("reconciliation-b")
    notification_b = insert_legacy_notification!(event_b, "user:b")
    event_a = insert_legacy_event!("reconciliation-a")
    notification_a = insert_legacy_notification!(event_a, "user:a")

    report = Reconciliation.report()

    assert report == Reconciliation.report()
    assert report.schema_version == 1
    assert report.status == "ambiguous_tenant_ownership"
    assert report.counts == %{events: 2, notifications: 2, deliveries: 0}
    assert report.assignment == "host must explicitly supply tenant_id; no inference performed"

    assert report.events ==
             [
               %{
                 id: event_a.id,
                 notification_ids: [notification_a.id],
                 delivery_ids: [],
                 tenant_id: nil
               },
               %{
                 id: event_b.id,
                 notification_ids: [notification_b.id],
                 delivery_ids: [],
                 tenant_id: nil
               }
             ]
             |> Enum.sort_by(& &1.id)

    refute inspect(report) =~ "reconciliation-a"
    refute inspect(report) =~ "user:a"
  end

  test "returns an empty deterministic report when no legacy ownership is pending" do
    assert %{counts: %{events: 0, notifications: 0, deliveries: 0}, events: []} =
             Reconciliation.report()
  end

  test "assigns only the named NULL-owned event tree to a trimmed host tenant" do
    event = insert_legacy_event!("assign-target")
    notification = insert_legacy_notification!(event, "user:target")
    delivery = insert_legacy_delivery!(notification)
    other_event = insert_legacy_event!("assign-other")
    other_notification = insert_legacy_notification!(other_event, "user:other")

    assert {:ok,
            %{
              status: "assigned",
              tenant_id: "tenant-a",
              counts: %{events: 1, notifications: 1, deliveries: 1}
            }} =
             Reconciliation.assign_event_tree(event.id, " tenant-a ")

    assert Repo.get!(Event, event.id).tenant_id == "tenant-a"
    assert Repo.get!(Notification, notification.id).tenant_id == "tenant-a"
    assert Repo.get!(Delivery, delivery.id).tenant_id == "tenant-a"
    assert Repo.get!(Event, other_event.id).tenant_id == nil
    assert Repo.get!(Notification, other_notification.id).tenant_id == nil
  end

  test "rejects invalid inputs, missing events, and conflicting ownership without mutation" do
    event = insert_legacy_event!("invalid-input")
    notification = insert_legacy_notification!(event, "user:invalid")

    assert {:error, :invalid_event_id} = Reconciliation.assign_event_tree("invalid", "tenant-a")
    assert {:error, :invalid_tenant_id} = Reconciliation.assign_event_tree(event.id, "   ")

    assert {:error, :not_found} =
             Reconciliation.assign_event_tree(Ecto.UUID.generate(), "tenant-a")

    assert {:ok, _} = Reconciliation.assign_event_tree(event.id, "tenant-a")
    assert {:error, :ownership_conflict} = Reconciliation.assign_event_tree(event.id, "tenant-b")
    assert Repo.get!(Event, event.id).tenant_id == "tenant-a"
    assert Repo.get!(Notification, notification.id).tenant_id == "tenant-a"
  end

  test "returns an explicit already-assigned result for a repeated matching assignment" do
    event = insert_legacy_event!("already-assigned")

    assert {:ok, %{status: "assigned"}} = Reconciliation.assign_event_tree(event.id, "tenant-a")
    assert {:error, :already_assigned} = Reconciliation.assign_event_tree(event.id, "tenant-a")
  end

  test "rolls back the event update when an existing child has conflicting ownership" do
    event = insert_legacy_event!("child-conflict")
    notification = insert_legacy_notification!(event, "user:child-conflict")

    {1, _} =
      Repo.update_all(from(n in Notification, where: n.id == ^notification.id),
        set: [tenant_id: "tenant-b"]
      )

    assert {:error, :ownership_conflict} = Reconciliation.assign_event_tree(event.id, "tenant-a")
    assert Repo.get!(Event, event.id).tenant_id == nil
    assert Repo.get!(Notification, notification.id).tenant_id == "tenant-b"
  end

  test "rejects a conflicting delivery without partially assigning its legacy tree" do
    event = insert_legacy_event!("delivery-conflict")
    notification = insert_legacy_notification!(event, "user:delivery-conflict")
    delivery = insert_delivery!(notification, "tenant-b")

    assert {:error, :ownership_conflict} = Reconciliation.assign_event_tree(event.id, "tenant-a")
    assert Repo.get!(Event, event.id).tenant_id == nil
    assert Repo.get!(Notification, notification.id).tenant_id == nil
    assert Repo.get!(Delivery, delivery.id).tenant_id == "tenant-b"
  end

  test "reports deterministic delivery IDs for ambiguous legacy event trees" do
    event = insert_legacy_event!("delivery-report")
    notification = insert_legacy_notification!(event, "user:delivery-report")
    delivery_b = insert_legacy_delivery!(notification, channel: "sms")
    delivery_a = insert_legacy_delivery!(notification, channel: "email")
    event_id = event.id
    notification_id = notification.id

    assert %{counts: %{events: 1, notifications: 1, deliveries: 2}} = Reconciliation.report()

    assert [%{id: ^event_id, notification_ids: [^notification_id], delivery_ids: delivery_ids}] =
             Reconciliation.report().events

    assert delivery_ids == Enum.sort([delivery_a.id, delivery_b.id])
    refute inspect(Reconciliation.report()) =~ "user:delivery-report"
  end

  test "retains a matching owned delivery while assigning NULL parents and siblings" do
    event = insert_legacy_event!("matching-delivery")
    notification = insert_legacy_notification!(event, "user:matching-delivery")
    retained_delivery = insert_delivery!(notification, "tenant-a")
    assigned_delivery = insert_legacy_delivery!(notification, channel: "sms")

    assert {:ok, %{counts: %{events: 1, notifications: 1, deliveries: 1}}} =
             Reconciliation.assign_event_tree(event.id, "tenant-a")

    assert Repo.get!(Event, event.id).tenant_id == "tenant-a"
    assert Repo.get!(Notification, notification.id).tenant_id == "tenant-a"
    assert Repo.get!(Delivery, retained_delivery.id).tenant_id == "tenant-a"
    assert Repo.get!(Delivery, assigned_delivery.id).tenant_id == "tenant-a"
  end

  test "concurrent conflicting assignments leave the event tree with one coherent owner", %{
    sandbox_owner: sandbox_owner
  } do
    event = insert_legacy_event!("concurrent-conflict")
    notification = insert_legacy_notification!(event, "user:concurrent-conflict")
    delivery = insert_legacy_delivery!(notification)

    results =
      ["tenant-a", "tenant-b"]
      |> Enum.map(fn tenant_id ->
        Task.async(fn ->
          receive do
            :assign -> Reconciliation.assign_event_tree(event.id, tenant_id)
          end
        end)
      end)
      |> Enum.map(fn task ->
        :ok = Ecto.Adapters.SQL.Sandbox.allow(Repo, sandbox_owner, task.pid)
        send(task.pid, :assign)
        task
      end)
      |> Enum.map(&Task.await/1)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, :ownership_conflict}, &1)) == 1

    event_owner = Repo.get!(Event, event.id).tenant_id
    assert event_owner in ["tenant-a", "tenant-b"]
    assert Repo.get!(Notification, notification.id).tenant_id == event_owner
    assert Repo.get!(Delivery, delivery.id).tenant_id == event_owner
  end

  defp insert_legacy_event!(idempotency_key) do
    event =
      %Event{}
      |> Event.changeset(%{
        notification_key: "reconciliation.test",
        notification_version: 1,
        idempotency_key: idempotency_key,
        payload: %{"sensitive" => idempotency_key},
        tenant_id: "seed-tenant"
      })
      |> Repo.insert!()

    {1, _} = Repo.update_all(from(e in Event, where: e.id == ^event.id), set: [tenant_id: nil])
    Repo.get!(Event, event.id)
  end

  defp insert_legacy_notification!(event, recipient_identity) do
    notification =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: recipient_identity,
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

  defp insert_delivery!(notification, tenant_id) do
    %Delivery{}
    |> Delivery.changeset(%{
      notification_id: notification.id,
      channel: "email",
      status: :pending,
      tenant_id: tenant_id,
      actor_id: "actor:reconciliation"
    })
    |> Repo.insert!()
  end

  defp insert_legacy_delivery!(notification, attrs \\ []) do
    delivery =
      %Delivery{}
      |> Delivery.changeset(%{
        notification_id: notification.id,
        channel: Keyword.get(attrs, :channel, "email"),
        status: :pending,
        tenant_id: "seed-tenant",
        actor_id: "actor:reconciliation"
      })
      |> Repo.insert!()

    {1, _} =
      Repo.update_all(from(d in Delivery, where: d.id == ^delivery.id), set: [tenant_id: nil])

    Repo.get!(Delivery, delivery.id)
  end
end
