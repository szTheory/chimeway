---
phase: 24-workflow-contracts-state-spine
plan: 01
subsystem: database
tags: [elixir, ecto, postgres, workflow, contracts]
requires:
  - phase: 19-digest-data-model-accumulation
    provides: stable key-plus-version schemas and explicit child-row persistence patterns
  - phase: 21.1-rendering-durability-and-preview-hardening
    provides: replay-safe declaration normalization and durable serialization posture
provides:
  - notifier workflow declaration normalization with durable string-keyed serialization
  - versioned workflow definition storage keyed by workflow_key and workflow_version
  - ordered workflow step storage with per-definition step_key and step_order uniqueness
affects: [24-02-trigger-persistence, 24-03-replay-linkage, workflow-journeys]
tech-stack:
  added: []
  patterns:
    - optional notifier callback resolved into one normalized durable declaration
    - definition-plus-ordered-step tables for replay-safe workflow identity
key-files:
  created:
    - lib/chimeway/workflows.ex
    - lib/chimeway/workflows/workflow_definition.ex
    - lib/chimeway/workflows/workflow_step.ex
    - priv/repo/migrations/20260429160000_create_chimeway_workflow_definitions.exs
    - priv/repo/migrations/20260429160100_create_chimeway_workflow_steps.exs
  modified:
    - lib/chimeway/notifier.ex
    - test/chimeway/notifier_contract_test.exs
key-decisions:
  - "Workflow declarations resolve through an optional workflow/2 notifier callback and serialize into string-keyed durable data for replay without callback re-entry."
  - "Workflow identity persists in a dedicated definition table plus ordered step rows, not in module names or opaque metadata blobs."
patterns-established:
  - "Workflow declarations mirror orchestration/rendering normalization: tagged errors, string channel keys, and explicit source metadata."
  - "Ordered workflow steps are first-class rows with per-definition uniqueness on step_key and step_order."
requirements-completed: [WRK-01, API-02]
duration: 5 min
completed: 2026-04-29
---

# Phase 24 Plan 01: Workflow Contracts & State Spine Summary

**Workflow notifier declarations now normalize into stable workflow identity plus ordered durable step facts, backed by versioned definition and workflow-step schemas.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-29T16:23:14Z
- **Completed:** 2026-04-29T16:28:24Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added RED contract coverage for valid workflow declarations, invalid declaration shapes, and replay-safe serialization in `test/chimeway/notifier_contract_test.exs`.
- Added an optional `workflow/2` notifier callback with normalization, tagged errors, durable serialization, and persisted replay helpers in `lib/chimeway/notifier.ex`.
- Added workflow definition and workflow step schemas plus migrations that persist stable workflow identity and ordered step facts independently from notifier module names.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add RED contract coverage for workflow declaration normalization** - `493a305` (test)
2. **Task 2: Implement workflow declaration normalization and versioned schema storage** - `3ca153d` (feat)

## Files Created/Modified

- `test/chimeway/notifier_contract_test.exs` - Defines workflow declaration contract expectations, invalid-shape failures, and durable replay assertions.
- `lib/chimeway/notifier.ex` - Adds the workflow callback, resolution pipeline, normalization helpers, and durable serialization helpers.
- `lib/chimeway/workflows.ex` - Provides upsert/fetch helpers for workflow definitions and ordered steps.
- `lib/chimeway/workflows/workflow_definition.ex` - Defines stable workflow identity storage and `(workflow_key, workflow_version)` uniqueness.
- `lib/chimeway/workflows/workflow_step.ex` - Defines ordered per-definition step rows with durable config storage.
- `priv/repo/migrations/20260429160000_create_chimeway_workflow_definitions.exs` - Creates workflow definition storage and uniqueness indexes.
- `priv/repo/migrations/20260429160100_create_chimeway_workflow_steps.exs` - Creates ordered workflow step storage and per-definition uniqueness indexes.

## Decisions Made

- Added workflow declarations as an optional notifier contract rather than inferring workflow identity from module names or reusing orchestration blobs.
- Kept workflow replay on durable serialized maps with string keys so later trigger/recovery flows can rehydrate workflow facts without callback re-entry.
- Persisted workflow declarations as definition rows plus ordered step rows to keep workflow truth queryable and explainable for later run-state plans.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The migration acceptance grep from the plan needed a broader search because the unique-index definitions are multi-line, but the required indexes were created as planned.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase `24-02` can now create notification-anchored workflow runs and transition history against stable workflow definition ids and ordered step ids.
- Persisted replay of workflow declarations is available for later trigger/recovery linkage work.

## Self-Check: PASSED

- Verified summary file exists at `.planning/phases/24-workflow-contracts-state-spine/24-01-SUMMARY.md`.
- Verified task commits `493a305` and `3ca153d` exist in git history.

---
*Phase: 24-workflow-contracts-state-spine*
*Completed: 2026-04-29*
