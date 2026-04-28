---
phase: 22-recovery-outcome-analytics
plan: 04
subsystem: testing
tags: [elixir, ecto, recovery, dispatch, rendering, regression]
requires:
  - phase: 22-02
    provides: recovery APIs and dispatcher-backed re-drive flows
  - phase: 22-03
    provides: outcome analytics and validation context for the full-suite gate
provides:
  - recovery-only persisted-channel planning fallback
  - retryable recovery claim compensation after dispatcher handoff failure
  - regression coverage for ordinary notifier-less planning versus recovery fanout
affects: [delivery_planning, deliveries, recovery, dispatch]
tech-stack:
  added: []
  patterns: [recovery-only planner opts, guarded recovery-claim compensation]
key-files:
  created: [.planning/phases/22-recovery-outcome-analytics/22-04-SUMMARY.md]
  modified: [lib/chimeway/delivery_planning.ex, lib/chimeway/deliveries.ex, test/chimeway/orchestration/delivery_planning_test.exs, test/chimeway/orchestration/recovery_test.exs]
key-decisions:
  - "Persisted render_channels remain available only when recovery explicitly opts into them; ordinary notifier-less planning falls back to a single in_app path."
  - "Failed recovery dispatch handoffs must clear recovery metadata and restore recoverable age so operators can retry immediately."
patterns-established:
  - "Recovery-only capability toggles should be explicit opts rather than inferred from missing notifier callbacks."
  - "Recovery compensation should mutate the canonical row in place with guarded update_all queries and no replacement rows."
requirements-completed: [OPS-01]
duration: 3 min
completed: 2026-04-28
---

# Phase 22 Plan 04: Recovery Contract Closure Summary

**Recovery re-drive now uses persisted channels only when explicitly requested, and failed dispatcher handoffs leave canonical rows immediately recoverable.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-28T22:42:18Z
- **Completed:** 2026-04-28T22:45:51Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Restored the ordinary notifier-less planning contract to a single default `in_app` path instead of widening fanout across persisted `render_channels`.
- Routed `recover_event/2` through an explicit `use_persisted_channels: true` opt so recovery re-drive still fans out across persisted channel declarations.
- Compensated failed `recover_delivery/2` handoffs by clearing recovery claim metadata and restoring immediate recoverability on the canonical row.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add regression tests for recovery-only persisted-channel fanout and retryable recovery failures** - `ad694f1` (`test`)
2. **Task 2: Restrict persisted-channel fallback to recovery and compensate failed recovery claims** - `9fbf089` (`fix`)

## Files Created/Modified
- `lib/chimeway/delivery_planning.ex` - gates persisted-channel fallback and persisted render validation behind an explicit recovery opt
- `lib/chimeway/deliveries.ex` - forwards the recovery-only opt during event re-drive and compensates failed delivery recovery claims
- `test/chimeway/orchestration/delivery_planning_test.exs` - locks ordinary notifier-less planning to the default single-channel contract
- `test/chimeway/orchestration/recovery_test.exs` - locks recovery-only fanout and retryable dispatcher failure behavior

## Decisions Made
- Used `use_persisted_channels: true` as the explicit recovery-only switch so ordinary planner callers do not inherit broadened fanout semantics accidentally.
- Restored failed recovery rows to the recoverable cutoff timestamp during compensation so operators can retry immediately instead of waiting for row age to elapse again.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Normalized the targeted verification command for the local Mix version**
- **Found during:** Task 1 (Add regression tests for recovery-only persisted-channel fanout and retryable recovery failures)
- **Issue:** The plan-specified `mix test ... -x` command is not supported by this repository's Mix test task and exits before running any tests.
- **Fix:** Ran the equivalent targeted `mix test` command without `-x` for RED/GREEN verification and kept the full-suite `mix test` gate unchanged.
- **Files modified:** None
- **Verification:** `mix test test/chimeway/orchestration/delivery_planning_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/dispatch/sync_test.exs`; `mix test`
- **Committed in:** None (execution-only deviation)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep. The deviation only normalized an unsupported verification flag so the planned tests could run on this environment.

## Issues Encountered
- `git commit` briefly failed on a transient `.git/index.lock`; the lock was gone on recheck and the commit succeeded on retry.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plan `22-04` closes the remaining Phase 22 recovery correctness gaps and leaves the full test suite green.
- Ready for phase-level verification or whatever follows the final Phase 22 plan.

## Verification

- `mix test test/chimeway/orchestration/delivery_planning_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/dispatch/sync_test.exs` -> PASS
- `mix test` -> PASS (`355 tests, 0 failures`)

## Self-Check: PASSED

- Verified summary file exists on disk.
- Verified task commits `ad694f1` and `9fbf089` exist in git history.
