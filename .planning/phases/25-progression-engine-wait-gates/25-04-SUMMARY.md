---
phase: 25-progression-engine-wait-gates
plan: "04"
subsystem: workflows
tags: [elixir, ecto, workflow, progression, wait_until, tdd]

requires:
  - phase: 25-progression-engine-wait-gates/25-03
    provides: "WorkflowProgressionWorker and due-step engine seam"
  - phase: 25-progression-engine-wait-gates/25-02
    provides: "advance_run/8 canonical post-cursor path and status_context schema"

provides:
  - "advance_after_wait/5 in progression.ex: direct wait_until advancement seam using persisted to_step"
  - "CR-01 blocker closed: wait_until elapsed-time advancement path now wires through canonical seam"
  - "Regression test: describe wait_until rule advancement after due_at elapses (CR-01 regression)"

affects:
  - 25-progression-engine-wait-gates
  - 26-workflow-journeys (if planned)

tech-stack:
  added: []
  patterns:
    - "advance_after_wait/5: reloads anchor delivery, appends reactivated_from_wait once, advances cursor to persisted to_step via update_run + step_activated + plan_next_step_delivery"
    - "maybe_reactivate_due/3: pattern-match on full status_context (to_step + anchor_delivery_id required) before advancing; backward-compat clause for incomplete contexts"
    - "progress_run/2: with/case short-circuit pattern handles {:advanced, ...} return from maybe_reactivate_due without falling through to do_progress_active_run"

key-files:
  created: []
  modified:
    - lib/chimeway/workflows/progression.ex
    - test/chimeway/orchestration/workflow_progression_test.exs

key-decisions:
  - "Use persisted to_step from status_context directly instead of re-evaluating progress rules on reactivation — avoids the wait_until -> enter_waiting loop"
  - "advance_after_wait/5 reads run.workflow_definition_id (locked row) not notification.workflow_definition_id per WR-03 to stay inside the FOR UPDATE discipline"
  - "Backward-compat clause: contexts missing to_step/anchor_delivery_id return :wait_context_incomplete noop instead of crashing on function-clause error for legacy waiting runs"
  - "Remove reactivate_run/3 entirely (dead code after fix) rather than leaving it dormant"
  - "TDD discipline: RED commit (fbdabc6) before GREEN commit (11455b2)"

patterns-established:
  - "Wait advancement seam: advance_after_wait/5 appends reactivated_from_wait, updates cursor to persisted to_step, appends step_activated, emits next-step delivery"
  - "progress_run/2 handles {:ok, {:advanced, ...}} from maybe_reactivate_due by short-circuiting do_progress_active_run"

requirements-completed:
  - WRK-02

duration: 25min
completed: 2026-04-29
---

# Phase 25 Plan 04: CR-01 wait_until Elapsed-Time Advancement Summary

**`advance_after_wait/5` wires wait_until elapsed-time advancement through the canonical cursor-update + step_activated + plan_next_step_delivery seam, closing the CR-01 infinite-loop blocker and satisfying WRK-02's elapsed-time branch**

## Performance

- **Duration:** 25 min
- **Started:** 2026-04-29T20:21:00Z
- **Completed:** 2026-04-29T20:46:00Z
- **Tasks:** 2 (TDD: 1 RED + 1 GREEN)
- **Files modified:** 2

## Accomplishments

- Fixed CR-01 BLOCKER: wait_until rules now advance after due_at elapses instead of looping forever (reactivate -> re-evaluate -> re-enter wait -> repeat)
- Implemented `advance_after_wait/5` that appends exactly one `reactivated_from_wait` transition and exactly one `step_activated` transition per advancement, then emits one canonical next-step delivery
- Added regression test that drives `progress_run/2` past `due_at` twice and asserts: advancement to persisted `to_step`, exactly one email delivery, noop on re-entry, exact transition counts
- All 37 Phase 25 tests pass with 0 regressions

## Task Commits

Each task was committed atomically (TDD order):

1. **Task 1: RED regression test for CR-01** - `fbdabc6` (test)
2. **Task 2: advance_after_wait/5 implementation** - `11455b2` (feat)

**Plan metadata:** (committed with SUMMARY)

_Note: TDD tasks have separate RED (test) and GREEN (implementation) commits per plan spec_

## Files Created/Modified

- `lib/chimeway/workflows/progression.ex` - Replaced `maybe_reactivate_due/3` (loop site) + added `advance_after_wait/5`, `fetch_anchor_delivery/2`, `current_step_key/1`; removed dead `reactivate_run/3`; updated `progress_run/2` with/case to short-circuit on `{:advanced, ...}`
- `test/chimeway/orchestration/workflow_progression_test.exs` - Added `describe "wait_until rule advancement after due_at elapses (CR-01 regression)"` block with comprehensive regression test

## Decisions Made

- Used persisted `to_step` from `status_context` for advancement instead of re-evaluating progress rules — this is the correct fix because re-evaluation was the root cause of the loop
- Used `run.workflow_definition_id` (locked row) rather than `notification.workflow_definition_id` per WR-03 guidance: the locked run row is the authoritative source inside the `FOR UPDATE` discipline
- Added backward-compat clause: `status_context` with `due_at` present but `to_step`/`anchor_delivery_id` absent returns `:wait_context_incomplete` noop instead of a function-clause crash — defensive handling for any legacy persisted wait context
- Removed `reactivate_run/3` entirely (no longer reachable) rather than leaving dead code

## Deviations from Plan

None - plan executed exactly as written. The implementation follows the plan's fix sketch (Step A through Step E) precisely.

## Issues Encountered

- Worktree did not have `deps/` or `_build/` symlinked to the main project. Created symlinks (`deps` and `_build`) from the main project into the worktree to enable `mix test` to compile and run from the worktree directory. This is a standard git worktree setup issue and not a code problem.

## Known Stubs

None — `advance_after_wait/5` is fully wired: it reads `to_step` from `status_context`, loads the anchor delivery from the database, and emits the canonical next-step delivery through `DeliveryPlanning.plan_next_step_delivery/3`. No hardcoded values or placeholder paths remain.

## Next Phase Readiness

- CR-01 is closed: `wait_until` rules now advance after elapsed time
- WRK-02 elapsed-time branch is functionally satisfied
- Phase 25 VERIFICATION gap #1 (BLOCKER) is resolved
- Regression test in `workflow_progression_test.exs` gates future regressions
- Plans 25-05 (WR-01 race test documentation) and 25-06 (WR-02 temporary_failure contract) address the remaining PARTIAL gaps from VERIFICATION

---
*Phase: 25-progression-engine-wait-gates*
*Completed: 2026-04-29*
