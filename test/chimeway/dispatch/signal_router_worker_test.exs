defmodule Chimeway.Dispatch.SignalRouterWorkerTest do
  use Chimeway.DataCase, async: true
  use Oban.Testing, repo: Chimeway.Repo

  import Ecto.Query

  alias Chimeway.Dispatch.SignalRouterWorker
  alias Chimeway.Repo
  alias Chimeway.Signals.Signal
  alias Chimeway.Workflows.{WorkflowRun, WorkflowTransition}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  # ---- Fixtures ----------------------------------------------------------------

  defp insert_signal!(attrs) do
    defaults = %{
      tenant_id: "acme",
      actor_id: "cw_signal_worker_42",
      event_name: "form_submitted",
      payload: %{}
    }

    Repo.insert!(Signal.changeset(%Signal{}, Map.merge(defaults, attrs)))
  end

  defp insert_waiting_workflow_run!(tenant_id, pending_signals) do
    event =
      Repo.insert!(%Event{
        notification_key: "test.signal_worker",
        notification_version: 1,
        idempotency_key: "sw-#{System.unique_integer([:positive])}",
        tenant_id: "default",
        payload: %{}
      })

    notification =
      Repo.insert!(%Notification{
        event_id: event.id,
        tenant_id: event.tenant_id,
        recipient_identity: "cw_signal_worker_42",
        recipient_type: "user",
        metadata: %{},
        render_assigns: %{
          "headline" => "test",
          "body" => "test body",
          "primary_action" => %{"label" => "Open", "url" => "https://example.test"}
        },
        render_channels: %{
          "in_app" => %{"render_key" => "test.in_app", "render_version" => 1}
        }
      })

    definition =
      Repo.insert!(
        Chimeway.Workflows.WorkflowDefinition.changeset(
          %Chimeway.Workflows.WorkflowDefinition{},
          %{
            workflow_key: "test.signal_worker.workflow.#{System.unique_integer([:positive])}",
            workflow_version: 1,
            notification_key: "test.signal_worker"
          }
        )
      )

    step =
      Repo.insert!(
        Chimeway.Workflows.WorkflowStep.changeset(%Chimeway.Workflows.WorkflowStep{}, %{
          workflow_definition_id: definition.id,
          step_key: "in_app",
          step_order: 1,
          channel: "in_app",
          config: %{}
        })
      )

    Repo.insert!(
      WorkflowRun.changeset(%WorkflowRun{}, %{
        notification_id: notification.id,
        workflow_definition_id: definition.id,
        current_step_id: step.id,
        state: :waiting,
        started_at: DateTime.utc_now(),
        last_transition_at: DateTime.utc_now(),
        status_reason: "waiting_for_signal",
        tenant_id: tenant_id,
        pending_signals: pending_signals
      })
    )
  end

  # ---- Tests -------------------------------------------------------------------

  describe "perform/1 success path" do
    test "fetches the signal and delegates to Workflows.route_signal/1" do
      signal = insert_signal!(%{event_name: "form_submitted"})
      run = insert_waiting_workflow_run!("acme", ["form_submitted"])

      assert :ok = perform_job(SignalRouterWorker, %{"signal_id" => signal.id})

      updated_run = Repo.get!(WorkflowRun, run.id)
      assert updated_run.state == :active
      assert updated_run.pending_signals == []
    end

    test "returns :ok when no workflows match" do
      signal = insert_signal!(%{event_name: "unknown_event"})

      # No waiting run exists for this event_name
      assert :ok = perform_job(SignalRouterWorker, %{"signal_id" => signal.id})
    end

    test "writes a WorkflowTransition for each matched run" do
      signal = insert_signal!(%{event_name: "payment_verified"})
      run = insert_waiting_workflow_run!("acme", ["payment_verified"])

      assert :ok = perform_job(SignalRouterWorker, %{"signal_id" => signal.id})

      transitions =
        Repo.all(
          from(wt in WorkflowTransition,
            where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
          )
        )

      assert length(transitions) == 1
      [transition] = transitions
      assert transition.context["event_name"] == "payment_verified"
    end
  end

  describe "perform/1 error path" do
    test "returns {:error, :signal_not_found} when signal_id does not exist" do
      missing_id = Ecto.UUID.generate()

      assert {:error, :signal_not_found} =
               perform_job(SignalRouterWorker, %{"signal_id" => missing_id})
    end
  end

  describe "perform/1 cross-tenant isolation" do
    test "does not resume runs belonging to a different tenant" do
      # Signal is from tenant 'acme' but run is from tenant 'evil_corp'
      signal = insert_signal!(%{tenant_id: "acme", event_name: "form_submitted"})
      other_run = insert_waiting_workflow_run!("evil_corp", ["form_submitted"])

      assert :ok = perform_job(SignalRouterWorker, %{"signal_id" => signal.id})

      unchanged_run = Repo.get!(WorkflowRun, other_run.id)
      assert unchanged_run.state == :waiting, "cross-tenant run must not be resumed"
    end
  end
end
