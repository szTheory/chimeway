---
phase: 24-workflow-contracts-state-spine
plan: 03
subsystem: delivery-runtime
tags: [elixir, ecto, postgres, workflow, recovery]
requires:
  - phase: 24-workflow-contracts-state-spine
    provides: durable workflow definitions, runs, and transition history from plans 24-01 and 24-02
provides:
  - canonical delivery linkage back to persisted workflow runs and active steps
  - persisted-workflow replay gating for recovery without notifier callback re-entry
  - workflow helper queries that reconstruct active-step truth from durable rows
affects: [workflow-journeys, recovery, traces]
tech-stack:
  added: []
  patterns:
    - canonical delivery rows carry explicit workflow foreign keys instead of metadata-only joins
    - recovery replay validates persisted workflow snapshots before dispatching with persisted planner opts
key-files:
  created:
    - priv/repo/migrations/20260429170300_alter_chimeway_deliveries_for_workflow_linkage.exs
  modified:
    - lib/chimeway/delivery.ex
    - lib/chimeway/delivery_planning.ex
    - lib/chimeway/deliveries.ex
    - lib/chimeway/workflows.ex
    - test/chimeway/orchestration/recovery_test.exs
    - test/chimeway/integration/delivery_lifecycle_test.exs
key-decisions:
  - "Canonical delivery linkage resolves from the durable workflow run's current_step_id, and only the active-step channel receives workflow_run_id and workflow_step_id."
  - "Recovery keeps persisted workflow replay behind explicit use_persisted_workflow: true validation while still reading linkage from Chimeway-owned workflow rows."
patterns-established:
  - "Delivery planning now uses the same canonical-row update seam for workflow linkage that rendering and orchestration already use for persisted planning facts."
  - "Persisted workflow declarations are queryable through Chimeway.Workflows helpers instead of requiring notifier callback access during replay."
requirements-completed: [WRK-01, WRK-03, API-02]
duration: 9 min
completed: 2026-04-29
---

# Phase 24 Plan 03: Workflow Contracts & State Spine Summary

**Canonical delivery rows now join back to the durable workflow spine, and recovery can opt into persisted workflow replay without notifier callback re-entry.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-29T16:40:31Z
- **Completed:** 2026-04-29T16:48:53Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added RED coverage proving that workflow-enabled deliveries persist `workflow_run_id` / `workflow_step_id` and that `recover_event/2` can replay with `use_persisted_workflow: true` while a raising notifier workflow callback stays untouched.
- Added nullable workflow linkage foreign keys plus indexes on `chimeway_deliveries`.
- Updated delivery planning to resolve the active workflow step from durable run state and stamp the canonical delivery row for the active-step channel.
- Added persisted workflow helpers in `Chimeway.Workflows` and recovery validation that forwards `use_persisted_workflow: true` alongside persisted channels and orchestration replay.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add RED coverage for delivery workflow linkage and persisted-workflow replay** - `bb26f44` (test)
2. **Task 2: Stamp workflow linkage on canonical deliveries and replay from persisted workflow declarations** - `c9d7aa0` (feat)

## Files Created/Modified

- `priv/repo/migrations/20260429170300_alter_chimeway_deliveries_for_workflow_linkage.exs` - Adds delivery-level workflow run and workflow step foreign keys plus indexes.
- `lib/chimeway/delivery.ex` - Extends the delivery schema with `workflow_run_id` and `workflow_step_id`.
- `lib/chimeway/delivery_planning.ex` - Resolves persisted active-step linkage and stamps the canonical delivery row through the planner seam.
- `lib/chimeway/deliveries.ex` - Persists workflow linkage, forwards `use_persisted_workflow`, and validates persisted workflow snapshots before recovery replay.
- `lib/chimeway/workflows.ex` - Exposes persisted workflow reconstruction and active-step linkage helpers from durable workflow definition/run rows.
- `test/chimeway/orchestration/recovery_test.exs` - Proves persisted workflow recovery succeeds without re-entering a notifier workflow callback.
- `test/chimeway/integration/delivery_lifecycle_test.exs` - Proves the active-step canonical delivery row links back to the persisted workflow run and step.

## Decisions Made

- Kept workflow current truth on `workflow_runs.current_step_id`; deliveries add explicit execution-artifact joins instead of becoming the state authority.
- Limited workflow linkage to the active-step channel so later phases can advance steps from one canonical execution artifact without ambiguous multi-channel joins.
- Treated persisted workflow replay as an explicit recovery opt, mirroring the existing persisted rendering and orchestration posture.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The test database needed `MIX_ENV=test mix ecto.migrate` before verification because the new delivery-linkage columns were not present yet.
- Raw string-table UUID selects in the new tests returned dumped binary ids, so the assertions were normalized to compare loaded UUID values rather than changing runtime behavior.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Later workflow progression phases can advance from a delivery row directly to its owning workflow run and active step.
- Recovery and replay now have a durable workflow path that stays independent from notifier callback code for historical truth.

## Self-Check: PASSED

- Verified summary file exists at `.planning/phases/24-workflow-contracts-state-spine/24-03-SUMMARY.md`.
- Verified task commits `bb26f44` and `c9d7aa0` exist in git history.

---
*Phase: 24-workflow-contracts-state-spine*
*Completed: 2026-04-29*
