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
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/workflow"}
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

defmodule Chimeway.RuntimePrefixIntegrationTest do
  use Chimeway.PrefixedRuntimeCase
  use Oban.Testing, repo: Chimeway.Repo, prefix: "public"

  import Chimeway.Test.DispatchHelpers,
    only: [create_notification: 1, create_pending_delivery: 1]

  alias Chimeway.{Deliveries, Preferences, Repo, Signal, Traces}
  alias Chimeway.Dispatch.{DeferredResumeWorker, DigestFlushWorker, ObanWorker}
  alias Chimeway.Digests.{Accumulation, DigestBucket}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Policy
  alias Chimeway.Policy.Settings
  alias Chimeway.Signals.Signal, as: PersistedSignal
  alias Chimeway.Webhooks.{Ingress, ProcessFeedbackWorker}

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
  test "operator and inbox APIs reload durable rows from the runtime prefix" do
    recipient_id = unique_recipient("operator")

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

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 2)
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

    assert {:ok, signal} =
             Signal.track("default", recipient_id, "chimeway.notification.read", %{
               "recipient_id" => recipient_id
             })

    assert_prefixed_only("chimeway_signals", 1)

    assert_enqueued(
      worker: Chimeway.Dispatch.SignalRouterWorker,
      args: %{"signal_id" => signal.id}
    )
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

    assert {:ok, ingress} =
             %Ingress{}
             |> Ingress.changeset(%{
               adapter_module: "RuntimePrefixAdapter",
               delivery_id: delivery.id,
               normalized_status: "bounced",
               ingress_state: :queued
             })
             |> Repo.insert()

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 1)
    assert_prefixed_only("chimeway_webhook_ingress", 1)

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
