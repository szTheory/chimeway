# Notifier fixtures defined at module top so they compile as named modules and
# share one stable `notification_key` across the whole file. Each test triggers
# this notifier with a unique `idempotency_key` so we get one event/notification
# per scenario without cross-test idempotency collisions.
defmodule ChimewayTest.Notifiers.WorkflowProgression do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.workflow_progression"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Workflow progression"}}

  def channels(_params, _recipient), do: {:ok, [:in_app]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Workflow progression",
         "body" => "Workflow progression body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/wp"},
         "subject" => "Workflow progression",
         "html_body" => "<p>Workflow progression</p>",
         "text_body" => "Workflow progression"
       },
       channels: %{
         in_app: %{render_key: "test.workflow_progression.in_app", render_version: 1},
         email: %{render_key: "test.workflow_progression.email", render_version: 1}
       }
     }}
  end

  # `in_app -> email` workflow whose first step declares both a wait_until and
  # an on_outcome rule per the Plan 25-02 fixture spec. Both rules target the
  # same `email` second step so the test scenarios only differ in *which* rule
  # the engine evaluates against the prior delivery's converged outcome.
  def workflow(_params, _recipient) do
    {:ok,
     %{
       workflow_key: "test.workflow_progression.workflow",
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
                 "delay_seconds" => 1800,
                 "to_step" => "email"
               },
               %{
                 "kind" => "on_outcome",
                 "outcome" => "bounced",
                 "to_step" => "email"
               }
             ]
           }
         },
         %{
           step_key: "email",
           step_order: 2,
           channel: :email,
           config: %{}
         }
       ]
     }}
  end
end

# Plan-only dispatcher: plans canonical delivery rows but does not drive them
# through the adapter. This lets the test control terminal convergence
# explicitly so we can prove `Progression.progress_run/2` evaluates the engine
# logic itself rather than the side-effects of the auto-progression hook on
# `Deliveries.record_attempt/2`.
defmodule ChimewayTest.Dispatchers.PlanOnly do
  @behaviour Chimeway.Dispatch

  alias Chimeway.DeliveryPlanning

  @impl true
  def dispatch(notifications, opts) when is_list(notifications) do
    DeliveryPlanning.plan_notifications(notifications, opts)
  end

  @impl true
  def dispatch_delivery(delivery, _opts), do: {:ok, delivery}
end

