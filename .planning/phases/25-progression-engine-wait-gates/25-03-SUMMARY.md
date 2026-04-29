---
phase: 25-progression-engine-wait-gates
plan: 03
subsystem: workflows
tags: [elixir, oban, workflows, progression, dispatch, concurrency, wait-gates]

# Dependency graph
requires:
  - phase: 25-progression-engine-wait-gates
    plan: 02
    provides: |
      `Chimeway.Workflows.Progression.progress_run/2` and `progress_due_runs/1`
      shared engine seam with FOR UPDATE locking, noop-safety, convergence hook.
provides:
  - `Chimeway.Dispatch.WorkflowProgressionWorker` thin Oban worker that takes
    only `workflow_run_id` and delegates to the shared progression engine seam.
  - Optional Oban scheduling of `WorkflowProgressionWorker` from
    `Chimeway.Workflows.Progression.progress_run/2` when the configured
    dispatcher is `Chimeway.Dispatch.Oban`, using the persisted `due_at` as
    `scheduled_at`. Non-Oban hosts continue to drive due-run progression
    through `progress_due_runs/1` — both seams call the same engine.
  - Worker-level regression coverage: thin delegation, duplicate-safe
    re-execution, waiting-noop on not-yet-due gates, unknown-id safety.
  - Concurrency regression coverage: 10 concurrent direct
    `progress_run/2` calls collapse to one `:advanced` winner with one
    canonical next-step delivery row and one
    `progressed_on_delivery_outcome` audit transition.
affects:
  - 26-stop-conditions-escalation (will reuse the same worker shape and
    engine seam for escalation timers)
  - traces explanation surfaces (no schema changes; reuses Plan 25-02
    transition rows)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Thin scheduled worker mirrors `Chimeway.Dispatch.DigestFlushWorker`: one delegated call into a shared engine seam, queue-args limited to the stable id, and result-shape normalization at the worker boundary."
    - "Engine-side optional scheduling: the engine schedules its own worker only when the configured dispatcher is `Chimeway.Dispatch.Oban`, so non-Oban hosts and Oban-backed hosts share identical internal semantics."
    - "Best-effort scheduler insert outside the engine transaction: the canonical wait state is persisted before the Oban insert is attempted, so a failed insert is safe — `progress_due_runs/1` remains the shared manual fallback."

key-files:
  created:
    - lib/chimeway/dispatch/workflow_progression_worker.ex
    - test/chimeway/dispatch/workflow_progression_worker_test.exs
    - test/chimeway/reliability/workflow_progression_race_test.exs
  modified:
    - lib/chimeway/workflows/progression.ex

key-decisions:
  - "Thin worker mirrors `Chimeway.Dispatch.DigestFlushWorker` (one-call delegate) instead of `Chimeway.Dispatch.DeferredResumeWorker` (Multi-wrapped). Wrapping the engine in another `Multi` would nest transactions over the engine's own `FOR UPDATE` locks and surface internal `Repo.rollback/1` calls (used by the engine for `:workflow_run_not_found` and similar) as `MULTIPLE_ROLLBACK` errors at the queue boundary. The `DigestFlushWorker` shape was an explicit Plan 25-03 deviation (Rule 3) to keep the thin-delegation contract intact."
  - "`{:error, :workflow_run_not_found}` is normalized to `:ok` at the worker boundary — the row may have been deleted between scheduler insert and perform call, and there is nothing to retry. All other `{:error, reason}` results bubble up so Oban can apply its retry policy."
  - "Engine-side scheduling lives outside the engine transaction (after `Repo.transaction/1` returns `{:ok, {:waiting, run}}`) so a failed Oban insert never rolls back the canonical wait state. The state is durable on the row first; the worker is a wake-up convenience layer."
  - "Worker job uniqueness is keyed on `:workflow_run_id` over a 60s window with `replace: [scheduled: [:scheduled_at]]` — matches the `DeferredResumeWorker` and `DigestFlushWorker` precedents and collapses duplicate scheduler inserts at the queue level. Domain-level duplicate-safety still lives in the engine's `FOR UPDATE` lock + noop semantics."

