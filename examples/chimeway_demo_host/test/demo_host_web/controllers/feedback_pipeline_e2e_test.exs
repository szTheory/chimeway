defmodule DemoHostWeb.FeedbackPipelineE2ETest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  import Ecto.Query, only: [from: 2]
  use Oban.Testing, repo: Chimeway.Repo, prefix: "public"

  alias Chimeway.{Deliveries, Repo, Traces}
  alias Chimeway.DeliveryAttempt
  alias Chimeway.Webhooks.Ingress
  alias Chimeway.Signals.Signal
  alias Chimeway.Workflows.{WorkflowDefinition, WorkflowRun, WorkflowStep, WorkflowTransition}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chimeway.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, {:shared, self()})
    Application.put_env(:demo_host, :chimeway_adapter_config, [])
    :ok
  end

  describe "progress path (delivered → step advances) — FLOW-01 + FLOW-02" do
    test "real webhook → ingress → worker → signal → route_signal → trace" do
      %{tenant_id: _tenant, actor_id: _actor, delivery: delivery, run: run} =
        insert_progress_path_fixture()

      # 1. POST to real /webhooks/chimeway/echo route. EchoAdapter resolves
      #    via the "delivery_id" clause at echo_adapter.ex:37 and normalizes
      #    "ok" -> :delivered (adapter axis).
      body = Jason.encode!(%{"delivery_id" => delivery.id, "status" => "ok"})

      conn =
        conn(:post, "/webhooks/chimeway/echo", body)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("signature", "valid")
        |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

      # B1: HTTP 2xx + Ingress row committed (Phase 33 atomic-handoff seam).
      assert conn.status == 200
      assert [%Ingress{} = ingress] = Repo.all(Ingress)
      assert ingress.delivery_id == delivery.id
      # EchoAdapter.normalize_feedback/1 maps "ok" -> {:ok, %{status: :delivered}}
      # and the ingress row stores the adapter-axis string "delivered".
      assert ingress.normalized_status == "delivered"

      # DRAIN #1 — runs ProcessFeedbackWorker (B2 + B3).
      # Drain shape robustness: assert observable state, not %{success: N}.
      result1 = Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true)

      total1 =
        Map.get(result1, :success, 0) +
          Map.get(result1, :failure, 0) +
          Map.get(result1, :discard, 0)

      assert total1 >= 1,
             "expected ProcessFeedbackWorker to run; got #{inspect(result1)}"

      # B2: DeliveryAttempt with canonical outcome atom (worker contract).
      # canonicalize_status/1 maps "delivered" -> "succeeded" (process_feedback_worker.ex:139).
      attempts = Repo.all(DeliveryAttempt)
      assert length(attempts) == 1
      assert hd(attempts).outcome == :succeeded
      assert hd(attempts).adapter_module == to_string(DemoHost.Adapters.EchoAdapter)

      # B3: Signal with canonical event_name string (D-01 — locked vocabulary).
      # Never use String.to_atom/1 — compare event names as strings per atom-safety rule.
      signals = Repo.all(Signal)
      assert length(signals) == 1
      assert hd(signals).event_name == "chimeway.delivery.succeeded"
      assert hd(signals).tenant_id == delivery.tenant_id
      assert hd(signals).actor_id == delivery.actor_id

      # DRAIN #2 — runs SignalRouterWorker, which writes the signal_received
      # WorkflowTransition with delivery_id populated (Phase 32 D-02 wiring).
      result2 = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)

      total2 =
        Map.get(result2, :success, 0) +
          Map.get(result2, :failure, 0) +
          Map.get(result2, :discard, 0)

      assert total2 >= 1,
             "expected SignalRouterWorker to run; got #{inspect(result2)}"

      # B5: WorkflowRun resumed AND signal_received transition with delivery_id.
      # route_signal/1 finds the :waiting run (matching tenant + actor + pending_signals)
      # and writes a "signal_received" transition with delivery_id = signal.payload["delivery_id"].
      updated_run = Repo.get!(WorkflowRun, run.id)
      assert updated_run.state == :active
      assert updated_run.pending_signals == []

      [signal_received_transition] =
        Repo.all(
          from(wt in WorkflowTransition,
            where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
          )
        )

      assert signal_received_transition.delivery_id == delivery.id

      # B6: Trace timeline proves Phase 32 joint projection (T-32-01 TRAC-01 contract).
      # :webhook_received is produced from the DeliveryAttempt row.
      # signal_event_name is enriched from the signal_received WorkflowTransition's
      # context["event_name"] — proving the D-02 delivery_id linkage closes the
      # webhook → signal → routing chain end-to-end.
      {:ok, %{timeline: timeline}} = Traces.explain_delivery(delivery.id)
      event_atoms = Enum.map(timeline, & &1.event)

      assert :webhook_received in event_atoms

      webhook_entry = Enum.find(timeline, &(&1.event == :webhook_received))
      assert webhook_entry.detail.signal_event_name == "chimeway.delivery.succeeded"
    end
  end

  describe "stop path (bounced → workflow stops) — FLOW-01 + FLOW-02" do
    test "real bounced webhook → worker progression → run stopped + trace" do
      %{tenant_id: _tenant, actor_id: _actor, delivery: delivery, run: run} =
        insert_stop_path_fixture()

      body = Jason.encode!(%{"delivery_id" => delivery.id, "status" => "bounce"})

      conn =
        conn(:post, "/webhooks/chimeway/echo", body)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("signature", "valid")
        |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

      # B1 (stop): HTTP 2xx, ingress committed.
      assert conn.status == 200
      assert [%Ingress{} = ingress] = Repo.all(Ingress)
      assert ingress.delivery_id == delivery.id
      assert ingress.normalized_status == "bounced"

      # DRAIN #1 — worker writes attempt + emits bounced signal + stop_run
      # writes workflow_stopped transition synchronously inside record_attempt/2.
      result1 = Oban.drain_queue(queue: :chimeway_delivery, with_scheduled: true)

      total1 =
        Map.get(result1, :success, 0) +
          Map.get(result1, :failure, 0) +
          Map.get(result1, :discard, 0)

      assert total1 >= 1,
             "expected ProcessFeedbackWorker to run; got #{inspect(result1)}"

      # B2 (stop): DeliveryAttempt with :bounced outcome.
      attempts = Repo.all(DeliveryAttempt)
      assert length(attempts) == 1
      assert hd(attempts).outcome == :bounced

      # B3 (stop): Signal with canonical .bounced event_name.
      # String comparison — never String.to_atom (atom-safety rule).
      signals = Repo.all(Signal)
      assert length(signals) == 1
      assert hd(signals).event_name == "chimeway.delivery.bounced"

      # B4 (stop): WorkflowRun reached terminal state via stop_run.
      # stop_run (progression.ex:348-379) evaluates the "stop" kind rule when the
      # curated ProgressionOutcome matches "bounced", then flips run.state = :stopped.
      updated_run = Repo.get!(WorkflowRun, run.id)
      assert updated_run.state == :stopped

      # workflow_stopped transition with delivery_id (progression.ex:370).
      # Written synchronously by record_attempt/2 -> maybe_apply_progression hook.
      [stopped_transition] =
        Repo.all(
          from(wt in WorkflowTransition,
            where: wt.workflow_run_id == ^run.id and wt.reason == "workflow_stopped"
          )
        )

      assert stopped_transition.delivery_id == delivery.id

      # DRAIN #2 — runs SignalRouterWorker. The run is :stopped (not :waiting),
      # so route_signal/1 finds zero matching runs and returns {:ok, %{}}.
      # That is correct stop-path behavior; no signal_received transition expected.
      _ = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)

      # B6 (stop): Trace timeline carries :webhook_received + :workflow_stopped.
      # Both events share delivery_id as the join key (Phase 32 D-02 / TRAC-02).
      {:ok, %{timeline: timeline}} = Traces.explain_delivery(delivery.id)
      event_atoms = Enum.map(timeline, & &1.event)

      assert :webhook_received in event_atoms
      assert :workflow_stopped in event_atoms
    end
  end

  # ---------------------------------------------------------------------------
  # Private fixture helpers
  # ---------------------------------------------------------------------------

  # Progress path: one :waiting run keyed on chimeway.delivery.succeeded.
  # The delivery is linked to the run; route_signal/1 will resume the run after
  # drain_queue(:chimeway_signals) and write a signal_received transition with
  # delivery_id (Phase 32 D-02 wiring).
  #
  # Tenancy invariant: delivery.tenant_id == run.tenant_id AND
  # delivery.actor_id == notification.recipient_identity (route_signal/1 join).
  defp insert_progress_path_fixture do
    tenant_id = "default"
    actor_id = "user:phase34-#{System.unique_integer([:positive])}"

    event =
      Repo.insert!(%Event{
        notification_key: "test.phase34",
        notification_version: 1,
        idempotency_key: "phase34-#{System.unique_integer([:positive])}",
        payload: %{}
      })

    notification =
      Repo.insert!(%Notification{
        event_id: event.id,
        recipient_identity: actor_id,
        recipient_type: "user",
        metadata: %{}
      })

    definition =
      Repo.insert!(
        WorkflowDefinition.changeset(%WorkflowDefinition{}, %{
          workflow_key: "test.phase34.delivered_then_done.#{System.unique_integer([:positive])}",
          workflow_version: 1,
          notification_key: "test.phase34"
        })
      )

    step1 =
      Repo.insert!(
        WorkflowStep.changeset(%WorkflowStep{}, %{
          workflow_definition_id: definition.id,
          step_key: "wait_for_delivery",
          step_order: 1,
          channel: "in_app",
          config: %{}
        })
      )

    _step2 =
      Repo.insert!(
        WorkflowStep.changeset(%WorkflowStep{}, %{
          workflow_definition_id: definition.id,
          step_key: "done",
          step_order: 2,
          channel: "in_app",
          config: %{}
        })
      )

    now = DateTime.utc_now()

    run =
      Repo.insert!(
        WorkflowRun.changeset(%WorkflowRun{}, %{
          notification_id: notification.id,
          workflow_definition_id: definition.id,
          current_step_id: step1.id,
          state: :waiting,
          started_at: now,
          last_transition_at: now,
          status_reason: "waiting_for_signal",
          tenant_id: tenant_id,
          pending_signals: ["chimeway.delivery.succeeded"]
        })
      )

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, "in_app",
        tenant_id: tenant_id,
        actor_id: actor_id,
        workflow_run_id: run.id,
        workflow_step_id: step1.id
      )

    # Move delivery off :pending so record_attempt/2 has a valid transition target.
    # @allowed_transitions permits: dispatched <- pending, succeeded <- dispatched.
    {:ok, delivery} = Deliveries.transition_status(delivery, :dispatched)

    %{tenant_id: tenant_id, actor_id: actor_id, delivery: delivery, run: run}
  end

  # Stop path: one :active run with a "stop" rule for the "bounced" outcome.
  # record_attempt/2 -> maybe_apply_progression -> progress_run evaluates the
  # active step's rules, matches "bounced" -> stop_run writes "workflow_stopped"
  # transition synchronously in the same worker call stack.
  defp insert_stop_path_fixture do
    tenant_id = "default"
    actor_id = "user:phase34-stop-#{System.unique_integer([:positive])}"

    event =
      Repo.insert!(%Event{
        notification_key: "test.phase34_stop",
        notification_version: 1,
        idempotency_key: "phase34-stop-#{System.unique_integer([:positive])}",
        payload: %{}
      })

    notification =
      Repo.insert!(%Notification{
        event_id: event.id,
        recipient_identity: actor_id,
        recipient_type: "user",
        metadata: %{}
      })

    definition =
      Repo.insert!(
        WorkflowDefinition.changeset(%WorkflowDefinition{}, %{
          workflow_key: "test.phase34_stop.bounced.#{System.unique_integer([:positive])}",
          workflow_version: 1,
          notification_key: "test.phase34_stop"
        })
      )

    step =
      Repo.insert!(
        WorkflowStep.changeset(%WorkflowStep{}, %{
          workflow_definition_id: definition.id,
          step_key: "send_email",
          step_order: 1,
          channel: "in_app",
          config: %{
            "progress" => [
              %{"kind" => "stop", "outcome" => "bounced"}
            ]
          }
        })
      )

    now = DateTime.utc_now()

    run =
      Repo.insert!(
        WorkflowRun.changeset(%WorkflowRun{}, %{
          notification_id: notification.id,
          workflow_definition_id: definition.id,
          current_step_id: step.id,
          state: :active,
          started_at: now,
          last_transition_at: now,
          status_reason: "phase34_stop",
          tenant_id: tenant_id,
          pending_signals: []
        })
      )

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, "in_app",
        tenant_id: tenant_id,
        actor_id: actor_id,
        workflow_run_id: run.id,
        workflow_step_id: step.id
      )

    {:ok, delivery} = Deliveries.transition_status(delivery, :dispatched)

    %{tenant_id: tenant_id, actor_id: actor_id, delivery: delivery, run: run}
  end
end
