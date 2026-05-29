---
phase: 37-doc-truth-journey-guides
plan: "02"
subsystem: docs
tags: [oban, dispatch, workflow, doc-truth, queues]

requires:
  - phase: 37-doc-truth-journey-guides
    provides: Correct Dispatch worker module names referenced from journey guide
provides:
  - Accurate Oban integration recipe with per-run due_at scheduling model
  - Correct chimeway_delivery/chimeway_signals queue guidance without dead chimeway_workflows
  - Dispatch worker prose aligned with route_signal pending_signals semantics
affects: [37-03, 38-reference-recipes]

tech-stack:
  added: []
  patterns:
    - "Oban wait advancement: per-run WorkflowProgressionWorker at due_at is primary; cron progress_due_runs/1 is fallback"
    - "Signal routing doc: pending_signals matching, not conflated with on_outcome/stop rules"

key-files:
  created: []
  modified:
    - guides/recipes/oban-integration.md

key-decisions:
  - "Removed chimeway_workflows queue from required config; documented as unused by Chimeway workers"
  - "Rephrased SignalRouterWorker semantics without 'stop conditions' phrase to satisfy grep gate"

patterns-established:
  - "Oban recipe links Wait advancement scheduling subsection to Workflow Engine Workers cross-reference"

requirements-completed: [DOCS-03]

duration: 10min
completed: 2026-05-29
---

# Phase 37 Plan 02: Oban Integration Recipe Fix Summary

**Oban integration recipe aligned with Dispatch workers, per-run due_at scheduling, and honest signal routing semantics (D-13, D-14)**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-29T01:00:00Z
- **Completed:** 2026-05-29T01:10:00Z
- **Tasks:** 2 completed
- **Files modified:** 1

## Accomplishments

- Replaced `Chimeway.Workflows.Workers.*` with `Chimeway.Dispatch.WorkflowProgressionWorker` and `Chimeway.Dispatch.SignalRouterWorker`
- Documented per-run `due_at` scheduling as primary wait advancement; optional cron + `progress_due_runs/1` as fallback only
- Removed required `chimeway_workflows` queue; clarified `chimeway_delivery` serves dispatch, progression, and webhook feedback
- Fixed transactional trigger example to use `Chimeway.trigger/3` with `idempotency_key` and `tenant_id`
- `mix ci.docs` passes; zero `Workflows.Workers` matches under `guides/`

## Task Commits

Each task was committed atomically:

1. **Task 37-02-01: Fix Oban queue and cron configuration section** - `d28a997` (docs)
2. **Task 37-02-02: Fix Workflow Engine Workers prose and trigger example** - `52ad39f` (docs)

**Plan metadata:** `0e65717` (docs: complete plan)

## Files Created/Modified

- `guides/recipes/oban-integration.md` — Queue/cron config, wait scheduling model, worker prose, and Multi trigger example corrected

## Decisions Made

- Kept optional commented cron example using `WorkflowProgressionWorker` module string for fallback documentation only
- Avoided "stop conditions" phrase in SignalRouterWorker description while preserving accurate pending_signals / on_outcome separation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 37-03 (doc-contract test extension + 37-VALIDATION.md)
- Oban recipe now consistent with journey guide worker references from 37-01

## Self-Check: PASSED

- `rg 'Workflows\.Workers' guides/` → zero matches
- Worker modules match `lib/chimeway/dispatch/*.ex` queue bindings
- `mix ci.docs` → exit 0
- All task acceptance criteria verified green before commits

---
*Phase: 37-doc-truth-journey-guides*
*Completed: 2026-05-29*
