defmodule ChimewayTest.Notifiers.RecoveryCallbackProbe do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.recovery.callback_probe"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Recovery callback probe"}}

  def channels(_params, _recipient) do
    if test_pid = test_pid(), do: send(test_pid, {:channels_called, self()})
    {:ok, [:email, :in_app]}
  end

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Recovery callback probe",
         "body" => "Probe body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/recovery"},
         "subject" => "Recovery callback probe",
         "html_body" => "<p>Probe body</p>",
         "text_body" => "Probe body"
       },
       channels: %{
         email: %{render_key: "test.recovery.callback_probe.email", render_version: 1},
         in_app: %{render_key: "test.recovery.callback_probe.in_app", render_version: 1}
       }
     }}
  end

  defp test_pid do
    :chimeway
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:test_pid)
  end
end

defmodule ChimewayTest.Notifiers.RecoveryDigestCallbackProbe do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.recovery.digest_callback_probe"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Recovery digest callback probe"}}

  def channels(_params, _recipient) do
    if test_pid = test_pid(), do: send(test_pid, {:digest_channels_called, self()})
    {:ok, [:email]}
  end

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "subject" => "Recovery digest callback probe",
         "html_body" => "<p>Probe body</p>",
         "text_body" => "Probe body"
       },
       channels: %{
         email: %{render_key: "test.recovery.digest_callback_probe.email", render_version: 1}
       }
     }}
  end

  def orchestration(_params, recipient) do
    if test_pid = test_pid(),
      do: send(test_pid, {:orchestration_called, recipient.recipient_identity})

    {:ok, [email: {:digest, [digest_key: "thread:#{recipient.recipient_identity}"]}]}
  end

  defp test_pid do
    :chimeway
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:test_pid)
  end
end

defmodule ChimewayTest.Notifiers.RecoveryPersistedWorkflowProbe do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.recovery.persisted_workflow_probe"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Recovery persisted workflow probe"}}
  def channels(_params, _recipient), do: {:ok, [:email]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "subject" => "Recovery persisted workflow probe",
         "html_body" => "<p>Workflow probe</p>",
         "text_body" => "Workflow probe"
       },
       channels: %{
         email: %{render_key: "test.recovery.persisted_workflow_probe.email", render_version: 1}
       }
     }}
  end

  def workflow(_params, recipient) do
    if test_pid = test_pid() do
      send(test_pid, {:workflow_called, recipient.recipient_identity})
    end

    case workflow_mode() do
      :raise -> raise "workflow callback should not run during persisted recovery"
      _allow -> workflow_declaration()
    end
  end

  defp workflow_declaration do
    {:ok,
     %{
       workflow_key: "test.recovery.persisted_workflow",
       workflow_version: 1,
       steps: [
         %{
           step_key: "email-first",
           step_order: 1,
           channel: :email,
           config: %{"template" => "first"}
         },
         %{
           step_key: "in-app-followup",
           step_order: 2,
           channel: :in_app,
           config: %{"template" => "followup"}
         }
       ]
     }}
  end

  defp test_pid do
    :chimeway
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:test_pid)
  end

  defp workflow_mode do
    :chimeway
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:workflow_mode, :allow)
  end
end

defmodule Chimeway.Orchestration.RecoveryDispatcherStub do
  @behaviour Chimeway.Dispatch

  alias Chimeway.Deliveries
  alias Chimeway.DeliveryPlanning
  alias Chimeway.Repo

  def dispatch(notifications, opts) do
    send(test_pid!(), {:dispatch, Enum.map(notifications, & &1.id), opts})

    with {:ok, deliveries} <- DeliveryPlanning.plan_notifications(notifications, opts) do
      {:ok,
       Enum.map(deliveries, fn delivery ->
         delivery =
           delivery
           |> Ecto.Changeset.change(status: :dispatched)
           |> Repo.update!()

         {:ok, delivery}
       end)}
    end
  end

  def dispatch_delivery(delivery_or_id, opts) do
    delivery =
      case delivery_or_id do
        %{id: _id} = loaded -> loaded
        id when is_binary(id) -> Deliveries.get_delivery!(id)
      end

    send(test_pid!(), {:dispatch_delivery, delivery.id, opts})

    case Application.get_env(:chimeway, __MODULE__, [])[:dispatch_delivery_result] do
      :skip ->
        {:skip, delivery}

      {:error, reason} ->
        {:error, reason}

      _ ->
        updated_delivery =
          delivery
          |> Ecto.Changeset.change(status: :dispatched)
          |> Repo.update!()

        {:ok, updated_delivery}
    end
  end

  defp test_pid! do
    :chimeway
    |> Application.get_env(__MODULE__, [])
    |> Keyword.fetch!(:test_pid)
  end
