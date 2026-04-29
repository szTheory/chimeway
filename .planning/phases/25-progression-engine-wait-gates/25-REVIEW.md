---
phase: 25-progression-engine-wait-gates
reviewed: 2026-04-29T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - lib/chimeway/notifier.ex
  - lib/chimeway/workflows/progression_outcome.ex
  - lib/chimeway/workflows.ex
  - lib/chimeway/workflows/progression.ex
  - lib/chimeway/delivery_planning.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/dispatch/workflow_progression_worker.ex
  - test/chimeway/notifier_contract_test.exs
  - test/chimeway/workflows/progression_outcome_test.exs
  - test/chimeway/orchestration/workflow_progression_test.exs
  - test/chimeway/dispatch/workflow_progression_worker_test.exs
  - test/chimeway/reliability/workflow_progression_race_test.exs
findings:
  critical: 1
  warning: 5
  info: 2
  total: 8
status: issues_found
---

# Phase 25: Code Review Report

**Reviewed:** 2026-04-29
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

The Phase 25 progression engine successfully establishes the durable contract for workflow rule normalization, the curated outcome vocabulary, and the duplicate-safe `progress_run/2` seam. The `on_outcome` advancement path, the wait-state entry path, the canonical convergence hook in `Deliveries`, and the thin Oban worker all hang together as the design intends.

However, **the `wait_until` rule has no advancement code path**. After a wait gate elapses and the run reactivates, the engine re-evaluates the same rules against the same converged delivery, re-matches the `wait_until` rule, and re-enters the same waiting state with the same `due_at`. Manual or Oban-driven due-progression then loops forever — the run can only escape via an `on_outcome` rule that happens to match the same converged outcome. The integration test for `wait_until` only asserts the initial wait entry; it never drives the wait to expiry, so this gap is not caught by the test suite. This is a contract-level correctness defect for the headline Phase 25 capability and is the primary blocker.

Several lower-severity issues compound the risk: the race test does not actually exercise multi-connection locking under the SQL Sandbox, the `temporary_failure` outcome is treated as branchable while the underlying delivery may still succeed on retry, and the `advance_run` path queries `notification.workflow_definition_id` rather than `run.workflow_definition_id`, coupling the engine to a denormalized field instead of the locked row.

## Critical Issues

### CR-01: `wait_until` rule has no advancement path — infinite reactivation loop

**File:** `lib/chimeway/workflows/progression.ex:149-175, 321-367`
**Issue:** The engine's only advancement code is `advance_run/8`, which is reached exclusively from `match_on_outcome/2` matching a `:branchable` outcome. The `match_wait_until/2` branch only ever calls `enter_waiting/6`, never `advance_run`. After a wait elapses:

1. `progress_due_runs/1` (or the Oban worker) calls `progress_run/2` for the waiting run.
2. `maybe_reactivate_due/3` flips the row from `:waiting` back to `:active` and returns `{:ok, run}`.
3. `do_progress_active_run/3` re-runs `evaluate_step/5` against the same step config and the same converged delivery row.
4. `match_on_outcome/2` returns `:no_match` (the prior delivery already converged before the first wait was entered, and no `on_outcome <that-outcome>` rule was authored — otherwise `wait_until` would not have fired in the first place).
5. `match_wait_until/2` matches again because the outcome is still `{:branchable, ...}`.
6. `enter_waiting/6` writes the run back to `:waiting` with the same `due_at` (anchored to `delivery.updated_at + delay_seconds` — both unchanged).
7. The next `progress_due_runs/1` sweep finds the row again. Loop.

Each loop iteration appends a fresh `waiting_for_step_progression` and `reactivated_from_wait` transition, polluting `chimeway_workflow_transitions` while never emitting the next-step delivery the rule promised. The `to_step` value persisted in `status_context` is purely informational — no code reads it for advancement.

The integration test (`test/chimeway/orchestration/workflow_progression_test.exs:122-185`) only asserts the initial wait entry on a not-yet-due gate; it never advances `now` past `due_at` to drive the elapsed-wait scenario, so the bug escapes coverage.