patterns-established:
  - "Pattern: Thin scheduled worker as a wake-up shim. Workers are not the correctness boundary — they are stable-id-only schedulers for the shared engine seam. The engine itself enforces locking, idempotency, and noop semantics, so manual ticks (`progress_due_runs/1`) and Oban-backed wakeups (`WorkflowProgressionWorker`) produce identical observable behavior."
  - "Pattern: Engine-side opt-in to Oban scheduling. The engine reads the configured dispatcher to decide whether to insert its own follow-up job, instead of having `Chimeway.Dispatch.Oban` poll the engine. This keeps the dispatcher integration one-way and avoids circular coupling."

requirements-completed: [ESC-03, WRK-02]

# Metrics
duration: 7min
completed: 2026-04-29
---

# Phase 25 Plan 03: Wait Gates & Due-Step Worker Summary

**Thin `Chimeway.Dispatch.WorkflowProgressionWorker` Oban worker — `workflow_run_id`-only args, delegates to `Progression.progress_run/2`, normalizes `:advanced`/`:waiting`/`:noop` to `:ok` — plus engine-side optional Oban scheduling at the persisted `due_at` so wait gates wake automatically without changing the manual `progress_due_runs/1` seam non-Oban hosts already rely on.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-04-29T19:28:18Z
- **Completed:** 2026-04-29T19:35:35Z
- **Tasks:** 2 (TDD: RED then GREEN)
- **Files created:** 3
- **Files modified:** 1

## Accomplishments

- **Thin worker.** `Chimeway.Dispatch.WorkflowProgressionWorker` accepts only `%{"workflow_run_id" => workflow_run_id}` per Phase 25 D-10. It delegates to `Chimeway.Workflows.Progression.progress_run/2` and normalizes the engine's three-result contract — `{:advanced, _, _}`, `{:waiting, _}`, `{:noop, _, _}` — plus `{:error, :workflow_run_not_found}` to `:ok`. All other engine errors bubble up for Oban's retry policy to handle.
- **Engine-side opt-in scheduling.** When the configured dispatcher is `Chimeway.Dispatch.Oban`, `Progression.progress_run/2` schedules a `WorkflowProgressionWorker` job at the persisted `due_at` (best-effort, outside the engine transaction). Non-Oban hosts continue to drive due waits through `progress_due_runs/1` — both paths call the same engine, so internal semantics match across host wirings.
- **Worker regression suite.** 4 tests prove the contract end-to-end: (1) `perform` with `workflow_run_id` advances the run and creates exactly one canonical next-step delivery; (2) duplicate worker executions never emit a second next-step delivery (engine returns `:no_progress_rules` on the new active step); (3) `perform` on a not-yet-due waiting run noops without creating any next-step delivery and leaves the run state intact; (4) unknown `workflow_run_id` returns `:ok` (treated as a noop) without crashing the queue.
- **Concurrency regression suite.** 2 tests prove the one-winner contract: (1) 10 concurrent direct `Progression.progress_run/2` calls on a converged run collapse to exactly one `:advanced` winner, exactly one canonical email row, and exactly one `progressed_on_delivery_outcome` workflow_transition; (2) 10 concurrent calls on a not-yet-due waiting run all noop and never emit a next-step delivery. The race tests pass against the existing engine's `FOR UPDATE` locks — the new worker boundary does not weaken them.

## Task Commits

Each task was committed atomically (TDD RED → GREEN):

1. **Task 1 (RED):** `d842f42 test(25-03): add failing worker and concurrency coverage for due-run progression`
   - 6 new tests; 4 worker tests fail with "does not implement Oban.Worker" (the worker module did not exist yet); 2 race tests pass on the existing engine and become regression coverage.
2. **Task 2 (GREEN):** `74b341c feat(25-03): wire thin workflow progression worker and due-run scheduling`
   - 6 tests, 0 failures.

