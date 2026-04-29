---
phase: 24-workflow-contracts-state-spine
plan: 02
subsystem: database
tags: [elixir, ecto, postgres, workflow, trigger]
requires:
  - phase: 24-workflow-contracts-state-spine
    provides: workflow definition and ordered step persistence from plan 24-01
provides:
  - notification-anchored workflow run persistence at trigger time
  - append-only workflow transition history with explicit initial reasons
  - trigger-time linkage from notifications to durable workflow definitions
affects: [24-03-replay-linkage, workflow-journeys, traces]
tech-stack:
  added: []
  patterns:
    - one Ecto.Multi transaction persists notifications, workflow runs, and initial transition facts together
    - workflow definitions are cached per trigger invocation so duplicated recipients reuse one durable step set
key-files:
  created:
    - lib/chimeway/workflows/workflow_run.ex
    - lib/chimeway/workflows/workflow_transition.ex
    - priv/repo/migrations/20260429170000_add_workflow_definition_id_to_chimeway_notifications.exs
    - priv/repo/migrations/20260429170100_create_chimeway_workflow_runs.exs
    - priv/repo/migrations/20260429170200_create_chimeway_workflow_transitions.exs
  modified:
    - lib/chimeway/trigger.ex
    - lib/chimeway/workflows.ex
    - lib/chimeway/notifications/notification.ex
    - test/chimeway/trigger_pipeline_test.exs
key-decisions:
  - "Notifications persist nullable workflow_definition_id so trigger-time run creation can reuse durable workflow identity without hiding linkage in metadata."
  - "Initial workflow truth is split between one current-state workflow_run row and two explicit transition facts: workflow_started and step_activated."
patterns-established:
  - "Workflow trigger persistence mirrors digest accumulation posture: aggregate row plus append-only reason-bearing child rows."
  - "Per-trigger workflow definition caching prevents repeated step rewrites from invalidating foreign-key links under recipient fanout."
requirements-completed: [WRK-03, API-02]
duration: 6 min
completed: 2026-04-29
---

# Phase 24 Plan 02: Workflow Contracts & State Spine Summary

**Trigger-time workflow persistence now creates one durable workflow run per notification, stores the active step on the run row, and records explicit initial transition reasons on Chimeway-owned history rows.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-29T12:33:13-04:00
- **Completed:** 2026-04-29T12:38:39-04:00
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added RED integration coverage for workflow-enabled trigger fanout, persisted workflow run state, initial transition reasons, and duplicate-trigger idempotency.
- Added workflow run and workflow transition schemas plus migrations, including durable linkage from notifications to workflow definitions.
- Updated the trigger transaction to resolve workflow definitions once per workflow identity, insert notifications, and append initial `workflow_started` / `step_activated` history in the same transaction.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add RED integration coverage for workflow run and transition persistence** - `0735496` (test)
2. **Task 2: Implement workflow run and transition persistence inside the trigger transaction** - `e7d0059` (feat)

## Files Created/Modified

- `test/chimeway/trigger_pipeline_test.exs` - Defines trigger-time workflow persistence expectations and duplicate-run regression coverage.
- `lib/chimeway/trigger.ex` - Resolves durable workflow definitions during notification insertion and creates initial workflow runs/transitions in the same transaction.
- `lib/chimeway/workflows.ex` - Adds repo-aware definition persistence with step rewrites and initial workflow run creation helpers.
- `lib/chimeway/workflows/workflow_run.ex` - Defines the current-state workflow aggregate row anchored to one notification.
- `lib/chimeway/workflows/workflow_transition.ex` - Defines append-only workflow transition history with reason, state, and linkage fields.
- `lib/chimeway/notifications/notification.ex` - Adds optional `workflow_definition_id` linkage for durable joins.
- `priv/repo/migrations/20260429170000_add_workflow_definition_id_to_chimeway_notifications.exs` - Adds notification-level workflow definition linkage.
- `priv/repo/migrations/20260429170100_create_chimeway_workflow_runs.exs` - Creates workflow run state storage and indexes.
- `priv/repo/migrations/20260429170200_create_chimeway_workflow_transitions.exs` - Creates append-only workflow transition history and indexes.

## Decisions Made

- Kept workflow current truth directly on `chimeway_workflow_runs` instead of reconstructing state from the history table.
- Recorded both `workflow_started` and `step_activated` as separate machine-readable reasons so later trace surfaces can explain initial run state without timestamp inference.
- Reused trigger-generated notification ids and a per-trigger workflow-definition cache so fanout persistence stays deterministic and duplicate-safe inside one transaction.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The local test database had not yet applied the workflow definition/step migrations from plan `24-01`, so `MIX_ENV=test mix ecto.migrate` was required before verification could exercise the new workflow run tables.
- The plan acceptance grep for migration table creation needed a broader search because the `create table(...)` declarations are split across multiple migration files and line formats.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan `24-03` can now attach canonical deliveries to durable workflow runs/steps and verify replay without workflow callback re-entry.
- Trigger-time workflow state and historical reasons are persisted entirely on Chimeway-owned rows, ready for later progression and trace work.

## Self-Check: PASSED

- Verified summary file exists at `.planning/phases/24-workflow-contracts-state-spine/24-02-SUMMARY.md`.
- Verified task commits `0735496` and `e7d0059` exist in git history.

---
*Phase: 24-workflow-contracts-state-spine*
*Completed: 2026-04-29*
