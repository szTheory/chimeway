---
phase: 48-wait-until-pending-signals
plan: 03
subsystem: docs
tags: [documentation, cancel_signals, pending_signals, doc-contract, READ-01]

requires:
  - phase: 48-wait-until-pending-signals
    provides: enter_waiting/6 auto-populates pending_signals from cancel_signals (48-02)
provides:
  - Journey guide documents optional cancel_signals on wait_until rules with canonical inbox event names
  - READ-01 engine-gap callout removed from journey guide
  - Doc contract tests require cancel_signals and forbid gap regression language
affects: [Phase 49, READ-02, Phase 50]

tech-stack:
  added: []
  patterns:
    - "Doc contract @required/@forbidden_strings guards doc-truth for shipped READ-01 behavior"

key-files:
  created: []
  modified:
    - guides/flows/multi-step-journeys.md
    - test/chimeway/doc_contract_test.exs

key-decisions:
  - "Keep READ-02 deferral in journey guide Deferred section — inbox emission remains Phase 49 scope"
  - "Forbid 'Engine gap today' via doc contract rather than READ-01 string to avoid false positives"

patterns-established:
  - "Journey guide cancel_signals authoring: explicit opt-in per D-06, canonical chimeway.notification.read/.seen per D-05"

requirements-completed: [READ-01]

duration: 12min
completed: 2026-05-29
---

# Phase 48 Plan 03: Journey Guide Doc-Truth Summary

**Journey guide documents shipped `cancel_signals` DSL and canonical inbox event names; READ-01 engine-gap callout removed and locked by doc contract tests**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-29T16:20:00Z
- **Completed:** 2026-05-29T16:32:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- §1 example and §2 progress rules table document optional `cancel_signals` on `wait_until` rules with explicit opt-in (D-06)
- §7 replaces READ-01 engine-gap paragraph with shipped `enter_waiting/6` auto-population behavior
- Canonical event names `chimeway.notification.read` and `chimeway.notification.seen` documented; READ-02 deferral retained
- Doc contract tests require `cancel_signals` and forbid `Engine gap today` regression

## Task Commits

Each task was committed atomically:

1. **Task 1: Journey guide doc-truth for cancel_signals and READ-01 shipped (D-05, D-09)** - `d154df4` (docs)
2. **Task 2: Doc contract test updates for cancel_signals and gap regression guard** - `9ba8c9d` (test)

**Plan metadata:** `919b75c` (docs)

## Files Created/Modified

- `guides/flows/multi-step-journeys.md` - cancel_signals authoring, canonical inbox events, READ-01 gap removed, READ-02 deferral kept
- `test/chimeway/doc_contract_test.exs` - @required cancel_signals, @forbidden_strings Engine gap today

## Decisions Made

- Kept READ-02 bullet in Deferred section so existing `Deferred|READ-0` doc contract test continues to pass
- Did not add READ-01 to @forbidden_strings — minimum requirement met via Engine gap today guard

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 48 complete — READ-01 engine behavior and doc-truth aligned
- Ready for Phase 49 (Inbox Read → Signal) — mark_read/mark_seen emission wiring (READ-02)
- Mention-escalation recipe rewrite remains Phase 50 / DEMO-04 scope

## Self-Check: PASSED

- `mix ci.verify_gates` — 90 tests, 0 failures
- `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` — 90 tests, 0 failures
- `grep cancel_signals guides/flows/multi-step-journeys.md` — 6+ occurrences (example, table, prose)
- `grep "Engine gap today" guides/flows/multi-step-journeys.md` — no matches
- `grep "READ-01" guides/flows/multi-step-journeys.md` — no matches
- `grep "READ-02" guides/flows/multi-step-journeys.md` — present in Deferred section
- `grep stage_escalation_webhook guides/flows/multi-step-journeys.md` — no matches

---
*Phase: 48-wait-until-pending-signals*
*Completed: 2026-05-29*
