---
phase: 48-wait-until-pending-signals
plan: 02
subsystem: api
tags: [elixir, workflow, pending_signals, cancel_signals, signal-router, progression]

requires:
  - phase: 48-wait-until-pending-signals
    provides: cancel_signals DSL validation at notifier declaration time (48-01)
provides:
  - enter_waiting/6 auto-populates pending_signals from wait_until cancel_signals atomically with :waiting state
  - Time-only waits persist pending_signals == [] unchanged from pre-Phase-48 behavior
  - Progression integration tests proving READ-01 population at wait entry
  - SignalRouterWorker end-to-end proof without host update_run glue (D-08)
affects: [48-03, READ-01, Phase 49]

tech-stack:
  added: []
  patterns:
    - "pending_signals sourced from Map.get(rule, \"cancel_signals\", []) at wait entry — not mirrored into status_context"

key-files:
  created: []
  modified:
    - lib/chimeway/workflows/progression.ex
    - test/chimeway/orchestration/workflow_progression_test.exs

key-decisions:
  - "Do not mirror cancel_signals into status_context — single source of truth on pending_signals column (RESEARCH discretion)"
  - "route_signal/1 matching and post-match behavior unchanged per D-02/D-07"

patterns-established:
  - "WorkflowProgressionWithSignals test fixture for cancel_signals scenarios without mutating WorkflowProgression regression fixture"

requirements-completed: [READ-01]

duration: 18min
completed: 2026-05-29
---

# Phase 48 Plan 02: enter_waiting pending_signals Population Summary

**`enter_waiting/6` atomically persists `pending_signals` from `wait_until` rule `cancel_signals`, with progression and SignalRouterWorker proofs that signal routing works without host glue**

## Performance

- **Duration:** 18 min
- **Started:** 2026-05-29T15:58:00Z
- **Completed:** 2026-05-29T16:15:56Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- `enter_waiting/6` binds `pending_signals = Map.get(rule, "cancel_signals", [])` and writes it in the same `Workflows.update_run/3` transaction as `state: :waiting`
- Time-only `wait_until` waits continue to persist `pending_signals == []` when `cancel_signals` key is omitted
- New `ChimewayTest.Notifiers.WorkflowProgressionWithSignals` fixture and READ-01 describe block with time-only and cancel_signals population tests
- End-to-end test proves `Signal.track/4` + `SignalRouterWorker` resumes a progression-driven waiting run without manual `Workflows.update_run` glue

## Task Commits

Each task was committed atomically:

1. **Task 1: Populate pending_signals in enter_waiting/6 (D-01, D-03)** - `0bfa3eb` (feat)
2. **Task 2: Progression tests for auto-populated pending_signals (READ-01)** - `3f45ca9` (test)
3. **Task 3: SignalRouterWorker end-to-end proof without host glue (D-08)** - `487c113` (test)

**Plan metadata:** `34e56d8` (docs)

## Files Created/Modified

- `lib/chimeway/workflows/progression.ex` - `enter_waiting/6` sets `pending_signals` from rule `cancel_signals`; moduledoc updated
- `test/chimeway/orchestration/workflow_progression_test.exs` - `WorkflowProgressionWithSignals` fixture, READ-01 tests, SignalRouterWorker integration test

## Decisions Made

- Followed RESEARCH discretion: no `cancel_signals` mirror in `status_context` — avoids dual-source drift
- Left `route_signal/1`, `advance_after_wait/5`, and `find_runs_waiting_for_signal/3` unchanged per plan scope

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Engine gap closed: waiting runs auto-populate `pending_signals` for signal routing (READ-01 engine behavior)
- Ready for 48-03 (journey guide doc-truth + doc contract tests)
- Phase 49 (Inbox Read → Signal) can build on auto-populated `pending_signals`

## Self-Check: PASSED

- `mix test test/chimeway/orchestration/workflow_progression_test.exs --warnings-as-errors` — 12 tests, 0 failures
- `mix test test/chimeway/dispatch/signal_router_worker_test.exs --warnings-as-errors` — 5 tests, 0 failures
- `mix compile --warnings-as-errors` — green
- `grep pending_signals lib/chimeway/workflows/progression.ex` — assignment in `enter_waiting/6`
- No edits to `lib/chimeway/workflows.ex` `route_signal/1` function body

---
*Phase: 48-wait-until-pending-signals*
*Completed: 2026-05-29*
