---
phase: 25-progression-engine-wait-gates
plan: 02
subsystem: workflows
tags: [elixir, ecto, workflows, progression, deliveries, integration]

# Dependency graph
requires:
  - phase: 25-progression-engine-wait-gates
    plan: 01
    provides: |
      Curated progression rule shape (`wait_until` + `on_outcome`) and the pure
      `ProgressionOutcome.from_delivery/2` mapper that the engine reads.
provides:
  - Durable `Chimeway.Workflows.Progression.progress_run/2` seam (FOR UPDATE locked, transactional, noop-safe)
  - `Chimeway.Workflows.Progression.progress_due_runs/1` for the Plan 25-03 due-step worker
  - Workflow-run helpers (`lock_run`, `get_run!`, `get_current_step!`, `fetch_step_by_key`, `append_transition`, `update_run`) on `Chimeway.Workflows`
  - `Chimeway.DeliveryPlanning.plan_next_step_delivery/3` for canonical next-step emission
  - Convergence hook: `Deliveries.record_attempt/2`, `suppress_delivery/3`, and `exhaust_delivery/1` invoke the progression seam exactly once after the durable row update
affects:
  - 25-03-wait-gates-and-due-step-worker
  - 26-stop-conditions-escalation
  - traces explanation surfaces (workflow_transitions now carry curated `workflow_outcome` + raw evidence)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Resolve, persist, then branch: lock canonical rows under FOR UPDATE, derive a curated outcome from persisted facts, append one workflow_transition with the curated value plus raw evidence, then advance through the canonical planner."
    - "Single convergence seam: `Deliveries.record_attempt/2`, `suppress_delivery/3`, and `exhaust_delivery/1` are the *only* terminal helpers that invoke `Progression.progress_run/2`, and they invoke it exactly once after the row update commits."
    - "Engine-side noop short-circuits for non-workflow-linked rows, non-active runs, non-converged or unknown-bucket deliveries, and unmatched rule sets."

key-files:
  created:
    - lib/chimeway/workflows/progression.ex
    - test/chimeway/orchestration/workflow_progression_test.exs
  modified:
    - lib/chimeway/workflows.ex
    - lib/chimeway/delivery_planning.ex
    - lib/chimeway/deliveries.ex

key-decisions:
  - "`wait_until` and `on_outcome` rules co-exist on one step's `progress` config; `on_outcome` rules are evaluated first so a curated outcome match takes precedence over a passive wait gate (D-03/D-12)."
  - "`wait_until` rules anchor `due_at` to the prior delivery's `updated_at` because Chimeway already serializes terminal writes through helpers that touch `updated_at`. No new column added — the anchor is durable from the existing row (D-01)."
  - "`status_context` stores ISO-8601 strings for `anchor_timestamp`, `due_at`, and `reactivated_at` so the JSON column round-trips without losing precision and `progress_due_runs/1` can compare via `?->>?` against an ISO-now string."
  - "The convergence hook lives at the `Repo.transaction` boundary in `Deliveries.record_attempt/2` — never inside the inner Multi — so the engine takes its own FOR UPDATE locks without nesting `SELECT FOR UPDATE` inside the attempt-recording lock."
  - "Cancelled rows whose `suppression_reason` is not in the curated vocabulary collapse to `:not_branchable_yet` per Plan 25-01, so the engine returns `:noop, :no_matching_progress_rule` instead of guessing a branch."

patterns-established:
  - "Pattern: Single-seam convergence hook — every canonical terminal write helper invokes one shared progression call, the engine itself enforces noop semantics, and callers never need to reason about workflow state."
  - "Pattern: Engine returns three result kinds (`:advanced`, `:waiting`, `:noop`) plus an explicit reason atom on every noop, so callers and traces can explain *why* nothing changed without re-deriving state."

requirements-completed: [WRK-02, ESC-03]

# Metrics
duration: 13min
completed: 2026-04-29
---

# Phase 25 Plan 02: Workflow Progression Engine Summary

**Durable, transactional `Chimeway.Workflows.Progression.progress_run/2` seam that evaluates `wait_until` and `on_outcome` rules against canonical delivery facts, advances through the canonical planner, and is invoked exactly once per terminal convergence by `Deliveries.record_attempt/2` / `suppress_delivery/3` / `exhaust_delivery/1`.**

