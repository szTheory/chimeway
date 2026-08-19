defmodule Chimeway.DeliveryTargetTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{DeliveryPlanning, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  defmodule PushNotifier do
    use Chimeway.Notifier

    def notification_key, do: "delivery-target.tracer"
    def version, do: 1
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-target"}]}
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}
    def channels(_params, _recipient), do: {:ok, [:push]}

    def rendering(_params, _recipient) do
      {:ok,
       %{
         assigns: %{},
         channels: %{push: %{render_key: "delivery-target.push", render_version: 1}}
       }}
    end
  end

  defmodule Resolver do
    @behaviour Chimeway.TargetResolver

    @impl true
    def resolve_targets(tenant_id, _opts) do
      {:ok,
       [
         %Chimeway.TargetResolver.BindingRevision{
           tenant_id: tenant_id,
           binding_revision_ref: "cw_binding_revision_001"
         }
       ]}
    end
  end

  defmodule Adapter do
    @behaviour Chimeway.TargetAdapter

    @impl true
    def deliver(%Chimeway.TargetAdapter.TargetEnvelope{target: target}, _opts) do
      attempt = Repo.one!(Chimeway.DeliveryTargetAttempt)
      assert attempt.delivery_target_id == target.id
      assert attempt.outcome == :attempt_started
      {:ok, %{provider_code: "accepted"}}
    end
  end

  setup do
    previous_resolver = Application.get_env(:chimeway, :target_resolver)
    previous_adapter = Application.get_env(:chimeway, :target_adapter)
    Application.put_env(:chimeway, :target_resolver, Resolver)
    Application.put_env(:chimeway, :target_adapter, Adapter)

    on_exit(fn ->
      restore(:target_resolver, previous_resolver)
      restore(:target_adapter, previous_adapter)
    end)

    :ok
  end

  test "push planning and target execution preserve canonical identity and safe evidence" do
    notification = insert_notification()

    planning_opts = [
      use_persisted_channels: true,
      precomputed_rendering: %{
        {notification.id, "push"} => %{
          render_key: "delivery-target.push",
          render_version: 1,
          render_data: %{}
        }
      }
    ]

    assert {:ok, [delivery]} = DeliveryPlanning.plan_notification(notification, planning_opts)

    assert {:ok, [replanned]} = DeliveryPlanning.plan_notification(notification, planning_opts)

    assert delivery.id == replanned.id
    assert Repo.aggregate(Chimeway.DeliveryTarget, :count, :id) == 1

    assert {:ok, %{delivery: succeeded, target: target, attempt: attempt}} =
             Chimeway.Dispatch.Executor.run_target(delivery)

    assert succeeded.status == :succeeded
    assert target.status == :provider_accepted
    assert attempt.outcome == :provider_accepted
    assert attempt.safe_facts == %{"provider_code" => "accepted"}
    refute inspect({succeeded, target, attempt}) =~ "raw-token-sentinel"

    assert {:ok, trace} = Chimeway.Traces.get_trace(notification.event_id, tenant_id: "default")

    traced_attempt =
      trace.notifications
      |> hd()
      |> Map.fetch!(:deliveries)
      |> hd()
      |> Map.fetch!(:targets)
      |> hd()
      |> Map.fetch!(:attempts)
      |> hd()

    assert traced_attempt.outcome == :provider_accepted
    refute inspect(trace) =~ "raw-token-sentinel"
  end

  test "synchronous push dispatch executes durable targets through the target seam" do
    notification = insert_notification()

    planning_opts = [
      use_persisted_channels: true,
      precomputed_rendering: %{
        {notification.id, "push"} => %{
          render_key: "delivery-target.push",
          render_version: 1,
          render_data: %{}
        }
      }
    ]

    assert {:ok, [delivery]} = DeliveryPlanning.plan_notification(notification, planning_opts)

    assert {:ok, succeeded} = Chimeway.Dispatch.Sync.dispatch_delivery(delivery, [])
    assert succeeded.status == :succeeded
    assert Repo.one!(Chimeway.DeliveryTarget).status == :provider_accepted
    assert Repo.one!(Chimeway.DeliveryTargetAttempt).outcome == :provider_accepted
  end

  defp insert_notification do
    event =
      Repo.insert!(%Event{
        notification_key: "delivery-target.tracer",
        notification_version: 1,
        idempotency_key: "delivery-target-#{System.unique_integer([:positive])}",
        tenant_id: "default",
        payload: %{}
      })

    Repo.insert!(%Notification{
      event_id: event.id,
      recipient_identity: "user-target",
      recipient_type: "user",
      tenant_id: "default",
      metadata: %{},
      render_channels: %{
        "push" => %{"render_key" => "delivery-target.push", "render_version" => 1}
      }
    })
  end

  defp restore(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore(key, value), do: Application.put_env(:chimeway, key, value)
end
