---
phase: 07-delayed-fallback-runtime-wiring
plan: "07-02"
subsystem: dispatch
tags: [delayed-fallback, sync, oban, traces]
requires:
  - phase: 07-delayed-fallback-runtime-wiring
    provides: delayed-fallback planner wiring from 07-01
provides:
  - Explicit perform-checkpoint suppression persistence in sync and Oban worker runtime paths.
  - Pending-only enqueue and planner-error parity hardening across sync and Oban dispatchers.
  - Suppression trace explainability with delayed-fallback source metadata.
affects: [07-03, POLC-03, dispatch-parity, trace-explainability]
tech-stack:
  added: []
  patterns:
    - explicit perform-checkpoint suppression writes
    - pending-only enqueue from planner output
    - stable suppression provenance fields in traces
key-files:
  created: []
  modified:
    - lib/chimeway/dispatch/sync.ex
    - lib/chimeway/dispatch/oban.ex
    - lib/chimeway/dispatch/oban_worker.ex
    - lib/chimeway/traces.ex
key-decisions:
  - "Always persist perform-time suppressions with checkpoint: :perform in both runtime paths."
  - "Keep planner failures normalized as {:planning_failed, reason} in sync and Oban to avoid drift."
  - "Expose delayed_fallback_source in suppressed trace details with an unknown fallback."
patterns-established:
  - "Runtime suppression paths remain adapter-bypass and attempt-free on suppress outcomes."
  - "Oban enqueue uses planner output but schedules only deliveries that remain pending."
  - "Suppression timeline detail keeps stable keys: reason, policy_checkpoint, delayed_fallback_source."
requirements-completed: [POLC-03]
duration: 4 min
completed: 2026-04-24
---

# Phase 07 Plan 07-02: Runtime suppression parity and trace provenance summary

**Sync and Oban runtime paths now persist perform-time suppression metadata consistently while traces explain both suppression checkpoint and delayed-fallback provenance.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-24T15:09:10Z
- **Completed:** 2026-04-24T15:13:27Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- Updated sync and Oban worker suppression branches to persist `policy_checkpoint = perform`.
- Hardened dispatcher parity by normalizing planner failure mapping and making pending-only enqueue filtering explicit.
- Expanded suppressed trace event details to include `delayed_fallback_source` alongside `policy_checkpoint`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Normalize perform-time delayed-fallback suppression in sync and worker flows** - `ad10866` (fix)
2. **Task 2: Preserve planner-to-runtime parity in Oban enqueue and sync planner error flow** - `4f1ae43` (fix)
3. **Task 3: Surface delayed-fallback suppression provenance in traces** - `0f252b2` (fix)

**Plan metadata:** recorded in the `docs(07-02)` completion commit.

## Files Created/Modified
- `lib/chimeway/dispatch/sync.ex` - Persists perform-checkpoint suppression metadata in sync dispatch.
- `lib/chimeway/dispatch/oban_worker.ex` - Persists perform-checkpoint suppression metadata in Oban perform path.
- `lib/chimeway/dispatch/oban.ex` - Makes pending-only enqueue filtering and planner error mapping parity explicit.
- `lib/chimeway/traces.ex` - Adds delayed fallback provenance field to suppressed trace event details.

## Decisions Made
- Kept public sync/worker return shapes unchanged while aligning internal suppression persistence behavior.
- Preserved planner-owned delivery planning; dispatchers continue consuming planner output rather than re-planning.
- Used deterministic trace key names (`policy_checkpoint`, `delayed_fallback_source`) for grep-based verification stability.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed (0 bug fix, 0 missing critical, 0 blocker)
**Impact on plan:** No scope creep; all task and plan verification gates passed.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Runtime suppression parity and trace provenance requirements for `07-02` are complete and verified.
- Ready for `07-03` trigger-driven and parity-focused verification coverage.

---
*Phase: 07-delayed-fallback-runtime-wiring*
*Completed: 2026-04-24*