## Performance

- **Duration:** ~13 min
- **Started:** 2026-04-29T19:09:59Z
- **Completed:** 2026-04-29T19:23:41Z
- **Tasks:** 2 (TDD: RED then GREEN)
- **Files created:** 2
- **Files modified:** 3

## Accomplishments

- **Engine.** Built `Chimeway.Workflows.Progression.progress_run/2` as the single seam for evaluating a workflow run's active step against the canonical prior delivery row. Inside one transaction it:
  1. Locks the workflow run with `FOR UPDATE`.
  2. Reactivates the run from `:waiting` to `:active` if `due_at` has elapsed (recording a `reactivated_from_wait` transition).
  3. Locks the active-step delivery row with `FOR UPDATE`.
  4. Derives the curated workflow outcome via `ProgressionOutcome.from_delivery/2`.
  5. Tries `on_outcome` rules first; if any matches, advances through the canonical planner. Otherwise tries `wait_until`; if a converged outcome is present and a wait rule exists, enters `:waiting` with full anchor context.
  6. Returns `:noop, run, reason` for every other case (`:run_not_active`, `:no_active_step_delivery`, `:no_progress_rules`, `:no_matching_progress_rule`, `:prior_delivery_not_converged`, `:wait_not_due`, `:unknown_to_step`, `:wait_missing_due_at`, `:invalid_due_at`).
- **Due helper.** Added `Chimeway.Workflows.Progression.progress_due_runs/1` that lists `:waiting` runs whose persisted `due_at <= now` (compared against the `status_context["due_at"]` JSON value) and re-evaluates each through the same `progress_run/2` seam. This is the foundation Plan 25-03 will hook the due-step worker into.
- **Workflow helpers.** Extended `Chimeway.Workflows` with `lock_run/2`, `get_run!/1`, `get_current_step!/1`, `fetch_step_by_key/2`, `append_transition/2`, and `update_run/3` so the engine never reaches into Repo internals directly. All helpers accept the supplied `repo` argument (or use `Repo` for read-only paths) so they participate cleanly in the progression transaction.
- **Canonical planner extension.** `Chimeway.DeliveryPlanning.plan_next_step_delivery/3` exposes the existing `plan_one_channel/5` private path as a public single-channel entry, so progression-emitted next-step rows reuse `Deliveries.plan_delivery/3` and `resolve_workflow_linkage/3` with the now-active email step (D-10). No replacement rows; one canonical planning seam.
- **Convergence hook.** `Deliveries.record_attempt/2`, `suppress_delivery/3`, and `exhaust_delivery/1` invoke the progression seam exactly once after the durable row update commits. The call lives at the `Repo.transaction` boundary in `record_attempt/2` (NOT inside the inner Multi) so the engine takes its own row locks without nesting `SELECT FOR UPDATE`. The cancel path inside `record_attempt/2` (`cancel_with_reason/2`) intentionally does not invoke progression itself — the outer Multi-completion path is the single entry.
- **Integration tests.** Added 4 integration tests that prove the contract end-to-end:
  1. `wait_until + succeeded` ⇒ run becomes `:waiting` with `status_reason = "waiting_for_step_progression"`, full anchor/due context, and zero next-step deliveries.
  2. `on_outcome bounced` ⇒ run advances to `:active` on the email step, exactly one canonical email delivery is created, and the transition row records `workflow_outcome = "bounced"` plus raw evidence.
  3. Pending and unknown-cancellation prior deliveries return `:noop, :no_matching_progress_rule` and never emit an email delivery, even on repeat calls.
  4. After advancing, repeated progression entry returns `:noop, :no_progress_rules` and the email delivery count stays at 1.

## Task Commits

Each task was committed atomically (TDD RED → GREEN):

1. **Task 1 (RED):** `8f1efb7 test(25-02): add failing coverage for wait gates, outcome branching, and duplicate-safe progression`
   - 4 new tests, all failing on `UndefinedFunctionError` for `Chimeway.Workflows.Progression.progress_run/2`.
2. **Task 2 (GREEN):** `33b2a36 feat(25-02): wire durable workflow progression engine into canonical convergence`
   - 4 tests, 0 failures (GREEN gate).

_Note: No REFACTOR commit was needed — the engine landed clean with explicit reason atoms on every result branch, and the helpers in `Chimeway.Workflows` are minimal._

