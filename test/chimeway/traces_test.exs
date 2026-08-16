defmodule Chimeway.TracesTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{Deliveries, Delivery, Repo, Traces}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Traces.Explanation
  alias Chimeway.Workflows.{WorkflowDefinition, WorkflowRun, WorkflowStep, WorkflowTransition}

  setup do
    previous = Application.get_env(:chimeway, :single_tenant_compatibility)
    Application.put_env(:chimeway, :single_tenant_compatibility, tenant_id: "default")

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:chimeway, :single_tenant_compatibility),
        else: Application.put_env(:chimeway, :single_tenant_compatibility, previous)
    end)
  end

  # --- Helpers ---

  defp insert_event(attrs \\ %{}) do
    {:ok, event} =
      Repo.insert(%Event{
        notification_key: Map.get(attrs, :notification_key, "test_notifier"),
        notification_version: 1,
        idempotency_key: Map.get(attrs, :idempotency_key, "key-#{System.unique_integer()}"),
        tenant_id: Map.get(attrs, :tenant_id, "default"),
        payload: %{},
        correlation_id: Map.get(attrs, :correlation_id)
      })

    event
  end

  defp insert_notification(event, recipient \\ nil) do
    {:ok, notification} =
      Repo.insert(%Notification{
        event_id: event.id,
        recipient_identity: recipient || "user:#{System.unique_integer()}",
        recipient_type: "user",
        tenant_id: event.tenant_id,
        metadata: %{}
      })

    notification
  end

  defp plan_delivery(notification, channel \\ :in_app) do
    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, channel, tenant_id: "default", actor_id: "system")

    delivery
  end

  defp succeed_delivery(delivery) do
    {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

    {:ok, %{delivery: updated}} =
      Deliveries.record_attempt(dispatched, %{outcome: :succeeded, provider_response: %{}})

    updated
  end

  defp fail_delivery(delivery) do
    {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

    {:ok, %{delivery: updated}} =
      Deliveries.record_attempt(dispatched, %{outcome: :failed, provider_response: %{}})

    updated
  end

  defp suppress_delivery(delivery, reason) do
    {:ok, suppressed} = Deliveries.suppress_delivery(delivery, reason)
    suppressed
  end

  # Phase 32 fixtures — workflow run + transition rows that link by delivery_id.
  # The run keeps a private notification (different from the delivery's), satisfying
  # the unique_constraint on chimeway_workflow_runs.notification_id while still
  # exercising the delivery_id linkage on workflow transitions (D-21).
  defp insert_workflow_run_for(delivery, opts) do
    step_key = Keyword.get(opts, :step_key, "send_email")
    tenant_id = Keyword.get(opts, :tenant_id, delivery.tenant_id)

    run_event =
      Repo.insert!(%Event{
        notification_key: "test.phase32",
        notification_version: 1,
        idempotency_key: "phase32-#{System.unique_integer([:positive])}",
        tenant_id: tenant_id,
        payload: %{}
      })

    run_notification =
      Repo.insert!(%Notification{
        event_id: run_event.id,
        recipient_identity: "user:phase32-#{System.unique_integer([:positive])}",
        recipient_type: "user",
        tenant_id: tenant_id,
        metadata: %{}
      })

    definition =
      Repo.insert!(
        WorkflowDefinition.changeset(%WorkflowDefinition{}, %{
          workflow_key: "test.phase32.workflow.#{System.unique_integer([:positive])}",
          workflow_version: 1,
          notification_key: "test.phase32"
        })
      )

    step =
      Repo.insert!(
        WorkflowStep.changeset(%WorkflowStep{}, %{
          workflow_definition_id: definition.id,
          step_key: step_key,
          step_order: 1,
          channel: "in_app",
          config: %{}
        })
      )

    now = DateTime.utc_now()

    run =
      Repo.insert!(
        WorkflowRun.changeset(%WorkflowRun{}, %{
          notification_id: run_notification.id,
          workflow_definition_id: definition.id,
          current_step_id: step.id,
          state: :active,
          started_at: now,
          last_transition_at: now,
          status_reason: "phase32_test",
          tenant_id: tenant_id,
          pending_signals: []
        })
      )

    Map.put(run, :current_step, step)
  end

  defp insert_workflow_transition!(run, delivery_id, reason, context, opts \\ []) do
    Repo.insert!(
      WorkflowTransition.changeset(%WorkflowTransition{}, %{
        workflow_run_id: run.id,
        from_state: Keyword.get(opts, :from_state, :active),
        to_state: Keyword.get(opts, :to_state, :active),
        reason: reason,
        delivery_id: delivery_id,
        workflow_step_id: Keyword.get(opts, :workflow_step_id, run.current_step.id),
        context: context
      })
    )
  end

  defp insert_attempt!(delivery, attrs) do
    {:ok, attempt} =
      %Chimeway.DeliveryAttempt{}
      |> Chimeway.DeliveryAttempt.changeset(
        Map.merge(
          %{
            delivery_id: delivery.id,
            outcome: :succeeded,
            attempt_number: 1,
            adapter_module: "TestAdapter",
            provider_message_id: "msg_#{System.unique_integer([:positive])}"
          },
          attrs
        )
      )
      |> Repo.insert()

    attempt
  end

  # --- get_trace/1 ---

  describe "get_trace/1" do
    test "returns an exact closed event map with nested lifecycle maps" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _succeeded = succeed_delivery(delivery)

      assert {:ok, loaded} = Traces.get_trace(event.id)

      assert Map.keys(loaded) |> Enum.sort() ==
               [:correlation_id, :id, :inserted_at, :notification_key, :notifications, :tenant_id]

      assert loaded.id == event.id
      assert loaded.tenant_id == "default"
      assert [loaded_notification] = loaded.notifications

      assert Map.keys(loaded_notification) |> Enum.sort() ==
               [:deliveries, :id, :inserted_at, :notification_key, :recipient_id, :recipient_type]

      assert loaded_notification.id == notification.id
      assert [loaded_delivery] = loaded_notification.deliveries

      assert Map.keys(loaded_delivery) |> Enum.sort() ==
               [
                 :attempts,
                 :channel,
                 :id,
                 :inserted_at,
                 :planning_reason,
                 :render_key,
                 :render_version,
                 :status,
                 :suppression_reason,
                 :updated_at
               ]

      assert loaded_delivery.id == delivery.id
      assert length(loaded_delivery.attempts) == 1
    end

    test "returns {:error, :not_found} for unknown event_id" do
      assert {:error, :not_found} = Traces.get_trace(Ecto.UUID.generate())
    end

    test "projects correlation_id on event as an opaque reference" do
      event = insert_event(%{correlation_id: "req-abc-123"})

      assert {:ok, loaded} = Traces.get_trace(event.id)
      assert loaded.correlation_id =~ ~r/^cw_correlation_/
    end
  end

  # --- find_traces_for_recipient/2 ---

  describe "find_traces_for_recipient/2" do
    test "returns notifications for the given recipient" do
      event = insert_event()
      notification = insert_notification(event, "user:42")

      results = Traces.find_traces_for_recipient("user:42")

      assert Enum.any?(results, &(&1.id == notification.id))
    end

    test "filters by notification_key option" do
      event_a = insert_event(%{notification_key: "order_shipped"})
      event_b = insert_event(%{notification_key: "password_reset"})
      notification_a = insert_notification(event_a, "user:99")
      _notification_b = insert_notification(event_b, "user:99")

      results = Traces.find_traces_for_recipient("user:99", notification_key: "order_shipped")

      assert length(results) == 1
      assert hd(results).id == notification_a.id
    end

    test "respects limit option" do
      for _ <- 1..5 do
        e = insert_event()
        insert_notification(e, "user:limited")
      end

      results = Traces.find_traces_for_recipient("user:limited", limit: 3)
      assert length(results) == 3
    end

    test "returns [] for unknown recipient" do
      assert [] = Traces.find_traces_for_recipient("user:nonexistent")
    end
  end

  # --- find_traces_by_correlation_id/1 ---

  describe "find_traces_by_correlation_id/1" do
    test "returns matching events preloaded" do
      event = insert_event(%{correlation_id: "req-xyz"})
      _notification = insert_notification(event)

      results = Traces.find_traces_by_correlation_id("req-xyz")

      assert Enum.any?(results, &(&1.id == event.id))
      assert [loaded] = Enum.filter(results, &(&1.id == event.id))
      assert is_list(loaded.notifications)
    end

    test "returns [] for unknown correlation_id" do
      assert [] = Traces.find_traces_by_correlation_id("nonexistent-correlation")
    end

    test "respects limit option" do
      for _i <- 1..3 do
        event = insert_event(%{correlation_id: "req-limit"})
        insert_notification(event)
      end

      assert length(Traces.find_traces_by_correlation_id("req-limit", limit: 2)) == 2
    end

    test "OPS-01: get_trace and correlation lookup recover the same event identity" do
      # OPS-01: trigger-facing correlation pointers must map to the same durable event identity.
      event = insert_event(%{correlation_id: "req-ops-01-link"})
      _notification = insert_notification(event, "user:ops-01")

      assert {:ok, loaded} = Traces.get_trace(event.id)

      events = Traces.find_traces_by_correlation_id("req-ops-01-link")
      assert Enum.any?(events, &(&1.id == loaded.id))
    end
  end

  describe "trace delivery id contract for trigger outcomes" do
    test "OPS-01: trace preloads expose delivery ids as UUID lists suitable for equality checks" do
      # OPS-01: trace delivery ids should be directly comparable to trigger trace.delivery_ids.
      event = insert_event(%{correlation_id: "req-delivery-id-contract"})
      notification = insert_notification(event, "user:delivery-ids")
      delivery_one = plan_delivery(notification, :in_app)
      delivery_two = plan_delivery(notification, :email)

      assert {:ok, loaded} = Traces.get_trace(event.id)

      trace_delivery_ids =
        loaded.notifications
        |> Enum.flat_map(fn loaded_notification ->
          Enum.map(loaded_notification.deliveries, & &1.id)
        end)
        |> Enum.sort()

      durable_delivery_ids =
        Repo.all(
          from(d in Delivery,
            join: n in Notification,
            on: d.notification_id == n.id,
            where: n.event_id == ^event.id,
            select: d.id
          )
        )
        |> Enum.sort()

      assert MapSet.new(trace_delivery_ids) == MapSet.new([delivery_one.id, delivery_two.id])
      assert MapSet.new(trace_delivery_ids) == MapSet.new(durable_delivery_ids)

      assert Enum.all?(trace_delivery_ids, &is_binary/1)
    end
  end

  # --- explain_delivery/1 ---

  describe "explain_delivery/1 — succeeded delivery" do
    test "preserves the digested lifecycle status through the safe trace projection" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)

      {:ok, held} =
        Deliveries.apply_planning_decision(delivery, %{
          orchestration_state: :digest_held,
          planning_reason: "digest_rule",
          planning_context: %{"rule_identity" => "digest.test:v1"},
          next_eligible_at: nil
        })

      digest_event = insert_event(%{notification_key: "digest.test"})
      digest_notification = insert_notification(digest_event)
      digest_delivery = plan_delivery(digest_notification, :email)

      {:ok, digested} =
        Deliveries.mark_digested(
          held,
          digest_delivery.id,
          "included_in_digest",
          resolved_at: ~U[2026-08-12 12:00:00Z]
        )

      assert {:ok, explanation} = Traces.explain_delivery(digested.id)
      assert explanation.status == :digested
      assert explanation.digest["outcome"] == "digested"
      assert explanation.digest["resolution_reason"] == "included_in_digest"
    end

    test "projects hostile legacy trace values into safe operator evidence" do
      event = insert_event(%{correlation_id: "raw-correlation-sentinel"})
      notification = insert_notification(event, "raw-recipient-sentinel")
      delivery = plan_delivery(notification, :email)

      delivery =
        delivery
        |> Ecto.Changeset.change(%{
          planning_context: %{
            "rule_identity" => "quiet-hours",
            "nested" => %{"Provider_Body" => "provider-detail-sentinel"}
          }
        })
        |> Repo.update!()

      insert_attempt!(delivery, %{
        outcome: :failed,
        error_class: "temporary",
        adapter_module: "Raw.Adapter.Sentinel",
        provider_message_id: "cw_provider_trace-safe",
        provider_response: %{"Provider_Body" => "provider-detail-sentinel"}
      })

      assert {:ok, explanation} = Traces.explain_delivery(delivery.id)
      encoded = :erlang.term_to_binary(explanation)

      for sentinel <- [
            "raw-correlation-sentinel",
            "raw-recipient-sentinel",
            "provider-detail-sentinel",
            "Raw.Adapter.Sentinel"
          ] do
        assert :binary.match(encoded, sentinel) == :nomatch, "leaked #{sentinel}"
      end

      assert explanation.notification_key == "test_notifier"
      assert explanation.last_attempt.outcome == :failed
      assert explanation.last_attempt.error_class == "temporary"

      assert Map.keys(explanation.last_attempt) |> Enum.sort() == [
               :attempt_number,
               :error_class,
               :id,
               :inserted_at,
               :outcome,
               :provider_message_id
             ]

      assert String.starts_with?(
               explanation.last_attempt.provider_message_id,
               "cw_provider_message_id_"
             )

      assert :attempt_recorded in Enum.map(explanation.timeline, & &1.event)

      assert Enum.all?(explanation.timeline, fn entry ->
               Enum.sort(Map.keys(entry)) == [:at, :detail, :event]
             end)
    end

    test "returns correct explanation struct" do
      event = insert_event(%{correlation_id: "req-success"})
      notification = insert_notification(event, "user:success")
      delivery = plan_delivery(notification)
      _succeeded = succeed_delivery(delivery)

      assert {:ok, %Explanation{} = exp} = Traces.explain_delivery(delivery.id)
      assert exp.delivery_id == delivery.id
      assert exp.event_id == event.id
      assert String.starts_with?(exp.correlation_id, "cw_correlation_")
      assert exp.notification_key == "test_notifier"
      assert String.starts_with?(exp.recipient_id, "cw_recipient_")
      assert exp.channel == "in_app"
      assert exp.status == :succeeded
      assert exp.suppression_reason == nil
      assert %{outcome: :succeeded} = exp.last_attempt
      assert is_list(exp.timeline)
    end

    test "timeline contains :event_created, :notification_created, :delivery_planned, :attempt_recorded" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _succeeded = succeed_delivery(delivery)

      assert {:ok, exp} = Traces.explain_delivery(delivery.id)
      event_names = Enum.map(exp.timeline, & &1.event)

      assert :event_created in event_names
      assert :notification_created in event_names
      assert :delivery_planned in event_names
      assert :attempt_recorded in event_names
    end

    test "timeline is sorted ascending by timestamp" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _succeeded = succeed_delivery(delivery)

      assert {:ok, exp} = Traces.explain_delivery(delivery.id)
      timestamps = Enum.map(exp.timeline, & &1.at)
      assert timestamps == Enum.sort(timestamps, DateTime)
    end
  end

  describe "explain_delivery/1 — webhook + workflow timeline" do
    test "Scenario A: bounced delivery + workflow_stopped transition surfaces both events" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)

      # Bounced attempt — drives :webhook_received with outcome :bounced
      _attempt =
        insert_attempt!(delivery, %{
          outcome: :bounced,
          error_class: "bounced",
          attempt_number: 1,
          adapter_module: "TestAdapter",
          provider_message_id: "msg_abc"
        })

      run = insert_workflow_run_for(delivery, step_key: "send_email")

      # signal_received companion row (Phase 32 D-02 populated delivery_id)
      insert_workflow_transition!(run, delivery.id, "signal_received", %{
        "event_name" => "chimeway.delivery.bounced"
      })

      # The progression engine's transition row
      insert_workflow_transition!(run, delivery.id, "workflow_stopped", %{
        "workflow_outcome" => "bounced",
        "from_step" => "send_email",
        "to_step" => nil
      })

      assert {:ok, %Explanation{timeline: timeline}} = Traces.explain_delivery(delivery.id)
      event_names = Enum.map(timeline, & &1.event)

      assert :webhook_received in event_names
      assert :workflow_stopped in event_names
      # Backward-compat: existing entries still present
      assert :attempt_recorded in event_names

      webhook = Enum.find(timeline, &(&1.event == :webhook_received))
      assert webhook.detail.outcome == :bounced
      refute Map.has_key?(webhook.detail, :adapter_module)
      refute Map.has_key?(webhook.detail, :provider_message_id)
      assert webhook.detail.signal_event_name == "chimeway.delivery.bounced"

      stopped = Enum.find(timeline, &(&1.event == :workflow_stopped))
      assert stopped.detail.workflow_outcome == "bounced"
      assert stopped.detail.from_step == "send_email"
      assert stopped.detail.workflow_run_id == run.id
      # D-12 seven-field contract: reason is a verbatim copy of transition.reason
      # (UI-SPEC line 273 shows `reason: "workflow_stopped"` in the operator output)
      assert stopped.detail.reason == "workflow_stopped"
    end

    test "Scenario B: succeeded + workflow_progressed surfaces both events" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)

      _attempt =
        insert_attempt!(delivery, %{
          outcome: :succeeded,
          error_class: nil,
          attempt_number: 1,
          adapter_module: "TestAdapter",
          provider_message_id: "msg_def"
        })

      run = insert_workflow_run_for(delivery, step_key: "send_email")

      insert_workflow_transition!(run, delivery.id, "signal_received", %{
        "event_name" => "chimeway.delivery.succeeded"
      })

      insert_workflow_transition!(run, delivery.id, "progressed_on_delivery_outcome", %{
        "workflow_outcome" => "delivered",
        "from_step" => "send_email",
        "to_step" => "wait_for_open"
      })

      assert {:ok, %Explanation{timeline: timeline}} = Traces.explain_delivery(delivery.id)
      event_names = Enum.map(timeline, & &1.event)

      assert :webhook_received in event_names
      assert :workflow_progressed in event_names

      webhook = Enum.find(timeline, &(&1.event == :webhook_received))
      assert webhook.detail.outcome == :succeeded

      progressed = Enum.find(timeline, &(&1.event == :workflow_progressed))
      assert progressed.detail.workflow_outcome == "delivered"
      assert progressed.detail.from_step == "send_email"
      assert progressed.detail.to_step == "wait_for_open"
      assert progressed.detail.workflow_run_id == run.id
      # D-12 seven-field contract — verbatim copy of transition.reason
      assert progressed.detail.reason == "progressed_on_delivery_outcome"
    end

    test "Scenario C: list_traces/3 surfaces populated delivery_id by struct introspection" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)

      run = insert_workflow_run_for(delivery, step_key: "send_email")

      # One transition WITHOUT a delivery link (e.g. step_activated)
      insert_workflow_transition!(run, nil, "step_activated", %{"event_name" => "internal_cursor"})

      # One transition WITH a delivery link (Phase 32 D-02)
      insert_workflow_transition!(run, delivery.id, "workflow_stopped", %{
        "workflow_outcome" => "bounced"
      })

      assert {:ok, traces} = Chimeway.Workflows.list_traces(delivery.tenant_id, run.id)
      delivery_ids = Enum.map(traces, & &1.delivery_id)

      # The populated delivery_id surfaces by struct introspection (D-10)
      assert delivery.id in delivery_ids
      # The unpopulated transition is still nil
      assert nil in delivery_ids
    end

    test "Scenario D: cross-tenant transitions are excluded by defensive WorkflowRun.tenant_id join" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)

      _attempt =
        insert_attempt!(delivery, %{
          outcome: :succeeded,
          error_class: nil,
          attempt_number: 1,
          adapter_module: "TestAdapter",
          provider_message_id: "msg_xyz"
        })

      # Tenant A's run + transition keyed by delivery.id (delivery.tenant_id == "default")
      run_a = insert_workflow_run_for(delivery, step_key: "send_email")

      insert_workflow_transition!(run_a, delivery.id, "workflow_completed", %{
        "workflow_outcome" => "delivered"
      })

      # Tenant B's run pointing at the same delivery.id but owned by a foreign tenant.
      # FK chain limitation — cross-tenant delivery_id reuse is impossible in
      # production, so we synthesize the adversarial state at the WorkflowRun
      # boundary to verify the defensive wr.tenant_id == ^delivery.tenant_id
      # filter (D-09 / T-32-T1).
      run_b =
        insert_workflow_run_for(delivery, step_key: "send_email", tenant_id: "tenant_b_synth")

      insert_workflow_transition!(run_b, delivery.id, "workflow_stopped", %{
        "workflow_outcome" => "bounced"
      })

      # Querying explain_delivery/1 for delivery (tenant "default") must NOT surface
      # tenant_b's transition — the wr.tenant_id filter excludes it (D-09).
      assert {:ok, %Explanation{timeline: timeline}} = Traces.explain_delivery(delivery.id)
      event_names = Enum.map(timeline, & &1.event)

      assert :workflow_completed in event_names
      refute :workflow_stopped in event_names
    end
  end

  describe "explain_delivery/1 — timeline detail PII boundary" do
    test "no new event atom's :detail map exposes payload, recipient, or provider_response" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)

      _attempt =
        insert_attempt!(delivery, %{
          outcome: :succeeded,
          error_class: nil,
          attempt_number: 1,
          adapter_module: "TestAdapter",
          provider_message_id: "msg_pii_check"
        })

      run = insert_workflow_run_for(delivery, step_key: "send_email")

      insert_workflow_transition!(run, delivery.id, "signal_received", %{
        "event_name" => "chimeway.delivery.succeeded"
      })

      # One row per progression atom so each appears in the timeline.
      insert_workflow_transition!(run, delivery.id, "progressed_on_delivery_outcome", %{
        "workflow_outcome" => "delivered",
        "from_step" => "a",
        "to_step" => "b"
      })

      insert_workflow_transition!(run, delivery.id, "waiting_for_step_progression", %{
        "due_at" => "2026-05-02T00:00:00Z",
        "rule_kind" => "wait_until"
      })

      insert_workflow_transition!(run, delivery.id, "workflow_stopped", %{
        "workflow_outcome" => "stopped"
      })

      insert_workflow_transition!(run, delivery.id, "workflow_completed", %{
        "workflow_outcome" => "completed"
      })

      assert {:ok, %Explanation{timeline: timeline}} = Traces.explain_delivery(delivery.id)

      new_atoms = [
        :webhook_received,
        :workflow_progressed,
        :workflow_waiting,
        :workflow_stopped,
        :workflow_completed
      ]

      # NOTE: :reason is allowed (D-12 seven-field detail contract) and is
      # NOT in this list. Vendor PII strings (recipient, email, phone,
      # provider_response body, raw payload) ARE forbidden.
      forbidden = [:payload, :data, :recipient, :email, :phone, :provider_response]

      for atom <- new_atoms,
          entry <- Enum.filter(timeline, &(&1.event == atom)),
          key <- forbidden do
        refute Map.has_key?(entry.detail, key),
               "expected #{atom} :detail to not contain #{inspect(key)}; got: #{inspect(entry.detail)}"
      end

      # Defense-in-depth: every new atom appears in this fixture (sanity check
      # so the for-comprehension above is not vacuously true).
      event_names = Enum.map(timeline, & &1.event)

      for atom <- new_atoms do
        assert atom in event_names, "expected fixture to produce #{atom} entry"
      end
    end
  end

  describe "explain_delivery/1 — suppressed delivery" do
    test "returns suppressed status with reason, no last_attempt" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _suppressed = suppress_delivery(delivery, :channel_disabled)

      assert {:ok, %Explanation{} = exp} = Traces.explain_delivery(delivery.id)
      assert exp.status == :suppressed
      assert exp.suppression_reason == "channel_disabled"
      assert exp.last_attempt == nil
    end

    test "timeline includes :suppressed entry" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _suppressed = suppress_delivery(delivery, :channel_disabled)

      assert {:ok, exp} = Traces.explain_delivery(delivery.id)
      event_names = Enum.map(exp.timeline, & &1.event)
      assert :suppressed in event_names
    end
  end

  describe "explain_delivery/1 — failed delivery" do
    test "returns failed status with last_attempt outcome" do
      event = insert_event()
      notification = insert_notification(event)
      delivery = plan_delivery(notification)
      _failed = fail_delivery(delivery)

      assert {:ok, %Explanation{} = exp} = Traces.explain_delivery(delivery.id)
      assert exp.status == :failed
      assert exp.suppression_reason == nil
      assert %{outcome: :failed} = exp.last_attempt
    end
  end

  describe "explain_delivery/1 — custom channel safety" do
    test "OPS-01: returns explanation for custom string channel without raising" do
      # OPS-01: operator explainability must remain available for valid custom channels.
      event = insert_event(%{correlation_id: "req-custom-channel"})
      notification = insert_notification(event, "user:webhook")
      delivery = plan_delivery(notification, "webhook_partner")

      assert {:ok, %Explanation{channel: "webhook_partner"}} =
               Traces.explain_delivery(delivery.id)
    end

    test "OPS-01: timeline keeps :delivery_planned for custom string channel explanations" do
      # OPS-01: timeline event coverage must include planning for custom channels.
      event = insert_event()
      notification = insert_notification(event, "user:webhook-timeline")
      delivery = plan_delivery(notification, "webhook_partner")

      assert {:ok, %Explanation{channel: "webhook_partner", timeline: timeline}} =
               Traces.explain_delivery(delivery.id)

      assert :delivery_planned in Enum.map(timeline, & &1.event)
    end
  end

  describe "explain_delivery/1 — not found" do
    test "returns {:error, :not_found} for unknown delivery_id" do
      assert {:error, :not_found} = Traces.explain_delivery(Ecto.UUID.generate())
    end
  end

  describe "explain_delivery/1 — REL-02 D-07 attempt_number and error_class fields" do
    test "last_attempt surfaces attempt_number and error_class on a temporary failure" do
      ctx = create_pending_delivery_for_traces()

      {:ok, dispatched} = Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: failed}} =
        Deliveries.record_attempt(dispatched, %{
          outcome: :failed,
          error_class: "temporary",
          provider_response: %{reason: "x"}
        })

      assert {:ok, %Chimeway.Traces.Explanation{last_attempt: last_attempt, timeline: timeline}} =
               Chimeway.Traces.explain_delivery(failed.id)

      assert last_attempt.outcome == :failed
      assert last_attempt.attempt_number == 1
      assert last_attempt.error_class == "temporary"

      attempt_entries = Enum.filter(timeline, fn entry -> entry.event == :attempt_recorded end)
      assert length(attempt_entries) == 1
      [%{detail: detail}] = attempt_entries
      assert detail.outcome == :failed
      assert detail.attempt_number == 1
      assert detail.error_class == "temporary"
    end

    test "last_attempt has nil error_class on a succeeded delivery" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: succeeded}} =
        Deliveries.record_attempt(dispatched, %{
          outcome: :succeeded,
          error_class: nil,
          provider_response: %{}
        })

      assert {:ok, %Chimeway.Traces.Explanation{last_attempt: last_attempt}} =
               Chimeway.Traces.explain_delivery(succeeded.id)

      assert last_attempt.outcome == :succeeded
      assert last_attempt.error_class == nil
      assert last_attempt.attempt_number == 1
    end

    test "last_attempt reflects the most recent attempt across multiple records" do
      ctx = create_pending_delivery_for_traces()

      # Record three attempts: failed temporary, failed temporary, succeeded.
      {:ok, dispatched_a} = Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: failed_a}} =
        Deliveries.record_attempt(dispatched_a, %{
          outcome: :failed,
          error_class: "temporary",
          provider_response: %{seq: 1}
        })

      {:ok, dispatched_b} = Deliveries.transition_status(failed_a, :dispatched)

      {:ok, %{delivery: failed_b}} =
        Deliveries.record_attempt(dispatched_b, %{
          outcome: :failed,
          error_class: "temporary",
          provider_response: %{seq: 2}
        })

      {:ok, dispatched_c} = Deliveries.transition_status(failed_b, :dispatched)

      {:ok, %{delivery: succeeded}} =
        Deliveries.record_attempt(dispatched_c, %{
          outcome: :succeeded,
          error_class: nil,
          provider_response: %{seq: 3}
        })

      assert {:ok, %Chimeway.Traces.Explanation{last_attempt: last_attempt}} =
               Chimeway.Traces.explain_delivery(succeeded.id)

      assert last_attempt.outcome == :succeeded
      assert last_attempt.attempt_number == 3
      assert last_attempt.error_class == nil
    end
  end

  describe "explain_delivery/1 — adapter privacy boundary" do
    test "last_attempt omits adapter module persisted on the attempt row" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: succeeded}} =
        Deliveries.record_attempt(dispatched, %{
          outcome: :succeeded,
          provider_response: %{},
          adapter_module: "Chimeway.Adapters.Test"
        })

      assert {:ok, %Explanation{last_attempt: last_attempt, timeline: timeline}} =
               Traces.explain_delivery(succeeded.id)

      refute Map.has_key?(last_attempt, :adapter_module)

      attempt_entries = Enum.filter(timeline, fn entry -> entry.event == :attempt_recorded end)
      assert length(attempt_entries) == 1
      [%{detail: detail}] = attempt_entries
      refute Map.has_key?(detail, :adapter_module)
    end

    test "last_attempt omits adapter module for legacy attempts" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Deliveries.transition_status(ctx.delivery, :dispatched)

      # Simulate a pre-Phase-29 attempt by NOT supplying :adapter_module — the
      # column is nullable and defaults to nil for legacy rows.
      {:ok, %{delivery: succeeded}} =
        Deliveries.record_attempt(dispatched, %{
          outcome: :succeeded,
          provider_response: %{}
        })

      assert {:ok, %Explanation{last_attempt: last_attempt, timeline: timeline}} =
               Traces.explain_delivery(succeeded.id)

      refute Map.has_key?(last_attempt, :adapter_module)

      attempt_entries = Enum.filter(timeline, fn entry -> entry.event == :attempt_recorded end)
      assert length(attempt_entries) == 1
      [%{detail: detail}] = attempt_entries
      refute Map.has_key?(detail, :adapter_module)
    end

    test "adapter_module remains absent across multiple attempts" do
      ctx = create_pending_delivery_for_traces()

      {:ok, dispatched_a} = Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: failed_a}} =
        Deliveries.record_attempt(dispatched_a, %{
          outcome: :failed,
          error_class: "temporary",
          provider_response: %{seq: 1},
          adapter_module: "Chimeway.Adapters.Logger"
        })

      {:ok, dispatched_b} = Deliveries.transition_status(failed_a, :dispatched)

      {:ok, %{delivery: succeeded}} =
        Deliveries.record_attempt(dispatched_b, %{
          outcome: :succeeded,
          provider_response: %{seq: 2},
          adapter_module: "Chimeway.Adapters.Test"
        })

      assert {:ok, %Explanation{last_attempt: last_attempt, timeline: timeline}} =
               Traces.explain_delivery(succeeded.id)

      assert last_attempt.attempt_number == 2
      refute Map.has_key?(last_attempt, :adapter_module)

      attempt_entries =
        timeline
        |> Enum.filter(fn entry -> entry.event == :attempt_recorded end)
        |> Enum.sort_by(& &1.detail.attempt_number)

      assert length(attempt_entries) == 2
      [first_entry, second_entry] = attempt_entries
      refute Map.has_key?(first_entry.detail, :adapter_module)
      refute Map.has_key?(second_entry.detail, :adapter_module)
    end
  end

  describe "explain_delivery/1 — Phase 14 trace surface drift fixes (WR-05, WR-06)" do
    test "WR-05 regression: last_attempt_summary selects by attempt_number when inserted_at ties" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Chimeway.Deliveries.transition_status(ctx.delivery, :dispatched)

      # B1 fix: insert two attempts with the SAME inserted_at value. The schema field
      # type is :utc_datetime_usec (lib/chimeway/delivery_attempt.ex:43), which requires
      # microsecond precision ({microseconds, scale} where scale == 6). We truncate to
      # second then set microsecond: {0, 6} — both rows store the same bytewise-identical
      # timestamp with zero microseconds at usec scale. There is NO :updated_at field on
      # DeliveryAttempt (moduledoc line 4: "No updated_at — attempts are never mutated.")
      # — do NOT try to put_change/3 it.
      #
      # The changeset's put_inserted_at/1 helper (lib/chimeway/delivery_attempt.ex:71-77)
      # preserves an explicitly-set :inserted_at via get_field check, so
      # `|> Ecto.Changeset.put_change(:inserted_at, shared_at)` is the right wedge.
      shared_at =
        DateTime.utc_now()
        |> DateTime.truncate(:second)
        |> then(fn dt -> %{dt | microsecond: {0, 6}} end)

      {:ok, %Chimeway.DeliveryAttempt{} = first} =
        %Chimeway.DeliveryAttempt{}
        |> Chimeway.DeliveryAttempt.changeset(%{
          delivery_id: dispatched.id,
          outcome: :failed,
          error_class: "temporary",
          attempt_number: 1,
          provider_response: %{seq: 1}
        })
        |> Ecto.Changeset.put_change(:inserted_at, shared_at)
        |> Chimeway.Repo.insert()

      {:ok, %Chimeway.DeliveryAttempt{} = second} =
        %Chimeway.DeliveryAttempt{}
        |> Chimeway.DeliveryAttempt.changeset(%{
          delivery_id: dispatched.id,
          outcome: :succeeded,
          error_class: nil,
          attempt_number: 2,
          provider_response: %{seq: 2}
        })
        |> Ecto.Changeset.put_change(:inserted_at, shared_at)
        |> Chimeway.Repo.insert()

      # Sanity: tied inserted_at would make Enum.max_by(_, & &1.inserted_at) non-deterministic.
      # Both rows store the same %DateTime{} value (microseconds {0, 6} on both).
      assert first.inserted_at == second.inserted_at,
             "test setup invariant: both attempts must share inserted_at to exercise the tie-break. " <>
               "first=#{inspect(first.inserted_at)} second=#{inspect(second.inserted_at)}"

      assert {:ok, %Chimeway.Traces.Explanation{last_attempt: last_attempt}} =
               Chimeway.Traces.explain_delivery(dispatched.id)

      # Post-fix: max_by attempt_number wins. attempt 2 (succeeded) is "last".
      # Pre-fix: max_by inserted_at ties; result depends on list ordering.
      assert last_attempt.attempt_number == 2
      assert last_attempt.outcome == :succeeded
    end

    test "WR-06 regression: :cancelled with retries_exhausted emits a :cancelled timeline entry" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Chimeway.Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: failed}} =
        Chimeway.Deliveries.record_attempt(dispatched, %{
          outcome: :failed,
          error_class: "temporary",
          provider_response: %{}
        })

      {:ok, exhausted} = Chimeway.Deliveries.exhaust_delivery(failed)
      assert exhausted.status == :cancelled
      assert exhausted.suppression_reason == "retries_exhausted"

      assert {:ok, %Chimeway.Traces.Explanation{timeline: timeline}} =
               Chimeway.Traces.explain_delivery(exhausted.id)

      cancelled_entries = Enum.filter(timeline, fn entry -> entry.event == :cancelled end)
      assert length(cancelled_entries) == 1
      [%{at: at, detail: detail}] = cancelled_entries
      assert detail.reason == "retries_exhausted"
      assert at == exhausted.updated_at
    end

    test "WR-06 regression: :cancelled with permanent_failure emits a :cancelled timeline entry" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Chimeway.Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: cancelled}} =
        Chimeway.Deliveries.record_attempt(dispatched, %{
          outcome: :rejected,
          error_class: "permanent",
          provider_response: %{}
        })

      assert cancelled.status == :cancelled
      assert cancelled.suppression_reason == "permanent_failure"

      assert {:ok, %Chimeway.Traces.Explanation{timeline: timeline}} =
               Chimeway.Traces.explain_delivery(cancelled.id)

      cancelled_entries = Enum.filter(timeline, fn entry -> entry.event == :cancelled end)
      assert length(cancelled_entries) == 1
      [%{detail: detail}] = cancelled_entries
      assert detail.reason == "permanent_failure"
    end

    test "WR-06 regression: :cancelled with bounced emits a :cancelled timeline entry" do
      ctx = create_pending_delivery_for_traces()
      {:ok, dispatched} = Chimeway.Deliveries.transition_status(ctx.delivery, :dispatched)

      {:ok, %{delivery: cancelled}} =
        Chimeway.Deliveries.record_attempt(dispatched, %{
          outcome: :bounced,
          error_class: "bounced",
          provider_response: %{}
        })

      assert cancelled.status == :cancelled
      assert cancelled.suppression_reason == "bounced"

      assert {:ok, %Chimeway.Traces.Explanation{timeline: timeline}} =
               Chimeway.Traces.explain_delivery(cancelled.id)

      cancelled_entries = Enum.filter(timeline, fn entry -> entry.event == :cancelled end)
      assert length(cancelled_entries) == 1
      [%{detail: detail}] = cancelled_entries
      assert detail.reason == "bounced"
    end

    test "WR-06 regression: :suppressed deliveries do NOT emit a :cancelled timeline entry (no double-counting)" do
      ctx = create_pending_delivery_for_traces()

      {:ok, suppressed} =
        Chimeway.Deliveries.suppress_delivery(ctx.delivery, :channel_disabled,
          checkpoint: :perform
        )

      assert suppressed.status == :suppressed

      assert {:ok, %Chimeway.Traces.Explanation{timeline: timeline}} =
               Chimeway.Traces.explain_delivery(suppressed.id)

      cancelled_entries = Enum.filter(timeline, fn entry -> entry.event == :cancelled end)

      assert cancelled_entries == [],
             "expected no :cancelled entries for a :suppressed delivery; got #{inspect(cancelled_entries)}"

      suppressed_entries = Enum.filter(timeline, fn entry -> entry.event == :suppressed end)
      assert length(suppressed_entries) == 1
    end
  end

  describe "opts propagation" do
    test "get_trace/2 passes opts to Repo" do
      assert_raise Postgrex.Error,
                   ~r/relation "nonexistent_schema.chimeway_events" does not exist/,
                   fn ->
                     Traces.get_trace(Ecto.UUID.generate(), prefix: "nonexistent_schema")
                   end
    end

    test "find_traces_for_recipient/2 passes opts to Repo" do
      assert_raise Postgrex.Error,
                   ~r/relation "nonexistent_schema.chimeway_notifications" does not exist/,
                   fn ->
                     Traces.find_traces_for_recipient("user:123", prefix: "nonexistent_schema")
                   end
    end

    test "find_traces_by_correlation_id/2 passes opts to Repo" do
      assert_raise Postgrex.Error,
                   ~r/relation "nonexistent_schema.chimeway_events" does not exist/,
                   fn ->
                     Traces.find_traces_by_correlation_id("req-xyz", prefix: "nonexistent_schema")
                   end
    end

    test "explain_delivery/2 passes opts to Repo" do
      assert_raise Postgrex.Error,
                   ~r/relation "nonexistent_schema.chimeway_deliveries" does not exist/,
                   fn ->
                     Traces.explain_delivery(Ecto.UUID.generate(), prefix: "nonexistent_schema")
                   end
    end
  end

  describe "Phase 22 recovery explainability and outcome analytics" do
    test "explain_delivery surfaces durable recovery facts after a delivery is claimed for recovery" do
      ctx = create_pending_delivery_for_traces()
      recovered_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      assert {:ok, recovered} =
               Deliveries.begin_recovery(ctx.delivery,
                 now: recovered_at,
                 older_than: 0,
                 source: "ops_console",
                 reason: "worker_missed",
                 actor_ref: "ops:1",
                 confirmation_marker: "operator_confirmed_recovery",
                 session: %{"token" => "raw-session-token"},
                 params: %{"auth_code" => "raw-auth-code"},
                 payload: %{"secret" => "raw-payload-secret"},
                 provider_response: %{"authorization" => "Bearer raw"},
                 recipient_email: "alex@example.test"
               )

      assert {:ok, %Explanation{} = explanation} = Traces.explain_delivery(recovered.id)

      recovered_entries = Enum.filter(explanation.timeline, &(&1.event == :recovered))
      assert length(recovered_entries) == 1

      [%{at: timeline_recovered_at, detail: recovery_detail}] = recovered_entries

      assert DateTime.compare(timeline_recovered_at, recovered_at) == :eq
      assert recovery_detail.recovery_source == "ops_console"
      assert recovery_detail.recovery_reason == "worker_missed"
      refute Map.has_key?(recovery_detail, :recovery_actor_ref)
      refute Map.has_key?(recovery_detail, :recovery_confirmation_marker)
      assert DateTime.compare(recovery_detail.recovered_at, recovered_at) == :eq
      refute Map.has_key?(recovery_detail, :payload)
      refute Map.has_key?(recovery_detail, :provider_response)

      rendered_detail = inspect(recovery_detail)
      refute rendered_detail =~ "raw-session-token"
      refute rendered_detail =~ "raw-auth-code"
      refute rendered_detail =~ "raw-payload-secret"
      refute rendered_detail =~ "Bearer raw"
      refute rendered_detail =~ "alex@example.test"
    end

    test "aggregate_outcomes groups counts by notification_key, channel, and lifecycle bucket" do
      _base = create_outcome_fixture("ops.analytics", "email")

      assert outcome_rows(notification_key: "ops.analytics", channel: "email") == [
               %{
                 notification_key: "ops.analytics",
                 channel: "email",
                 outcome: "delayed",
                 count: 1
               },
               %{
                 notification_key: "ops.analytics",
                 channel: "email",
                 outcome: "digested",
                 count: 1
               },
               %{
                 notification_key: "ops.analytics",
                 channel: "email",
                 outcome: "exhausted",
                 count: 1
               },
               %{
                 notification_key: "ops.analytics",
                 channel: "email",
                 outcome: "failed",
                 count: 1
               },
               %{notification_key: "ops.analytics", channel: "email", outcome: "sent", count: 2},
               %{
                 notification_key: "ops.analytics",
                 channel: "email",
                 outcome: "suppressed",
                 count: 1
               }
             ]
    end

    test "aggregate_outcomes keeps exhausted distinct from other cancelled outcomes" do
      _base = create_outcome_fixture("ops.cancelled", "email")

      exhausted =
        Traces.aggregate_outcomes(notification_key: "ops.cancelled", channel: "email")
        |> Enum.find(&(&1.outcome == "exhausted"))

      assert exhausted.count == 1

      refute Enum.any?(
               Traces.aggregate_outcomes(notification_key: "ops.cancelled", channel: "email"),
               &(&1.outcome == "cancelled")
             )
    end

    test "aggregate_outcomes counts delayed only while rows remain pending and deferred" do
      _base = create_outcome_fixture("ops.delayed", "email")

      assert [
               %{notification_key: "ops.delayed", channel: "email", outcome: "delayed", count: 1}
             ] =
               Traces.aggregate_outcomes(
                 notification_key: "ops.delayed",
                 channel: "email",
                 outcomes: ["delayed"]
               )
    end

    test "aggregate_outcomes returns payload-safe identifiers and counts only" do
      _base = create_outcome_fixture("ops.safe-surface", "email")

      rows = Traces.aggregate_outcomes(notification_key: "ops.safe-surface", channel: "email")

      assert Enum.all?(rows, fn row ->
               Enum.sort(Map.keys(row)) == [:channel, :count, :notification_key, :outcome]
             end)

      refute inspect(rows) =~ "provider_response"
      refute inspect(rows) =~ "secret"
      refute inspect(rows) =~ "payload"
    end
  end

  defp create_pending_delivery_for_traces do
    {:ok, event} =
      Chimeway.Repo.insert(%Chimeway.Events.Event{
        notification_key: "traces.attempt.fields.test",
        notification_version: 1,
        idempotency_key: "traces-#{System.unique_integer()}",
        tenant_id: "default",
        payload: %{}
      })

    {:ok, notification} =
      Chimeway.Repo.insert(%Chimeway.Notifications.Notification{
        event_id: event.id,
        recipient_identity: "user:#{System.unique_integer()}",
        recipient_type: "user",
        tenant_id: "default",
        metadata: %{}
      })

    {:ok, delivery} =
      %Chimeway.Delivery{}
      |> Chimeway.Delivery.changeset(%{
        notification_id: notification.id,
        channel: "in_app",
        status: :pending,
        tenant_id: "default",
        actor_id: "system"
      })
      |> Chimeway.Repo.insert()

    %{event: event, notification: notification, delivery: delivery}
  end

  defp create_outcome_fixture(notification_key, channel) do
    sent = insert_notification(insert_event(%{notification_key: notification_key}), "user:sent")

    suppressed =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:suppressed")

    delayed =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:delayed")

    resumed =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:resumed")

    digested =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:digested")

    failed =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:failed")

    exhausted =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:exhausted")

    cancelled =
      insert_notification(insert_event(%{notification_key: notification_key}), "user:cancelled")

    sent_delivery =
      sent
      |> plan_delivery(channel)
      |> succeed_delivery()

    _suppressed_delivery =
      suppressed
      |> plan_delivery(channel)
      |> suppress_delivery(:channel_disabled)

    delayed_delivery =
      delayed
      |> plan_delivery(channel)
      |> defer_delivery()

    resumed
    |> plan_delivery(channel)
    |> defer_delivery()
    |> resume_delivery()
    |> succeed_delivery()

    digested_delivery =
      digested
      |> plan_delivery(channel)
      |> digest_delivery()

    failed_delivery =
      failed
      |> plan_delivery(channel)
      |> fail_delivery()

    exhausted_delivery =
      exhausted
      |> plan_delivery(channel)
      |> fail_delivery()
      |> exhaust_delivery()

    _other_cancelled_delivery =
      cancelled
      |> plan_delivery(channel)
      |> cancel_delivery("manual")

    %{
      notification_key: notification_key,
      channel: channel,
      sent_delivery: sent_delivery,
      delayed_delivery: delayed_delivery,
      digested_delivery: digested_delivery,
      failed_delivery: failed_delivery,
      exhausted_delivery: exhausted_delivery
    }
  end

  defp defer_delivery(delivery) do
    {:ok, updated} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :deferred,
        planning_reason: "quiet_hours",
        planning_context: %{
          "rule_identity" => "quiet_hours",
          "time_zone" => "America/New_York",
          "payload" => %{"secret" => "ignored"}
        },
        next_eligible_at: ~U[2026-01-15 13:00:00.000000Z]
      })

    updated
  end

  defp resume_delivery(delivery) do
    {:ok, resumed} =
      Deliveries.resume_deferred_delivery(delivery.id,
        now: ~U[2026-01-15 13:05:00.000000Z],
        source: "scheduled_resume"
      )

    resumed
  end

  defp digest_delivery(delivery) do
    {:ok, held} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :digest_held,
        planning_reason: "digest_rule",
        planning_context: %{"rule_identity" => "digest_rule", "channel" => delivery.channel}
      })

    digest_delivery_id =
      held.channel
      |> insert_digest_delivery()
      |> Map.fetch!(:id)

    {:ok, digested} =
      Deliveries.mark_digested(held, digest_delivery_id, "digest_window_closed")

    digested
  end

  defp exhaust_delivery(delivery) do
    {:ok, exhausted} = Deliveries.exhaust_delivery(delivery)
    exhausted
  end

  defp cancel_delivery(delivery, reason) do
    {:ok, cancelled} =
      delivery
      |> Ecto.Changeset.change(%{status: :cancelled, suppression_reason: reason})
      |> Repo.update()

    cancelled
  end

  defp insert_digest_delivery(channel) do
    digest_event = insert_event(%{notification_key: "ops.digest.summary"})
    digest_notification = insert_notification(digest_event, "user:digest-summary")
    plan_delivery(digest_notification, channel)
  end

  defp outcome_rows(opts) do
    opts
    |> Traces.aggregate_outcomes()
    |> Enum.sort_by(&{&1.notification_key, &1.channel, &1.outcome})
  end
end
