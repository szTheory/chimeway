defmodule Chimeway.Workflows.Progression do
  @moduledoc """
  Durable workflow progression engine for Phase 25.

  This is the single seam through which workflow runs move from active to
  waiting and from waiting/active to the next step. It evaluates the active
  step's normalized `progress` rules against the canonical prior delivery row
  inside one transaction, persisting the decision durably so that:

    * `wait_until` rules write the run to `:waiting` with explicit
      `status_reason: "waiting_for_step_progression"` and a `status_context`
      map carrying `rule_kind`, `anchor`, `anchor_delivery_id`,
      `anchor_delivery_status`, `anchor_timestamp`, `due_at`, and `to_step`
      (D-01/D-13).
    * `on_outcome` rules append a `workflow_transition` with reason
      `progressed_on_delivery_outcome` and the curated workflow outcome plus
      raw evidence facts (D-12), then advance the workflow run cursor to the
      target step and emit the next-step delivery through the canonical
      `Chimeway.DeliveryPlanning.plan_next_step_delivery/3` seam (D-10).

  Re-entry is duplicate-safe: if the run is no longer `:active`, if the prior
  delivery is not converged yet, if the curated mapper returns
  `:not_branchable_yet`, or if no progress rule matches, the engine returns
  `{:noop, run, reason}` without creating any new delivery rows or appending
  transitions. This is the ESC-03 contract.

  All locking happens inside one `Repo.transaction/1`:

    * the workflow run row is locked with `FOR UPDATE` first
    * the active-step delivery row is then locked with `FOR UPDATE`

  Threats covered:

    * **T-25-04 (tampering):** outcomes are derived from canonical persisted
      rows only via `ProgressionOutcome.from_delivery/2`; the engine never
      branches from queue or in-flight job state.
    * **T-25-05 (repudiation):** explicit `status_reason` and `reason` strings
      plus the curated `status_context` / transition `context` keys make the
      decision auditable from durable rows alone.
    * **T-25-06 (DoS / duplicate emission):** noop short-circuits prevent
      retry storms from emitting duplicate next-step deliveries.
  """

  import Ecto.Query, only: [from: 2]

  alias Chimeway.{Delivery, DeliveryAttempt, DeliveryPlanning, Repo, Workflows}
  alias Chimeway.Notifications.Notification
  alias Chimeway.Workflows.{ProgressionOutcome, WorkflowRun, WorkflowStep}

  @advanced_reason "progressed_on_delivery_outcome"
  @waiting_reason "waiting_for_step_progression"
  @reactivated_reason "reactivated_from_wait"

  @type progress_result ::
          {:ok, {:advanced, WorkflowRun.t(), [Delivery.t()]}}
          | {:ok, {:waiting, WorkflowRun.t()}}
          | {:ok, {:noop, WorkflowRun.t() | nil, atom()}}
          | {:error, term()}

  @doc """
  Evaluates the workflow run's active step against the canonical prior
  delivery row and persists the resulting waiting/advanced/noop outcome.

  Options:

    * `:now` — `DateTime.t()` used as the evaluation time for due-checks and
      anchor stamping. Defaults to `DateTime.utc_now/0`. Provided for
      deterministic tests and the due-step worker (Plan 25-03).
  """
  @spec progress_run(Ecto.UUID.t(), keyword()) :: progress_result()
  def progress_run(workflow_run_id, opts \\ []) when is_binary(workflow_run_id) do
    now = Keyword.get(opts, :now, DateTime.utc_now()) |> DateTime.truncate(:microsecond)

    Repo.transaction(fn ->
      with {:ok, run} <- Workflows.lock_run(Repo, workflow_run_id),
           {:ok, intermediate} <- maybe_reactivate_due(Repo, run, now) do
        case intermediate do
          # Past-due wait advanced directly via advance_after_wait/5 — done.
          {:advanced, _advanced_run, _deliveries} = advanced ->
            advanced

          # Run was already :active (not waiting) — fall through to evaluation.
          %WorkflowRun{} = run ->
            case do_progress_active_run(Repo, run, now) do
              {:ok, result} -> result
              {:noop, run, reason} -> {:noop, run, reason}
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      else
        {:noop, run, reason} -> {:noop, run, reason}
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, {:advanced, run, deliveries}} ->
        {:ok, {:advanced, run, deliveries}}

      {:ok, {:waiting, run}} ->
        # Per D-11, Oban-backed hosts schedule a `WorkflowProgressionWorker`
        # job at the persisted `due_at` so due waits wake automatically. The
        # canonical wait state is already durable on the row at this point,
        # so any scheduling failure is safe — `progress_due_runs/1` is the
        # shared manual fallback for non-Oban hosts and for failed scheduler
        # inserts. Scheduling lives outside the engine transaction to avoid
        # nesting Oban inserts inside the FOR UPDATE locks the engine took.
        _ = maybe_schedule_due_progression_job(run)
        {:ok, {:waiting, run}}

      {:ok, {:noop, run, reason}} ->
        {:ok, {:noop, run, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists workflow runs that are currently `:waiting` with a due wait gate that
  has elapsed (per persisted `status_context["due_at"]`) and re-evaluates each
  one through `progress_run/2`. The Plan 25-03 due-step worker calls into
  this helper so wait gates always advance through the same shared seam.
  """
  @spec progress_due_runs(keyword()) :: [progress_result()]
  def progress_due_runs(opts \\ []) when is_list(opts) do
    now = Keyword.get(opts, :now, DateTime.utc_now()) |> DateTime.truncate(:microsecond)
    iso_now = DateTime.to_iso8601(now)

    Repo.all(
      from(wr in WorkflowRun,
        where:
          wr.state == :waiting and wr.status_reason == ^@waiting_reason and
            fragment("?->>?", wr.status_context, ^"due_at") <= ^iso_now,
        order_by: [asc: wr.last_transition_at, asc: wr.id],
        select: wr.id
      )
    )
    |> Enum.map(&progress_run(&1, Keyword.put(opts, :now, now)))
  end

  # ---- Internal: evaluate active run -----------------------------------------

  defp do_progress_active_run(repo, %WorkflowRun{state: :active} = run, now) do
    step = Workflows.get_current_step!(run)

    case lock_active_step_delivery(repo, run, step) do
      nil ->
        {:noop, run, :no_active_step_delivery}

      delivery ->
        evaluate_step(repo, run, step, delivery, now)
    end
  end

  defp do_progress_active_run(_repo, %WorkflowRun{} = run, _now) do
    # :waiting (still not due), :completed, or :stopped — duplicate-safe noop.
    {:noop, run, :run_not_active}
  end

  defp evaluate_step(repo, run, step, delivery, now) do
    rules = step.config |> Map.get("progress", []) |> List.wrap()
    outcome = ProgressionOutcome.from_delivery(delivery, latest_attempt(delivery))

    cond do
      rules == [] ->
        {:noop, run, :no_progress_rules}

      true ->
        case match_on_outcome(rules, outcome) do
          {:match, rule, branchable_outcome, evidence} ->
            advance_run(repo, run, step, delivery, rule, branchable_outcome, evidence, now)

          :no_match ->
            case match_wait_until(rules, outcome) do
              {:match, rule} ->
                enter_waiting(repo, run, step, delivery, rule, now)

              :no_match ->
                {:noop, run, :no_matching_progress_rule}

              {:not_branchable, _rule} ->
                {:noop, run, :prior_delivery_not_converged}
            end
        end
    end
  end

  # ---- Internal: rule matching -----------------------------------------------

  defp match_on_outcome(rules, {:branchable, outcome, evidence}) do
    outcome_string = Atom.to_string(outcome)

    rules
    |> Enum.find(fn rule ->
      rule["kind"] == "on_outcome" and rule["outcome"] == outcome_string
    end)
    |> case do
      nil -> :no_match
      rule -> {:match, rule, outcome, evidence}
    end
  end

  defp match_on_outcome(_rules, :not_branchable_yet), do: :no_match

  defp match_wait_until(rules, {:branchable, _outcome, _evidence}) do
    case Enum.find(rules, fn rule -> rule["kind"] == "wait_until" end) do
      nil -> :no_match
      rule -> {:match, rule}
    end
  end

  defp match_wait_until(rules, :not_branchable_yet) do
    case Enum.find(rules, fn rule -> rule["kind"] == "wait_until" end) do
      nil -> :no_match
      rule -> {:not_branchable, rule}
    end
  end

  # ---- Internal: enter waiting (wait_until) ----------------------------------

  defp enter_waiting(repo, run, step, delivery, rule, now) do
    anchor_timestamp = anchor_timestamp_for(delivery)
    delay_seconds = Map.fetch!(rule, "delay_seconds")
    due_at = DateTime.add(anchor_timestamp, delay_seconds, :second)
    to_step = Map.fetch!(rule, "to_step")

    status_context = %{
      "rule_kind" => "wait_until",
      "anchor" => Map.fetch!(rule, "anchor"),
      "anchor_delivery_id" => delivery.id,
      "anchor_delivery_status" => Atom.to_string(delivery.status),
      "anchor_timestamp" => DateTime.to_iso8601(anchor_timestamp),
      "due_at" => DateTime.to_iso8601(due_at),
      "to_step" => to_step
    }

    with {:ok, updated_run} <-
           Workflows.update_run(repo, run, %{
             state: :waiting,
             status_reason: @waiting_reason,
             status_context: status_context,
             last_transition_at: now
           }),
         {:ok, _transition} <-
           Workflows.append_transition(repo, %{
             workflow_run_id: run.id,
             workflow_step_id: step.id,
             delivery_id: delivery.id,
             from_state: :active,
             to_state: :waiting,
             reason: @waiting_reason,
             context: status_context,
             inserted_at: now
           }) do
      {:ok, {:waiting, updated_run}}
    end
  end

  # ---- Internal: advance (on_outcome) ----------------------------------------

  defp advance_run(repo, run, step, delivery, rule, outcome, evidence, now) do
    to_step_key = Map.fetch!(rule, "to_step")
    notification = Repo.get!(Notification, delivery.notification_id)

    case Workflows.fetch_step_by_key(notification.workflow_definition_id, to_step_key) do
      nil ->
        {:noop, run, :unknown_to_step}

      %WorkflowStep{} = next_step ->
        outcome_string = Atom.to_string(outcome)

        context =
          %{
            "rule_kind" => "on_outcome",
            "workflow_outcome" => outcome_string,
            "anchor_delivery_id" => delivery.id,
            "to_step" => to_step_key,
            "from_step" => step.step_key
          }
          |> maybe_put_evidence(evidence)

        with {:ok, _transition} <-
               Workflows.append_transition(repo, %{
                 workflow_run_id: run.id,
                 workflow_step_id: step.id,
                 delivery_id: delivery.id,
                 from_state: :active,
                 to_state: :active,
                 reason: @advanced_reason,
                 context: context,
                 inserted_at: now
               }),
             {:ok, updated_run} <-
               Workflows.update_run(repo, run, %{
                 current_step_id: next_step.id,
                 last_transition_at: now,
                 status_reason: @advanced_reason,
                 status_context: context
               }),
             {:ok, _activated_transition} <-
               Workflows.append_transition(repo, %{
                 workflow_run_id: run.id,
                 workflow_step_id: next_step.id,
                 from_state: :active,
                 to_state: :active,
                 reason: "step_activated",
                 context: %{"step_key" => next_step.step_key, "source" => "progression"},
                 inserted_at: now
               }),
             {:ok, next_delivery} <-
               DeliveryPlanning.plan_next_step_delivery(notification, next_step.channel,
                 notification_key: persisted_notification_key(notification),
                 use_persisted_workflow: true,
                 use_persisted_channels: true,
                 use_persisted_orchestration: true
               ) do
          {:ok, {:advanced, updated_run, [next_delivery]}}
        end
    end
  end

  defp maybe_put_evidence(context, %{} = evidence) do
    Enum.reduce(evidence, context, fn {key, value}, acc ->
      Map.put(acc, Atom.to_string(key), value)
    end)
  end

  defp maybe_put_evidence(context, _), do: context

  # ---- Internal: reactivation (due waits) ------------------------------------

  defp maybe_reactivate_due(repo, %WorkflowRun{state: :waiting} = run, now) do
    case run.status_context do
      %{"due_at" => due_at_iso, "to_step" => to_step, "anchor_delivery_id" => anchor_delivery_id}
      when is_binary(due_at_iso) and is_binary(to_step) and is_binary(anchor_delivery_id) ->
        case DateTime.from_iso8601(due_at_iso) do
          {:ok, due_at, _offset} ->
            if DateTime.compare(now, due_at) in [:gt, :eq] do
              # Wait elapsed: advance directly to the persisted to_step instead
              # of re-evaluating the active step's rules (which would re-match
              # the same wait_until rule and loop forever — CR-01).
              advance_after_wait(repo, run, to_step, anchor_delivery_id, now)
            else
              {:noop, run, :wait_not_due}
            end

          _ ->
            {:noop, run, :invalid_due_at}
        end

      # Backward-compat: persisted contexts from older runs that lack to_step
      # or anchor_delivery_id can still surface a deterministic noop reason.
      %{"due_at" => due_at_iso} when is_binary(due_at_iso) ->
        case DateTime.from_iso8601(due_at_iso) do
          {:ok, due_at, _offset} ->
            if DateTime.compare(now, due_at) in [:gt, :eq] do
              {:noop, run, :wait_context_incomplete}
            else
              {:noop, run, :wait_not_due}
            end

          _ ->
            {:noop, run, :invalid_due_at}
        end

      _ ->
        {:noop, run, :wait_missing_due_at}
    end
  end

  defp maybe_reactivate_due(_repo, %WorkflowRun{} = run, _now), do: {:ok, run}

  # CR-01 fix: the wait_until rule's advancement seam. Reloads the anchor
  # delivery row, appends one `reactivated_from_wait` transition, then runs
  # the canonical post-cursor advancement (cursor update + step_activated
  # transition + canonical plan_next_step_delivery) using the persisted
  # to_step from status_context. This replaces the previous
  # reactivate_run -> rule-re-evaluation path which looped forever.
  defp advance_after_wait(repo, %WorkflowRun{} = run, to_step_key, anchor_delivery_id, now)
       when is_binary(to_step_key) and is_binary(anchor_delivery_id) do
    reactivation_context =
      run.status_context
      |> Map.put("reactivated_at", DateTime.to_iso8601(now))

    with {:ok, anchor_delivery} <- fetch_anchor_delivery(repo, anchor_delivery_id),
         {:ok, _reactivated_transition} <-
           Workflows.append_transition(repo, %{
             workflow_run_id: run.id,
             workflow_step_id: run.current_step_id,
             delivery_id: anchor_delivery.id,
             from_state: :waiting,
             to_state: :active,
             reason: @reactivated_reason,
             context: reactivation_context,
             inserted_at: now
           }),
         %WorkflowStep{} = next_step <-
           Workflows.fetch_step_by_key(run.workflow_definition_id, to_step_key) ||
             {:error, :unknown_to_step},
         {:ok, advanced_run} <-
           Workflows.update_run(repo, run, %{
             state: :active,
             current_step_id: next_step.id,
             last_transition_at: now,
             status_reason: @advanced_reason,
             status_context: %{
               "rule_kind" => "wait_until",
               "workflow_outcome" => "wait_elapsed",
               "anchor_delivery_id" => anchor_delivery.id,
               "to_step" => to_step_key,
               "from_step" => current_step_key(run)
             }
           }),
         {:ok, _activated_transition} <-
           Workflows.append_transition(repo, %{
             workflow_run_id: run.id,
             workflow_step_id: next_step.id,
             from_state: :active,
             to_state: :active,
             reason: "step_activated",
             context: %{"step_key" => next_step.step_key, "source" => "progression"},
             inserted_at: now
           }),
         notification = Repo.get!(Notification, anchor_delivery.notification_id),
         {:ok, next_delivery} <-
           DeliveryPlanning.plan_next_step_delivery(notification, next_step.channel,
             notification_key: persisted_notification_key(notification),
             use_persisted_workflow: true,
             use_persisted_channels: true,
             use_persisted_orchestration: true
           ) do
      {:ok, {:advanced, advanced_run, [next_delivery]}}
    else
      {:error, :unknown_to_step} -> {:noop, run, :unknown_to_step}
      nil -> {:noop, run, :unknown_to_step}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_anchor_delivery(repo, anchor_delivery_id) do
    case repo.get(Delivery, anchor_delivery_id) do
      nil -> {:error, :anchor_delivery_not_found}
      %Delivery{} = delivery -> {:ok, delivery}
    end
  end

  defp current_step_key(%WorkflowRun{current_step_id: step_id}) when is_binary(step_id) do
    case Repo.get(WorkflowStep, step_id) do
      %WorkflowStep{step_key: step_key} -> step_key
      _ -> nil
    end
  end

  defp current_step_key(_), do: nil

  # ---- Internal: row locking + helpers ---------------------------------------

  defp lock_active_step_delivery(repo, %WorkflowRun{} = run, %WorkflowStep{} = step) do
    repo.one(
      from(d in Delivery,
        where: d.workflow_run_id == ^run.id and d.workflow_step_id == ^step.id,
        lock: "FOR UPDATE"
      )
    )
  end

  defp latest_attempt(%Delivery{id: delivery_id}) do
    Repo.one(
      from(a in DeliveryAttempt,
        where: a.delivery_id == ^delivery_id,
        order_by: [desc: a.attempt_number],
        limit: 1
      )
    )
  end

  # The progression engine anchors `wait_until` rules to the prior delivery's
  # terminal-convergence moment per D-01. Chimeway already serializes terminal
  # writes through `record_attempt/2`, `suppress_delivery/3`, `exhaust_delivery/1`,
  # and `cancel_with_reason/2` — all of which update `updated_at`. Using
  # `updated_at` keeps the anchor durable without introducing a new column.
  defp anchor_timestamp_for(%Delivery{updated_at: updated_at}) do
    case updated_at do
      %DateTime{} = dt -> DateTime.truncate(dt, :microsecond)
      _ -> DateTime.utc_now() |> DateTime.truncate(:microsecond)
    end
  end

  defp persisted_notification_key(%Notification{} = notification) do
    case notification.metadata do
      %{"notification_key" => key} when is_binary(key) -> key
      _ -> nil
    end
  end

  # ---- Internal: optional Oban scheduling (D-11) -----------------------------

  # When the configured dispatcher is `Chimeway.Dispatch.Oban`, schedule a
  # `Chimeway.Dispatch.WorkflowProgressionWorker` job at the persisted
  # `due_at` so the wait gate wakes automatically. Non-Oban dispatchers
  # continue to drive due-run progression through `progress_due_runs/1` —
  # both seams call this same engine, so internal semantics match
  # regardless of host wiring.
  defp maybe_schedule_due_progression_job(%WorkflowRun{} = run) do
    cond do
      not oban_dispatcher_configured?() ->
        :ok

      not Code.ensure_loaded?(Chimeway.Dispatch.WorkflowProgressionWorker) ->
        :ok

      true ->
        case parse_due_at(run.status_context) do
          {:ok, %DateTime{} = due_at} ->
            insert_due_progression_job(run.id, due_at)

          :error ->
            :ok
        end
    end
  end

  defp oban_dispatcher_configured? do
    Application.get_env(:chimeway, :dispatcher) == Chimeway.Dispatch.Oban
  end

  defp parse_due_at(%{"due_at" => due_at_iso}) when is_binary(due_at_iso) do
    case DateTime.from_iso8601(due_at_iso) do
      {:ok, due_at, _offset} -> {:ok, due_at}
      _ -> :error
    end
  end

  defp parse_due_at(_), do: :error

  defp insert_due_progression_job(workflow_run_id, %DateTime{} = due_at) do
    job =
      apply(Chimeway.Dispatch.WorkflowProgressionWorker, :new, [
        %{workflow_run_id: workflow_run_id},
        [scheduled_at: due_at]
      ])

    case apply(Oban, :insert, [job]) do
      {:ok, _job} -> :ok
      # Best-effort scheduling: a failed insert is non-fatal because the
      # canonical wait state is already durable and `progress_due_runs/1`
      # remains the shared manual fallback. We swallow the error and let the
      # caller see the original `{:ok, {:waiting, run}}` result.
      _ -> :ok
    end
  rescue
    _ -> :ok
  end
end