## Files Created/Modified

- `lib/chimeway/workflows/progression.ex` (created, 393 lines) — Engine with `progress_run/2`, `progress_due_runs/1`, the `wait_until` / `on_outcome` evaluation pipeline, due-wait reactivation, transactional `FOR UPDATE` locks, and explicit noop reasons.
- `lib/chimeway/workflows.ex` (modified) — Added `lock_run/2`, `get_run!/1`, `get_current_step!/1`, `fetch_step_by_key/2`, `append_transition/2`, and `update_run/3` helpers. None of them mutate behavior of the existing `upsert_definition`, `create_initial_run`, or `active_step_linkage` paths.
- `lib/chimeway/delivery_planning.ex` (modified) — Added `plan_next_step_delivery/3` as a public wrapper around `plan_one_channel/5`. Reuses `resolve_workflow_linkage/3` so the planner picks up the post-advance active-step linkage automatically.
- `lib/chimeway/deliveries.ex` (modified) — Added `maybe_apply_progression/1` and `maybe_progress_workflow/1` private helpers. Wired them into `record_attempt/2` (post-Multi), `suppress_delivery/3`, and `exhaust_delivery/1`. The `cancel_with_reason/2` private helper inside `record_attempt/2`'s Multi intentionally does not call progression itself — the outer Multi-completion path is the single entry.
- `test/chimeway/orchestration/workflow_progression_test.exs` (created, 389 lines) — Notifier fixture (`in_app -> email`, both wait and outcome rules on the first step), test-local `PlanOnly` dispatcher so deliveries stay pending and the test owns convergence, four integration tests covering wait gates, outcome branching, and duplicate-safe noops.

## Decisions Made

- **`on_outcome` beats `wait_until`.** When the prior delivery is converged with a curated outcome that matches an `on_outcome` rule, the engine advances immediately even if a `wait_until` rule is also declared on the same step. This matches the natural reading of "if X bounced, escalate immediately; otherwise wait 30 minutes and escalate".
- **Anchor on `delivery.updated_at`.** Chimeway already serializes terminal writes through helpers that touch `updated_at` (`record_attempt/2`, `suppress_delivery/3`, `exhaust_delivery/1`, `cancel_with_reason/2`). Using `updated_at` as the anchor keeps Phase 25 self-contained without a new schema migration. If Phase 26 needs sub-microsecond terminal-time precision separate from the row's last write, it can introduce a `terminal_at` column then.
- **Convergence hook at the `Repo.transaction` boundary.** `record_attempt/2` invokes progression in the outer success branch — *not* inside the inner Multi — so the engine's `FOR UPDATE` locks do not nest inside the attempt-recording lock and concurrent record_attempt calls do not block each other on workflow rows that another caller is evaluating.
- **Explicit noop reason on every branch.** Every `{:noop, run, reason}` carries one of nine atom reasons (`:run_not_active`, `:no_active_step_delivery`, `:no_progress_rules`, `:no_matching_progress_rule`, `:prior_delivery_not_converged`, `:wait_not_due`, `:unknown_to_step`, `:wait_missing_due_at`, `:invalid_due_at`). Operators get a precise explanation without having to inspect the row again.
- **Activated-on-advance transition.** Advancing also appends a `step_activated` transition for the new step (with `source: "progression"`) so traces show one append-only history of `step_activated` rows whether the activation came from `Workflows.create_initial_run/4` or from progression advancing the cursor.

## Deviations from Plan

None — plan executed exactly as written.

The acceptance criteria literal substring checks all pass:

- Test file contains `"prior_delivery_terminal_at"`, `"workflow_outcome"`, `"anchor_delivery_id"`, and `:waiting`.
- `progression.ex` contains `def progress_run`, `def progress_due_runs`, `FOR UPDATE`, `waiting_for_step_progression`, `progressed_on_delivery_outcome`, `anchor_delivery_id`, and `due_at`.
- `workflows.ex` contains `append_transition`.
- `deliveries.ex` contains `Chimeway.Workflows.Progression`.
- `mix test test/chimeway/orchestration/workflow_progression_test.exs --trace` exits 0 with 4 tests, 0 failures.

The minimum file-line targets in the plan's `must_haves.artifacts` are all met (progression 393 ≥ 140, workflows 327 ≥ 60, test 389 ≥ 120).

