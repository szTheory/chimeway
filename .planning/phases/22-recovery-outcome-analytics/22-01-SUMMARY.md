---
phase: 22-recovery-outcome-analytics
plan: 01
subsystem: recovery
tags: [elixir, ecto, postgres, deliveries, recovery, tdd]
requires:
  - phase: 21.1-rendering-durability-and-preview-hardening
    provides: durable notification snapshots and canonical delivery-row mutation patterns
provides:
  - recoverable event-gap query helpers over canonical event/notification/delivery tables
  - recoverable delivery-row query helpers over canonical delivery state only
  - guarded delivery recovery metadata claims with explicit noop semantics
affects: [22-02, ops-01, operator-recovery]
tech-stack:
  added: []
  patterns: [guarded update_all claims, durable recovery metadata, queue-independent recovery detection]
key-files:
  created: [.planning/phases/22-recovery-outcome-analytics/22-01-SUMMARY.md]
  modified: [lib/chimeway/deliveries.ex, test/chimeway/deliveries_test.exs]
key-decisions:
  - "Recovery detection stays anchored on canonical Ecto state instead of Oban job inspection."
  - "Duplicate recovery claims collapse through a guarded metadata write on the same delivery row."
patterns-established:
  - "Recoverable rows are filtered by pending+ready durable state, age threshold, and absence of prior recovery metadata."
  - "Recovery facts persist as recovery_source, recovery_reason, and recovered_at on the canonical delivery metadata map."
requirements-completed: [OPS-01]
duration: 6min
completed: 2026-04-28
---

# Phase 22 Plan 01: Durable recovery queries and guarded metadata claims Summary

**Durable recoverable-row queries plus one-shot recovery metadata claims on canonical delivery rows**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-28T21:52:00Z
- **Completed:** 2026-04-28T21:57:58Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `list_recoverable_events/1` to find aged events with notifications but zero delivery rows from Chimeway-owned tables only.
- Added `list_recoverable_deliveries/1` to find aged `:pending` + `:ready` delivery rows while excluding deferred, dispatched, and terminal states.
- Added `begin_recovery/2` to stamp `recovery_source`, `recovery_reason`, and `recovered_at` exactly once on the canonical delivery row, with duplicate calls returning `{:noop, delivery}`.

## Verification Evidence

- `mix test test/chimeway/deliveries_test.exs --trace`
- Result: `32 tests, 0 failures`
- Acceptance checks passed via `rg` against `test/chimeway/deliveries_test.exs` and `lib/chimeway/deliveries.ex` for `list_recoverable_events`, `list_recoverable_deliveries`, `older_than`, `left_join`, `recovery_source`, `recovery_reason`, `recovered_at`, `status == :pending`, `orchestration_state == :ready`, and `Repo.update_all`.

## Task Commits

1. **Task 1: Add RED tests for recoverable delivery detection and row-level recovery guards** - `936edf7` (`test`)
2. **Task 2: Implement recoverable-row queries and recovery metadata helpers in `Chimeway.Deliveries`** - `b97d97c` (`feat`)

## Files Created/Modified

- `lib/chimeway/deliveries.ex` - Adds recoverable event/delivery queries, age-threshold normalization, and guarded canonical recovery metadata claims.
- `test/chimeway/deliveries_test.exs` - Locks threshold-based recovery detection, excluded-state coverage, metadata stamping, and duplicate noop behavior.
- `.planning/phases/22-recovery-outcome-analytics/22-01-SUMMARY.md` - Records plan outcome and verification evidence.

## Decisions Made

- Recovery-claim idempotency is enforced by the same row-level `update_all` boundary that writes metadata, so concurrent callers cannot both claim the row.
- Recovery eligibility excludes rows that already have `recovered_at` metadata, which keeps duplicate recovery attempts explainable and no-op.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `22-02` can reuse `list_recoverable_events/1`, `list_recoverable_deliveries/1`, and `begin_recovery/2` to re-drive stuck rows through the existing dispatcher without inventing new queue truth.
- No blockers for the next plan.

## Self-Check

PASSED
