---
phase: 25-progression-engine-wait-gates
reviewed: 2026-04-29T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - lib/chimeway/workflows/progression.ex
  - lib/chimeway/notifier.ex
  - lib/chimeway/workflows/progression_outcome.ex
  - test/chimeway/orchestration/workflow_progression_test.exs
  - test/chimeway/reliability/workflow_progression_race_test.exs
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Phase 25 Wave 4: Code Review Report

**Reviewed:** 2026-04-29T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Wave 4 closes three VERIFICATION findings (CR-01 BLOCKER, WR-01 PARTIAL, WR-02 PARTIAL). The CR-01 fix to `advance_after_wait/5` is structurally sound and the regression test does prove the loop closure, single-delivery, and noop-on-re-entry contracts. However, the new function has **one BLOCKER**: an `:unknown_to_step` failure inside `advance_after_wait/5` commits an orphan `reactivated_from_wait` transition row, breaks idempotency on retry, and pollutes the audit trail. Several lesser issues span over-permissive test assertions, stale line-number references in the WR-01 moduledoc, weakened backward-compat semantics for partially-persisted wait contexts, and a moduledoc claim about lock discipline that no longer holds for the wait-elapse path. The WR-02 warnings are accurate and well-placed at both the runtime mapper and the curated vocabulary, though only one of the two warnings is actually exposed in generated documentation.

## Critical Issues

### CR-01 (BLOCKER): `advance_after_wait/5` commits orphan `reactivated_from_wait` transition when `to_step` cannot be resolved, breaking idempotency

**File:** `lib/chimeway/workflows/progression.ex:379-438`

**Issue:** The `with` chain in `advance_after_wait/5` runs in this order:

1. `fetch_anchor_delivery(repo, anchor_delivery_id)`
2. `Workflows.append_transition(...)` writes the `reactivated_from_wait` row
3. `Workflows.fetch_step_by_key(...) || {:error, :unknown_to_step}` — the lookup
4. `Workflows.update_run(...)` cursor advancement
5. `Workflows.append_transition(...)` `step_activated`
6. `DeliveryPlanning.plan_next_step_delivery(...)`

If step 3 fails (the persisted `to_step` no longer exists in the workflow definition — which can happen during a workflow definition migration, or if a custom `WorkflowDefinitionLoader` is in use), the `else` branch returns `{:noop, run, :unknown_to_step}` (lines 433-437). This is NOT a `Repo.rollback/1` call — `Repo.transaction/1` only rolls back when `rollback/1` is invoked explicitly. Returning a plain `{:noop, ...}` tuple **commits the transaction**, leaving the `reactivated_from_wait` row from step 2 persisted while the run state is unchanged (still `:waiting`, status_context still complete, current_step_id still pointing at the prior step).

Consequences:

1. **Audit trail corruption (T-25-05 / repudiation):** A `reactivated_from_wait` row exists for a reactivation that didn't happen. The moduledoc explicitly claims (lines 36-39) that "explicit `status_reason` and `reason` strings plus the curated `status_context` / transition `context` keys make the decision auditable from durable rows alone." A reader of the transition log will see a reactivation that did not actually transition.

2. **Idempotency violation (ESC-03 / T-25-06):** Each subsequent `progress_run/2` call on this run will re-enter the same path (run still `:waiting`, still past-due, status_context still has the unresolvable `to_step`), append ANOTHER `reactivated_from_wait` row, and return `:unknown_to_step` again. The due-step worker (Plan 25-03) calls this on every tick — in a 60-second tick interval over a day of stuck `to_step`, that is 1,440 orphan transition rows for one run. The moduledoc explicitly lists "**T-25-06 (DoS / duplicate emission):** noop short-circuits prevent retry storms from emitting duplicate next-step deliveries" (lines 40-41) — duplicate-emission protection covers `Delivery` rows but the same property is broken for `WorkflowTransition` rows here.

The exact same defect applies to a hypothetical concurrent `update_run` failure (e.g., changeset error) since `update_run` runs AFTER the reactivated transition is appended — but that one would correctly roll back via `Repo.rollback(reason)` because the with's else branch matches `{:error, reason} -> {:error, reason}` which propagates to `progress_run/2`'s `Repo.rollback`. Only the explicit `:unknown_to_step` short-circuit returns a noop (committing) instead of an error (rolling back).

**Fix:** Either reorder the with so the step lookup happens before any transition is appended, OR rollback explicitly inside `advance_after_wait/5` for the unknown-to-step case.

