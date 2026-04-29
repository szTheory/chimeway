# Notifier fixture and PlanOnly dispatcher mirror the Plan 25-02 progression
# integration test: an `in_app -> email` workflow whose first step declares
# both a `wait_until` (1800s) and `on_outcome bounced` rule targeting the
# `email` step. The PlanOnly dispatcher leaves deliveries pending so the test
# owns terminal convergence and the worker exercises its own progression call
# (rather than the convergence hook embedded in `Deliveries.record_attempt/2`).
defmodule ChimewayTest.Notifiers.WorkflowProgressionWorker do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.workflow_progression_worker"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Workflow progression worker"}}

  def channels(_params, _recipient), do: {:ok, [:in_app]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Workflow progression worker",
         "body" => "Workflow progression worker body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/wpw"},
         "subject" => "Workflow progression worker",
         "html_body" => "<p>Workflow progression worker</p>",
         "text_body" => "Workflow progression worker"
       },
       channels: %{
         in_app: %{render_key: "test.workflow_progression_worker.in_app", render_version: 1},
         email: %{render_key: "test.workflow_progression_worker.email", render_version: 1}
       }
     }}
  end

  def workflow(_params, _recipient) do
    {:ok,
     %{
       workflow_key: "test.workflow_progression_worker.workflow",
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

defmodule ChimewayTest.Dispatchers.WorkflowProgressionWorkerPlanOnly do
  @behaviour Chimeway.Dispatch

  alias Chimeway.DeliveryPlanning

  @impl true
  def dispatch(notifications, opts) when is_list(notifications) do
    DeliveryPlanning.plan_notifications(notifications, opts)
  end

  @impl true
  def dispatch_delivery(delivery, _opts), do: {:ok, delivery}
end

defmodule Chimeway.Dispatch.WorkflowProgressionWorkerTest do
  @moduledoc """
  Worker-level coverage for the thin `Chimeway.Dispatch.WorkflowProgressionWorker`.

  Asserts the Phase 25 D-10 contract:

    * Job args are limited to `%{"workflow_run_id" => workflow_run_id}` — no
      delivery facts, no rule data, no tenancy state in queue payloads.
    * The worker delegates all correctness to the shared
      `Chimeway.Workflows.Progression.progress_run/2` seam and returns `:ok`
      for `{:advanced, _, _}`, `{:waiting, _}`, and `{:noop, _, _}` results.
    * Re-running the same worker invocation never emits a second next-step
      delivery (ESC-03 duplicate-safety at the worker boundary).
    * The worker no-ops safely when the run is already advanced (no rules on
      the new active step) or the run state has changed under it.
  """

  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  import Ecto.Query

  alias Chimeway.{Deliveries, Delivery, Repo}
  alias Chimeway.Dispatch.WorkflowProgressionWorker
  alias Chimeway.Notifications.Notification
  alias Chimeway.Workflows.{WorkflowRun, WorkflowStep}

  setup do
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

    Application.put_env(:chimeway, :dispatcher, ChimewayTest.Dispatchers.WorkflowProgressionWorkerPlanOnly)
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
      Application.put_env(:chimeway, :adapter, previous_adapter)
      Chimeway.Adapters.Test.clear()
    end)

    :ok
  end

  describe "WorkflowProgressionWorker thin delegation (D-10)" do
    test "perform with workflow_run_id advances the run and creates exactly one next-step delivery" do
      %{notification: notification, workflow_run: workflow_run, email_step: email_step} =
        trigger_workflow!("worker-advance-once")

      in_app_delivery = fetch_delivery!(notification.id, "in_app")

      # Drive the in_app row to a `bounced` terminal directly via Ecto so the
      # test owns convergence — the convergence hook in `record_attempt/2`
      # would otherwise drive progression itself, masking the worker boundary.
      _terminal =
        in_app_delivery
        |> Ecto.Changeset.change(status: :cancelled, suppression_reason: "bounced")
        |> Repo.update!()

      # Pre-condition: no email delivery yet.
      assert email_delivery_count(notification.id) == 0

      # Worker performs with ONLY workflow_run_id in args (D-10): no delivery
      # facts, no rule data, no tenancy hints in the queue payload.
      assert :ok = perform_job(WorkflowProgressionWorker, %{workflow_run_id: workflow_run.id})

      assert email_delivery_count(notification.id) == 1

      # Run advanced to the email step through the shared seam.
      advanced_run = Repo.get!(WorkflowRun, workflow_run.id)
      assert advanced_run.state == :active
      assert advanced_run.current_step_id == email_step.id
    end

    test "duplicate worker executions never emit a second next-step delivery" do
      %{notification: notification, workflow_run: workflow_run} =
        trigger_workflow!("worker-duplicate-execute")

      in_app_delivery = fetch_delivery!(notification.id, "in_app")

      _terminal =
        in_app_delivery
        |> Ecto.Changeset.change(status: :cancelled, suppression_reason: "bounced")
        |> Repo.update!()

      assert :ok = perform_job(WorkflowProgressionWorker, %{workflow_run_id: workflow_run.id})
      assert email_delivery_count(notification.id) == 1

      # Re-running the identical worker invocation must noop. The new active
      # step (`email`) has no progress rules, so the engine returns
      # `{:noop, run, :no_progress_rules}` and the worker normalizes to `:ok`.
      assert :ok = perform_job(WorkflowProgressionWorker, %{workflow_run_id: workflow_run.id})
      assert :ok = perform_job(WorkflowProgressionWorker, %{workflow_run_id: workflow_run.id})

      assert email_delivery_count(notification.id) == 1
    end

    test "perform on a non-due waiting run noops without creating any next-step delivery" do
      %{notification: notification, workflow_run: workflow_run} =
        trigger_workflow!("worker-noop-wait")

      in_app_delivery = fetch_delivery!(notification.id, "in_app")

      # Drive the in_app row to `succeeded` via the canonical convergence path.
      # That hits the convergence hook in `record_attempt/2`, which itself
      # drives progression once and leaves the run `:waiting` with a future
      # `due_at` (1800 seconds out). The worker must noop without emitting
      # any next-step delivery for the not-yet-due wait.
      {:ok, dispatched} = Deliveries.transition_status(in_app_delivery, :dispatched)

      {:ok, %{delivery: terminal_delivery}} =
        Deliveries.record_attempt(dispatched, %{outcome: :succeeded})

      assert terminal_delivery.status == :succeeded

      waiting_run = Repo.get!(WorkflowRun, workflow_run.id)
      assert waiting_run.state == :waiting
      assert waiting_run.status_reason == "waiting_for_step_progression"

      # Pre-condition: no email row yet (wait gate not yet due).
      assert email_delivery_count(notification.id) == 0

      assert :ok = perform_job(WorkflowProgressionWorker, %{workflow_run_id: workflow_run.id})

      # Worker is duplicate-safe at this boundary too: still no email row.
      assert email_delivery_count(notification.id) == 0

      # Worker did not flip the run state away from :waiting either.
      assert Repo.get!(WorkflowRun, workflow_run.id).state == :waiting
    end

    test "perform with an unknown workflow_run_id noops safely (no rule data leaked into args)" do
      # Unknown id surfaces inside the engine transaction as
      # `:workflow_run_not_found` and the worker normalizes any noop/error to
      # `:ok` (or `{:error, reason}`) without crashing — the queue must never
      # treat a missing row as a retry storm trigger.
      result = perform_job(WorkflowProgressionWorker, %{workflow_run_id: Ecto.UUID.generate()})

      assert result == :ok or match?({:error, _}, result),
             "expected :ok or {:error, _}, got #{inspect(result)}"
    end
  end

  # ---- Helpers ----------------------------------------------------------------

  defp trigger_workflow!(scenario_tag) do
    user_id = "wpw-#{scenario_tag}-#{System.unique_integer([:positive])}"

    {:ok, _result} =
      Chimeway.trigger(
        ChimewayTest.Notifiers.WorkflowProgressionWorker,
        %{user_id: user_id},
        idempotency_key: "wpw-#{scenario_tag}-#{System.unique_integer([:positive])}"
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
end