end

defmodule Chimeway.Orchestration.RecoveryTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query

  alias Chimeway.{Deliveries, Delivery, Repo}
  alias Chimeway.Test.DispatchHelpers

  setup do
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

    previous_recovery_dispatcher =
      Application.get_env(:chimeway, Chimeway.Orchestration.RecoveryDispatcherStub, [])

    previous_probe =
      Application.get_env(:chimeway, ChimewayTest.Notifiers.RecoveryCallbackProbe, [])

    previous_digest_probe =
      Application.get_env(:chimeway, ChimewayTest.Notifiers.RecoveryDigestCallbackProbe, [])

    previous_workflow_probe =
      Application.get_env(:chimeway, ChimewayTest.Notifiers.RecoveryPersistedWorkflowProbe, [])

    Application.put_env(:chimeway, :dispatcher, Chimeway.Orchestration.RecoveryDispatcherStub)

    Application.put_env(:chimeway, Chimeway.Orchestration.RecoveryDispatcherStub,
      test_pid: self()
    )

    Application.put_env(:chimeway, ChimewayTest.Notifiers.RecoveryCallbackProbe, test_pid: self())

    Application.put_env(
      :chimeway,
      ChimewayTest.Notifiers.RecoveryDigestCallbackProbe,
      test_pid: self()
    )

    Application.put_env(
      :chimeway,
      ChimewayTest.Notifiers.RecoveryPersistedWorkflowProbe,
      test_pid: self(),
      workflow_mode: :allow
    )

    on_exit(fn ->
      Application.put_env(:chimeway, :dispatcher, previous_dispatcher)

      Application.put_env(
        :chimeway,
        Chimeway.Orchestration.RecoveryDispatcherStub,
        previous_recovery_dispatcher
      )

      Application.put_env(
        :chimeway,
        ChimewayTest.Notifiers.RecoveryCallbackProbe,
        previous_probe
      )

      Application.put_env(
        :chimeway,
        ChimewayTest.Notifiers.RecoveryDigestCallbackProbe,
        previous_digest_probe
      )

      Application.put_env(
        :chimeway,
        ChimewayTest.Notifiers.RecoveryPersistedWorkflowProbe,
        previous_workflow_probe
      )
    end)

    :ok
  end

  describe "recover_event/2" do
    test "plans deliveries from persisted render_channels and dispatches them without notifier callbacks" do
      %{event: event, notification: notification} =
        DispatchHelpers.create_notification(
          notification_key: "test.recovery.persisted_event",
          recipient_identity: "user:recovery-event"
        )

      notification =
        notification
        |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
        |> Repo.update!()

      event =
        event
        |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
        |> Repo.update!()

      assert {:ok, recovery} =
               Deliveries.recover_event(event.id,
                 now: ~U[2026-01-15 12:30:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "trigger_commit_gap"
               )

      assert recovery.event.id == event.id
      assert recovery.recovery.source == "ops_console"
      assert recovery.recovery.reason == "trigger_commit_gap"
      assert recovery.recovery.recovered_at == ~U[2026-01-15 12:30:00.000000Z]

      assert Enum.sort(Enum.map(recovery.deliveries, & &1.channel)) == [
               "email",
               "in_app",
               "sms_custom"
             ]

      assert Enum.all?(recovery.deliveries, &(&1.status == :dispatched))

      notification_id = notification.id
      assert_receive {:dispatch, [^notification_id], dispatch_opts}
      assert dispatch_opts[:event_id] == event.id
      assert dispatch_opts[:post_commit] == true
      assert dispatch_opts[:use_persisted_channels] == true
      refute Keyword.has_key?(dispatch_opts, :notifier)
      refute_receive {:channels_called, _}, 50
      assert [%Delivery{} = delivery | _] = recovery.deliveries
      assert delivery.id

      persisted_delivery =
        Repo.one!(
          from(d in Delivery,
            where: d.notification_id == ^notification.id and d.channel == "email"
          )
        )

      assert persisted_delivery.metadata["recovery_source"] == "ops_console"
      assert persisted_delivery.metadata["recovery_reason"] == "trigger_commit_gap"
      assert persisted_delivery.metadata["recovered_at"] == "2026-01-15T12:30:00.000000Z"
    end

    test "returns {:noop, event} when the persisted event is no longer recoverable" do
      %{event: event, notification: notification} =
        DispatchHelpers.create_notification(
          notification_key: "test.recovery.event_noop",
          recipient_identity: "user:recovery-event-noop"
        )

      {:ok, _delivery} = Deliveries.plan_delivery(notification.id, :in_app, tenant_id: "default", actor_id: "system")

      assert {:noop, recovery} =
               Deliveries.recover_event(event.id,
                 now: ~U[2026-01-15 12:30:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "already_planned"
               )

      assert recovery.event.id == event.id
      assert recovery.deliveries == []
      refute_received {:dispatch, _, _}
    end

    test "replays persisted digest orchestration and keeps recovered deliveries digest_held" do
      assert {:ok, trigger_result} =
               Chimeway.Trigger.trigger(
                 ChimewayTest.Notifiers.RecoveryDigestCallbackProbe,
                 %{user_id: 42},
                 idempotency_key: "recovery-digest-held",
                 tenant_id: "acme"
               )

      event = trigger_result.event

      notification =
        Repo.one!(
          from(n in Chimeway.Notifications.Notification,
            where: n.event_id == ^event.id
          )
        )

      notification_id = notification.id
      assert_receive {:dispatch, [^notification_id], initial_dispatch_opts}
      assert_receive {:digest_channels_called, _}
      assert_receive {:orchestration_called, "user:42"}
      assert_receive {:orchestration_called, "user:42"}
      refute initial_dispatch_opts[:use_persisted_channels]
      refute initial_dispatch_opts[:use_persisted_orchestration]

      Repo.delete_all(from(d in Delivery, where: d.notification_id == ^notification.id))

      notification
      |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
      |> Repo.update!()

      event
      |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
      |> Repo.update!()

      assert {:ok, recovery} =
               Deliveries.recover_event(event.id,
                 now: ~U[2026-01-15 12:30:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "digest_replay_gap"
               )

      [recovered_delivery] = recovery.deliveries
      assert recovered_delivery.channel == "email"
      assert recovered_delivery.status == :dispatched
      assert recovered_delivery.orchestration_state == :digest_held
      assert recovered_delivery.planning_reason == "digest_rule"

      assert recovered_delivery.planning_context == %{
               "channel" => "email",
               "digest_key" => "thread:user:42",
               "source" => "planner_override"
             }

      assert_receive {:dispatch, [^notification_id], dispatch_opts}
      assert dispatch_opts[:use_persisted_channels] == true
      assert dispatch_opts[:use_persisted_orchestration] == true
      refute Keyword.has_key?(dispatch_opts, :notifier)
      refute_receive {:digest_channels_called, _}, 50
      refute_receive {:orchestration_called, _}, 50
    end

    test "use_persisted_workflow replays the stored workflow declaration without re-entering callback code" do
      assert {:ok, trigger_result} =
               Chimeway.Trigger.trigger(
                 ChimewayTest.Notifiers.RecoveryPersistedWorkflowProbe,
                 %{user_id: 77},
                 idempotency_key: "recovery-persisted-workflow",
                 tenant_id: "acme"
               )

      event = trigger_result.event

      notification =
        Repo.one!(
          from(n in Chimeway.Notifications.Notification,
            where: n.event_id == ^event.id
          )
        )

      workflow_run =
        Repo.one!(
          from(wr in "chimeway_workflow_runs",
            where: field(wr, :notification_id) == ^Ecto.UUID.dump!(notification.id),
            select: %{
              id: field(wr, :id),
              current_step_id: field(wr, :current_step_id)
            }
          )
        )

      notification_id = notification.id
      assert_receive {:dispatch, [^notification_id], _initial_dispatch_opts}
      assert_receive {:workflow_called, "user:77"}

      Repo.delete_all(from(d in Delivery, where: d.notification_id == ^notification.id))

      notification
      |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
      |> Repo.update!()

      event
      |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
      |> Repo.update!()

      Application.put_env(
        :chimeway,
        ChimewayTest.Notifiers.RecoveryPersistedWorkflowProbe,
        test_pid: self(),
        workflow_mode: :raise
      )

      assert {:ok, recovery} =
               Deliveries.recover_event(event.id,
                 now: ~U[2026-01-15 12:30:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "workflow_replay_gap",
                 use_persisted_workflow: true
               )

      [recovered_delivery] = recovery.deliveries
      assert recovered_delivery.workflow_run_id == Ecto.UUID.load!(workflow_run.id)
      assert recovered_delivery.workflow_step_id == Ecto.UUID.load!(workflow_run.current_step_id)

      assert_receive {:dispatch, [^notification_id], dispatch_opts}
      assert dispatch_opts[:use_persisted_channels] == true
      assert dispatch_opts[:use_persisted_orchestration] == true
      assert dispatch_opts[:use_persisted_workflow] == true
      refute_receive {:workflow_called, _}, 50
    end
  end

  describe "recover_delivery/2" do
    test "reuses the same delivery.id, records recovery metadata, and no-ops after dispatch started" do
      %{delivery: delivery} =
        DispatchHelpers.create_pending_delivery(
          notification_key: "test.recovery.delivery",
          recipient_identity: "user:recovery-delivery",
          channel: :email
        )

      delivery =
        delivery
        |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
        |> Repo.update!()

      assert {:ok, recovery} =
               Chimeway.recover_delivery(delivery.id,
                 now: ~U[2026-01-15 12:30:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "worker_missed"
               )

      assert recovery.delivery.id == delivery.id
      assert recovery.delivery.status == :dispatched
      assert recovery.recovery.source == "ops_console"
      assert recovery.recovery.reason == "worker_missed"
      assert recovery.recovery.recovered_at == ~U[2026-01-15 12:30:00.000000Z]
      delivery_id = delivery.id
      assert_receive {:dispatch_delivery, ^delivery_id, dispatch_opts}
      assert dispatch_opts[:pre_planned] == true
      assert dispatch_opts[:post_commit] == true

      recovered = Repo.get!(Delivery, delivery.id)
      assert recovered.metadata["recovery_source"] == "ops_console"
      assert recovered.metadata["recovery_reason"] == "worker_missed"
      assert recovered.metadata["recovered_at"] == "2026-01-15T12:30:00.000000Z"

      assert {:noop, duplicate} =
               Deliveries.recover_delivery(delivery.id,
                 now: ~U[2026-01-15 12:31:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "second_try"
               )

      assert duplicate.delivery.id == delivery.id
      assert duplicate.delivery.status == :dispatched
      refute_receive {:dispatch_delivery, ^delivery_id, _}, 50
    end

    test "dispatcher failure returns the error and leaves the row recoverable" do
      %{delivery: delivery} =
        DispatchHelpers.create_pending_delivery(
          notification_key: "test.recovery.delivery_error",
          recipient_identity: "user:recovery-delivery-error",
          channel: :email
        )

      delivery =
        delivery
        |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
        |> Repo.update!()

      Application.put_env(
        :chimeway,
        Chimeway.Orchestration.RecoveryDispatcherStub,
        test_pid: self(),
        dispatch_delivery_result: {:error, :boom}
      )

      assert {:error, :boom} =
               Deliveries.recover_delivery(delivery.id,
                 now: ~U[2026-01-15 12:30:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "worker_missed"
               )

      delivery_id = delivery.id
      assert_receive {:dispatch_delivery, ^delivery_id, dispatch_opts}
      assert dispatch_opts[:pre_planned] == true
      assert dispatch_opts[:post_commit] == true

      failed_delivery = Repo.get!(Delivery, delivery.id)
      assert failed_delivery.status == :pending
      assert failed_delivery.orchestration_state == :ready
      refute Map.has_key?(failed_delivery.metadata || %{}, "recovered_at")

      recoverable_ids =
        Deliveries.list_recoverable_deliveries(
          now: ~U[2026-01-15 12:30:00Z],
          older_than: 60
        )
        |> Enum.map(& &1.id)

      assert delivery.id in recoverable_ids
    end

    test "normalizes dispatcher skip and terminal/deferred rows into explicit noop results" do
      %{delivery: deferred_delivery} =
        DispatchHelpers.create_pending_delivery(
          notification_key: "test.recovery.deferred_noop",
          recipient_identity: "user:recovery-deferred",
          channel: :email
        )

      deferred_delivery =
        deferred_delivery
        |> Ecto.Changeset.change(
          orchestration_state: :deferred,
          updated_at: ~U[2026-01-15 11:00:00.000000Z]
        )
        |> Repo.update!()

      assert {:noop, deferred} =
               Deliveries.recover_delivery(deferred_delivery.id,
                 now: ~U[2026-01-15 12:30:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "deferred_rows_excluded"
               )

      assert deferred.delivery.id == deferred_delivery.id
      deferred_delivery_id = deferred_delivery.id
      refute_received {:dispatch_delivery, ^deferred_delivery_id, _}

      %{delivery: skip_delivery} =
        DispatchHelpers.create_pending_delivery(
          notification_key: "test.recovery.skip_noop",
          recipient_identity: "user:recovery-skip",
          channel: :email
        )

      skip_delivery =
        skip_delivery
        |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
        |> Repo.update!()

      Application.put_env(
        :chimeway,
        Chimeway.Orchestration.RecoveryDispatcherStub,
        test_pid: self(),
        dispatch_delivery_result: :skip
      )

      assert {:noop, skipped} =
               Deliveries.recover_delivery(skip_delivery.id,
                 now: ~U[2026-01-15 12:30:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "already_started_elsewhere"
               )

      assert skipped.delivery.id == skip_delivery.id
      skip_delivery_id = skip_delivery.id
      assert_receive {:dispatch_delivery, ^skip_delivery_id, _}
    end
  end
end
