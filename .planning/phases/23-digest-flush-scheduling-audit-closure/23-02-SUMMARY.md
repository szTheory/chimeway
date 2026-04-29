---
phase: 23-digest-flush-scheduling-audit-closure
plan: 02
subsystem: database
tags: [ecto, postgres, recovery, digests, orchestration]
requires:
  - phase: 21.1-rendering-durability-and-preview-hardening
    provides: persisted notification render declarations for recovery replay
  - phase: 22-recovery-outcome-analytics
    provides: canonical recover_event/2 replay path and persisted-channel recovery behavior
provides:
  - durable notification-level orchestration snapshots
  - digest-held recovery replay through planner overrides
  - regression coverage for persisted orchestration recovery
affects: [phase-23-verification, recovery, digests, explainability]
tech-stack:
  added: []
  patterns:
    - trigger-time snapshotting of notifier orchestration declarations
    - recovery replay through existing planner override normalization
key-files:
  created:
    - priv/repo/migrations/20260428230000_add_orchestration_snapshot_to_chimeway_notifications.exs
  modified:
    - lib/chimeway/notifications/notification.ex
    - lib/chimeway/notifier.ex
    - lib/chimeway/trigger.ex
    - lib/chimeway/delivery_planning.ex
    - lib/chimeway/deliveries.ex
    - test/chimeway/trigger_pipeline_test.exs
    - test/chimeway/orchestration/recovery_test.exs
key-decisions:
  - "Persist normalized orchestration snapshots on notifications with string-keyed durable fields instead of reconstructing digest semantics from notifier callbacks during recovery."
  - "Replay recovered orchestration through Notifier.resolve_orchestration/4 override normalization so recovered deliveries keep planner_override explainability while reusing the existing planner seam."
patterns-established:
  - "Notification rows must snapshot notifier callback outputs that affect durable recovery semantics."
  - "Recovery replays should prefer persisted planner inputs over notifier re-entry whenever canonical notification data exists."
requirements-completed: [DIGEST-02, DIGEST-03]
duration: 5 min
completed: 2026-04-29
---

# Phase 23 Plan 02: Digest Flush Scheduling & Audit Closure Summary

**Durable notification orchestration snapshots now preserve digest-held recovery semantics through the existing planner override seam**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-29T01:54:00Z
- **Completed:** 2026-04-29T01:59:34Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Added RED coverage that proves notifications must persist normalized orchestration snapshots and that `recover_event/2` must keep digest-held rows out of immediate dispatch.
- Added a non-null notification `orchestration` snapshot column plus schema/runtime support for serializing normalized notifier orchestration at trigger time.
- Replayed persisted orchestration during recovery by opting `recover_event/2` into planner override normalization, preserving digest-key planning context and explainability facts.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add RED tests for durable orchestration snapshot persistence and digest-held recovery replay** - `2644272` (test)
2. **Task 2: Persist orchestration snapshots on notifications and replay them during recovery** - `84a2276` (feat)

## Files Created/Modified
- `priv/repo/migrations/20260428230000_add_orchestration_snapshot_to_chimeway_notifications.exs` - adds durable notification orchestration storage.
- `lib/chimeway/notifier.ex` - serializes persisted orchestration snapshots and converts them back into planner override declarations.
- `lib/chimeway/trigger.ex` - resolves orchestration once per recipient and stores the normalized snapshot on notification rows.
- `lib/chimeway/delivery_planning.ex` - selects persisted orchestration replay when recovery opts into notification-backed planning.
- `lib/chimeway/deliveries.ex` - enables persisted orchestration replay in `recover_event/2`.
- `test/chimeway/trigger_pipeline_test.exs` - locks the persisted snapshot shape.
- `test/chimeway/orchestration/recovery_test.exs` - proves recovered digest-held deliveries stay held with preserved planning context and no notifier re-entry.

## Decisions Made
- Persisted orchestration uses a string-keyed map with `default`, `channels`, `default_digest_key`, `digest_keys`, and `source` so recovery reads durable data without module coupling.
- Recovery keeps `planning_context["source"] == "planner_override"` by feeding persisted snapshots through the existing override normalization path instead of adding a second recovery-only planner format.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The test database needed `MIX_ENV=test mix ecto.migrate` before verification because the new notification `orchestration` column was not yet present locally.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Recovery now preserves digest-held orchestration and digest-key context from canonical notification data.
- Phase 23-03 can focus on end-to-end verification and traceability closure instead of recovery correctness gaps.

## Self-Check: PASSED