## Issues Encountered

- **Pre-existing test failure (out of scope):** `test/chimeway/deliveries_test.exs:646` (`record_attempt/2 rolls back attempt insert if status transition fails`) fails on the worktree's base commit `489750e` and continues to fail after Plan 25-02 changes. Verified by stashing the worktree's working changes and re-running the test against base. Logged in `.planning/phases/25-progression-engine-wait-gates/deferred-items.md`. The defect is in `Deliveries.record_attempt/2` Multi rollback semantics, not in any file owned by Plan 25-02.

## Threat Flags

None. The trust boundaries and STRIDE register from the plan (`T-25-04` tampering, `T-25-05` repudiation, `T-25-06` duplicate emission) all carry `mitigate` dispositions and are implemented exactly as specified:

- **T-25-04 (tampering):** Workflow runs and active-step deliveries are locked with `FOR UPDATE` inside one transaction; outcomes are derived only from `ProgressionOutcome.from_delivery/2` reading persisted rows; the engine never branches on queue or in-flight job state.
- **T-25-05 (repudiation):** Every transition appended by the engine carries an explicit `reason` (`waiting_for_step_progression`, `progressed_on_delivery_outcome`, `step_activated`, `reactivated_from_wait`) and a `context` map containing the curated workflow outcome plus the raw evidence facts (`delivery_status`, `suppression_reason`, `attempt_outcome`, `attempt_error_class`) that produced the decision.
- **T-25-06 (DoS / duplicate emission):** The engine returns `:noop, run, reason` for non-workflow-linked rows, non-active runs, non-converged deliveries, unknown-bucket cancellations, missing rules, unmatched rules, missing/invalid `due_at`, and waits that have not yet elapsed. Repeated calls after `:advanced` see the new active step's empty `progress` config and return `:noop, :no_progress_rules`.

## Known Stubs

None. The engine emits real next-step deliveries, real transition rows, and real workflow-run state changes; no placeholder values, empty arrays, or mock data flow into UI or trace surfaces.

## TDD Gate Compliance

- **RED gate satisfied:** `8f1efb7 test(25-02): ...` — all 4 progression tests failed with `UndefinedFunctionError` for `Chimeway.Workflows.Progression.progress_run/2` before implementation.
- **GREEN gate satisfied:** `33b2a36 feat(25-02): ...` — `mix test test/chimeway/orchestration/workflow_progression_test.exs --trace` runs 4 tests with 0 failures after implementation.
- No REFACTOR commit was necessary; implementation landed clean and small.

## Next Phase Readiness

- **Plan 25-03 (wait gates / due-step worker)** can call `Chimeway.Workflows.Progression.progress_due_runs/1` directly. The function already lists due `:waiting` runs and re-evaluates each through `progress_run/2`, including reactivation. The Oban worker only needs to schedule itself periodically and pass `now: DateTime.utc_now()`.
- **Phase 26 (stop conditions / escalation)** can extend the progress rule vocabulary by adding new normalizers in `Notifier` (matching the Plan 25-01 contract pattern) and new clauses in the engine's `evaluate_step/5` rule-matcher. The convergence hook does not need to change.
- **Traces** already see the new transition rows because the engine writes through `Workflows.append_transition/2`, which uses the same `WorkflowTransition.changeset/2` validation as `create_initial_run/4`.

---

## Self-Check: PASSED

Verified before returning:

- `[ -f lib/chimeway/workflows/progression.ex ]` → FOUND
- `[ -f test/chimeway/orchestration/workflow_progression_test.exs ]` → FOUND
- `git log --oneline --all | grep 8f1efb7` → FOUND `8f1efb7 test(25-02): add failing coverage for wait gates, outcome branching, and duplicate-safe progression`
- `git log --oneline --all | grep 33b2a36` → FOUND `33b2a36 feat(25-02): wire durable workflow progression engine into canonical convergence`
- `mix test test/chimeway/orchestration/workflow_progression_test.exs --trace` → 4 tests, 0 failures
- Full suite: `mix test` → 392 tests, 1 pre-existing failure (`test/chimeway/deliveries_test.exs:646`, fails on base commit `489750e`, logged in `deferred-items.md`)

---

*Phase: 25-progression-engine-wait-gates*
*Plan: 02*
*Completed: 2026-04-29*
