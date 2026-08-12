defmodule Chimeway.TenantScopeContractTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{Delivery, Inbox, Repo, Traces}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.TenantScope

  setup do
    previous = Application.get_env(:chimeway, :single_tenant_compatibility)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:chimeway, :single_tenant_compatibility)
      else
        Application.put_env(:chimeway, :single_tenant_compatibility, previous)
      end
    end)
  end

  test "explicit scope is trimmed and wins over compatibility configuration" do
    Application.put_env(:chimeway, :single_tenant_compatibility, tenant_id: "compat-tenant")

    assert {:ok, "explicit-tenant"} = TenantScope.resolve(tenant_id: " explicit-tenant ")
  end

  test "missing and malformed compatibility configurations fail closed" do
    Application.delete_env(:chimeway, :single_tenant_compatibility)
    assert {:error, :tenant_scope_required} = TenantScope.resolve([])

    Application.put_env(:chimeway, :single_tenant_compatibility, tenant_id: "   ")
    assert {:error, :invalid_compatibility_tenant} = TenantScope.resolve([])
  end

  test "new lifecycle ownership rejects blank tenant values" do
    event =
      Event.changeset(%Event{}, %{
        notification_key: "tenant.validation",
        notification_version: 1,
        idempotency_key: "tenant-validation",
        tenant_id: "   ",
        payload: %{}
      })

    notification =
      Notification.changeset(%Notification{}, %{
        event_id: Ecto.UUID.generate(),
        recipient_identity: "tenant-user",
        recipient_type: "user",
        tenant_id: "   ",
        metadata: %{},
        render_assigns: %{},
        render_channels: %{}
      })

    refute event.valid?
    refute notification.valid?
  end

  test "trace preloads exclude a delivery linked across tenant ownership" do
    event =
      Repo.insert!(%Event{
        notification_key: "tenant.nested",
        notification_version: 1,
        idempotency_key: "tenant-nested-#{System.unique_integer()}",
        tenant_id: "tenant-a",
        payload: %{}
      })

    notification =
      Repo.insert!(%Notification{
        event_id: event.id,
        recipient_identity: "tenant-nested-user",
        recipient_type: "user",
        tenant_id: "tenant-a",
        metadata: %{},
        render_assigns: %{},
        render_channels: %{}
      })

    Repo.insert!(
      Delivery.changeset(%Delivery{}, %{
        notification_id: notification.id,
        channel: "in_app",
        status: :pending,
        tenant_id: "tenant-b",
        actor_id: "tenant-nested-user"
      })
    )

    assert {:ok, trace} = Traces.get_trace(event.id, tenant_id: "tenant-a")
    assert [%{deliveries: []}] = trace.notifications
  end

  test "configured compatibility is the only legacy inbox authority" do
    notification = insert_tenant_notification!("compat-tenant")

    Application.put_env(:chimeway, :single_tenant_compatibility, tenant_id: "compat-tenant")
    assert :ok = Inbox.mark_read(notification.id, "compat-user")

    Application.delete_env(:chimeway, :single_tenant_compatibility)
    assert {:error, :tenant_scope_required} = Inbox.mark_seen(notification.id, "compat-user")
  end

  defp insert_tenant_notification!(tenant_id) do
    event =
      Repo.insert!(%Event{
        notification_key: "tenant.inbox",
        notification_version: 1,
        idempotency_key: "tenant-inbox-#{System.unique_integer()}",
        tenant_id: tenant_id,
        payload: %{}
      })

    Repo.insert!(%Notification{
      event_id: event.id,
      tenant_id: tenant_id,
      recipient_identity: "compat-user",
      recipient_type: "user",
      metadata: %{},
      render_assigns: %{},
      render_channels: %{}
    })
  end
end