**Fix:** After `maybe_reactivate_due/3` succeeds (i.e., the wait actually elapsed), advance via the `wait_until` rule's persisted `to_step` instead of re-evaluating the step's progress rules. One option:

```elixir
defp maybe_reactivate_due(repo, %WorkflowRun{state: :waiting} = run, now) do
  case run.status_context do
    %{"due_at" => due_at_iso, "to_step" => to_step, "anchor_delivery_id" => anchor_delivery_id}
    when is_binary(due_at_iso) and is_binary(to_step) and is_binary(anchor_delivery_id) ->
      with {:ok, due_at, _} <- DateTime.from_iso8601(due_at_iso),
           true <- DateTime.compare(now, due_at) in [:gt, :eq] do
        # Reactivate AND advance to the wait_until rule's to_step in one shot
        # so reactivation does not re-evaluate the rule that produced the wait.
        advance_after_wait(repo, run, to_step, anchor_delivery_id, now)
      else
        _ -> {:noop, run, :wait_not_due}
      end

    _ ->
      {:noop, run, :wait_missing_due_at}
  end
end
```

`advance_after_wait/5` should reload the anchor delivery, append the `reactivated_from_wait` transition once, then call into the existing `advance_run` post-cursor logic (workflow_run cursor update + `step_activated` transition + `plan_next_step_delivery`). This keeps next-step emission single-sourced through `DeliveryPlanning.plan_next_step_delivery/3` and preserves the duplicate-safety guarantees.

Add a regression test in `test/chimeway/orchestration/workflow_progression_test.exs` that drives `progress_run/2` with `now: due_at + 1` and asserts: (a) exactly one next-step delivery is created, (b) `current_step_id` is the wait's `to_step`, (c) repeated calls noop.

## Warnings

### WR-01: Race test does not exercise true multi-connection row locking

**File:** `test/chimeway/reliability/workflow_progression_race_test.exs:148-197`
**Issue:** The test uses `Task.async_stream` plus `Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())` to fan out 10 progression calls. In SQL Sandbox manual mode, every `allow`-ed process shares the same checked-out database connection. PostgreSQL `FOR UPDATE` only serializes work across DIFFERENT connections — within a single connection, locks are non-blocking. The 10 tasks therefore run sequentially against one transaction, not concurrently against ten. The test demonstrates that the engine's noop short-circuit logic is correct under sequential re-entry, but it does NOT prove that two production processes hitting the same `workflow_run_id` over separate connections collapse to one winner.

The same observation applies to the "10 concurrent calls on a not-yet-due waiting run all noop" assertion: the noops are due to in-process state checks, not DB-level locking.

**Fix:** Either (a) document explicitly that this test covers in-process re-entry safety only and add a separate test that uses `Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)` (or a non-sandboxed test mode) to exercise actual `FOR UPDATE` contention, or (b) restructure the test to spawn separate OS processes that each open their own connection. At minimum, update the test moduledoc to clarify what is and is not being verified, so future readers do not assume `FOR UPDATE` is being exercised by this test.

### WR-02: `temporary_failure` outcome branches before retry exhaustion

**File:** `lib/chimeway/workflows/progression_outcome.ex:75-77`, `lib/chimeway/workflows/progression.ex:149-175`, `lib/chimeway/deliveries.ex:1005-1020`
**Issue:** `ProgressionOutcome.from_delivery/2` maps `%Delivery{status: :failed}` to `{:branchable, :temporary_failure, evidence}`. `:failed` is the explicit non-terminal state Oban uses while a delivery is still being retried (`@allowed_transitions` has `failed: [:dispatched]`). Yet the engine treats it as a branchable outcome that can fire `on_outcome temporary_failure` rules and create a next-step delivery.

