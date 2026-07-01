defmodule ChimewayTest.Notifiers.RuntimePrefix do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.runtime_prefix"
  def version, do: 1

  def recipients(%{recipient_id: recipient_id}),
    do: {:ok, [%{recipient_identity: recipient_id, recipient_type: "user"}]}

  def build(params, _recipient) do
    {:ok,
     %{
       title: Map.get(params, :title, "Runtime prefix"),
       body: Map.get(params, :body, "Runtime prefix body"),
       category: Map.get(params, :category, "runtime")
     }}
  end

  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Runtime prefix",
         "body" => "Runtime prefix body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/runtime"},
         "subject" => "Runtime prefix",
         "html_body" => "<p>Runtime prefix</p>",
         "text_body" => "Runtime prefix"
       },
       channels: %{
         in_app: %{render_key: "test.runtime_prefix.in_app", render_version: 1},
         email: %{render_key: "test.runtime_prefix.email", render_version: 1}
       }
     }}
  end
end

defmodule ChimewayTest.Notifiers.RuntimePrefixWorkflow do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.runtime_prefix.workflow"
  def version, do: 1

  def recipients(%{recipient_id: recipient_id}),
    do: {:ok, [%{recipient_identity: recipient_id, recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Runtime workflow"}}

  def channels(_params, _recipient), do: {:ok, [:in_app]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Runtime workflow",
         "body" => "Runtime workflow body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/workflow"},
         "subject" => "Runtime workflow",
         "html_body" => "<p>Runtime workflow body</p>",
         "text_body" => "Runtime workflow body"
       },
       channels: %{
         in_app: %{render_key: "test.runtime_prefix.workflow.in_app", render_version: 1},
         email: %{render_key: "test.runtime_prefix.workflow.email", render_version: 1}
       }
     }}
  end

  def workflow(_params, _recipient) do
    {:ok,
     %{
       workflow_key: "test.runtime_prefix.workflow",
       workflow_version: 1,
       steps: [
         %{
           step_key: "in_app",
           step_order: 1,
           channel: :in_app,
           config: %{
             "progress" => [
               %{
                 "kind" => "wait_until",
                 "anchor" => "prior_delivery_terminal_at",
                 "delay_seconds" => 60,
                 "to_step" => "email",
                 "cancel_signals" => ["chimeway.notification.read"]
               }
             ]
           }
         },
         %{step_key: "email", step_order: 2, channel: :email, config: %{}}
       ]
     }}
  end
end

defmodule ChimewayTest.Adapters.RuntimePrefixWebhook do
  @behaviour Chimeway.Adapter

  def deliver(_delivery, _config), do: {:ok, %{}}

  def verify_webhook(_body, [{"signature", "valid"}], _config), do: :ok
  def verify_webhook(_body, _headers, _config), do: {:error, :unauthorized}

  def resolve_delivery(%{"delivery_id" => id}) when is_binary(id),
    do: {:ok, %{delivery_id: id}}

  def resolve_delivery(_parsed), do: :error

  def normalize_feedback(%{"status" => "bounced"}), do: {:ok, %{status: :bounced}}
  def normalize_feedback(_parsed), do: :error

  def resolve_provider_event_id(%{"event_id" => id}) when is_binary(id), do: {:ok, id}
  def resolve_provider_event_id(_parsed), do: :none
end