Preferred — reorder so no writes happen until the step is resolved:

```elixir
defp advance_after_wait(repo, %WorkflowRun{} = run, to_step_key, anchor_delivery_id, now)
     when is_binary(to_step_key) and is_binary(anchor_delivery_id) do
  reactivation_context =
    run.status_context
    |> Map.put("reactivated_at", DateTime.to_iso8601(now))

  with {:ok, anchor_delivery} <- fetch_anchor_delivery(repo, anchor_delivery_id),
       %WorkflowStep{} = next_step <-
         Workflows.fetch_step_by_key(run.workflow_definition_id, to_step_key) ||
           {:error, :unknown_to_step},
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
       {:ok, advanced_run} <- Workflows.update_run(repo, run, %{...}),
       ...
  do
    {:ok, {:advanced, advanced_run, [next_delivery]}}
  else
    {:error, :unknown_to_step} -> {:noop, run, :unknown_to_step}
    {:error, :anchor_delivery_not_found} -> {:noop, run, :anchor_delivery_not_found}
    {:error, reason} -> {:error, reason}
  end
end
```

Add a regression test in `test/chimeway/orchestration/workflow_progression_test.exs` that:

1. Stamps a `:waiting` run whose `status_context["to_step"]` is a step_key that does NOT exist in the workflow definition.
2. Calls `Progression.progress_run/2` with `now` past `due_at`.
3. Asserts `{:ok, {:noop, _, :unknown_to_step}}`.
4. Asserts ZERO `reactivated_from_wait` transitions exist on the run.
5. Calls `progress_run/2` a second time and asserts ZERO new transitions.

## Warnings

### WR-01: CR-01 regression test accepts three different `status_reason` values when only one is correct

**File:** `test/chimeway/orchestration/workflow_progression_test.exs:222-226`

**Issue:** The test asserts:

```elixir
assert advanced_run.status_reason in [
         "progressed_on_delivery_outcome",
         "step_activated",
         "reactivated_from_wait"
       ]
```

But `advance_after_wait/5` always sets `status_reason: @advanced_reason` which is the literal string `"progressed_on_delivery_outcome"` (line 405 of `progression.ex`). The test would still pass if the implementation regressed to `"reactivated_from_wait"` (the old buggy value) or to `"step_activated"` (which is a transition reason, not a run-status reason). This weakens the regression test's ability to catch a future re-introduction of CR-01 — the original CR-01 bug would have left `status_reason: "reactivated_from_wait"`, which this assertion would still accept.

**Fix:**

```elixir
assert advanced_run.status_reason == "progressed_on_delivery_outcome"
```

If the test author wanted leeway in case the canonical reason name evolves, the better expression of intent is to assert against `Chimeway.Workflows.Progression`'s module attribute via a public accessor or constant — not a wide whitelist that admits known-bad values.

### WR-02: Moduledoc still claims active-step-delivery `FOR UPDATE` locking, but the wait-elapse path locks neither the anchor delivery nor the new active step's delivery

**File:** `lib/chimeway/workflows/progression.ex:27-31`

**Issue:** The moduledoc says:

```
All locking happens inside one `Repo.transaction/1`:
  * the workflow run row is locked with `FOR UPDATE` first
  * the active-step delivery row is then locked with `FOR UPDATE`
```

This is true for the active-evaluation path (`do_progress_active_run/3` -> `lock_active_step_delivery/3`). It is NOT true for the new wait-elapse path through `advance_after_wait/5`, which only locks the run row (via `lock_run` at line 75) and reads the anchor delivery via plain `repo.get(Delivery, ...)` at line 441. There is no second `FOR UPDATE` lock in this path.

For correctness this is acceptable (the run-row lock is sufficient because the anchor delivery is already terminal at this point — its row is no longer being mutated by `record_attempt/2` or other paths). But the moduledoc is now an inaccurate description of the lock discipline. Operators reading the moduledoc to reason about contention will assume two locks are taken when only one is.

**Fix:** Update the moduledoc to describe both paths. For example:

```
All locking happens inside one `Repo.transaction/1`:

  * For active-step evaluation (on_outcome / wait_until entry / no-rule noops),
    the workflow run row is locked with `FOR UPDATE` first, then the active-step
    delivery row is locked with `FOR UPDATE`.
  * For wait-elapse advancement (a past-due `wait_until` rule transitioning the
    run from `:waiting` back to `:active` and onto the persisted `to_step`),
    only the workflow run row is locked. The anchor delivery is already
    terminal at this point and is read without a row lock; serialization
    against concurrent `progress_run/2` callers is enforced by the run-row
    lock alone.
```