Concrete consequence: a notifier authoring `on_outcome temporary_failure -> escalate_to_email` will fire `escalate_to_email` on the FIRST transient failure (before any retry has been attempted), even though the original delivery may succeed on its second Oban attempt. The host now has both a successful primary delivery and an escalation delivery for the same notification — exactly the duplicate-side-effect outcome the workflow was supposed to prevent.

The 25-02 plan calls this out as intentional ("a persisted `delivery.status == :failed` row may advance the run immediately"), so this is partly a contract decision rather than a pure implementation bug. But the contract obscures the operational consequence: workflow authors will reasonably read "temporary_failure" as "the delivery has given up after retries" and will be surprised when their escalation fires after a single transient timeout.

**Fix:** Either (a) remove `temporary_failure` from `@progress_outcomes` in `lib/chimeway/notifier.ex:543` and from `ProgressionOutcome` so authors must explicitly opt into `retries_exhausted` for the post-retry scenario, or (b) document the early-fire behavior prominently in the `Notifier` moduledoc and the `ProgressionOutcome` moduledoc, including the recommendation that `on_outcome temporary_failure` rules should advance to channels that are safe to over-trigger (or should be paired with idempotency keys at the next step).

### WR-03: `advance_run` reads `workflow_definition_id` from notification, not from the locked workflow_run

**File:** `lib/chimeway/workflows/progression.ex:250-256`
**Issue:**

```elixir
defp advance_run(repo, run, step, delivery, rule, outcome, evidence, now) do
  to_step_key = Map.fetch!(rule, "to_step")
  notification = Repo.get!(Notification, delivery.notification_id)

  case Workflows.fetch_step_by_key(notification.workflow_definition_id, to_step_key) do
```

The `notification` row is loaded fresh outside any lock and its `workflow_definition_id` field is used to scope the `to_step` lookup. The locked, authoritative source is `run.workflow_definition_id` — that is the row the engine took `FOR UPDATE` on, and it is guaranteed to be set (an active workflow_run cannot exist without a definition). Using `notification.workflow_definition_id` couples progression to a denormalized field on `chimeway_notifications` that is not protected by the engine's locking discipline; if that field is ever nil or stale (e.g., during a future migration), `fetch_step_by_key/2` will crash on its `is_binary(workflow_definition_id)` guard.

**Fix:**

```elixir
case Workflows.fetch_step_by_key(run.workflow_definition_id, to_step_key) do
```

The `notification` is still needed for `plan_next_step_delivery/3` (recipient, render_assigns, etc.), so the `Repo.get!(Notification, ...)` call stays — but the step lookup should use the locked run's definition id.

### WR-04: `evaluate_step` checks `match_on_outcome` before `match_wait_until` — wait gate is silently skipped when both rules apply to the same outcome

**File:** `lib/chimeway/workflows/progression.ex:149-175`
**Issue:** When a step declares both `wait_until` and `on_outcome <converged-outcome>`, the engine takes the `on_outcome` branch immediately (line 158). The wait gate is silently skipped. This is the intended behavior per the test fixtures (`bounced` advances immediately even though a `wait_until` is also declared), but the precedence is undocumented in the engine's moduledoc and not asserted as a contract anywhere. A future maintainer adding an `on_outcome delivered -> step_X` rule alongside an existing `wait_until -> step_Y` will silently drop the wait — operators auditing transition logs will see an immediate `progressed_on_delivery_outcome` row instead of a `waiting_for_step_progression -> reactivated_from_wait` pair, with no telemetry indicating the wait was bypassed.

**Fix:** Document the precedence explicitly in the `Chimeway.Workflows.Progression` moduledoc and in `Chimeway.Notifier.normalize_workflow_progress_rule/1`. Optionally add a normalization-time validation that rejects mixing `wait_until` with `on_outcome` rules whose `to_step` differs, since the user almost certainly did not intend two divergent paths from the same converged outcome. At minimum, add a test that asserts the precedence so a future reordering does not flip the priority unintentionally.

### WR-05: `to_step` references are not validated at declaration time