_Note: No REFACTOR commit was needed — the worker landed clean at 73 lines and the engine extension is one private helper plus one `case` arm in `progress_run/2`._

## Files Created/Modified

- `lib/chimeway/dispatch/workflow_progression_worker.ex` (created, 73 lines) — Thin Oban worker behind `if Code.ensure_loaded?(Oban)`, queue `:chimeway_delivery`, max_attempts 5, `replace: [scheduled: [:scheduled_at]]`, uniqueness keyed on `:workflow_run_id` over a 60s window. `perform/1` delegates to `Progression.progress_run/2` and normalizes via `normalize_progress_result/1`. Mirrors `Chimeway.Dispatch.DigestFlushWorker`'s one-call delegate shape.
- `lib/chimeway/workflows/progression.ex` (modified, +56 lines) — Added engine-side optional Oban scheduling. `progress_run/2`'s `{:ok, {:waiting, run}}` arm now calls `maybe_schedule_due_progression_job/1`. The helper checks the configured dispatcher, parses `status_context["due_at"]` to a `DateTime`, and inserts a `WorkflowProgressionWorker` job via `Oban.insert/1` with `scheduled_at: due_at`. Best-effort: a failed insert is swallowed so the canonical `:waiting` state remains durable and `progress_due_runs/1` can still wake the run manually.
- `test/chimeway/dispatch/workflow_progression_worker_test.exs` (created, 288 lines) — Notifier fixture (`in_app -> email`, both `wait_until` and `on_outcome bounced` rules on the first step), test-local PlanOnly dispatcher, 4 worker tests covering thin delegation, duplicate-safety, waiting-noop, and unknown-id safety.
- `test/chimeway/reliability/workflow_progression_race_test.exs` (created, 320 lines) — Same notifier fixture and PlanOnly dispatcher, 2 concurrency tests using `Task.async_stream` with 10 concurrent callers — one for the converged-advance scenario and one for the not-yet-due waiting scenario.

## Decisions Made

