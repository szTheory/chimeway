---
phase: 07-delayed-fallback-runtime-wiring
plan: "07-03"
subsystem: testing
tags: [delayed-fallback, policy, dispatch, verification]
requires:
  - phase: 07-delayed-fallback-runtime-wiring
    provides: runtime delayed-fallback wiring and suppression parity from 07-01/07-02
provides:
  - Trigger-driven proof that planner-persisted delayed-fallback intent survives normal dispatch flow.
  - Sync/Oban suppression signature parity assertions for already-read delayed-fallback outcomes.
  - Guardrail regression coverage for invalid delayed-fallback channel declarations.
affects: [POLC-03, phase-07-closeout, dispatch-parity, planner-guardrails]
tech-stack:
  added: []
  patterns:
    - shared suppression signature helper for parity assertions
    - trigger-first delayed-fallback persistence verification
    - planner error contract assertions for invalid delayed-fallback declarations
key-files:
  created: []
  modified:
    - test/chimeway/integration/delivery_lifecycle_test.exs
    - test/chimeway/dispatch/sync_test.exs
    - test/chimeway/dispatch/oban_test.exs
    - test/chimeway/dispatch/oban_worker_test.exs
    - test/chimeway/policy/delayed_fallback_test.exs
    - test/support/chimeway/dispatch_helpers.ex
key-decisions:
  - "Use trigger-driven integration scenarios as primary delayed-fallback persistence evidence instead of fixture-only setup."
  - "Assert sync/Oban already-read suppression parity via one shared signature helper to prevent drift."
  - "Lock planner guardrails with explicit planning_failed + invalid_delayed_fallback_channels error contract assertions."
patterns-established:
  - "POLC-03 parity scenarios assert status, suppression_reason, policy_checkpoint, and attempt_count from shared helper."
  - "Guardrail failures are validated through dispatcher return contract, not internal-only function tests."
  - "Notifier compatibility without delayed_fallback_channels/2 remains explicitly regression-tested."
requirements-completed: [POLC-03]
duration: 6 min
completed: 2026-04-24
---

# Phase 07 Plan 07-03: POLC-03 runtime evidence matrix summary

**Phase 07 closes with trigger-driven delayed-fallback persistence evidence, sync/Oban suppression parity guarantees, and planner guardrail regressions locked behind executable tests.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-24T15:15:12Z
- **Completed:** 2026-04-24T15:21:28Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- Added trigger-path delayed-fallback scenarios proving planner persistence (`delay_fallback`) and provenance (`delayed_fallback_source`).
- Introduced a shared suppression-signature helper and updated sync/Oban parity coverage to assert identical already-read suppression outcomes.
- Added guardrail tests for invalid delayed-fallback subset declarations and `in_app` misuse, with a valid-subset positive control.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add trigger-driven delayed-fallback planning persistence tests** - `6d8744b` (feat)
2. **Task 2: Add sync and Oban suppression parity matrix for already-read fallback** - `b467369` (feat)
3. **Task 3: Add guardrail tests for invalid delayed-fallback declarations and run full verification** - `600b515` (feat)

**Plan metadata:** recorded in the `docs(07-03)` completion commit.

## Files Created/Modified
- `test/chimeway/integration/delivery_lifecycle_test.exs` - Trigger-driven delayed-fallback planning persistence and compatibility scenarios.
- `test/support/chimeway/dispatch_helpers.ex` - Shared `already_read` suppression signature helper.
- `test/chimeway/dispatch/sync_test.exs` - POLC-03 sync suppression parity assertion now uses shared helper.
- `test/chimeway/dispatch/oban_test.exs` - POLC-03 Oban suppression parity assertion now uses shared helper.
- `test/chimeway/dispatch/oban_worker_test.exs` - Worker-level zero-attempt assertion for already-read delayed-fallback suppression.
- `test/chimeway/policy/delayed_fallback_test.exs` - Planner guardrail failures (`invalid_delayed_fallback_channels`) and positive control coverage.

## Decisions Made
- Kept parity assertions centralized through one helper to reduce signature-drift risk across dispatch suites.
- Validated planner guardrails through `Sync.dispatch/2` error contracts (`{:planning_failed, ...}`) to match runtime behavior.
- Kept compatibility evidence alongside trigger-driven coverage to protect notifiers that do not implement delayed fallback callbacks.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed (0 bug fix, 0 missing critical, 0 blocker)
**Impact on plan:** No scope creep; all task and plan verification gates passed.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 07 delayed-fallback runtime wiring now has trigger-path, parity, and guardrail evidence for POLC-03.
- Ready to advance from Phase 07 to Phase 08 planning/execution flow.

---
*Phase: 07-delayed-fallback-runtime-wiring*
*Completed: 2026-04-24*
