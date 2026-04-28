---
phase: 22-recovery-outcome-analytics
plan: 03
subsystem: api
tags: [elixir, ecto, traces, analytics, recovery, tdd]
requires:
  - phase: 22-recovery-outcome-analytics
    provides: durable recovery claims and dispatcher-backed recovery orchestration
provides:
  - recovery-aware delivery explanations with durable recovery timeline facts
  - grouped outcome aggregates by notification key, channel, and lifecycle bucket
  - payload-safe operator analytics derived from canonical delivery state only
affects: [ops-01, ops-02, operator-traces, operator-analytics]
tech-stack:
  added: []
  patterns: [trace-level recovery timeline projection, grouped delivery-state analytics via subquery]
key-files:
  created: [.planning/phases/22-recovery-outcome-analytics/22-03-SUMMARY.md]
  modified: [lib/chimeway/traces.ex, test/chimeway/traces_test.exs]
key-decisions:
  - "Recovery facts stay operator-facing through a dedicated :recovered timeline event instead of widening payload or provider surfaces."
  - "Outcome aggregates group from canonical delivery status, orchestration_state, and suppression_reason rather than attempt history."
patterns-established:
  - "Aggregate outcome queries join events, notifications, and deliveries once, then group in SQL over a payload-safe subquery."
  - "Delayed analytics count only rows still pending and deferred; resumed rows move into their current durable bucket."
requirements-completed: [OPS-02, OPS-01]
duration: 3min
completed: 2026-04-28
---

# Phase 22 Plan 03: Recovery-aware traces and grouped outcome analytics Summary

**Recovery metadata now appears in delivery trace timelines, and grouped operator outcome analytics are available from canonical delivery state**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-28T22:12:21Z
- **Completed:** 2026-04-28T22:15:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added Phase 22 trace coverage for durable recovery facts, grouped lifecycle buckets, delayed-versus-resumed semantics, and safe aggregate response shapes.
- Implemented `Chimeway.Traces.aggregate_outcomes/1` plus `aggregate_outcomes_for_notification/2` using grouped Ecto joins across events, notifications, and deliveries.
- Projected `recovery_source`, `recovery_reason`, and `recovered_at` into `explain_delivery/2` through a dedicated `:recovered` timeline event without exposing payload or provider data.

## Verification Evidence

- Command: `mix test test/chimeway/traces_test.exs --trace`
- Result: `37 tests, 0 failures`
- Acceptance checks passed via `rg` for:
  - `recovery_source`, `recovery_reason`, `recovered_at`, `sent`, `suppressed`, `delayed`, `digested`, `failed`, `exhausted`, `notification_key`, and `channel` in `test/chimeway/traces_test.exs`
  - `recovery_source`, `recovery_reason`, `recovered_at`, `def aggregate_`, `group_by`, `notification_key`, `channel`, `retries_exhausted`, and `count(` in `lib/chimeway/traces.ex`

## Task Commits

1. **Task 1: Add RED tests for grouped outcome analytics in `Chimeway.Traces`** - `e26bb04` (`test`)
2. **Task 2: Implement payload-safe aggregate outcome queries in `Chimeway.Traces`** - `04f678d` (`feat`)

## Files Created/Modified

- `lib/chimeway/traces.ex` - adds grouped outcome aggregate APIs, query filters, and recovery timeline projection from durable metadata.
- `test/chimeway/traces_test.exs` - locks recovery explainability, lifecycle bucket counts, exhausted-versus-cancelled behavior, delayed row semantics, and safe aggregate result shapes.
- `.planning/phases/22-recovery-outcome-analytics/22-03-SUMMARY.md` - records execution outcome and verification evidence.

## Decisions Made

- Recovery explainability was added as timeline data, which fit the existing `Explanation` surface without widening the struct or leaking unsafe fields.
- Aggregate analytics count the row’s current durable lifecycle bucket, so resumed deferred rows stop counting as `delayed` and contribute to their current state instead.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Ecto rejected a helper-based bucket expression inside `select`, so the aggregate bucket mapping was inlined in the SQL fragment backing the subquery. Verification remained unchanged after the adjustment.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 22 now has both recovery orchestration and operator-facing grouped outcome analytics in place.
- No blockers in the owned plan files.

## Known Stubs

None.

## Self-Check

PASSED
