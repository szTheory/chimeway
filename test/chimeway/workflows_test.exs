defmodule Chimeway.WorkflowsTest do
  use Chimeway.DataCase, async: true

  import Ecto.Query

  alias Chimeway.Repo
  alias Chimeway.Signals.Signal
  alias Chimeway.Workflows
  alias Chimeway.Workflows.{WorkflowRun, WorkflowTransition}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Ecto.Adapters.SQL.Sandbox

  # ---- Fixtures ----------------------------------------------------------------

  @base_run_attrs %{
    state: :waiting,
    started_at: DateTime.utc_now(),
    last_transition_at: DateTime.utc_now(),
    status_reason: "waiting_for_signal",
    status_context: %{},
    tenant_id: "acme"
  }

  defp insert_workflow_run!(attrs) do
    {recipient_identity, attrs} = Map.pop(attrs, :recipient_identity, "user_1")

    event =
      Repo.insert!(%Event{
        notification_key: "test.signal_routing",
        notification_version: 1,
        idempotency_key: "sig-routing-#{System.unique_integer([:positive])}",
        tenant_id: "default",
        payload: %{}
      })

    notification =
      Repo.insert!(%Notification{
        event_id: event.id,
        tenant_id: event.tenant_id,
        recipient_identity: recipient_identity,
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

    # We need a WorkflowDefinition and WorkflowStep to link the run.
    definition =
      Repo.insert!(
        Chimeway.Workflows.WorkflowDefinition.changeset(
          %Chimeway.Workflows.WorkflowDefinition{},
          %{
            workflow_key: "test.signal_routing.workflow.#{System.unique_integer([:positive])}",
            workflow_version: 1,
            notification_key: "test.signal_routing"
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

    merged = Map.merge(@base_run_attrs, attrs)

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

  defp insert_signal!(attrs) do
    defaults = %{tenant_id: "acme", actor_id: "user_1", event_name: "invoice_paid", payload: %{}}
    Repo.insert!(Signal.changeset(%Signal{}, Map.merge(defaults, attrs)))
  end

  defp insert_workflow_definition!(attrs) do
    definition =
      Repo.insert!(
        Chimeway.Workflows.WorkflowDefinition.changeset(
          %Chimeway.Workflows.WorkflowDefinition{},
          Map.merge(
            %{
              workflow_key: "test.initial_run.workflow.#{System.unique_integer([:positive])}",
              workflow_version: 1,
              notification_key: "test.initial_run"
            },
            attrs
          )
        )
      )

    step =
      Repo.insert!(
        Chimeway.Workflows.WorkflowStep.changeset(%Chimeway.Workflows.WorkflowStep{}, %{
          workflow_definition_id: definition.id,
          step_key: "email-first",
          step_order: 1,
          channel: "email",
          config: %{}
        })
      )

    %{definition | steps: [step]}
  end

  # ---- Tests -------------------------------------------------------------------

  describe "create_initial_run/5" do
    test "persists the supplied tenant_id on the workflow run" do
      event =
        Repo.insert!(%Event{
          notification_key: "test.initial_run",
          notification_version: 1,
          idempotency_key: "initial-run-#{System.unique_integer([:positive])}",
          tenant_id: "default",
          payload: %{}
        })

      notification =
        Repo.insert!(%Notification{
          event_id: event.id,
          tenant_id: event.tenant_id,
          recipient_identity: "user:#{System.unique_integer([:positive])}",
          recipient_type: "user",
          metadata: %{},
          render_assigns: %{},
          render_channels: %{}
        })

      definition = insert_workflow_definition!(%{})
      timestamp = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      assert {:ok, run} =
               Workflows.create_initial_run(Repo, notification.id, definition, timestamp, "acme")

      assert run.tenant_id == "acme"

      persisted_run = Repo.get!(WorkflowRun, run.id)
      assert persisted_run.tenant_id == "acme"
      assert persisted_run.status_reason == "workflow_started"
    end

    test "rejects an empty tenant_id through the workflow run changeset" do
      event =
        Repo.insert!(%Event{
          notification_key: "test.initial_run.invalid",
          notification_version: 1,
          idempotency_key: "initial-run-invalid-#{System.unique_integer([:positive])}",
          tenant_id: "default",
          payload: %{}
        })

      notification =
        Repo.insert!(%Notification{
          event_id: event.id,
          tenant_id: event.tenant_id,
          recipient_identity: "user:#{System.unique_integer([:positive])}",
          recipient_type: "user",
          metadata: %{},
          render_assigns: %{},
          render_channels: %{}
        })

      definition = insert_workflow_definition!(%{notification_key: "test.initial_run.invalid"})
      timestamp = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Workflows.create_initial_run(Repo, notification.id, definition, timestamp, "")

      assert {"can't be blank", _metadata} = changeset.errors[:tenant_id]
    end
  end

  describe "route_signal/1 — basic matching" do
    test "resumes a waiting workflow run that has the signal's event_name in pending_signals" do
      run =
        insert_workflow_run!(%{
          pending_signals: ["invoice_paid"],
          suspended_until: DateTime.utc_now()
        })

      signal = insert_signal!(%{event_name: "invoice_paid"})

      assert {:ok, results} = Workflows.route_signal(signal)

      updated_run = Repo.get!(WorkflowRun, run.id)
      assert updated_run.state == :active
      assert updated_run.pending_signals == []
      assert updated_run.status_reason == "signal_received"
      assert updated_run.suspended_until == nil
      assert Map.has_key?(results, {:run_updated, run.id})
      assert Map.has_key?(results, {:transition_inserted, run.id})
    end

    test "does not resume a waiting run from a different actor_id (tenant and event match)" do
      run =
        insert_workflow_run!(%{
          recipient_identity: "user_2",
          pending_signals: ["invoice_paid"]
        })

      signal = insert_signal!(%{event_name: "invoice_paid", actor_id: "user_1"})

      assert {:ok, _results} = Workflows.route_signal(signal)

      unchanged_run = Repo.get!(WorkflowRun, run.id)
      assert unchanged_run.state == :waiting
    end

    test "does not resume a waiting run from a different tenant" do
      _other_tenant_run =
        insert_workflow_run!(%{
          tenant_id: "other_tenant",
          pending_signals: ["invoice_paid"]
        })

      signal = insert_signal!(%{tenant_id: "acme", event_name: "invoice_paid"})

      assert {:ok, _results} = Workflows.route_signal(signal)

      # The other-tenant run must not have been touched
      other_runs = Repo.all(from(wr in WorkflowRun, where: wr.tenant_id == "other_tenant"))

      for run <- other_runs do
        assert run.state == :waiting, "expected other-tenant run to remain :waiting"
      end
    end

    test "does not resume a waiting run that does not include the signal's event_name" do
      run = insert_workflow_run!(%{pending_signals: ["receipt_sent"]})
      signal = insert_signal!(%{event_name: "invoice_paid"})

      assert {:ok, _results} = Workflows.route_signal(signal)

      unchanged_run = Repo.get!(WorkflowRun, run.id)
      assert unchanged_run.state == :waiting
    end

    test "does not resume a run that is not in :waiting state" do
      run = insert_workflow_run!(%{state: :active, pending_signals: ["invoice_paid"]})
      signal = insert_signal!(%{event_name: "invoice_paid"})

      assert {:ok, _results} = Workflows.route_signal(signal)

      unchanged_run = Repo.get!(WorkflowRun, run.id)
      assert unchanged_run.state == :active
    end

    test "resumes a wait_until waiting run with empty pending_signals (Accrue Outcome Signal path)" do
      run =
        insert_workflow_run!(%{
          pending_signals: [],
          status_reason: "waiting_for_step_progression",
          status_context: %{
            "rule_kind" => "wait_until",
            "to_step" => "escalation_email"
          }
        })

      signal = insert_signal!(%{event_name: "invoice.paid"})

      assert {:ok, results} = Workflows.route_signal(signal)

      updated_run = Repo.get!(WorkflowRun, run.id)
      assert updated_run.state == :active
      assert updated_run.pending_signals == []
      assert updated_run.status_reason == "signal_received"
      assert Map.has_key?(results, {:run_updated, run.id})
    end

    test "does not resume a waiting run with empty pending_signals when status_context is not wait_until" do
      run =
        insert_workflow_run!(%{
          pending_signals: [],
          status_reason: "waiting_for_signal",
          status_context: %{"rule_kind" => "outcome_branch"}
        })

      signal = insert_signal!(%{event_name: "invoice.paid"})

      assert {:ok, _results} = Workflows.route_signal(signal)

      unchanged_run = Repo.get!(WorkflowRun, run.id)
      assert unchanged_run.state == :waiting
    end
  end

  describe "route_signal/1 — transition traces" do
    test "inserts a WorkflowTransition for the matched run on signal receipt" do
      run = insert_workflow_run!(%{pending_signals: ["invoice_paid"]})
      signal = insert_signal!(%{event_name: "invoice_paid", payload: %{"amount" => 100}})

      assert {:ok, _results} = Workflows.route_signal(signal)

      transitions =
        Repo.all(
          from(wt in WorkflowTransition,
            where: wt.workflow_run_id == ^run.id,
            order_by: [asc: wt.inserted_at]
          )
        )

      signal_transitions = Enum.filter(transitions, &(&1.reason == "signal_received"))
      assert length(signal_transitions) == 1

      [transition] = signal_transitions
      assert transition.from_state == :waiting
      assert transition.to_state == :active
      # Transition context records the event name but NOT the payload (safety)
      assert transition.context["event_name"] == "invoice_paid"
      refute Map.has_key?(transition.context, "payload")
    end

    test "populates transition.delivery_id from signal.payload[\"delivery_id\"]" do
      run = insert_workflow_run!(%{pending_signals: ["invoice_paid"]})

      # Insert a real delivery row so the FK constraint
      # `chimeway_workflow_transitions_delivery_id_fkey` is satisfied. The
      # FK is `on_delete: :nilify_all` (governs delete behavior) but is still
      # enforced at insert time — non-null values must reference an existing
      # chimeway_deliveries.id row.
      delivery_event =
        Repo.insert!(%Event{
          notification_key: "test.delivery_link",
          notification_version: 1,
          idempotency_key: "delivery-link-#{System.unique_integer([:positive])}",
          tenant_id: "default",
          payload: %{}
        })

      delivery_notification =
        Repo.insert!(%Notification{
          event_id: delivery_event.id,
          tenant_id: delivery_event.tenant_id,
          recipient_identity: "user_1",
          recipient_type: "user",
          metadata: %{},
          render_assigns: %{},
          render_channels: %{}
        })

      delivery =
        Repo.insert!(
          Chimeway.Delivery.changeset(%Chimeway.Delivery{}, %{
            notification_id: delivery_notification.id,
            channel: "in_app",
            status: :pending,
            tenant_id: "acme",
            actor_id: "user_1"
          })
        )

      delivery_id = delivery.id

      signal =
        insert_signal!(%{
          event_name: "invoice_paid",
          payload: %{"delivery_id" => delivery_id, "amount" => 100}
        })

      assert {:ok, _results} = Workflows.route_signal(signal)

      [transition] =
        Repo.all(
          from(wt in WorkflowTransition,
            where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
          )
        )

      # The new column populated from signal.payload["delivery_id"] (D-02 / D-21)
      assert transition.delivery_id == delivery_id

      # Phase 31 payload-safety contract: context still records only event_name
      assert transition.context["event_name"] == "invoice_paid"
      refute Map.has_key?(transition.context, "payload")
      # Guards against accidental double-write: delivery_id is a column, not a context key
      refute Map.has_key?(transition.context, "delivery_id")
    end

    test "leaves transition.delivery_id nil when signal payload omits \"delivery_id\"" do
      run = insert_workflow_run!(%{pending_signals: ["invoice_paid"]})

      # payload: %{} exercises Map.get/2 returning nil — host-app callers via
      # Chimeway.Signal.track/4 may legitimately omit "delivery_id".
      signal = insert_signal!(%{event_name: "invoice_paid", payload: %{}})

      assert {:ok, _results} = Workflows.route_signal(signal)

      [transition] =
        Repo.all(
          from(wt in WorkflowTransition,
            where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
          )
        )

      assert transition.delivery_id == nil
    end

    test "routes multiple waiting runs for the same tenant and event_name" do
      run1 = insert_workflow_run!(%{pending_signals: ["invoice_paid"]})
      run2 = insert_workflow_run!(%{pending_signals: ["invoice_paid", "other_event"]})
      signal = insert_signal!(%{event_name: "invoice_paid"})

      assert {:ok, results} = Workflows.route_signal(signal)

      assert Repo.get!(WorkflowRun, run1.id).state == :active
      assert Repo.get!(WorkflowRun, run2.id).state == :active
      assert Map.has_key?(results, {:run_updated, run1.id})
      assert Map.has_key?(results, {:transition_inserted, run1.id})
      assert Map.has_key?(results, {:run_updated, run2.id})
      assert Map.has_key?(results, {:transition_inserted, run2.id})
    end
  end

  describe "route_signal/1 — idempotency" do
    test "calling route_signal twice does not double-transition a run" do
      run = insert_workflow_run!(%{pending_signals: ["invoice_paid"]})
      signal = insert_signal!(%{event_name: "invoice_paid"})

      assert {:ok, _} = Workflows.route_signal(signal)
      # Second call: run is now :active with empty pending_signals, so it won't match again
      assert {:ok, _} = Workflows.route_signal(signal)

      transitions =
        Repo.all(
          from(wt in WorkflowTransition,
            where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
          )
        )

      assert length(transitions) == 1
    end

    test "route_signal/1 holds FOR UPDATE locks through commit under concurrent calls" do
      run = insert_workflow_run!(%{pending_signals: ["invoice_paid"]})
      signal = insert_signal!(%{event_name: "invoice_paid"})
      parent = self()

      results =
        1..2
        |> Task.async_stream(
          fn _ ->
            Sandbox.allow(Repo, parent, self())
            Workflows.route_signal(signal)
          end,
          ordered: false,
          max_concurrency: 2,
          timeout: 15_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, &match?({:ok, _}, &1))

      updated_run = Repo.get!(WorkflowRun, run.id)
      assert updated_run.state == :active
      assert updated_run.pending_signals == []

      transitions =
        Repo.all(
          from(wt in WorkflowTransition,
            where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
          )
        )

      assert length(transitions) == 1
    end
  end
end