defmodule Chimeway.RuntimePrefixIntegrationTest do
  use Chimeway.PrefixedRuntimeCase
  use Oban.Testing, repo: Chimeway.Repo, prefix: "public"

  import Chimeway.Test.DispatchHelpers,
    only: [create_notification: 1, create_pending_delivery: 1]

  import Ecto.Query

  alias Chimeway.{Admin, Deliveries, Delivery, Preferences, Repo, Signal, Traces}

  alias Chimeway.Dispatch.{
    DeferredResumeWorker,
    DigestFlushWorker,
    ObanWorker,
    SignalRouterWorker,
    WorkflowProgressionWorker
  }

  alias Chimeway.Digests.{Accumulation, DigestBucket}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Policy
  alias Chimeway.Policy.Settings
  alias Chimeway.Signals.Signal, as: PersistedSignal
  alias Chimeway.Webhooks.ProcessFeedbackWorker
  alias Chimeway.Workflows.{WorkflowRun, WorkflowTransition}

  @operator_forbidden_keys ~w(
    payload render_assigns render_data provider_response provider_body metadata session params
    token secret auth_code authorization
  )a

  setup do
    previous_adapter = Application.fetch_env(:chimeway, :adapter)
    previous_dispatcher = Application.fetch_env(:chimeway, :dispatcher)

    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      restore_env(:adapter, previous_adapter)
      restore_env(:dispatcher, previous_dispatcher)
      Chimeway.Adapters.Test.clear()
    end)

    :ok
  end

  @tag :runtime_prefix_trigger
  test "trigger pipeline writes event, notification, delivery, and attempt rows only under runtime prefix" do
    recipient_id = unique_recipient("trigger")

    assert {:ok, result} =
             Chimeway.trigger(
               ChimewayTest.Notifiers.RuntimePrefix,
               %{recipient_id: recipient_id, title: "Trigger proof"},
               trigger_opts("trigger")
             )

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 2)
    assert_prefixed_only("chimeway_delivery_attempts", 2)

    assert {:duplicate, duplicate_event} =
             Chimeway.trigger(
               ChimewayTest.Notifiers.RuntimePrefix,
               %{recipient_id: recipient_id, title: "Trigger proof"},
               idempotency_key: result.event.idempotency_key,
               tenant_id: "acme"
             )

    assert duplicate_event.id == result.event.id
  end

  @tag :runtime_prefix_operator
  test "operator, admin, inbox, trace, and recovery APIs reload durable rows from the runtime prefix" do
    recipient_id = unique_recipient("operator")
    now = ~U[2026-01-15 12:30:00.000000Z]
    old = ~U[2026-01-15 11:00:00.000000Z]

    assert {:ok, %{event: event}} =
             Chimeway.trigger(
               ChimewayTest.Notifiers.RuntimePrefix,
               %{recipient_id: recipient_id},
               trigger_opts("operator")
             )

    assert [%Notification{id: notification_id}] = Chimeway.list_for_recipient(recipient_id)

    assert :ok = Chimeway.mark_seen(notification_id, recipient_id)
    assert :ok = Chimeway.mark_read(notification_id, recipient_id)

    assert Chimeway.unread_count(recipient_id) == 0

    assert {:ok, %Event{notifications: [_notification]}} = Traces.get_trace(event.id)

    problem =
      create_pending_delivery(
        notification_key: "test.runtime_prefix.admin.problem",
        recipient_identity: recipient_id,
        channel: :email
      )

    problem_delivery =
      problem.delivery
      |> update_delivery!(tenant_id: "acme", inserted_at: old, updated_at: old)
      |> then(fn delivery ->
        {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

        {:ok, %{delivery: failed}} =
          Deliveries.record_attempt(dispatched, %{
            outcome: :failed,
            error_class: "temporary",
            provider_response: %{"token" => "provider-token"}
          })

        failed
      end)

    recovery_candidate =
      create_pending_delivery(
        notification_key: "test.runtime_prefix.admin.recovery_candidate",
        recipient_identity: recipient_id,
        channel: :in_app
      )

    recovery_candidate_delivery =
      update_delivery!(recovery_candidate.delivery,
        tenant_id: "acme",
        inserted_at: old,
        updated_at: old
      )

    begin_candidate =
      create_pending_delivery(
        notification_key: "test.runtime_prefix.recovery.begin",
        recipient_identity: unique_recipient("recovery-begin"),
        channel: :email
      )

    begin_candidate_delivery =
      update_delivery!(begin_candidate.delivery,
        tenant_id: "acme",
        inserted_at: old,
        updated_at: old
      )

    assert {:ok, claimed_delivery} =
             Deliveries.begin_recovery(begin_candidate_delivery.id,
               now: now,
               older_than: 60,
               source: "runtime_prefix_operator",
               reason: "begin_recovery_probe",
               actor_ref: "ops:runtime-prefix"
             )

    assert claimed_delivery.metadata["recovery_source"] == "runtime_prefix_operator"
    assert claimed_delivery.metadata["recovery_reason"] == "begin_recovery_probe"
    assert claimed_delivery.metadata["recovery_actor_ref"] == "ops:runtime-prefix"

    delivery_recovery =
      create_pending_delivery(
        notification_key: "test.runtime_prefix.recovery.delivery",
        recipient_identity: unique_recipient("recovery-delivery"),
        channel: :email
      )

    delivery_recovery_candidate =
      update_delivery!(delivery_recovery.delivery,
        tenant_id: "acme",
        inserted_at: old,
        updated_at: old
      )

    assert {:ok, recovered_delivery} =
             Deliveries.recover_delivery(delivery_recovery_candidate.id,
               now: now,
               older_than: 60,
               source: "runtime_prefix_operator",
               reason: "recover_delivery_probe",
               actor_ref: "ops:runtime-prefix",
               confirmation_marker: "operator_confirmed_recovery"
             )

    assert recovered_delivery.delivery.status == :succeeded
    assert recovered_delivery.recovery.source == "runtime_prefix_operator"

    event_recovery =
      create_notification(
        notification_key: "test.runtime_prefix.recovery.event",
        recipient_identity: unique_recipient("recovery-event")
      )

    event_recovery.event
    |> update_timestamps!(inserted_at: old, updated_at: old)

    event_recovery.notification
    |> update_timestamps!(inserted_at: old, updated_at: old)

    assert {:ok, recovered_event} =
             Deliveries.recover_event(event_recovery.event.id,
               now: now,
               older_than: 60,
               source: "runtime_prefix_operator",
               reason: "recover_event_probe"
             )

    assert recovered_event.event.id == event_recovery.event.id

    assert Enum.map(recovered_event.deliveries, & &1.channel) |> Enum.sort() == [
             "email",
             "in_app",
             "sms_custom"
           ]

    admin_opts = [tenant_id: "acme", recipient_id: recipient_id, now: now, older_than: 60]

    command_center = Admin.command_center(Keyword.put(admin_opts, :limit, 8))
    recent_problems = Admin.recent_problem_deliveries(admin_opts)
    definitions = Admin.definitions(admin_opts)
    feed_rows = Admin.feed(admin_opts)
    recovery_candidates = Admin.recovery_candidates(admin_opts)
    outcome_totals = Admin.outcome_totals(admin_opts)

    assert command_center.outcomes["failed"] >= 1
    assert Enum.any?(recent_problems, &(&1.delivery_id == problem_delivery.id))
    assert Enum.any?(definitions, &(&1.notification_key == "test.runtime_prefix"))
    assert Enum.any?(feed_rows, &(&1.notification_id == notification_id and &1.state == "read"))

    assert Enum.any?(recovery_candidates, fn candidate ->
             candidate.type == "delivery" and candidate.id == recovery_candidate_delivery.id
           end)

    assert outcome_totals["failed"] >= 1
    assert outcome_totals["pending"] >= 1

    [
      command_center,
      recent_problems,
      definitions,
      feed_rows,
      recovery_candidates,
      outcome_totals
    ]
    |> assert_no_operator_forbidden_keys()

    assert_prefixed_only("chimeway_events")
    assert_prefixed_only("chimeway_notifications")
    assert_prefixed_only("chimeway_deliveries")
    assert public_count("chimeway_delivery_attempts") == 0
  end

  @tag :runtime_prefix_oban_boundary
  test "Oban enqueue boundaries keep Chimeway rows prefixed and Oban rows public" do
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
    recipient_id = unique_recipient("oban")

    assert {:ok, _result} =
             Chimeway.trigger(
               ChimewayTest.Notifiers.RuntimePrefix,
               %{recipient_id: recipient_id},
               trigger_opts("oban")
             )

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 2)

    assert public_count("oban_jobs") == 2
    assert prefixed_count("oban_jobs") == 0

    assert Enum.all?(all_enqueued(worker: ObanWorker), fn %{args: args} ->
             Map.keys(args) == ["delivery_id"]
           end)
  end

  @tag :runtime_prefix_workflow_signal
  test "workflow and signal progression reloads prefixed rows through durable ids" do
    recipient_id = unique_recipient("workflow")

    assert {:ok, _result} =
             Chimeway.trigger(
               ChimewayTest.Notifiers.RuntimePrefixWorkflow,
               %{recipient_id: recipient_id},
               trigger_opts("workflow")
             )

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 1)
    assert_prefixed_only("chimeway_workflow_runs", 1)

    notification = fetch_notification!(recipient_id)
    workflow_run = fetch_workflow_run!(notification.id)
    waiting_run = Repo.get!(WorkflowRun, workflow_run.id)

    assert waiting_run.state == :waiting
    assert waiting_run.pending_signals == ["chimeway.notification.read"]

    assert {:ok, signal} =
             Signal.track("acme", recipient_id, "chimeway.notification.read", %{
               "recipient_id" => recipient_id
             })

    assert_prefixed_only("chimeway_signals", 1)

    signal_args = %{"signal_id" => signal.id}
    assert_durable_id_args(signal_args, "signal_id")

    assert_enqueued(
      worker: SignalRouterWorker,
      args: signal_args
    )

    assert :ok = SignalRouterWorker.perform(%Oban.Job{args: signal_args})

    resumed_run = Repo.get!(WorkflowRun, workflow_run.id)
    assert resumed_run.state == :active
    assert resumed_run.pending_signals == []
    assert resumed_run.status_reason == "signal_received"

    signal_transitions =
      workflow_transitions(workflow_run.id)
      |> Enum.filter(&(&1.reason == "signal_received"))

    assert length(signal_transitions) == 1
    [signal_transition] = signal_transitions
    assert signal_transition.context == %{"event_name" => "chimeway.notification.read"}

    due_recipient_id = unique_recipient("workflow-due")

    assert {:ok, _result} =
             Chimeway.trigger(
               ChimewayTest.Notifiers.RuntimePrefixWorkflow,
               %{recipient_id: due_recipient_id},
               trigger_opts("workflow-due")
             )

    due_notification = fetch_notification!(due_recipient_id)
    due_run = due_notification.id |> fetch_workflow_run!() |> Repo.reload!()
    assert due_run.state == :waiting

    due_at = DateTime.utc_now() |> DateTime.add(-1, :second) |> DateTime.truncate(:microsecond)

    due_run =
      due_run
      |> Ecto.Changeset.change(
        status_context: Map.put(due_run.status_context, "due_at", DateTime.to_iso8601(due_at))
      )
      |> Repo.update!()

    progression_args = %{"workflow_run_id" => due_run.id}
    assert_durable_id_args(progression_args, "workflow_run_id")

    assert :ok = WorkflowProgressionWorker.perform(%Oban.Job{args: progression_args})

    advanced_run = Repo.get!(WorkflowRun, due_run.id)
    email_delivery = fetch_delivery!(due_notification.id, "email")

    assert advanced_run.state == :active
    assert advanced_run.status_reason == "progressed_on_delivery_outcome"
    assert email_delivery.workflow_run_id == due_run.id

    due_transitions = workflow_transitions(due_run.id)

    assert Enum.any?(due_transitions, &(&1.reason == "reactivated_from_wait"))

    assert Enum.any?(due_transitions, fn transition ->
             transition.reason == "step_activated" and transition.context["step_key"] == "email"
           end)

    assert_prefixed_only("chimeway_events")
    assert_prefixed_only("chimeway_notifications")
    assert_prefixed_only("chimeway_deliveries")
    assert_prefixed_only("chimeway_signals")
    assert_prefixed_only("chimeway_workflow_runs")
    assert_prefixed_only("chimeway_workflow_transitions")
  end

  @tag :runtime_prefix_dispatch_worker
  test "dispatch workers reload by durable delivery_id under the runtime prefix" do
    %{delivery: delivery} =
      create_pending_delivery(notification_key: "test.runtime_prefix.worker", channel: :in_app)

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 1)

    assert :ok = perform_job(ObanWorker, %{"delivery_id" => delivery.id})
    reloaded = Deliveries.get_delivery!(delivery.id)
    assert reloaded.status == :succeeded

    deferred =
      create_deferred_delivery!(
        notification_key: "test.runtime_prefix.deferred",
        recipient_identity: unique_recipient("deferred")
      )

    # Chimeway.Dispatch.ObanWorker.perform/1 and
    # Chimeway.Dispatch.DeferredResumeWorker.perform/1 must reload by durable delivery_id.
    assert :ok = DeferredResumeWorker.perform(%Oban.Job{args: %{"delivery_id" => deferred.id}})
  end

  @tag :runtime_prefix_digest
  test "digest accumulation and flush workers keep source and emitted rows prefixed" do
    rule = insert_digest_rule!("runtime.digest")

    %{delivery: delivery} =
      create_pending_delivery(
        notification_key: rule.match_notification_key,
        recipient_identity: unique_recipient("digest"),
        channel: :email
      )

    assert {:ok, delivery} =
             Deliveries.apply_planning_decision(delivery, %{
               orchestration_state: :digest_held,
               planning_reason: "digest_rule",
               planning_context: %{
                 "channel" => "email",
                 "source" => "runtime_prefix",
                 "rule_identity" => "#{rule.rule_key}:v#{rule.rule_version}"
               },
               next_eligible_at: nil
             })

    assert {:ok, bucket} =
             Accumulation.accumulate_delivery(delivery,
               accumulated_at: ~U[2026-06-01 10:05:00.000000Z]
             )

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 1)
    assert_prefixed_only("chimeway_digest_buckets", 1)
    assert_prefixed_only("chimeway_digest_memberships", 1)

    assert :ok =
             DigestFlushWorker.perform(%Oban.Job{
               args: %{"bucket_id" => bucket.id},
               scheduled_at: bucket.window_ends_at
             })

    assert %DigestBucket{digest_delivery_id: digest_delivery_id} =
             Repo.get!(DigestBucket, bucket.id)

    assert is_binary(digest_delivery_id)
  end

  @tag :runtime_prefix_webhook
  test "webhook feedback workers mutate prefixed deliveries and attempts from durable ingress ids" do
    %{delivery: delivery} =
      create_pending_delivery(notification_key: "test.runtime_prefix.webhook", channel: :email)

    body =
      Jason.encode!(%{
        "delivery_id" => delivery.id,
        "status" => "bounced",
        "event_id" => unique_key("webhook")
      })

    assert {:ok, ingress} =
             Chimeway.Webhooks.process(
               ChimewayTest.Adapters.RuntimePrefixWebhook,
               body,
               [{"signature", "valid"}],
               []
             )

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 1)
    assert_prefixed_only("chimeway_webhook_ingress", 1)

    assert_enqueued(
      worker: ProcessFeedbackWorker,
      args: %{"ingress_id" => ingress.id}
    )

    assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})
    assert Deliveries.get_delivery!(delivery.id).status == :cancelled
    assert Repo.aggregate(PersistedSignal, :count, :id) == 1
  end

  @tag :runtime_prefix_preferences
  test "preference writes and reads honor the runtime prefix" do
    recipient_id = unique_recipient("preferences")

    assert {:ok, _preference} =
             Preferences.upsert_preference(%{
               recipient_id: recipient_id,
               notification_key: "test.runtime_prefix",
               channel: "email",
               enabled: false
             })

    assert {:ok, _category} =
             Preferences.upsert_category_preference(%{
               recipient_id: recipient_id,
               notification_category: "runtime",
               enabled: false
             })

    assert_prefixed_only("chimeway_notification_preferences", 1)
    assert_prefixed_only("chimeway_category_preferences", 1)

    refute Preferences.channel_enabled?(recipient_id, "test.runtime_prefix", "email")
    refute Preferences.category_enabled?(recipient_id, "runtime")
  end

  @tag :runtime_prefix_policy_eval
  test "policy evaluation loads preferences and settings from the runtime prefix" do
    recipient_id = unique_recipient("policy")

    %{event: _event, notification: notification} =
      create_notification(
        notification_key: "test.runtime_prefix.policy",
        recipient_identity: recipient_id,
        payload: %{"category" => "runtime"}
      )

    assert {:ok, delivery} =
             Deliveries.plan_delivery(notification.id, :email,
               tenant_id: "default",
               actor_id: "system"
             )

    assert {:ok, _preference} =
             Preferences.upsert_preference(%{
               recipient_id: recipient_id,
               notification_key: "test.runtime_prefix.policy",
               channel: "email",
               enabled: false
             })

    assert {:ok, _settings} =
             Settings.upsert_settings(%{
               recipient_id: recipient_id,
               quiet_hours_enabled: true,
               quiet_hours_start: ~T[08:00:00],
               quiet_hours_end: ~T[17:00:00],
               timezone: "Etc/UTC",
               quiet_hours_behavior: :defer
             })

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 1)
    assert_prefixed_only("chimeway_notification_preferences", 1)
    assert_prefixed_only("chimeway_policy_settings", 1)

    assert {:suppress, :channel_disabled} = Policy.evaluate(delivery)
  end

  @tag :runtime_prefix_public
  test "public legacy mode remains available when host prefix config is false" do
    with_public_legacy_mode(fn ->
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.RuntimePrefix,
                 %{recipient_id: unique_recipient("public")},
                 trigger_opts("public")
               )

      assert public_count("chimeway_events") == 1
      assert public_count("chimeway_notifications") == 1
      assert public_count("chimeway_deliveries") == 2
      assert prefixed_count("chimeway_events") == 0
      assert prefixed_count("chimeway_notifications") == 0
      assert prefixed_count("chimeway_deliveries") == 0
    end)
  end

  defp create_deferred_delivery!(opts) do
    %{delivery: delivery} = create_pending_delivery(Keyword.put(opts, :delay_fallback, true))
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {:ok, deferred} =
      Deliveries.apply_planning_decision(delivery, %{
        delivery_id: delivery.id,
        delivery_ids: [delivery.id],
        channel: delivery.channel,
        planning_action: :defer,
        planning_reason: "runtime_prefix_resume",
        resume_at: DateTime.add(now, -60, :second),
        status: :pending,
        orchestration_state: :deferred
      })

    deferred
  end

  defp insert_digest_rule!(suffix) do
    {:ok, rule} =
      %{
        rule_key: "digest.#{suffix}",
        rule_version: 1,
        match_notification_key: "test.runtime_prefix.#{suffix}",
        channel: "email",
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30
      }
      |> Chimeway.Digests.upsert_rule()

    rule
  end

  defp unique_key(label), do: "runtime-prefix-#{label}-#{System.unique_integer([:positive])}"

  defp trigger_opts(label), do: [idempotency_key: unique_key(label), tenant_id: "acme"]

  defp unique_recipient(label),
    do: "user:runtime-prefix:#{label}:#{System.unique_integer([:positive])}"

  defp update_delivery!(%Delivery{} = delivery, attrs) do
    delivery
    |> Ecto.Changeset.change(attrs)
    |> Repo.update!()
  end

  defp update_timestamps!(struct, attrs) do
    struct
    |> Ecto.Changeset.change(attrs)
    |> Repo.update!()
  end

  defp fetch_notification!(recipient_id) do
    Repo.one!(
      from(n in Notification,
        where: n.recipient_identity == ^recipient_id,
        order_by: [desc: n.inserted_at],
        limit: 1
      )
    )
  end

  defp fetch_workflow_run!(notification_id) do
    Repo.one!(from(wr in WorkflowRun, where: wr.notification_id == ^notification_id))
  end

  defp fetch_delivery!(notification_id, channel) do
    Repo.one!(
      from(d in Delivery,
        where: d.notification_id == ^notification_id and d.channel == ^channel
      )
    )
  end

  defp workflow_transitions(workflow_run_id) do
    Repo.all(
      from(wt in WorkflowTransition,
        where: wt.workflow_run_id == ^workflow_run_id,
        order_by: [asc: wt.inserted_at]
      )
    )
  end

  defp assert_durable_id_args(args, key) do
    assert Map.keys(args) == [key]
    assert is_binary(Map.fetch!(args, key))
  end

  defp assert_no_operator_forbidden_keys(term) do
    term
    |> collect_keys()
    |> Enum.each(fn key ->
      refute key in @operator_forbidden_keys
    end)
  end

  defp collect_keys(%_struct{}), do: []

  defp collect_keys(term) when is_map(term) do
    Enum.flat_map(term, fn {key, value} -> [normalize_key(key) | collect_keys(value)] end)
  end

  defp collect_keys(term) when is_list(term), do: Enum.flat_map(term, &collect_keys/1)
  defp collect_keys(_term), do: []

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key), do: key

  defp restore_env(key, {:ok, value}), do: Application.put_env(:chimeway, key, value)
  defp restore_env(key, :error), do: Application.delete_env(:chimeway, key)

  defp with_public_legacy_mode(fun) do
    previous_prefix = Application.fetch_env(:chimeway, :prefix)

    Application.put_env(:chimeway, :prefix, false)

    try do
      fun.()
    after
      restore_env(:prefix, previous_prefix)
    end
  end
end
