defmodule Chimeway.DeliveryTargetTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query

  alias Chimeway.{DeliveryPlanning, DeliveryTarget, DeliveryTargetAttempt, DeliveryTargets, Repo}
  alias Chimeway.TargetResolver.BindingRevision
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
      attempt =
        Repo.one!(
          from(a in Chimeway.DeliveryTargetAttempt,
            where: a.delivery_target_id == ^target.id and a.outcome == :attempt_started
          )
        )

      assert attempt.delivery_target_id == target.id
      assert attempt.outcome == :attempt_started

      send(Application.fetch_env!(:chimeway, :target_adapter_test_pid), {
        :target_adapter_called,
        target.id
      })

      Application.get_env(:chimeway, :target_adapter_results, %{})
      |> Map.get(target.id, {:ok, %{provider_code: "accepted"}})
    end
  end

  setup do
    previous_resolver = Application.get_env(:chimeway, :target_resolver)
    previous_adapter = Application.get_env(:chimeway, :target_adapter)
    previous_adapter_test_pid = Application.get_env(:chimeway, :target_adapter_test_pid)
    previous_adapter_results = Application.get_env(:chimeway, :target_adapter_results)
    Application.put_env(:chimeway, :target_resolver, Resolver)
    Application.put_env(:chimeway, :target_adapter, Adapter)
    Application.put_env(:chimeway, :target_adapter_test_pid, self())
    Application.delete_env(:chimeway, :target_adapter_results)

    on_exit(fn ->
      restore(:target_resolver, previous_resolver)
      restore(:target_adapter, previous_adapter)
      restore(:target_adapter_test_pid, previous_adapter_test_pid)
      restore(:target_adapter_results, previous_adapter_results)
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

  test "synchronous push dispatch fans out in target order and repeated calls add no attempts" do
    delivery = create_push_delivery()
    [first, second] = plan_targets(delivery, ["cw_binding_revision_a", "cw_binding_revision_b"])
    first_id = first.id
    second_id = second.id

    assert {:ok, succeeded} = Chimeway.Dispatch.Sync.dispatch_delivery(delivery, [])
    assert succeeded.status == :succeeded
    assert_receive {:target_adapter_called, ^first_id}
    assert_receive {:target_adapter_called, ^second_id}

    assert target_attempt_numbers(first) == [1]
    assert target_attempt_numbers(second) == [1]

    assert {:ok, repeated} = Chimeway.Dispatch.Sync.dispatch_delivery(delivery, [])
    assert repeated.status == :succeeded
    refute_receive {:target_adapter_called, _target_id}, 50

    assert target_attempt_numbers(first) == [1]
    assert target_attempt_numbers(second) == [1]
  end

  test "concurrent sync fan-out claims each target once" do
    delivery = create_push_delivery()
    [first, second] = plan_targets(delivery, ["cw_binding_revision_a", "cw_binding_revision_b"])

    first_sync = Task.async(fn -> Chimeway.Dispatch.Sync.dispatch_delivery(delivery, []) end)
    second_sync = Task.async(fn -> Chimeway.Dispatch.Sync.dispatch_delivery(delivery, []) end)

    assert {:ok, %{status: :succeeded}} = Task.await(first_sync)
    assert {:ok, %{status: :succeeded}} = Task.await(second_sync)

    assert_receive {:target_adapter_called, target_id_one}
    assert_receive {:target_adapter_called, target_id_two}
    assert Enum.sort([target_id_one, target_id_two]) == Enum.sort([first.id, second.id])
    refute_receive {:target_adapter_called, _target_id}, 50

    assert target_attempt_numbers(first) == [1]
    assert target_attempt_numbers(second) == [1]
  end

  test "a failed target does not strand later sync targets and retains aggregate evidence" do
    delivery = create_push_delivery()
    [failed, accepted] = plan_targets(delivery, ["cw_binding_revision_a", "cw_binding_revision_b"])
    failed_id = failed.id
    accepted_id = accepted.id

    Application.put_env(:chimeway, :target_adapter_results, %{
      failed_id => {:error, :possible_handoff, "unknown"}
    })

    assert {:ok, succeeded} = Chimeway.Dispatch.Sync.dispatch_delivery(delivery, [])
    assert succeeded.status == :succeeded
    assert_receive {:target_adapter_called, ^failed_id}
    assert_receive {:target_adapter_called, ^accepted_id}

    assert Repo.get!(DeliveryTarget, failed.id).status == :ambiguous_handoff
    assert Repo.get!(DeliveryTarget, accepted.id).status == :provider_accepted
    assert target_attempt_numbers(failed) == [1]
    assert target_attempt_numbers(accepted) == [1]
    assert succeeded.metadata["target_aggregate"]["partial_failure"]
  end

  test "empty sync target snapshot suppresses without adapter handoff" do
    delivery = create_push_delivery()

    assert {:ok, suppressed} = Chimeway.Dispatch.Sync.dispatch_delivery(delivery, [])
    assert suppressed.status == :suppressed
    assert suppressed.suppression_reason == "no_eligible_targets"
    refute_receive {:target_adapter_called, _target_id}, 50
    assert Repo.aggregate(DeliveryTargetAttempt, :count, :id) == 0
  end

  test "copied migration retains the target and ordered-attempt contract" do
    migration = File.read!("priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs")

    for token <- [
          "@chimeway_prefix __CHIMEWAY_PREFIX__",
          "chimeway_delivery_targets",
          "binding_revision_ref",
          "chimeway_delivery_target_attempts",
          "attempt_number",
          "started_at",
          "finished_at",
          "duplicate_risk",
          "safe_facts",
          "[:delivery_id, :binding_revision_ref]",
          "[:delivery_target_id, :attempt_number]",
          "unique: true"
        ] do
      assert migration =~ token
    end
  end

  test "normalizes exact duplicates into a stable opaque target set" do
    notification = insert_notification()

    {:ok, delivery} =
      Chimeway.Deliveries.plan_delivery(notification.id, :push,
        tenant_id: "default",
        actor_id: "actor"
      )

    bindings =
      for ref <- ["cw_binding_revision_b", "cw_binding_revision_a", "cw_binding_revision_a"] do
        %BindingRevision{tenant_id: "default", binding_revision_ref: ref}
      end

    assert {:ok, targets} = DeliveryTargets.plan_targets(delivery, "default", bindings)

    assert Enum.map(targets, & &1.binding_revision_ref) == [
             "cw_binding_revision_a",
             "cw_binding_revision_b"
           ]

    assert {:ok, replanned} =
             DeliveryTargets.plan_targets(delivery, "default", Enum.reverse(bindings))

    assert Enum.map(replanned, & &1.id) == Enum.map(targets, & &1.id)
  end

  test "rejects malformed resolver entries without partial target rows" do
    notification = insert_notification()

    {:ok, delivery} =
      Chimeway.Deliveries.plan_delivery(notification.id, :push,
        tenant_id: "default",
        actor_id: "actor"
      )

    bindings = [
      %BindingRevision{tenant_id: "default", binding_revision_ref: "cw_binding_revision_a"},
      %{tenant_id: "default", binding_revision_ref: "raw-token-sentinel"}
    ]

    assert {:error, :invalid_target_resolution} =
             DeliveryTargets.plan_targets(delivery, "default", bindings)

    assert Repo.aggregate(Chimeway.DeliveryTarget, :count, :id) == 0
  end

  test "derives partial target failure without erasing the accepted target" do
    notification = insert_notification()

    {:ok, delivery} =
      Chimeway.Deliveries.plan_delivery(notification.id, :push,
        tenant_id: "default",
        actor_id: "actor"
      )

    {:ok, [accepted, failed]} =
      DeliveryTargets.plan_targets(delivery, "default", [
        %BindingRevision{tenant_id: "default", binding_revision_ref: "cw_binding_revision_a"},
        %BindingRevision{tenant_id: "default", binding_revision_ref: "cw_binding_revision_b"}
      ])

    accepted = Repo.update!(Ecto.Changeset.change(accepted, status: :provider_accepted))
    failed = Repo.update!(Ecto.Changeset.change(failed, status: :failed))

    assert {:ok, updated} = DeliveryTargets.recompute_delivery(delivery, "default")
    assert updated.status == :succeeded

    assert updated.metadata["target_aggregate"] == %{
             "target_count" => 2,
             "terminal_target_count" => 2,
             "provider_accepted_count" => 1,
             "terminal_failure_count" => 1,
             "partial_failure" => true,
             "all_targets_terminal" => true
           }

    assert Repo.get!(Chimeway.DeliveryTarget, accepted.id).status == :provider_accepted
    assert Repo.get!(Chimeway.DeliveryTarget, failed.id).status == :failed
  end

  test "empty target aggregate is the dedicated no-eligible-target suppression" do
    notification = insert_notification()

    {:ok, delivery} =
      Chimeway.Deliveries.plan_delivery(notification.id, :push,
        tenant_id: "default",
        actor_id: "actor"
      )

    assert {:ok, suppressed} = DeliveryTargets.recompute_delivery(delivery, "default")
    assert suppressed.status == :suppressed
    assert suppressed.suppression_reason == "no_eligible_targets"
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

  defp create_push_delivery do
    notification = insert_notification()

    {:ok, delivery} =
      Chimeway.Deliveries.plan_delivery(notification.id, :push,
        tenant_id: "default",
        actor_id: "actor"
      )

    delivery
  end

  defp plan_targets(delivery, refs) do
    bindings =
      Enum.map(refs, fn ref ->
        %BindingRevision{tenant_id: delivery.tenant_id, binding_revision_ref: ref}
      end)

    assert {:ok, targets} = DeliveryTargets.plan_targets(delivery, delivery.tenant_id, bindings)
    targets
  end

  defp target_attempt_numbers(target) do
    Repo.all(
      from(a in DeliveryTargetAttempt,
        where: a.delivery_target_id == ^target.id,
        order_by: [asc: a.attempt_number],
        select: a.attempt_number
      )
    )
  end

  defp restore(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore(key, value), do: Application.put_env(:chimeway, key, value)
end