### WR-03: WR-01 moduledoc cites stale line numbers for `lock_active_step_delivery/3`

**File:** `test/chimeway/reliability/workflow_progression_race_test.exs:117-119`

**Issue:** The new moduledoc says:

```
The engine's `FOR UPDATE` discipline lives in `lib/chimeway/workflows/progression.ex`
at `Chimeway.Workflows.lock_run/2` (called at the top of `progress_run/2`) and
`lock_active_step_delivery/3` (lines 372-378).
```

But `lock_active_step_delivery/3` is at lines **458-465** of `lib/chimeway/workflows/progression.ex` after this wave's edits to `maybe_reactivate_due/3` and the new `advance_after_wait/5` shifted everything below them down. Hard-coded line numbers in moduledoc rot the moment any code above them is edited — and this docstring is documenting precisely the file that was just edited.

**Fix:** Drop the line range. Either reference by function name only or use a code-anchor-stable reference:

```
`lock_active_step_delivery/3` (defined under the "Internal: row locking + helpers" section)
```

Better yet, link to the function by its module-qualified name and let the reader use IDE search:

```
`Chimeway.Workflows.Progression.lock_active_step_delivery/3`
```

### WR-04: `:wait_context_incomplete` backward-compat branch silently strands runs forever

**File:** `lib/chimeway/workflows/progression.ex:351-364`

**Issue:** The backward-compat clause:

```elixir
%{"due_at" => due_at_iso} when is_binary(due_at_iso) ->
  case DateTime.from_iso8601(due_at_iso) do
    {:ok, due_at, _offset} ->
      if DateTime.compare(now, due_at) in [:gt, :eq] do
        {:noop, run, :wait_context_incomplete}
      else
        {:noop, run, :wait_not_due}
      end
    ...
  end
```

is a deliberate "fail closed" choice for runs persisted by an older codebase that wrote `due_at` but neither `to_step` nor `anchor_delivery_id`. Such a run is now stuck `:waiting` forever — every call returns `:wait_context_incomplete` and nothing else moves the run forward. This is technically not a regression (the prior `reactivate_run` path was the buggy CR-01 loop), and it is unlikely to happen in practice because `enter_waiting/3` has been writing `to_step` and `anchor_delivery_id` since Wave 1. But:

1. There is no operator-visible alarm. An infinite-noop run is silent.
2. The deferred-items file does not list a manual recovery procedure.
3. The integration suite does not assert this branch's behaviour, so a future refactor could quietly break the noop semantics without anyone noticing.

**Fix:** Either log a warning when this branch fires (so an operator running `progress_due_runs/1` from IEx sees the issue), or add an integration test that stamps a run with the stripped-down context shape and asserts `:wait_context_incomplete` is returned exactly once per call with no transitions appended. Recommended: do both, plus add a one-line entry in `deferred-items.md` describing the manual recovery script (e.g., "set status_context to a complete map or re-enter `:active` via `Workflows.update_run/3`").

### WR-05: Operator-facing WR-02 warning at `Notifier.@progress_outcomes` is a code comment, not a docstring — invisible in generated docs (HexDocs / IEx `h`)

**File:** `lib/chimeway/notifier.ex:541-575`

**Issue:** The 35-line warning placed immediately above `@progress_outcomes` is a `#` source comment, not an `@doc` or `@moduledoc` attribute. Module attributes (`@progress_outcomes`) are private compile-time constants and do not surface their preceding comments in generated documentation. An operator running `h Chimeway.Notifier` in IEx, browsing HexDocs, or reading the public API surface in `mix docs` output will NOT see this warning.