defmodule Chimeway.Orchestration.WorkflowProgressionTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query

  alias Chimeway.{Deliveries, Delivery, Repo}
  alias Chimeway.Notifications.Notification
  alias Chimeway.Workflows.{Progression, WorkflowRun, WorkflowStep, WorkflowTransition}

  setup do
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

    Application.put_env(:chimeway, :dispatcher, ChimewayTest.Dispatchers.PlanOnly)
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
      Application.put_env(:chimeway, :adapter, previous_adapter)
      Chimeway.Adapters.Test.clear()
    end)

    :ok
  end

  describe "wait_until rule anchored to prior_delivery_terminal_at (D-01)" do
    test "succeeded prior delivery moves the run to :waiting with a due_at timestamp anchored to the terminal moment" do
      %{notification: notification, workflow_run: workflow_run, in_app_step: in_app_step} =
        trigger_workflow!("wait-due-success")

      # PlanOnly dispatcher leaves the in_app delivery :pending so we can drive
      # convergence ourselves. Going pending -> dispatched -> succeeded via the
      # canonical helpers exercises the same convergence path that production
      # code uses (REL-03), and `record_attempt/2` invokes the progression seam
      # automatically once the row converges.
      pending_delivery = fetch_delivery!(notification.id, "in_app")
      assert pending_delivery.status == :pending
      assert pending_delivery.workflow_run_id == workflow_run.id
      assert pending_delivery.workflow_step_id == in_app_step.id

      {:ok, dispatched} = Deliveries.transition_status(pending_delivery, :dispatched)

      {:ok, %{delivery: terminal_delivery}} =
        Deliveries.record_attempt(dispatched, %{outcome: :succeeded})

      assert terminal_delivery.status == :succeeded

      # The convergence hook inside `record_attempt/2` already drove progression
      # once. Calling the engine again must be duplicate-safe: the run is now
      # :waiting and the wait gate is not yet due, so we get a noop.
      assert {:ok, {:noop, updated_run, :wait_not_due}} =
               Progression.progress_run(workflow_run.id, [])

      assert updated_run.id == workflow_run.id
      assert updated_run.state == :waiting
      assert updated_run.status_reason == "waiting_for_step_progression"

      context = updated_run.status_context
      assert is_map(context)
      assert context["rule_kind"] == "wait_until"
      assert context["anchor"] == "prior_delivery_terminal_at"
      assert context["anchor_delivery_id"] == terminal_delivery.id
      assert context["anchor_delivery_status"] == "succeeded"
      assert context["to_step"] == "email"

      # Anchor timestamp tracks the canonical delivery's terminal updated_at, and
      # due_at is exactly delay_seconds after that anchor.
      anchor_timestamp = parse_iso8601!(context["anchor_timestamp"])
      due_at = parse_iso8601!(context["due_at"])

      assert DateTime.compare(anchor_timestamp, terminal_delivery.updated_at) == :eq
      assert DateTime.diff(due_at, anchor_timestamp, :second) == 1800

      # No second-step delivery should have been created yet — the wait gate is
      # the whole point of the rule.
      refute_email_delivery!(notification.id)

      # The waiting transition is appended once with the same anchor/due context.
      transitions = list_transitions(workflow_run.id)
      waiting_transitions = Enum.filter(transitions, &(&1.reason == "waiting_for_step_progression"))
      assert length(waiting_transitions) == 1

      [waiting_transition] = waiting_transitions
      assert waiting_transition.workflow_step_id == in_app_step.id
      assert waiting_transition.delivery_id == terminal_delivery.id
      assert waiting_transition.context["anchor_delivery_id"] == terminal_delivery.id
      assert waiting_transition.context["due_at"] == context["due_at"]
    end
  end

  describe "wait_until rule advancement after due_at elapses (CR-01 regression)" do
    test "past-due wait_until advances the run to the persisted to_step, creates exactly one next-step delivery, and noops on re-entry" do
      %{
        notification: notification,
        workflow_run: workflow_run,
        email_step: email_step
      } = trigger_workflow!("past-due-advance")

      # Drive the in_app delivery through the canonical convergence path with
      # a :succeeded outcome. record_attempt/2 invokes the progression seam
      # automatically once the row converges, stamping the run as :waiting with
      # a persisted due_at 1800 seconds after the terminal updated_at.
      pending_delivery = fetch_delivery!(notification.id, "in_app")
      {:ok, dispatched} = Deliveries.transition_status(pending_delivery, :dispatched)

      {:ok, %{delivery: _terminal_delivery}} =
        Deliveries.record_attempt(dispatched, %{outcome: :succeeded})

      # Sanity check: the convergence hook moved the run to :waiting.
      waiting_run = Repo.get!(WorkflowRun, workflow_run.id)
      assert waiting_run.state == :waiting

      # Parse the persisted due_at and compute a past-due now.
      due_at = parse_iso8601!(waiting_run.status_context["due_at"])
      past_due_now = DateTime.add(due_at, 1, :second)

      # First past-due call must advance the run — not loop back to :waiting.
      assert {:ok, {:advanced, advanced_run, [next_delivery]}} =
               Progression.progress_run(workflow_run.id, now: past_due_now)

      # The run must advance to the email step.
      assert advanced_run.state == :active
      assert advanced_run.current_step_id == email_step.id

      # The status_reason must be one of the canonical post-advancement reasons.
      assert advanced_run.status_reason in [
               "progressed_on_delivery_outcome",
               "step_activated",
               "reactivated_from_wait"
             ]

      # The next-step delivery must be canonical — linked to the email step.
      assert next_delivery.notification_id == notification.id
      assert next_delivery.channel == "email"
      assert next_delivery.workflow_step_id == email_step.id

      # Exactly one email delivery is created — no duplicates.
      assert email_delivery_count(notification.id) == 1

      # Second past-due call must noop — the active step is now email and its
      # config has no progress rules, so the engine returns :no_progress_rules.
      assert {:ok, {:noop, _run, _reason}} =
               Progression.progress_run(workflow_run.id,
                 now: DateTime.add(past_due_now, 60, :second)
               )

      # Still exactly one email delivery after the second call.
      assert email_delivery_count(notification.id) == 1

      # Transition audit: exactly one reactivated_from_wait (loop-closure proof)
      # and exactly one step_activated for the email step.
      transitions = list_transitions(workflow_run.id)

      reactivated_transitions =
        Enum.filter(transitions, &(&1.reason == "reactivated_from_wait"))

      activated_transitions =
        Enum.filter(transitions, fn t ->
          t.reason == "step_activated" and
            t.context["step_key"] == "email"
        end)

      assert length(reactivated_transitions) == 1,
             "expected exactly 1 reactivated_from_wait transition, got #{length(reactivated_transitions)}"

      assert length(activated_transitions) == 1,
             "expected exactly 1 step_activated transition for email step, got #{length(activated_transitions)}"
    end
  end

  describe "on_outcome rule advances on a curated terminal outcome (D-03/D-12)" do
    test "bounced prior delivery advances the run to the email step and persists supporting facts" do
      %{notification: notification, workflow_run: workflow_run, in_app_step: in_app_step, email_step: email_step} =
        trigger_workflow!("outcome-bounce")

      # PlanOnly dispatcher leaves the in_app delivery :pending. Drive it
      # through the canonical convergence path with a `bounced` adapter
      # outcome — `record_attempt/2` will route to terminal `:cancelled /
      # "bounced"` and invoke the progression seam automatically.
      pending_delivery = fetch_delivery!(notification.id, "in_app")
      {:ok, dispatched} = Deliveries.transition_status(pending_delivery, :dispatched)

      {:ok, %{delivery: terminal_delivery}} =
        Deliveries.record_attempt(dispatched, %{outcome: :bounced, error_class: "bounced"})

      assert terminal_delivery.status == :cancelled
      assert terminal_delivery.suppression_reason == "bounced"

      # The convergence hook already drove the engine — the run should already
      # be advanced onto the email step.
      updated_run = Repo.get!(WorkflowRun, workflow_run.id)
      assert updated_run.state == :active
      assert updated_run.current_step_id == email_step.id

      # The next-step delivery is created through the canonical planning path
      # (no replacement rows) and is linked to the new active step.
      [email_delivery] =
        Repo.all(
          from(d in Delivery,
            where: d.notification_id == ^notification.id and d.channel == "email"
          )
        )

      assert email_delivery.workflow_run_id == workflow_run.id
      assert email_delivery.workflow_step_id == email_step.id

      transitions = list_transitions(workflow_run.id)

      [progressed_transition] =
        Enum.filter(transitions, &(&1.reason == "progressed_on_delivery_outcome"))

      # Append-only transition records the curated workflow outcome and the raw
      # supporting facts so operators can replay the branch from durable rows.
      assert progressed_transition.workflow_step_id == in_app_step.id
      assert progressed_transition.delivery_id == terminal_delivery.id
      assert progressed_transition.context["workflow_outcome"] == "bounced"
      assert progressed_transition.context["rule_kind"] == "on_outcome"
      assert progressed_transition.context["anchor_delivery_id"] == terminal_delivery.id
      assert progressed_transition.context["delivery_status"] == "cancelled"
      assert progressed_transition.context["suppression_reason"] == "bounced"
      assert progressed_transition.context["to_step"] == "email"

      # Re-entering progression with the same converged inputs must not create a
      # second next-step delivery — duplicate-safe noops are mandatory under
      # ESC-03. The active step is now `email` and its config has no progress
      # rules, so the engine returns :no_progress_rules.
      assert {:ok, {:noop, _run, :no_progress_rules}} =
               Progression.progress_run(workflow_run.id, [])

      assert email_delivery_count(notification.id) == 1
    end
  end

  describe "duplicate-safe noops (ESC-03)" do
    test "repeated progression after a non-converged or unknown-reason delivery returns :noop and does not create a second next-step row" do
      %{notification: notification, workflow_run: workflow_run} =
        trigger_workflow!("noop-not-converged")

      in_app_delivery = fetch_delivery!(notification.id, "in_app")

      # Force the in_app row back to a non-terminal :pending state to model the
      # "prior delivery has not converged yet" case. The curated mapper returns
      # :not_branchable_yet for :pending so progression must noop.
      _pending =
        in_app_delivery
        |> Ecto.Changeset.change(status: :pending, suppression_reason: nil)
        |> Repo.update!()

      assert {:ok, {:noop, _run, _reason}} = Progression.progress_run(workflow_run.id, [])
      refute_email_delivery!(notification.id)

      # Now drive the in_app row to a :cancelled terminal whose suppression
      # reason is not in the curated vocabulary. The mapper still returns
      # :not_branchable_yet for unknown buckets, so progression must noop and
      # never emit an email next-step delivery.
      _superseded =
        Repo.get!(Delivery, in_app_delivery.id)
        |> Ecto.Changeset.change(status: :cancelled, suppression_reason: "superseded")
        |> Repo.update!()

      assert {:ok, {:noop, _run, _reason}} = Progression.progress_run(workflow_run.id, [])
      refute_email_delivery!(notification.id)

      # Multiple calls in a row stay duplicate-safe.
      assert {:ok, {:noop, _run, _reason}} = Progression.progress_run(workflow_run.id, [])
      refute_email_delivery!(notification.id)
    end

    test "after the engine advances on an outcome, repeated progression calls noop without emitting a second email delivery" do
      %{notification: notification, workflow_run: workflow_run} =
        trigger_workflow!("noop-after-advance")

      in_app_delivery = fetch_delivery!(notification.id, "in_app")

      # Drive convergence directly via Ecto so we can assert that calling the
      # progression engine after a converged delivery advances exactly once.
      _terminal =
        in_app_delivery
        |> Ecto.Changeset.change(status: :cancelled, suppression_reason: "bounced")
        |> Repo.update!()

      assert {:ok, {:advanced, _run, [_email_delivery]}} =
               Progression.progress_run(workflow_run.id, [])

      assert email_delivery_count(notification.id) == 1

      # Repeated re-entry on the now-advanced run must noop instead of branching
      # again or emitting another email delivery row.
      assert {:ok, {:noop, _run, _reason}} = Progression.progress_run(workflow_run.id, [])
      assert {:ok, {:noop, _run, _reason}} = Progression.progress_run(workflow_run.id, [])
      assert email_delivery_count(notification.id) == 1
    end
  end

  # ---- Helpers ----------------------------------------------------------------

  defp trigger_workflow!(scenario_tag) do
    user_id = "wp-#{scenario_tag}-#{System.unique_integer([:positive])}"

    {:ok, _result} =
      Chimeway.trigger(
        ChimewayTest.Notifiers.WorkflowProgression,
        %{user_id: user_id},
        idempotency_key: "wp-#{scenario_tag}-#{System.unique_integer([:positive])}"
      )

    notification =
      Repo.one!(
        from(n in Notification,
          where: n.recipient_identity == ^"user:#{user_id}",
          order_by: [desc: n.inserted_at],
          limit: 1
        )
      )

    workflow_run = Repo.one!(from(wr in WorkflowRun, where: wr.notification_id == ^notification.id))

    steps =
      Repo.all(
        from(ws in WorkflowStep,
          where: ws.workflow_definition_id == ^notification.workflow_definition_id,
          order_by: [asc: ws.step_order]
        )
      )

    [in_app_step, email_step] = steps

    %{
      notification: notification,
      workflow_run: workflow_run,
      in_app_step: in_app_step,
      email_step: email_step
    }
  end

  defp fetch_delivery!(notification_id, channel) do
    Repo.one!(
      from(d in Delivery,
        where: d.notification_id == ^notification_id and d.channel == ^channel
      )
    )
  end

  defp email_delivery_count(notification_id) do
    Repo.aggregate(
      from(d in Delivery, where: d.notification_id == ^notification_id and d.channel == "email"),
      :count,
      :id
    )
  end

  defp refute_email_delivery!(notification_id) do
    assert email_delivery_count(notification_id) == 0
  end

  defp list_transitions(workflow_run_id) do
    Repo.all(
      from(wt in WorkflowTransition,
        where: wt.workflow_run_id == ^workflow_run_id,
        order_by: [asc: wt.inserted_at]
      )
    )
  end

  defp parse_iso8601!(%DateTime{} = datetime), do: datetime

  defp parse_iso8601!(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      other -> raise "expected ISO-8601 datetime string, got: #{inspect(other)}"
    end
  end
end
