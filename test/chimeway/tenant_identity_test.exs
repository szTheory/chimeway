defmodule Chimeway.TenantIdentityTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query

  alias Chimeway.{Repo, Traces, Trigger}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  defmodule TenantNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "tenant.identity.test"

    @impl true
    def version, do: 7

    @impl true
    def recipients(_params) do
      {:ok,
       [
         %{recipient_identity: "tenant-user-a", channel: :in_app},
         %{recipient_identity: "tenant-user-b", channel: :email}
       ]}
    end

    @impl true
    def build(_params, recipient), do: {:ok, %{headline: "tenant", recipient: recipient}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:in_app]}
  end

  test "trigger persists its exact tenant through a tenant-scoped trace" do
    assert {:ok, result} =
             Trigger.trigger(TenantNotifier, %{},
               tenant_id: "tenant-a",
               idempotency_key: "tenant-a-1"
             )

    assert result.event.tenant_id == "tenant-a"

    assert ["tenant-a", "tenant-a"] =
             Repo.all(
               from(n in Notification,
                 where: n.event_id == ^result.event.id,
                 order_by: [asc: n.recipient_identity],
                 select: n.tenant_id
               )
             )

    assert {:ok, trace} = Traces.get_trace(result.event.id, tenant_id: "tenant-a")
    assert trace.tenant_id == "tenant-a"
    assert {:error, :not_found} = Traces.get_trace(result.event.id, tenant_id: "tenant-b")
  end

  test "idempotency is scoped by tenant and duplicate recovery retains ownership" do
    assert {:ok, first} =
             Trigger.trigger(TenantNotifier, %{},
               tenant_id: "tenant-a",
               idempotency_key: "shared-key"
             )

    assert {:duplicate, duplicate} =
             Trigger.trigger(TenantNotifier, %{},
               tenant_id: "tenant-a",
               idempotency_key: "shared-key"
             )

    assert duplicate.id == first.event.id

    assert {:ok, second} =
             Trigger.trigger(TenantNotifier, %{},
               tenant_id: "tenant-b",
               idempotency_key: "shared-key"
             )

    assert second.event.id != first.event.id

    assert 2 ==
             Repo.aggregate(
               from(e in Event, where: e.idempotency_key == "shared-key"),
               :count,
               :id
             )
  end

  test "event changeset recognizes both supported composite index names" do
    constraint_names =
      Event.changeset(%Event{}, %{})
      |> Map.fetch!(:constraints)
      |> Enum.map(& &1.constraint)

    assert "chimeway_events_tenant_id_idempotency_key_index" in constraint_names
    assert "chimeway_events_tenant_id_idempotency_key_idx" in constraint_names
  end

  test "concurrent same-tenant submissions converge without colliding with another tenant", %{
    sandbox_owner: sandbox_owner
  } do
    [first, second] = concurrent_triggers("tenant-a", "concurrent-key", sandbox_owner)

    assert Enum.any?([first, second], &match?({:ok, _}, &1))
    assert Enum.any?([first, second], &match?({:duplicate, _}, &1))

    assert {:ok, other_tenant} =
             Trigger.trigger(TenantNotifier, %{},
               tenant_id: "tenant-b",
               idempotency_key: "concurrent-key"
             )

    assert 2 ==
             Repo.aggregate(
               from(e in Event, where: e.idempotency_key == "concurrent-key"),
               :count,
               :id
             )

    assert other_tenant.event.tenant_id == "tenant-b"
  end

  test "tenant ownership is immutable after insertion" do
    event = %Event{
      id: Ecto.UUID.generate(),
      notification_key: "immutable.event",
      notification_version: 1,
      idempotency_key: "immutable-event",
      tenant_id: "tenant-a",
      payload: %{}
    }

    notification = %Notification{
      id: Ecto.UUID.generate(),
      event_id: Ecto.UUID.generate(),
      recipient_identity: "immutable-user",
      recipient_type: "user",
      tenant_id: "tenant-a",
      metadata: %{},
      render_assigns: %{},
      render_channels: %{}
    }

    refute Map.has_key?(Event.changeset(event, %{tenant_id: "tenant-b"}).changes, :tenant_id)

    refute Map.has_key?(
             Notification.changeset(notification, %{tenant_id: "tenant-b"}).changes,
             :tenant_id
           )
  end

  defp concurrent_triggers(tenant_id, idempotency_key, sandbox_owner) do
    tasks =
      for _ <- 1..2 do
        Task.async(fn ->
          receive do
            :trigger ->
              Trigger.trigger(TenantNotifier, %{},
                tenant_id: tenant_id,
                idempotency_key: idempotency_key
              )
          end
        end)
      end

    Enum.each(tasks, fn task ->
      :ok = Ecto.Adapters.SQL.Sandbox.allow(Repo, sandbox_owner, task.pid)
      send(task.pid, :trigger)
    end)

    Enum.map(tasks, &Task.await/1)
  end
end