The companion warning in `Chimeway.Workflows.ProgressionOutcome` (lines 27-50) IS in the `@moduledoc` and DOES surface in generated docs — that one is fine. The asymmetry means notifier authors who never read `progression_outcome.ex` source (which is the typical case — it's the runtime mapping site, not the authoring surface) will miss the warning at the only place they'd plausibly look for it: the notifier behaviour module.

This is partially defensible because `@progress_outcomes` is private and the warning is an implementation note rather than a contract for callers of `Chimeway.Notifier`. But the user-facing rationale of WR-02 is to warn AUTHORS of `workflow/2` callbacks who write `%{"kind" => "on_outcome", "outcome" => "temporary_failure", ...}`, and authoring is exactly the surface `Chimeway.Notifier` exposes. So the warning needs to live somewhere those authors can find it.

**Fix:** Promote the WR-02 warning to a section in the `Chimeway.Notifier` `@moduledoc` (lines 2-10), titled something like "## Workflow progress rules — `temporary_failure` early-fire warning". The current code comment can stay as a duplicate near `@progress_outcomes` for in-source readers, but the canonical operator-facing copy should be in `@moduledoc` so it appears in generated docs and `IEx.h`.

## Info

### IN-01: Mixed use of `Repo` (module) and `repo` (parameter) inside `advance_after_wait/5` is stylistically inconsistent with the rest of the file

**File:** `lib/chimeway/workflows/progression.ex:424, 448`

**Issue:** Inside `advance_after_wait/5`, the helper accepts a `repo` parameter and passes it to `fetch_anchor_delivery/2`, `Workflows.append_transition/2`, `Workflows.update_run/3`. But two calls bypass `repo` and use `Repo` directly:

- Line 424: `notification = Repo.get!(Notification, anchor_delivery.notification_id)`
- Line 448 inside `current_step_key/1`: `case Repo.get(WorkflowStep, step_id) do`

Functionally these are fine — Ecto's connection-per-process model means `Repo.X` calls inside a transaction use the same checked-out connection as `repo.X` would. But the parameter exists precisely so the engine could be repointed at a different repo (e.g., for tests or multi-tenant setups). Callers that override `repo` will silently get inconsistent behaviour.

`Workflows.fetch_step_by_key/2` has the same defect (its definition uses `Repo` directly, not a `repo` parameter), but that's outside this wave's scope.

**Fix:** Either accept that the engine hard-codes `Repo` throughout (and drop the `repo` parameter from helpers, since it's not actually a seam) or pass `repo` to all DB calls inside `advance_after_wait/5`. Given the rest of the engine is consistent about passing `repo`, the latter is the smaller change:

```elixir
notification = repo.get!(Notification, anchor_delivery.notification_id),
```

```elixir
defp current_step_key(repo, %WorkflowRun{current_step_id: step_id}) when is_binary(step_id) do
  case repo.get(WorkflowStep, step_id) do
    %WorkflowStep{step_key: step_key} -> step_key
    _ -> nil
  end
end
```

### IN-02: `current_step_key/1` performs a second DB round-trip purely to translate a step_id back to a step_key

**File:** `lib/chimeway/workflows/progression.ex:447-454`

**Issue:** `advance_after_wait/5` already has `run.current_step_id` in hand. The helper does an extra `Repo.get(WorkflowStep, step_id)` just to turn that UUID into a `step_key` string for the `from_step` audit field. This is a minor code-smell: a transaction that already locks the run row makes one more query for what amounts to a string-conversion lookup.

This is out of scope per the v1 review rules (no performance findings) — but it's also a maintainability flag because any future caller of `current_step_key/1` will pay the same query cost without realizing it. The helper's name suggests cheap accessor semantics; its body is a database hit.

**Fix:** If `from_step` is needed for audit, fetch the step row earlier in the with chain (paired with the new step lookup) so both step_key resolutions share one round-trip pattern. Or accept the cost and rename to `lookup_current_step_key/1` so the database access is named.

### IN-03: Dead `nil ->` clause in the `else` branch of `advance_after_wait/5` is unreachable

**File:** `lib/chimeway/workflows/progression.ex:435`

**Issue:** The `else` block:

```elixir
else
  {:error, :unknown_to_step} -> {:noop, run, :unknown_to_step}
  nil -> {:noop, run, :unknown_to_step}
  {:error, reason} -> {:error, reason}
end
```

The `nil ->` clause cannot match because the with's third clause uses `Workflows.fetch_step_by_key(...) || {:error, :unknown_to_step}` — the `||` short-circuit converts a `nil` return to `{:error, :unknown_to_step}` BEFORE the pattern match runs. So the only value the `%WorkflowStep{} = next_step <- ...` clause can fail on is `{:error, :unknown_to_step}`, which the first else clause already covers. The `nil ->` clause is dead code.

This is harmless but misleading: a reader assumes `nil` is a real failure mode and may try to engineer a path that produces it.

**Fix:** Drop the dead clause:

```elixir
else
  {:error, :unknown_to_step} -> {:noop, run, :unknown_to_step}
  {:error, reason} -> {:error, reason}
end
```

---

_Reviewed: 2026-04-29T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
