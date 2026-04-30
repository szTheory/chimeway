defmodule Chimeway.WorkflowsInspectionTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.Repo
  alias Chimeway.Workflows
  alias Chimeway.Workflows.{WorkflowRun, WorkflowTransition}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  # ---- Fixtures ----------------------------------------------------------------

  defp insert_workflow_run!(attrs \\ %{}) do
    event =
      Repo.insert!(%Event{
        notification_key: "test.inspection",
        notification_version: 1,
        idempotency_key: "insp-#{System.unique_integer([:positive])}",
        payload: %{}
      })

    notification =
      Repo.insert!(%Notification{
        event_id: event.id,
        recipient_identity: "user:#{System.unique_integer([:positive])}",
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
            workflow_key: "test.inspection.workflow.#{System.unique_integer([:positive])}",
            workflow_version: 1,
            notification_key: "test.inspection"
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

    defaults = %{
      state: :active,
      started_at: DateTime.utc_now(),
      last_transition_at: DateTime.utc_now(),
      status_reason: "workflow_started",
      status_context: %{},
      tenant_id: "acme"
    }

    merged = Map.merge(defaults, attrs)

    Repo.insert!(
      WorkflowRun.changeset(
        %WorkflowRun{},
        Map.merge(merged, %{
          notification_id: notification.id,
          workflow_definition_id: definition.id,
          current_step_id: step.id
        })
      )
    )
  end

  defp insert_transition!(run, attrs \\ %{}) do
    defaults = %{
      workflow_run_id: run.id,
      to_state: :active,
      reason: "workflow_started",
      context: %{"source" => "trigger"},
      inserted_at: DateTime.utc_now()
    }

    Repo.insert!(WorkflowTransition.changeset(%WorkflowTransition{}, Map.merge(defaults, attrs)))
  end

  # ---- explain/2 tests ---------------------------------------------------------

  describe "explain/2 — basic inspection" do
    test "returns the workflow run state for the given tenant_id and execution_id" do
      run = insert_workflow_run!(%{tenant_id: "acme", state: :active})

      assert {:ok, result} = Workflows.explain("acme", run.id)

      assert result.id == run.id
      assert result.state == :active
      assert result.status_reason == "workflow_started"
      assert result.tenant_id == "acme"
    end

    test "returns workflow run with current_step_name when a step exists" do
      run = insert_workflow_run!(%{tenant_id: "acme", state: :waiting})

      assert {:ok, result} = Workflows.explain("acme", run.id)

      assert result.state == :waiting
      # current_step_name should be present (from the associated current_step)
      assert is_binary(result.current_step_name)
    end

    test "returns suspended_until, pending_signals, and terminal_reason in the result" do
      suspended_until = ~U[2026-05-01 00:00:00.000000Z]

      run =
        insert_workflow_run!(%{
          tenant_id: "acme",
          state: :waiting,
          suspended_until: suspended_until,
          pending_signals: ["invoice.paid"],
          terminal_reason: nil
        })

      assert {:ok, result} = Workflows.explain("acme", run.id)

      assert result.suspended_until == suspended_until
      assert result.pending_signals == ["invoice.paid"]
      assert result.terminal_reason == nil
    end

    test "returns terminal_reason when workflow is stopped" do
      run =
        insert_workflow_run!(%{
          tenant_id: "acme",
          state: :stopped,
          terminal_reason: "max_escalations_reached"
        })

      assert {:ok, result} = Workflows.explain("acme", run.id)

      assert result.state == :stopped
      assert result.terminal_reason == "max_escalations_reached"
    end
  end

  describe "explain/2 — tenant isolation" do
    test "returns {:error, :not_found} when execution_id belongs to a different tenant" do
      run = insert_workflow_run!(%{tenant_id: "other_tenant"})

      assert {:error, :not_found} = Workflows.explain("acme", run.id)
    end

    test "returns {:error, :not_found} for a non-existent execution_id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = Workflows.explain("acme", non_existent_id)
    end

    test "returns the run for the correct tenant even if another tenant has a run with the same state" do
      acme_run = insert_workflow_run!(%{tenant_id: "acme", state: :waiting})
      _other_run = insert_workflow_run!(%{tenant_id: "other_tenant", state: :waiting})

      assert {:ok, result} = Workflows.explain("acme", acme_run.id)
      assert result.tenant_id == "acme"
    end
  end

  # ---- list_traces/3 tests -----------------------------------------------------

  describe "list_traces/3 — basic listing" do
    test "returns WorkflowTransition records for the given execution" do
      run = insert_workflow_run!(%{tenant_id: "acme"})
      t1 = insert_transition!(run, %{reason: "workflow_started", to_state: :active})
      t2 = insert_transition!(run, %{reason: "step_activated", to_state: :active})

      assert {:ok, traces} = Workflows.list_traces("acme", run.id)

      trace_ids = Enum.map(traces, & &1.id)
      assert t1.id in trace_ids
      assert t2.id in trace_ids
    end

    test "returns an empty list when the execution has no transitions" do
      run = insert_workflow_run!(%{tenant_id: "acme"})

      assert {:ok, []} = Workflows.list_traces("acme", run.id)
    end

    test "returns transitions ordered by inserted_at ascending by default" do
      run = insert_workflow_run!(%{tenant_id: "acme"})
      t1 = insert_transition!(run, %{reason: "workflow_started", inserted_at: ~U[2026-04-30 10:00:00Z]})
      t2 = insert_transition!(run, %{reason: "step_activated", inserted_at: ~U[2026-04-30 11:00:00Z]})

      assert {:ok, traces} = Workflows.list_traces("acme", run.id)

      ids = Enum.map(traces, & &1.id)
      assert ids == [t1.id, t2.id]
    end

    test "returns all transitions when no limit is supplied and limits when requested" do
      run = insert_workflow_run!(%{tenant_id: "acme"})
      t1 = insert_transition!(run, %{reason: "workflow_started", inserted_at: ~U[2026-04-30 10:00:00Z]})
      t2 = insert_transition!(run, %{reason: "step_activated", inserted_at: ~U[2026-04-30 11:00:00Z]})
      t3 = insert_transition!(run, %{reason: "workflow_waiting", inserted_at: ~U[2026-04-30 12:00:00Z]})
      t4 = insert_transition!(run, %{reason: "signal_received", inserted_at: ~U[2026-04-30 13:00:00Z]})
      t5 = insert_transition!(run, %{reason: "workflow_completed", inserted_at: ~U[2026-04-30 14:00:00Z]})

      assert {:ok, all_traces} = Workflows.list_traces("acme", run.id)
      assert Enum.map(all_traces, & &1.id) == [t1.id, t2.id, t3.id, t4.id, t5.id]

      assert {:ok, traces} = Workflows.list_traces("acme", run.id, limit: 2)

      assert Enum.map(traces, & &1.id) == [t1.id, t2.id]
      assert length(traces) == 2
    end

    test "returns an empty list when limit is zero" do
      run = insert_workflow_run!(%{tenant_id: "acme"})
      insert_transition!(run, %{reason: "workflow_started", inserted_at: ~U[2026-04-30 10:00:00Z]})
      insert_transition!(run, %{reason: "step_activated", inserted_at: ~U[2026-04-30 11:00:00Z]})

      assert {:ok, []} = Workflows.list_traces("acme", run.id, limit: 0)
    end
  end

  describe "list_traces/3 — tenant isolation" do
    test "does not return transitions belonging to a different tenant's execution" do
      acme_run = insert_workflow_run!(%{tenant_id: "acme"})
      other_run = insert_workflow_run!(%{tenant_id: "other_tenant"})

      insert_transition!(acme_run, %{reason: "workflow_started"})
      insert_transition!(other_run, %{reason: "workflow_started"})

      assert {:ok, traces} = Workflows.list_traces("acme", acme_run.id)

      # Only traces for the acme run should be returned
      for trace <- traces do
        assert trace.workflow_run_id == acme_run.id
      end
    end

    test "returns {:error, :not_found} when the execution_id belongs to a different tenant" do
      other_run = insert_workflow_run!(%{tenant_id: "other_tenant"})
      insert_transition!(other_run, %{reason: "workflow_started"})

      assert {:error, :not_found} = Workflows.list_traces("acme", other_run.id)
    end

    test "returns {:error, :not_found} for a non-existent execution_id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = Workflows.list_traces("acme", non_existent_id)
    end
  end

  describe "list_traces/3 — payload safety" do
    test "does not expose payload data in trace context" do
      run = insert_workflow_run!(%{tenant_id: "acme"})

      insert_transition!(run, %{
        reason: "signal_received",
        to_state: :active,
        context: %{"event_name" => "invoice.paid"}
      })

      assert {:ok, [trace]} = Workflows.list_traces("acme", run.id)

      # Structural data is allowed (event_name identifies what happened)
      assert trace.context["event_name"] == "invoice.paid"

      # Payload data must not be in the context — structural traces only
      refute Map.has_key?(trace.context, "payload")
      refute Map.has_key?(trace.context, "data")
      refute Map.has_key?(trace.context, "amount")
    end
  end
end
