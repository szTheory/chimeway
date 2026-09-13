defmodule Chimeway.TriggerPipelineTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query

  alias Chimeway.{Delivery, Notifications.Notification, Repo, Trigger}
  alias Chimeway.Events.Event

  defmodule FanoutNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created.fanout"

    @impl true
    def version, do: 3

    @impl true
    def recipients(_params) do
      {:ok,
       [
         %{recipient_ref: "cw_trigger_fanout_z", channel: :in_app},
         %{recipient_ref: "cw_trigger_fanout_a", channel: :email},
         %{recipient_ref: "cw_trigger_fanout_a", channel: :sms},
         %{recipient_ref: "cw_trigger_fanout_m", channel: :push}
       ]}
    end

    @impl true
    def build(_params, recipient),
      do:
        {:ok,
         %{
           "headline" => "test",
           "body" => "test",
           "primary_action" => %{"label" => "test", "url" => "http://test"},
           "subject" => "test",
           "html_body" => "test",
           "text_body" => "test",
           recipient: recipient
         }}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:in_app, :email]}
  end

  defmodule PipelineNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created.fallback"

    @impl true
    def version, do: 3

    @impl true
    def recipients(_params) do
      {:ok,
       [
         %{recipient_ref: "cw_trigger_pipeline_z", channel: :in_app},
         %{recipient_ref: "cw_trigger_pipeline_a", channel: :email},
         %{recipient_ref: "cw_trigger_pipeline_a", channel: :sms},
         %{recipient_ref: "cw_trigger_pipeline_m", channel: :push}
       ]}
    end

    @impl true
    def build(_params, recipient),
      do:
        {:ok,
         %{
           "headline" => "test",
           "body" => "test",
           "primary_action" => %{"label" => "test", "url" => "http://test"},
           "subject" => "test",
           "html_body" => "test",
           "text_body" => "test",
           recipient: recipient
         }}
  end

  defmodule DigestSnapshotNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created.digest_snapshot"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params) do
      {:ok,
       [
         %{recipient_ref: "cw_trigger_digest_a", channel: :email},
         %{recipient_ref: "cw_trigger_digest_z", channel: :email}
       ]}
    end

    @impl true
    def build(_params, recipient), do: {:ok, %{"subject" => "digest", recipient: recipient}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email, :in_app]}

    @impl true
    def orchestration(_params, recipient) do
      {:ok,
       %{
         default: :digest,
         email: {:digest, [digest_key: "thread:#{recipient.recipient_ref}"]},
         in_app: :immediate
       }}
    end
  end

  defmodule WorkflowSnapshotNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created.workflow_snapshot"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params) do
      {:ok,
       [
         %{recipient_ref: "cw_trigger_workflow_a", channel: :email},
         %{recipient_ref: "cw_trigger_workflow_z", channel: :email}
       ]}
    end

    @impl true
    def build(_params, recipient) do
      {:ok,
       %{
         "subject" => "workflow",
         "html_body" => "workflow",
         "text_body" => "workflow",
         recipient: recipient
       }}
    end

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email]}

    @impl true
    def workflow(_params, _recipient) do
      {:ok,
       %{
         workflow_key: "comment.escalation",
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
  end

  defmodule FailingDispatcher do
    @behaviour Chimeway.Dispatch

    @impl true
    def dispatch(_notifications, _opts), do: {:error, :forced_dispatch_failure}

    @impl true
    def dispatch_delivery(_delivery, _opts), do: {:error, :forced_dispatch_failure}
  end

  defmodule SpyDispatcher do
    @behaviour Chimeway.Dispatch

    @impl true
    def dispatch(notifications, opts) do
      if is_pid(opts[:spy_pid]) do
        send(opts[:spy_pid], {:dispatch_called, notifications})
      end

      {:ok, []}
    end

    @impl true
    def dispatch_delivery(_delivery, _opts), do: {:ok, nil}
  end

  test "returns error when idempotency key is missing" do
    assert {:error, :missing_idempotency_key} = Trigger.trigger(PipelineNotifier, %{}, [])
  end

  test "returns error when idempotency key is blank" do
    assert {:error, :blank_idempotency_key} =
             Trigger.trigger(PipelineNotifier, %{}, idempotency_key: "   ", tenant_id: "acme")
  end

  test "returns deterministic, deduped recipient output with explicit channel fanout" do
    assert {:ok, result} =
             Trigger.trigger(FanoutNotifier, %{}, idempotency_key: "idem-123", tenant_id: "acme")

    assert result.notification_key == "comment.created.fanout"
    assert result.notification_version == 3
    assert result.idempotency_key == "idem-123"

    refute Map.has_key?(result, :recipients)

    notifications =
      Repo.all(from(n in Notification, where: n.event_id == ^result.event.id, select: n.id))

    assert length(notifications) == 3

    delivery_count =
      Repo.aggregate(
        from(d in Delivery, where: d.notification_id in ^notifications),
        :count,
        :id
      )

    assert delivery_count == 6

    recipient_channels =
      Repo.all(
        from(d in Delivery,
          join: n in Notification,
          on: d.notification_id == n.id,
          where: n.event_id == ^result.event.id,
          select: {n.recipient_identity, d.channel}
        )
      )

    assert MapSet.new(recipient_channels) ==
             MapSet.new([
               {"cw_trigger_fanout_a", "email"},
               {"cw_trigger_fanout_a", "in_app"},
               {"cw_trigger_fanout_m", "email"},
               {"cw_trigger_fanout_m", "in_app"},
               {"cw_trigger_fanout_z", "email"},
               {"cw_trigger_fanout_z", "in_app"}
             ])

    assert result.dispatch_outcome == :ok
    assert result.dispatch_mode in [:sync, :oban, :unknown]
    assert result.dispatch_mode == :sync
    assert is_map(result.trace)
    assert result.trace.event_id == result.event.id
    assert Map.has_key?(result.trace, :correlation_id)
    assert is_list(result.trace.delivery_ids)
  end

  test "falls back to a single in_app delivery when notifier has no channels/2 callback" do
    assert {:ok, result} =
             Trigger.trigger(PipelineNotifier, %{},
               idempotency_key: "idem-124",
               tenant_id: "acme"
             )

    assert result.notification_key == "comment.created.fallback"
    refute Map.has_key?(result, :recipients)

    notifications =
      Repo.all(from(n in Notification, where: n.event_id == ^result.event.id, select: n.id))

    assert Repo.aggregate(
             from(d in Delivery, where: d.notification_id in ^notifications),
             :count,
             :id
           ) ==
             3

    channels =
      Repo.all(
        from(d in Delivery,
          where: d.notification_id in ^notifications,
          select: d.channel,
          distinct: true
        )
      )

    assert MapSet.new(channels) == MapSet.new(["in_app"])
  end

  test "returns structured dispatch error outcome while preserving {:ok, result} shape" do
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

    on_exit(fn ->
      Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
    end)

    Application.put_env(:chimeway, :dispatcher, FailingDispatcher)

    assert {:ok, result} =
             Trigger.trigger(
               PipelineNotifier,
               %{},
               idempotency_key: "idem-125",
               tenant_id: "acme"
             )

    assert result.dispatch_outcome == {:error, :forced_dispatch_failure}
    assert result.trace.event_id == result.event.id
    assert Map.has_key?(result.trace, :correlation_id)
  end

  test "duplicate idempotency trigger bypasses dispatch invocation on second call" do
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

    on_exit(fn ->
      Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
    end)

    Application.put_env(:chimeway, :dispatcher, SpyDispatcher)

    assert {:ok, _result} =
             Trigger.trigger(
               PipelineNotifier,
               %{},
               idempotency_key: "idem-dup-001",
               tenant_id: "acme",
               spy_pid: self()
             )

    assert_receive {:dispatch_called, _}

    assert {:duplicate, _event} =
             Trigger.trigger(
               PipelineNotifier,
               %{},
               idempotency_key: "idem-dup-001",
               tenant_id: "acme",
               spy_pid: self()
             )

    refute_receive {:dispatch_called, _}

    event_count =
      Repo.aggregate(from(e in Event, where: e.idempotency_key == "idem-dup-001"), :count, :id)

    assert event_count == 1

    [event] = Repo.all(from(e in Event, where: e.idempotency_key == "idem-dup-001"))

    notification_count =
      Repo.aggregate(from(n in Notification, where: n.event_id == ^event.id), :count, :id)

    assert notification_count == 3
  end

  test "persists a normalized orchestration snapshot on notifications at trigger time" do
    assert {:ok, result} =
             Trigger.trigger(DigestSnapshotNotifier, %{},
               idempotency_key: "idem-digest-snapshot",
               tenant_id: "acme"
             )

    notifications =
      Repo.all(
        from(n in Notification,
          where: n.event_id == ^result.event.id,
          order_by: [asc: n.recipient_identity]
        )
      )

    assert Enum.map(notifications, & &1.recipient_identity) == [
             "cw_trigger_digest_a",
             "cw_trigger_digest_z"
           ]

    assert Enum.map(notifications, &Map.get(&1, :orchestration)) == [
             %{
               "default" => "digest_held",
               "channels" => %{"email" => "digest_held", "in_app" => "immediate"},
               "default_digest_key" => nil,
               "digest_keys" => %{"email" => "thread:cw_trigger_digest_a"},
               "source" => "notifier"
             },
             %{
               "default" => "digest_held",
               "channels" => %{"email" => "digest_held", "in_app" => "immediate"},
               "default_digest_key" => nil,
               "digest_keys" => %{"email" => "thread:cw_trigger_digest_z"},
               "source" => "notifier"
             }
           ]
  end

  test "persists workflow runs and initial transitions for workflow-enabled triggers" do
    assert {:ok, result} =
             Trigger.trigger(
               WorkflowSnapshotNotifier,
               %{},
               idempotency_key: "idem-workflow-snapshot",
               tenant_id: "acme"
             )

    notifications =
      Repo.all(
        from(n in Notification,
          where: n.event_id == ^result.event.id,
          order_by: [asc: n.recipient_identity],
          select: %{id: n.id, recipient_identity: n.recipient_identity}
        )
      )

    definition =
      Repo.one!(
        from(wd in "chimeway_workflow_definitions",
          where:
            field(wd, :workflow_key) == "comment.escalation" and
              field(wd, :workflow_version) == 1,
          select: %{id: field(wd, :id)}
        )
      )

    first_step =
      Repo.one!(
        from(ws in "chimeway_workflow_steps",
          where: field(ws, :workflow_definition_id) == ^definition.id,
          order_by: [asc: field(ws, :step_order)],
          limit: 1,
          select: %{id: field(ws, :id), step_key: field(ws, :step_key)}
        )
      )

    workflow_runs =
      Repo.all(
        from(wr in "chimeway_workflow_runs",
          join: n in Notification,
          on: field(wr, :notification_id) == n.id,
          where: n.event_id == ^result.event.id,
          order_by: [asc: field(wr, :notification_id)],
          select: %{
            id: field(wr, :id),
            notification_id: field(wr, :notification_id),
            workflow_definition_id: field(wr, :workflow_definition_id),
            current_step_id: field(wr, :current_step_id),
            state: field(wr, :state),
            status_reason: field(wr, :status_reason)
          }
        )
      )

    assert length(workflow_runs) == length(notifications)

    assert Enum.all?(workflow_runs, fn run ->
             run.workflow_definition_id == definition.id and
               run.current_step_id == first_step.id and
               run.state == "completed" and
               run.status_reason == "workflow_completed"
           end)

    assert MapSet.new(Enum.map(workflow_runs, &Ecto.UUID.load!(&1.notification_id))) ==
             MapSet.new(Enum.map(notifications, & &1.id))

    workflow_transitions =
      Repo.all(
        from(wt in "chimeway_workflow_transitions",
          join: wr in "chimeway_workflow_runs",
          on: field(wt, :workflow_run_id) == field(wr, :id),
          join: n in Notification,
          on: field(wr, :notification_id) == n.id,
          where: n.event_id == ^result.event.id,
          order_by: [asc: field(wr, :notification_id), asc: field(wt, :inserted_at)],
          select: %{
            workflow_run_id: field(wt, :workflow_run_id),
            workflow_step_id: field(wt, :workflow_step_id),
            from_state: field(wt, :from_state),
            to_state: field(wt, :to_state),
            reason: field(wt, :reason)
          }
        )
      )

    assert Enum.count(workflow_transitions, &(&1.reason == "workflow_started")) ==
             length(workflow_runs)

    assert Enum.count(workflow_transitions, &(&1.reason == "step_activated")) ==
             length(workflow_runs)

    assert Enum.all?(workflow_transitions, fn transition ->
             (transition.reason in ["workflow_started", "step_activated"] and
                transition.to_state == "active") or
               (transition.reason == "workflow_completed" and transition.to_state == "completed")
           end)

    activated_steps =
      workflow_transitions
      |> Enum.filter(&(&1.reason == "step_activated"))
      |> Enum.map(& &1.workflow_step_id)

    assert activated_steps == List.duplicate(first_step.id, length(workflow_runs))
  end

  test "duplicate workflow triggers do not create duplicate workflow runs for the canonical event" do
    idempotency_key = "idem-workflow-duplicate"

    assert {:ok, first_result} =
             Trigger.trigger(WorkflowSnapshotNotifier, %{},
               idempotency_key: idempotency_key,
               tenant_id: "acme"
             )

    assert {:duplicate, duplicate_event} =
             Trigger.trigger(WorkflowSnapshotNotifier, %{},
               idempotency_key: idempotency_key,
               tenant_id: "acme"
             )

    assert duplicate_event.id == first_result.event.id

    workflow_runs_count =
      Repo.aggregate(
        from(wr in "chimeway_workflow_runs",
          join: n in Notification,
          on: field(wr, :notification_id) == n.id,
          where: n.event_id == ^first_result.event.id
        ),
        :count,
        :id
      )

    workflow_transitions_count =
      Repo.aggregate(
        from(wt in "chimeway_workflow_transitions",
          join: wr in "chimeway_workflow_runs",
          on: field(wt, :workflow_run_id) == field(wr, :id),
          join: n in Notification,
          on: field(wr, :notification_id) == n.id,
          where: n.event_id == ^first_result.event.id
        ),
        :count,
        :id
      )

    assert workflow_runs_count == 2
    assert workflow_transitions_count == 6
  end

  test "reuses persisted workflow definitions across distinct trigger events" do
    assert {:ok, first_result} =
             Trigger.trigger(WorkflowSnapshotNotifier, %{},
               idempotency_key: "idem-workflow-v1-a",
               tenant_id: "acme"
             )

    assert {:ok, second_result} =
             Trigger.trigger(WorkflowSnapshotNotifier, %{},
               idempotency_key: "idem-workflow-v1-b",
               tenant_id: "acme"
             )

    refute first_result.event.id == second_result.event.id

    definition_ids =
      Repo.all(
        from(n in Notification,
          where: n.event_id in ^[first_result.event.id, second_result.event.id],
          select: n.workflow_definition_id,
          distinct: true
        )
      )

    assert length(definition_ids) == 1

    definition_id = hd(definition_ids) |> Ecto.UUID.dump!()

    workflow_runs_count =
      Repo.aggregate(
        from(wr in "chimeway_workflow_runs",
          where: field(wr, :workflow_definition_id) == ^definition_id
        ),
        :count,
        :id
      )

    workflow_transitions_count =
      Repo.aggregate(
        from(wt in "chimeway_workflow_transitions",
          join: wr in "chimeway_workflow_runs",
          on: field(wt, :workflow_run_id) == field(wr, :id),
          where: field(wr, :workflow_definition_id) == ^definition_id
        ),
        :count,
        :id
      )

    assert workflow_runs_count == 4
    assert workflow_transitions_count == 12
  end
end