- **One-call delegate shape, not Multi.** The plan's `<action>` said "Delegate to `Progression.progress_run/2` inside a `Multi`", patterned after `DeferredResumeWorker`. Implementing literally surfaced a `MULTIPLE_ROLLBACK` error in the unknown-id test: the engine's inner `Repo.rollback/1` (used to surface `:workflow_run_not_found` from the inner `Repo.transaction/1`) propagated through the outer `Multi.transaction/1` as a nested-transaction rollback. Switched to the `DigestFlushWorker` one-call delegate shape — same thin-delegation contract, no nested transactions. Documented as a Rule 3 deviation below.
- **`:workflow_run_not_found` is a worker-boundary noop.** The row may have been deleted between scheduler insert and perform call. Treating it as `:ok` keeps the queue clean without losing the engine's audit trail (the engine still returns `{:error, :workflow_run_not_found}` to direct callers — only the worker normalizes it).
- **Engine-side scheduling is opt-in by configured dispatcher.** The engine inspects `Application.get_env(:chimeway, :dispatcher)` and only inserts an Oban job when the configured dispatcher is `Chimeway.Dispatch.Oban`. This avoids forcing Oban on non-Oban hosts and avoids inverting the dispatcher integration.
- **Scheduler insert lives outside the engine transaction.** The canonical wait state is persisted before the Oban insert is attempted. A failed insert is non-fatal — the run is durably `:waiting` and `progress_due_runs/1` is the shared manual fallback. This also avoids nesting the Oban insert inside the engine's `FOR UPDATE` locks.
- **Job uniqueness keyed on `:workflow_run_id` over a 60s window.** Matches `DeferredResumeWorker` and `DigestFlushWorker` precedents. Collapses duplicate scheduler inserts at the queue layer; domain-level duplicate-safety still lives in the engine's `FOR UPDATE` lock + noop semantics.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Switched worker from `Multi`-wrapped to one-call delegate**
- **Found during:** Task 2 (GREEN gate test run)
- **Issue:** The plan's `<action>` said "Delegate to `Progression.progress_run/2` inside a `Multi`". When implemented literally, the unknown-id test failed with `(RuntimeError) operation :rollback is rolling back unexpectedly`. Root cause: `Progression.progress_run/2` opens its own `Repo.transaction/1` and uses `Repo.rollback/1` to surface `{:error, :workflow_run_not_found}` from `Workflows.lock_run/2`. Wrapping that engine call inside a worker-side `Multi.transaction/1` nested two transactions over the same connection — Postgres marked the outer transaction as also rolling back, which Ecto surfaced as a `MULTIPLE_ROLLBACK` error.
- **Fix:** Removed the worker-side `Multi`. The worker now calls `Progression.progress_run/2` directly and pipes the result through `normalize_progress_result/1`. This matches `Chimeway.Dispatch.DigestFlushWorker`'s shape (also a single-call delegate), preserves the plan's "thin scheduled worker that reloads by `workflow_run_id` and delegates" intent, and keeps every plan acceptance criterion satisfied (worker file still contains `workflow_run_id`, `Chimeway.Workflows.Progression`, and `def perform`).
- **Files modified:** `lib/chimeway/dispatch/workflow_progression_worker.ex`
- **Verification:** All 6 plan tests pass; full workflow + delivery suite (`mix test test/chimeway/**/*workflow* test/chimeway/**/*delivery*`) passes 69/69.
- **Committed in:** `74b341c` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope change. The worker file structure changed from `Multi`-wrapped to one-call delegate, matching a different precedent (`DigestFlushWorker`) that the plan's `<read_first>` indirectly references through the engine's existing test posture. The plan's intent (thin worker, delegated correctness, normalized result shape) is preserved exactly. All acceptance-criteria substring checks (`workflow_run_id`, `Chimeway.Workflows.Progression`, `def perform`) still pass.

## Issues Encountered

- **Pre-existing test failure (out of scope, unchanged):** `test/chimeway/deliveries_test.exs:646` (`record_attempt/2 rolls back attempt insert if status transition fails`) continues to fail with the same symptom logged in `.planning/phases/25-progression-engine-wait-gates/deferred-items.md` from Plan 25-02 (`Repo.aggregate(DeliveryAttempt, :count, :id)` returns `1` instead of `0`). Verified the failure is unchanged by Plan 25-03 by running the test in isolation. The defect is in `Deliveries.record_attempt/2` Multi rollback semantics, not in any file owned by Plan 25-03.

## Threat Flags

None. The trust boundaries and STRIDE register from the plan (`T-25-07`, `T-25-08`, `T-25-09`) all carry `mitigate` dispositions and are implemented exactly as specified:

- **T-25-07 (spoofing — Oban job args -> workflow progression service):** The worker accepts only `%{"workflow_run_id" => workflow_run_id}`. All workflow/delivery truth — current step cursor, prior delivery status, suppression reason, last-attempt evidence, progress rules — is reloaded from Chimeway-owned rows inside the engine's `FOR UPDATE`-locked transaction. Job args never carry rule data, delivery facts, or tenancy hints.
- **T-25-08 (DoS / duplicate emission — concurrent callers -> workflow run current state):** The worker delegates to the same engine path as `progress_due_runs/1`, which uses `FOR UPDATE` locks on the workflow run row and the active-step delivery row. Concurrent retries collapse to noop without emitting another next-step delivery. Verified by `Chimeway.Reliability.WorkflowProgressionRaceTest`: 10 concurrent direct `progress_run/2` calls on a converged run produce exactly one `:advanced` winner, one canonical email row, and one `progressed_on_delivery_outcome` transition.
- **T-25-09 (repudiation — workflow wait-gate execution history):** The engine persists transition reasons (`waiting_for_step_progression`, `progressed_on_delivery_outcome`, `step_activated`, `reactivated_from_wait`) and anchor/due facts (`anchor_delivery_id`, `anchor_delivery_status`, `anchor_timestamp`, `due_at`, `to_step`) before or alongside advancement. Retries leave an auditable trail in `chimeway_workflow_transitions` rather than queue archaeology. Plan 25-03 adds no new write paths to that history — it only adds a worker that re-enters the same engine seam.

