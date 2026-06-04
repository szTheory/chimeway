defmodule Chimeway.AdminTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Admin, Deliveries, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  test "admin read models expose safe fields without payload/render/provider details" do
    event = insert_event(%{notification_key: "admin.safe", payload: %{"token" => "secret-token"}})
    notification = insert_notification(event, "user:alex@example.test")
    delivery = insert_delivery(notification, status: :failed, tenant_id: "tenant-a")

    {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

    {:ok, _} =
      Deliveries.record_attempt(dispatched, %{
        outcome: :failed,
        provider_response: %{"token" => "provider-secret"}
      })

    [problem] = Admin.recent_problem_deliveries(tenant_id: "tenant-a")

    assert problem.notification_key == "admin.safe"
    assert problem.recipient_id == "user:alex@example.test"
    refute Map.has_key?(problem, :payload)
    refute Map.has_key?(problem, :render_data)
    refute Map.has_key?(problem, :provider_response)
  end

  test "recovery candidates are tenant filtered and safe" do
    old = ~U[2026-01-15 12:00:00.000000Z]
    now = ~U[2026-01-15 12:05:00.000000Z]

    event_a = insert_event(%{notification_key: "admin.recover.a"})
    notification_a = insert_notification(event_a, "user:tenant-a@example.test")

    delivery_a =
      insert_delivery(notification_a, tenant_id: "tenant-a", inserted_at: old, updated_at: old)

    event_b = insert_event(%{notification_key: "admin.recover.b"})
    notification_b = insert_notification(event_b, "user:tenant-b@example.test")

    _delivery_b =
      insert_delivery(notification_b, tenant_id: "tenant-b", inserted_at: old, updated_at: old)

    candidates = Admin.recovery_candidates(tenant_id: "tenant-a", now: now, older_than: 60)

    assert [%{id: id, type: "delivery"}] = candidates
    assert id == delivery_a.id
    refute inspect(candidates) =~ "tenant-b@example.test"
  end

  test "tenant-scoped admin reads exclude every other tenant family" do
    old = ~U[2026-01-15 12:00:00.000000Z]
    now = ~U[2026-01-15 12:05:00.000000Z]

    event_a =
      insert_event(%{
        notification_key: "admin.tenant.a",
        notification_version: 1,
        correlation_id: "corr-a"
      })

    notification_a = insert_notification(event_a, "user:tenant-a@example.test")

    delivery_a =
      insert_delivery(notification_a,
        tenant_id: "tenant-a",
        status: :failed,
        channel: :email,
        inserted_at: old,
        updated_at: old
      )

    recovery_delivery_a =
      insert_delivery(notification_a,
        tenant_id: "tenant-a",
        inserted_at: old,
        updated_at: old
      )

    event_b =
      insert_event(%{
        notification_key: "admin.tenant.b",
        notification_version: 2,
        correlation_id: "corr-b"
      })

    notification_b = insert_notification(event_b, "user:tenant-b@example.test")

    _delivery_b =
      insert_delivery(notification_b,
        tenant_id: "tenant-b",
        status: :failed,
        channel: :sms,
        inserted_at: old,
        updated_at: old
      )

    opts = [tenant_id: "tenant-a", now: now, older_than: 60]

    snapshot = Admin.command_center(Keyword.put(opts, :limit, 8))
    assert snapshot.outcomes["failed"] == 1
    assert [%{delivery_id: delivery_id}] = snapshot.recent_problems
    assert delivery_id == delivery_a.id

    assert [%{delivery_id: ^delivery_id}] = Admin.recent_problem_deliveries(opts)
    assert [%{notification_key: "admin.tenant.a"}] = Admin.definitions(opts)

    assert [%{recipient_id: "user:tenant-a@example.test"}] =
             Admin.feed(Keyword.put(opts, :recipient_id, "user:tenant-a@example.test"))

    assert [] = Admin.feed(Keyword.put(opts, :recipient_id, "user:tenant-b@example.test"))

    assert [%{id: recovery_id, type: "delivery"}] = Admin.recovery_candidates(opts)
    assert recovery_id == recovery_delivery_a.id

    refute inspect(snapshot) =~ "tenant-b@example.test"
    refute inspect(Admin.definitions(opts)) =~ "admin.tenant.b"
    refute inspect(Admin.recovery_candidates(opts)) =~ "admin.tenant.b"
  end

  test "tenant-scoped recovery candidates omit no-delivery events without durable tenant proof" do
    old = ~U[2026-01-15 12:00:00.000000Z]
    now = ~U[2026-01-15 12:05:00.000000Z]

    no_delivery_event =
      insert_event(%{
        notification_key: "admin.unproven.event",
        inserted_at: old,
        updated_at: old
      })

    _notification = insert_notification(no_delivery_event, "user:unknown-tenant@example.test")

    assert [%{type: "event", id: event_id}] =
             Admin.recovery_candidates(now: now, older_than: 60)

    assert event_id == no_delivery_event.id
    assert [] = Admin.recovery_candidates(tenant_id: "tenant-a", now: now, older_than: 60)
  end

  test "definitions summarize durable keys and channels" do
    event = insert_event(%{notification_key: "admin.definition", notification_version: 2})
    notification = insert_notification(event, "user:definition")
    _delivery = insert_delivery(notification, channel: :email)

    assert Enum.any?(Admin.definitions(), fn definition ->
             definition.notification_key == "admin.definition" and
               definition.notification_version == 2 and definition.channels == ["email"]
           end)
  end

  defp insert_event(attrs) do
    event =
      %Event{}
      |> Event.changeset(%{
        notification_key: Map.fetch!(attrs, :notification_key),
        notification_version: Map.get(attrs, :notification_version, 1),
        idempotency_key: "admin-test-#{System.unique_integer([:positive])}",
        payload: Map.get(attrs, :payload, %{}),
        correlation_id: Map.get(attrs, :correlation_id)
      })
      |> Repo.insert!()

    timestamp_attrs =
      %{}
      |> maybe_put_timestamp(:inserted_at, Map.get(attrs, :inserted_at))
      |> maybe_put_timestamp(:updated_at, Map.get(attrs, :updated_at))

    case timestamp_attrs do
      attrs when attrs == %{} -> event
      attrs -> event |> Ecto.Changeset.change(attrs) |> Repo.update!()
    end
  end

  defp maybe_put_timestamp(attrs, _key, nil), do: attrs
  defp maybe_put_timestamp(attrs, key, value), do: Map.put(attrs, key, value)

  defp insert_notification(event, recipient_identity) do
    %Notification{}
    |> Notification.changeset(%{
      event_id: event.id,
      recipient_identity: recipient_identity,
      recipient_type: "user",
      metadata: %{},
      render_assigns: %{"token" => "render-secret"},
      render_channels: %{"email" => %{"render_key" => "admin.email", "render_version" => 1}}
    })
    |> Repo.insert!()
  end

  defp insert_delivery(notification, attrs) when is_list(attrs),
    do: insert_delivery(notification, Map.new(attrs))

  defp insert_delivery(notification, attrs) do
    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, Map.get(attrs, :channel, :in_app),
        tenant_id: Map.get(attrs, :tenant_id, "default"),
        actor_id: "system",
        metadata: %{"token" => "metadata-secret"},
        render_key: "admin.render",
        render_version: 1,
        render_data: %{"token" => "render-data-secret"}
      )

    delivery
    |> Ecto.Changeset.change(%{
      status: Map.get(attrs, :status, delivery.status),
      inserted_at: Map.get(attrs, :inserted_at, delivery.inserted_at),
      updated_at: Map.get(attrs, :updated_at, delivery.updated_at)
    })
    |> Repo.update!()
  end
end