**File:** `lib/chimeway/notifier.ex:550-685`, `lib/chimeway/workflows/progression.ex:254-257`
**Issue:** `normalize_workflow_progress_rule/1` validates that `to_step` is a non-blank string but does not check that the value matches a `step_key` actually declared in the same workflow. A typo like `to_step: "emial"` passes normalization, gets persisted in the workflow definition, and only surfaces at runtime when `Workflows.fetch_step_by_key/2` returns nil and `advance_run/8` returns `{:noop, run, :unknown_to_step}`. The run cursor stays on the source step, the engine re-noops on every subsequent progression call, and the workflow is silently stuck — there is no log, telemetry, or transition row that makes the misconfiguration visible to operators.

For `wait_until` rules with an unknown `to_step`, this compounds with CR-01: the wait elapses, reactivation happens, no advancement occurs (because there is no advancement path AT ALL for `wait_until`), and even the conceptual "advance to the wait's to_step" fix from CR-01 would silently noop forever instead of erroring loudly.

**Fix:** Extend `normalize_workflow_steps/1` (or add a final validation pass) so that after all steps are normalized, every rule's `to_step` is verified to be a member of the step_key set. Reject the workflow declaration with `{:error, {:workflow_resolution_failed, {:unknown_to_step, to_step, available_step_keys}}}` if any reference is dangling. This catches typos at declaration time when the host application boots, not at runtime when a user is mid-workflow.

## Info

### IN-01: `anchor_timestamp_for/1` silently falls back to `DateTime.utc_now/0`

**File:** `lib/chimeway/workflows/progression.ex:395-400`
**Issue:**

```elixir
defp anchor_timestamp_for(%Delivery{updated_at: updated_at}) do
  case updated_at do
    %DateTime{} = dt -> DateTime.truncate(dt, :microsecond)
    _ -> DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end
end
```

If `delivery.updated_at` is somehow not a `DateTime` (nil, NaiveDateTime, etc.), the engine silently uses `DateTime.utc_now/0` as the anchor. The test would still pass and the wait would still be entered, but the anchor — and therefore the persisted `due_at` — would no longer be derived from the prior delivery's terminal moment. Operators auditing `chimeway_workflow_transitions` would see an `anchor_timestamp` that does not match the anchor_delivery_id's actual updated_at, breaking the D-13 explainability promise.

**Fix:** Either raise on the unexpected branch (`raise ArgumentError, "expected delivery.updated_at to be a DateTime, got: #{inspect(updated_at)}"`) or return `{:error, {:invalid_anchor_timestamp, updated_at}}` so the progression transaction rolls back loudly. Ecto `:utc_datetime_usec` columns are non-nullable by schema definition, so reaching this branch means a real bug worth surfacing.

### IN-02: `maybe_progress_workflow/1` discards engine errors

**File:** `lib/chimeway/deliveries.ex:1153-1159`
**Issue:**

```elixir
defp maybe_progress_workflow(%Delivery{workflow_run_id: workflow_run_id})
     when is_binary(workflow_run_id) do
  case Chimeway.Workflows.Progression.progress_run(workflow_run_id, []) do
    {:ok, _result} -> :ok
    {:error, _reason} -> :error
  end
end
```

Engine errors (changeset failures inside `enter_waiting`/`advance_run`, missing notifications, transition insert failures) are downgraded to a bare `:error` atom and dropped on the floor by the convergence hook in `record_attempt/2` and by `maybe_apply_progression/1`. Operators get no telemetry, no log, and no error propagation when the engine fails mid-step. The delivery is already terminal at this point, so the host application sees a successful `record_attempt/2` while the workflow has silently failed to progress.

**Fix:** Emit a telemetry event (`:chimeway, :workflow_progression, :error`) including `workflow_run_id`, `delivery_id`, and the reason term before returning `:error`. This preserves the "terminal write succeeds even if progression fails" invariant (which is correct — progression failures should not roll back the delivery commit) while making the failure observable in production.

---

_Reviewed: 2026-04-29_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
