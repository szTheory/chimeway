---
phase: 21-template-versioning-rendering-contracts
plan: 04
subsystem: rendering
tags: [rendering, deliveries, traces, notifications, tdd]
requires:
  - phase: 21-template-versioning-rendering-contracts
    provides: explicit channel render contracts and durable render identity
provides:
  - planning-time render_data persistence on canonical delivery rows
  - adapter-side reuse of pre-rendered delivery payloads
  - payload-safe trace projection of render identity
affects: [delivery-planning, dispatch, rendering, traces, trigger, phase-21]
tech-stack:
  added: []
  patterns: [planner-side render materialization, canonical render result persistence, payload-safe trace projection]
key-files:
  created: []
  modified:
    - lib/chimeway/deliveries.ex
    - lib/chimeway/delivery_planning.ex
    - lib/chimeway/traces.ex
    - lib/chimeway/traces/explanation.ex
    - lib/chimeway/trigger.ex
    - test/chimeway/orchestration/delivery_planning_test.exs
    - test/chimeway/integration/delivery_lifecycle_test.exs
key-decisions:
  - "Canonical delivery rows now persist validated render_data during planning so adapters and workers consume one durable render artifact."
  - "Trace explanations project render_key and render_version only; rendered bodies and raw render_data remain excluded from operator surfaces."
  - "Unsupported custom channels keep durable render identity and empty render_data rather than re-entering rendering inside adapters."
patterns-established:
  - "Plan each delivery through the shared Rendering.render_delivery/4 seam before any dispatchable state is reached."
  - "Persist reused render results through Deliveries.apply_render_result/2 instead of recomputing in transport code."
requirements-completed: [TMPL-01]
duration: 9min
completed: 2026-04-28
---

# Phase 21 Plan 04: Template Versioning & Rendering Contracts Summary

**Canonical delivery rows now store validated channel render output before dispatch, and trace explanations expose render identity without leaking rendered bodies**

## Performance

- **Duration:** 9 min
- **Completed:** 2026-04-28T19:27:19Z
- **Tasks:** 1
- **Files modified:** 7

## Accomplishments

- Materialized validated `render_data` onto delivery rows during planning and resynchronized reused rows through a dedicated persistence helper.
- Kept adapters render-agnostic by proving the dispatch path consumes pre-rendered delivery structs without late notifier callbacks.
- Extended `Chimeway.Traces.Explanation` to expose `render_key` and `render_version` while explicitly excluding raw rendered body fields.
- Preserved held-delivery trace pointers by recording `{:skip, delivery}` IDs in trigger trace results.

## Task Commits

1. **Task 1: Persist validated render data before dispatch and expose safe trace identity** - `494a383` (`test`), `203bb2d` (`feat`)

## Files Created/Modified

- `lib/chimeway/deliveries.ex` - Accepts persisted `render_data` on insert and exposes `apply_render_result/2` for canonical row reuse.
- `lib/chimeway/delivery_planning.ex` - Resolves per-channel render results during planning, persists them before dispatch, and falls back safely for unsupported custom channels.
- `lib/chimeway/traces.ex` - Projects render identity into explanations without exposing render bodies.
- `lib/chimeway/traces/explanation.ex` - Adds `render_key` and `render_version` to the explainability struct contract.
- `lib/chimeway/trigger.ex` - Keeps held-delivery IDs in trigger trace pointers by recognizing `{:skip, delivery}` dispatch results.
- `test/chimeway/orchestration/delivery_planning_test.exs` - Locks planner-side `render_data` persistence before any dispatchable state.
- `test/chimeway/integration/delivery_lifecycle_test.exs` - Proves adapters receive pre-rendered payloads and traces stay payload-safe.

## Decisions Made

- Used the shared rendering contract seam from Plan 21-03 for planner-time materialization instead of inventing a second persistence-only shape.
- Treated payload-safe traces as a first-class contract by adding render identity fields to the explanation struct rather than leaking `render_data`.
- Preserved compatibility for unsupported channels by persisting render identity with empty `render_data`, keeping adapters transport-only.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Held-delivery trigger traces dropped skipped delivery IDs**
- **Found during:** Task 1 verification
- **Issue:** `trigger/3` trace pointers omitted delivery IDs for deferred and digest-held rows because `{:skip, delivery}` results were ignored.
- **Fix:** Extended trigger trace extraction to record IDs from skipped dispatch results.
- **Files modified:** `lib/chimeway/trigger.ex`
- **Commit:** `203bb2d`

**2. [Rule 3 - Blocking Issue] Legacy lifecycle fixtures no longer matched explicit render contracts**
- **Found during:** Task 1 verification
- **Issue:** Existing integration/planning test fixtures still relied on `build/2` payloads that did not satisfy the in-app and email render validators introduced in Plan 21-03.
- **Fix:** Added explicit `rendering/2` declarations to the affected phase-local notifier fixtures.
- **Files modified:** `test/chimeway/orchestration/delivery_planning_test.exs`, `test/chimeway/integration/delivery_lifecycle_test.exs`
- **Commit:** `203bb2d`

## Known Stubs

None.

## User Setup Required

None.

## Next Phase Readiness

- Phase 21 now has one durable render artifact shared by planning, dispatch, and trace explanation.
- The remaining phase work is TMPL-03 preview/verification surfacing in `21-05`.

## Self-Check: PASSED

- Verified `.planning/phases/21-template-versioning-rendering-contracts/21-04-SUMMARY.md` exists on disk.
- Verified task commits `494a383` and `203bb2d` exist in git history.