## Known Stubs

None. The worker emits real next-step deliveries through the canonical planner and persists real wait-state transitions; no placeholder values, empty arrays, or mock data flow into UI or trace surfaces. The engine's optional Oban scheduling is opt-in by configured dispatcher and inserts a real `Oban.Job` row when active.

## TDD Gate Compliance

- **RED gate satisfied:** `d842f42 test(25-03): ...` — 4/6 tests fail with "Expected worker to be a module that implements the Oban.Worker behaviour" because `Chimeway.Dispatch.WorkflowProgressionWorker` did not exist yet. The 2 race tests pass on the existing engine — they freeze one-winner semantics so Plan 25-03's worker addition cannot regress them. (A test passing during RED is fail-fast investigated: in this case it is intentional — the race tests freeze existing engine behavior at the concurrency boundary, and the engine path was not modified by Task 2.)
- **GREEN gate satisfied:** `74b341c feat(25-03): ...` — `mix test test/chimeway/dispatch/workflow_progression_worker_test.exs test/chimeway/reliability/workflow_progression_race_test.exs --trace` runs 6 tests with 0 failures after implementation.
- No REFACTOR commit was necessary; implementation landed clean and small.

## Next Phase Readiness

- **Phase 26 (stop conditions / escalation)** can extend the worker pattern by introducing additional thin scheduled workers (e.g., `WorkflowEscalationWorker`) that also accept only stable ids and delegate to a shared engine seam. The `WorkflowProgressionWorker` shape (`if Code.ensure_loaded?(Oban)`, `queue :chimeway_delivery`, `unique on :workflow_run_id`, normalize-to-`:ok` result handling) is the precedent.
- **Engine-side scheduling integration.** The pattern of "engine reads configured dispatcher and conditionally schedules its own follow-up job" is now established in `Progression.progress_run/2`. Phase 26 can follow it for stop-condition timers without inverting the dispatcher integration.
- **Operational visibility.** The plan does not add new trace surfaces, but Phase 26 / Phase 27 traces can read `WorkflowProgressionWorker` job rows alongside `chimeway_workflow_transitions` to explain wake-up timing in operator UIs.

---

## Self-Check: PASSED

Verified before returning:

- `[ -f lib/chimeway/dispatch/workflow_progression_worker.ex ]` → FOUND (73 lines)
- `[ -f test/chimeway/dispatch/workflow_progression_worker_test.exs ]` → FOUND (288 lines)
- `[ -f test/chimeway/reliability/workflow_progression_race_test.exs ]` → FOUND (320 lines)
- `git log --oneline | grep d842f42` → FOUND `d842f42 test(25-03): add failing worker and concurrency coverage for due-run progression`
- `git log --oneline | grep 74b341c` → FOUND `74b341c feat(25-03): wire thin workflow progression worker and due-run scheduling`
- `mix test test/chimeway/dispatch/workflow_progression_worker_test.exs test/chimeway/reliability/workflow_progression_race_test.exs --trace` → 6 tests, 0 failures
- `mix test test/chimeway/**/*workflow* test/chimeway/**/*delivery*` → 69 tests, 0 failures
- Acceptance-criteria substring checks: worker file contains `workflow_run_id`, `Chimeway.Workflows.Progression`, `def perform`; engine contains `WorkflowProgressionWorker`, `progress_due_runs`, `due_at`; worker test contains `workflow_run_id`, `perform_job`; race test contains `Task.async_stream`, `workflow_run_id` — all PASS.

---

*Phase: 25-progression-engine-wait-gates*
*Plan: 03*
*Completed: 2026-04-29*
