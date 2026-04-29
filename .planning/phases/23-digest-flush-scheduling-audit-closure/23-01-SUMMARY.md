---
phase: 23-digest-flush-scheduling-audit-closure
plan: 01
subsystem: api
tags: [elixir, ecto, oban, digests, scheduling]
requires:
  - phase: 20-digest-emission-explainability
    provides: durable bucket emission and emitted digest identity reuse
  - phase: 18-scheduled-resume-deferred-dispatch
    provides: thin scheduled worker and scheduled_at uniqueness pattern
provides:
  - automatic Oban-backed digest flush scheduling from durable bucket state
  - explicit non-Oban emit_bucket/2 boundary documentation
  - targeted regression coverage for scheduled flush enqueueing and duplicate-safe digest identity reuse
affects: [23-02, 23-03, digest scheduling, audit closure]
tech-stack:
  added: []
  patterns: [thin Oban worker delegation, durable bucket-owned scheduling, host-managed non-Oban seam]
key-files:
  created: [test/chimeway/digests/flush_scheduling_test.exs]
  modified: [lib/chimeway/digests/accumulation.ex, lib/chimeway/digests.ex, lib/chimeway/dispatch/oban.ex, lib/chimeway/dispatch/digest_flush_worker.ex, test/chimeway/digests/emission_test.exs]
key-decisions:
  - "Automatic digest flush scheduling is enabled only when the configured dispatcher is Chimeway.Dispatch.Oban; all other dispatchers keep emit_bucket/2 as the explicit host-managed seam."
  - "Bucket state remains the scheduling source of truth: accumulation only schedules on the first persisted membership while emit_bucket/2 still owns due/idempotency checks."
  - "DigestFlushWorker stays thin and carries only bucket_id, mirroring the Phase 18 scheduled worker posture."
patterns-established:
  - "Schedule from durable window_ends_at on the digest bucket, not from source delivery timestamps or in-memory timers."
  - "Use a thin scheduled worker that delegates due-ness and duplicate collapse back to the canonical digest emission service."
requirements-completed: [DIGEST-02]
duration: 6m
completed: 2026-04-29
---

# Phase 23 Plan 01: Digest Flush Scheduling & Audit Closure Summary

**Oban-backed digest buckets now schedule one future `DigestFlushWorker` from `window_ends_at` while non-Oban installs keep `emit_bucket/2` as the explicit durable flush seam**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-29T01:44:18Z
- **Completed:** 2026-04-29T01:50:49Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added RED coverage for automatic digest flush scheduling and duplicate-safe emitted identity reuse.
- Scheduled `DigestFlushWorker` automatically from persisted bucket state when `Chimeway.Dispatch.Oban` is configured.
- Documented that non-Oban hosts remain responsible for calling `emit_bucket/2` explicitly.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add RED coverage for automatic bucket scheduling and duplicate collapse** - `45ad52a` (test)
2. **Task 2: Schedule `DigestFlushWorker` from bucket refresh for Oban installs and document the non-Oban boundary** - `52989c6` (feat)

_Note: TDD tasks used RED then GREEN commits for the plan slice._

## Files Created/Modified
- `test/chimeway/digests/flush_scheduling_test.exs` - proves enqueue-at-window-end behavior and duplicate schedule collapse for Oban-backed accumulation.
- `test/chimeway/digests/emission_test.exs` - locks scheduled worker plus direct retry convergence on one `digest_delivery_id`.
- `lib/chimeway/digests/accumulation.ex` - refreshes the authoritative bucket row and schedules flush work from durable bucket state.
- `lib/chimeway/dispatch/oban.ex` - exposes digest flush enqueueing for Oban-backed installs and reuses the scheduled worker posture.
- `lib/chimeway/dispatch/digest_flush_worker.ex` - uses scheduled-time replacement/uniqueness while delegating directly to `Digests.emit_bucket/2`.
- `lib/chimeway/digests.ex` - documents the automatic Oban path and the explicit non-Oban `emit_bucket/2` boundary.

## Decisions Made
- Automatic flush scheduling is intentionally scoped to `Chimeway.Dispatch.Oban`; other dispatchers are documented rather than pretending they schedule digests.
- Scheduling is anchored on persisted bucket state and only the bucket's first durable membership schedules the future job, avoiding duplicate queue rows on repeated accumulation.
- `DigestFlushWorker` keeps `%{bucket_id: ...}` as its only job arg so due/idempotency checks remain inside `Digests.emit_bucket/2`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed a nonexistent Oban test helper from the RED suite**
- **Found during:** Task 1 (Add RED coverage for automatic bucket scheduling and duplicate collapse)
- **Issue:** The initial RED test setup called `Oban.Testing.reset_jobs/0`, which does not exist in the pinned Oban version and caused a false failure before the real scheduling gap could be observed.
- **Fix:** Removed the invalid helper call and reran the targeted digest tests until the failures reflected the missing runtime scheduling behavior only.
- **Files modified:** `test/chimeway/digests/flush_scheduling_test.exs`
- **Verification:** `mix test test/chimeway/digests/flush_scheduling_test.exs test/chimeway/digests/emission_test.exs --trace`
- **Committed in:** `45ad52a`

**2. [Rule 2 - Missing Critical] Hardened duplicate schedule collapse at the bucket boundary**
- **Found during:** Task 2 (Schedule `DigestFlushWorker` from bucket refresh for Oban installs and document the non-Oban boundary)
- **Issue:** Repeated accumulation attempts inserted duplicate scheduled flush jobs in this environment even after applying the planned worker uniqueness settings.
- **Fix:** Moved the first scheduling gate to durable bucket state so only the first persisted membership schedules the flush job, while keeping the thin worker and queue-side lookup hardening in the Oban helper.
- **Files modified:** `lib/chimeway/digests/accumulation.ex`, `lib/chimeway/dispatch/oban.ex`
- **Verification:** `mix test test/chimeway/digests/flush_scheduling_test.exs test/chimeway/digests/emission_test.exs --trace`
- **Committed in:** `52989c6`

**3. [Rule 3 - Blocking] Freed generated build artifacts after the test runner hit a full-disk temp-file failure**
- **Found during:** Task 2 verification
- **Issue:** `mix test` failed with `no space left on device` while creating a Mix sync temp file, blocking verification.
- **Fix:** Removed generated `_build/test` artifacts, which restored several gigabytes of free space without touching tracked source files.
- **Files modified:** none tracked
- **Verification:** reran `mix test test/chimeway/digests/flush_scheduling_test.exs test/chimeway/digests/emission_test.exs --trace` successfully after cleanup
- **Committed in:** not applicable

---

**Total deviations:** 3 auto-fixed (1 bug, 1 missing critical, 1 blocking)
**Impact on plan:** All deviations were necessary to get accurate RED coverage, deterministic duplicate collapse, and a runnable verification environment. No scope creep beyond the scheduling contract.

## Issues Encountered
- Verification was briefly blocked by full local disk space; removing generated `_build/test` artifacts resolved it without affecting tracked files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 23 now has the automatic Oban-backed digest flush handoff required for DIGEST-02.
- Remaining Phase 23 work can focus on recovery replay durability and audit/verification traceability without reopening the scheduler path.

## Self-Check: PASSED

- Summary file exists.
- Task commits `45ad52a` and `52989c6` exist in git history.

---
*Phase: 23-digest-flush-scheduling-audit-closure*
*Completed: 2026-04-29*
