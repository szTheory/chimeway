# Notifier fixture mirrors the Plan 25-02 progression integration test: an
# `in_app -> email` workflow whose first step declares both `wait_until` (1800s)
# and `on_outcome bounced` rules targeting the `email` step. The PlanOnly
# dispatcher leaves deliveries pending so the test owns terminal convergence
# and the race scenarios drive the engine directly.
defmodule ChimewayTest.Notifiers.WorkflowProgressionRace do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.workflow_progression_race"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Workflow progression race"}}

  def channels(_params, _recipient), do: {:ok, [:in_app]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Workflow progression race",
         "body" => "Workflow progression race body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/wpr"},
         "subject" => "Workflow progression race",
         "html_body" => "<p>Workflow progression race</p>",
         "text_body" => "Workflow progression race"
       },
       channels: %{
         in_app: %{render_key: "test.workflow_progression_race.in_app", render_version: 1},
         email: %{render_key: "test.workflow_progression_race.email", render_version: 1}
       }
     }}
  end

  def workflow(_params, _recipient) do
    {:ok,
     %{
       workflow_key: "test.workflow_progression_race.workflow",
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

defmodule ChimewayTest.Dispatchers.WorkflowProgressionRacePlanOnly do
  @behaviour Chimeway.Dispatch

  alias Chimeway.DeliveryPlanning

  @impl true
  def dispatch(notifications, opts) when is_list(notifications) do
    DeliveryPlanning.plan_notifications(notifications, opts)
  end

  @impl true
  def dispatch_delivery(delivery, _opts), do: {:ok, delivery}
end

defmodule Chimeway.Reliability.WorkflowProgressionRaceTest do
  @moduledoc """
  REL — concurrency regression for the Phase 25 workflow progression engine.

  Asserts ESC-03 + WRK-02:

    * 10 concurrent direct calls into `Chimeway.Workflows.Progression.progress_run/2`
      against the same `workflow_run_id` must collapse to exactly one
      `:advanced` winner — every other caller must observe a `:noop`.
    * Exactly one canonical next-step delivery row exists after the storm.
    * Exactly one `progressed_on_delivery_outcome` workflow_transition row is
      appended (no duplicate audit history).
    * Concurrent calls against a *waiting* (not-yet-due) run must all noop and
      never emit a next-step delivery — the wait gate is the contract.
  """

  use Chimeway.DataCase, async: false

  import Ecto.Query

  alias Chimeway.{Delivery, Repo}
  alias Chimeway.Notifications.Notification
  alias Chimeway.Workflows.{Progression, WorkflowRun, WorkflowStep, WorkflowTransition}

  @concurrency 10

  setup do
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

    Application.put_env(:chimeway, :dispatcher, ChimewayTest.Dispatchers.WorkflowProgressionRacePlanOnly)
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
      Application.put_env(:chimeway, :adapter, previous_adapter)
      Chimeway.Adapters.Test.clear()
    end)

    :ok
  end

  describe "concurrent due-run progression collapses to one winner (ESC-03)" do
    test "10 concurrent progress_run calls on a converged run advance exactly once" do
      %{notification: notification, workflow_run: workflow_run, email_step: email_step} =
        trigger_workflow!("race-advance-once")

      in_app_delivery = fetch_delivery!(notification.id, "in_app")

      # Drive the in_app row to a `bounced` terminal directly via Ecto so the
      # test owns convergence — the convergence hook in `record_attempt/2`
      # would otherwise drive progression itself, masking the race we want to
      # exercise at the engine boundary.
      _terminal =
        in_app_delivery
        |> Ecto.Changeset.change(status: :cancelled, suppression_reason: "bounced")
        |> Repo.update!()

      parent = self()

      results =
        1..@concurrency
        |> Task.async_stream(
          fn _attempt ->
            Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
            Progression.progress_run(workflow_run.id, [])
          end,
          ordered: false,
          max_concurrency: @concurrency,
          timeout: 15_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      advanced_count =
        Enum.count(results, &match?({:ok, {:advanced, _run, _deliveries}}, &1))

      noop_count =
        Enum.count(results, &match?({:ok, {:noop, _run, _reason}}, &1))

      # One winner emits the canonical next-step delivery; every other caller
      # observes the already-advanced state and noops.
      assert advanced_count == 1,
             "expected exactly one :advanced winner, got #{advanced_count} (results=#{inspect(results)})"

      assert advanced_count + noop_count == @concurrency,
             "expected only :advanced or :noop results, got #{inspect(results)}"

      # Exactly one canonical email row exists after the storm (no duplicate
      # next-step emission under concurrency).
      assert email_delivery_count(notification.id) == 1

      # Run state stable: advanced onto the email step, no flapping.
      advanced_run = Repo.get!(WorkflowRun, workflow_run.id)
      assert advanced_run.state == :active
      assert advanced_run.current_step_id == email_step.id

      # Exactly one `progressed_on_delivery_outcome` transition row was
      # appended (audit history stays one-winner too).
      progressed_transitions =
        Repo.all(
          from(wt in WorkflowTransition,
            where:
              wt.workflow_run_id == ^workflow_run.id and
                wt.reason == "progressed_on_delivery_outcome"
          )
        )

      assert length(progressed_transitions) == 1
    end

    test "10 concurrent progress_run calls on a not-yet-due waiting run all noop" do
      %{notification: notification, workflow_run: workflow_run} =
        trigger_workflow!("race-waiting-noop")

      in_app_delivery = fetch_delivery!(notification.id, "in_app")

      # Drive the in_app row to `succeeded` and stamp the run as `:waiting`
      # with a future `due_at` — concurrent re-entry must collapse to noops.
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      future_due_at = DateTime.add(now, 1800, :second)

      _converged =
        in_app_delivery
        |> Ecto.Changeset.change(
          status: :succeeded,
          updated_at: now
        )
        |> Repo.update!()

      _waiting_run =
        workflow_run
        |> Ecto.Changeset.change(
          state: :waiting,
          status_reason: "waiting_for_step_progression",
          status_context: %{
            "rule_kind" => "wait_until",
            "anchor" => "prior_delivery_terminal_at",
            "anchor_delivery_id" => in_app_delivery.id,
            "anchor_delivery_status" => "succeeded",
            "anchor_timestamp" => DateTime.to_iso8601(now),
            "due_at" => DateTime.to_iso8601(future_due_at),
            "to_step" => "email"
          },
          last_transition_at: now
        )
        |> Repo.update!()

      parent = self()

      results =
        1..@concurrency
        |> Task.async_stream(
          fn _attempt ->
            Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
            Progression.progress_run(workflow_run.id, now: now)
          end,
          ordered: false,
          max_concurrency: @concurrency,
          timeout: 15_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      noop_count = Enum.count(results, &match?({:ok, {:noop, _run, _reason}}, &1))

      assert noop_count == @concurrency,
             "expected all :noop results, got #{inspect(results)}"

      # No next-step delivery was emitted while the wait gate is not yet due.
      assert email_delivery_count(notification.id) == 0

      # Run state still :waiting after the storm.
      assert Repo.get!(WorkflowRun, workflow_run.id).state == :waiting
    end
  end

  # ---- Helpers ----------------------------------------------------------------

  defp trigger_workflow!(scenario_tag) do
    user_id = "wpr-#{scenario_tag}-#{System.unique_integer([:positive])}"

    {:ok, _result} =
      Chimeway.trigger(
        ChimewayTest.Notifiers.WorkflowProgressionRace,
        %{user_id: user_id},
        idempotency_key: "wpr-#{scenario_tag}-#{System.unique_integer([:positive])}"
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
