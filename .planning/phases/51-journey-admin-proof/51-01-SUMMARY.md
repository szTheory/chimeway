---
phase: 51-journey-admin-proof
plan: 01
subsystem: testing
tags: [exunit, journey, jour_06, mark_read, progression, escalation]

requires:
  - phase: 50-natural-escalation-demo
    provides: JOUR-03 escalation seed and mark_read resume path
provides:
  - JOUR-06 read-cancel journey proof (zero email after mark_read before due_at)
  - JOUR-06 time-fallback journey proof (email_escalation after past-due progress_run)
affects:
  - 51-journey-admin-proof
  - 51-02-PLAN (admin trace tests)

tech-stack:
  added: []
  patterns:
    - "JOUR-03 escalation seed extended with negative email assertion and get_current_step!"
    - "CR-01 progress_run(now:) pattern adapted for demo-host journey proof"

key-files:
  created: []
  modified:
    - examples/chimeway_demo_host/test/demo_host_web/journey_test.exs

key-decisions:
  - "Two separate @tag :jour_06 tests (read-cancel vs time-fallback) with fresh escalation_waiting!/0 per test"
  - "Read-cancel asserts :active on initial_notice via get_current_step!, not :stopped"

patterns-established:
  - "JOUR-06 read-cancel: mark_read + drain_oban!(:chimeway_signals) + zero email deliveries for workflow_run_id"
  - "JOUR-06 time-fallback: Progression.progress_run(run.id, now: past_due_now) without mark_read"

requirements-completed: [JOUR-06]

duration: 12min
completed: 2026-05-29
---

# Phase 51 Plan 01: JOUR-06 Read-Cancel Journey Proof Summary

**JOUR-06 journey tests prove email escalation fires only when unread: mark_read cancels before due_at; past-due progress_run creates exactly one email delivery.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-29T17:42:00Z
- **Completed:** 2026-05-29T17:54:13Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added `JOUR-06 mark_read cancels escalation before due_at` — zero email deliveries, run resumes `:active` on `initial_notice`
- Added `JOUR-06 unread time-fallback advances to email_escalation` — `Progression.progress_run/2` with injected `now` past `due_at` creates exactly one email delivery
- Updated `@moduledoc` to reference JOUR-01..06; JOUR-03 test body unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: JOUR-06 read-cancel — mark_read prevents email before due_at (D-01)** - `43d5720` (test)
2. **Task 2: JOUR-06 time-fallback — unread past due_at advances to email (D-02)** - `45d0ff1` (test)

**Plan metadata:** pending (docs commit)

## Files Created/Modified

- `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` — Two `@tag :jour_06` tests, `Workflows`/`Progression` aliases, `parse_due_at!/1` helper

## Decisions Made

None — followed plan as specified (two tests, fresh seed per test, direct `progress_run` for time-fallback).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `mix test --only jour_06 --warnings-as-errors` exits 1 due to pre-existing `Phoenix.ConnTest` deprecation warnings in `ConnCase` (not introduced by this plan). Tests pass (2 tests, 0 failures). `mix verify.journeys` exits 0 (7 tests).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- JOUR-06 complete; ready for 51-02 (JOUR-07/08 admin trace tests)
- `mix verify.journeys` currently runs 7 tests (JOUR-01..06); Phase 52 will document 8-test gate after JOUR-07/08 ship

## Self-Check: PASSED

- [x] `journey_test.exs` contains two `@tag :jour_06` tests
- [x] Read-cancel asserts zero email + `initial_notice` step
- [x] Time-fallback uses `Progression.progress_run(run.id, now: past_due_now)`
- [x] JOUR-03 test body unchanged
- [x] No `lib/chimeway/` modifications
- [x] `mix verify.journeys` — 7 tests, 0 failures

---
*Phase: 51-journey-admin-proof*
*Completed: 2026-05-29*
