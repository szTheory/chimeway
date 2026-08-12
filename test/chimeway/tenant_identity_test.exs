defmodule Chimeway.TenantIdentityTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query

  alias Chimeway.{Repo, Traces, Trigger}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Workflows.WorkflowRun

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

  defmodule PaddedTenantWorkflowNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "tenant.identity.padded"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params),
      do: {:ok, [%{recipient_identity: "padded-tenant-user", channel: :in_app}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{headline: "tenant", recipient: recipient}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:in_app]}

    @impl true
    def workflow(_params, _recipient) do
      {:ok,
       %{
         workflow_key: "tenant.identity.padded.workflow",
         workflow_version: 1,
         steps: [%{step_key: "record", step_order: 1, channel: :in_app, config: %{}}]
       }}
    end
  end

  defmodule SpyDispatcher do
    @behaviour Chimeway.Dispatch

    @impl true
    def dispatch(notifications, opts) do
      send(opts[:spy_pid], {:dispatch_called, notifications, opts})
      {:ok, []}
    end

    @impl true
    def dispatch_delivery(_delivery, _opts), do: {:ok, nil}
  end

  test "trigger canonicalizes padded tenant identity through persistence, trace reads, workflows, and dispatch" do
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    on_exit(fn -> Application.put_env(:chimeway, :dispatcher, previous_dispatcher) end)
    Application.put_env(:chimeway, :dispatcher, SpyDispatcher)

    assert {:ok, result} =
             Trigger.trigger(PaddedTenantWorkflowNotifier, %{},
               tenant_id: "  tenant-a  ",
               idempotency_key: "padded-tenant-1",
               spy_pid: self()
             )

    assert result.event.tenant_id == "tenant-a"

    assert ["tenant-a"] =
             Repo.all(
               from(n in Notification,
                 where: n.event_id == ^result.event.id,
                 select: n.tenant_id
               )
             )

    assert ["tenant-a"] =
             Repo.all(
               from(wr in WorkflowRun,
                 join: n in Notification,
                 on: wr.notification_id == n.id,
                 where: n.event_id == ^result.event.id,
                 select: wr.tenant_id
               )
             )

    assert {:ok, trace} = Traces.get_trace(result.event.id, tenant_id: "tenant-a")
    assert trace.tenant_id == "tenant-a"
    assert {:error, :not_found} = Traces.get_trace(result.event.id, tenant_id: "tenant-b")

    assert_receive {:dispatch_called, _notifications, dispatch_opts}
    assert dispatch_opts[:tenant_id] == "tenant-a"
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

  test "padded and canonical retries converge while case-distinct tenant identities remain independent" do
    assert {:ok, first} =
             Trigger.trigger(TenantNotifier, %{},
               tenant_id: "  tenant-a  ",
               idempotency_key: "padded-duplicate-key"
             )

    assert {:duplicate, duplicate} =
             Trigger.trigger(TenantNotifier, %{},
               tenant_id: "tenant-a",
               idempotency_key: "padded-duplicate-key"
             )

    assert duplicate.id == first.event.id
    assert duplicate.tenant_id == "tenant-a"

    assert {:ok, case_distinct} =
             Trigger.trigger(TenantNotifier, %{},
               tenant_id: "Tenant-A",
               idempotency_key: "padded-duplicate-key"
             )

    assert case_distinct.event.id != first.event.id
    assert case_distinct.event.tenant_id == "Tenant-A"
  end

  test "concurrent padded and canonical submissions converge on one canonical event", %{
    sandbox_owner: sandbox_owner
  } do
    [first, second] =
      concurrent_triggers(["  tenant-a  ", "tenant-a"], "padded-concurrent-key", sandbox_owner)

    assert Enum.any?([first, second], &match?({:ok, _}, &1))
    assert Enum.any?([first, second], &match?({:duplicate, _}, &1))

    assert 1 ==
             Repo.aggregate(
               from(e in Event,
                 where: e.idempotency_key == "padded-concurrent-key" and e.tenant_id == "tenant-a"
               ),
               :count,
               :id
             )
  end

  test "missing, malformed, and trim-empty tenant input keeps trigger errors and persists no event" do
    idempotency_key = "invalid-tenant-key"

    assert {:error, :missing_tenant_id} =
             Trigger.trigger(TenantNotifier, %{}, idempotency_key: idempotency_key)

    for tenant_id <- [nil, 123, "  "] do
      assert {:error, :invalid_tenant_id} =
               Trigger.trigger(TenantNotifier, %{},
                 tenant_id: tenant_id,
                 idempotency_key: idempotency_key
               )
    end

    assert 0 ==
             Repo.aggregate(
               from(e in Event, where: e.idempotency_key == ^idempotency_key),
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

  defp concurrent_triggers(tenant_ids, idempotency_key, sandbox_owner) when is_list(tenant_ids) do
    tasks =
      for tenant_id <- tenant_ids do
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

  defp concurrent_triggers(tenant_id, idempotency_key, sandbox_owner) do
    concurrent_triggers([tenant_id, tenant_id], idempotency_key, sandbox_owner)
  end
end
