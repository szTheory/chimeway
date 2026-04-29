---
phase: 23-digest-flush-scheduling-audit-closure
plan: 05
subsystem: testing
tags: [digest, accumulation, security, oban, ecto]
requires:
  - phase: 23-01
    provides: automatic digest flush scheduling from durable bucket state
provides:
  - hardened digest bucket lookup validation anchored to canonical delivery context
  - regression tests for forged recipient, channel, notification key, and notification version overrides
  - proof that helper lookup attrs still preserve normal flush scheduling
affects: [phase-23, digest-closure, audit-traceability]
tech-stack:
  added: []
  patterns: [tdd, canonical-identity-validation, tagged-rollbacks]
key-files:
  created: [.planning/phases/23-digest-flush-scheduling-audit-closure/23-05-SUMMARY.md]
  modified:
    - lib/chimeway/digests/accumulation.ex
    - test/chimeway/digests/accumulation_test.exs
    - test/chimeway/digests/flush_scheduling_test.exs
key-decisions:
  - "Digest bucket identity remains derived from locked delivery, notification, and event records; caller lookup_attrs may only supply helper fields or matching identity keys."
  - "Rejected lookup identity overrides fail with {:invalid_lookup_attrs, mismatch} so ownership-boundary violations are explicit and testable."
patterns-established:
  - "Validate caller overrides against canonical persisted identity before any bucket or membership write."
  - "Keep helper lookup attrs explicit and narrow instead of merging arbitrary caller input into durable digest selection."
requirements-completed: [DIGEST-02]
duration: 4min
completed: 2026-04-29
---

# Phase 23 Plan 05: Digest lookup boundary hardening with tagged rollback regressions

**Digest accumulation now rejects forged lookup identity overrides while preserving helper-attr scheduling for valid digest buckets.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-29T02:55:00Z
- **Completed:** 2026-04-29T02:59:15Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added explicit red-path regressions for forged `recipient_id`, `channel`, `notification_key`, and `notification_version` lookup overrides.
- Hardened `Chimeway.Digests.Accumulation` so bucket identity stays anchored to canonical delivery, notification, and event records.
- Kept the happy-path scheduling seam green by proving `category` and `digest_key` helper attrs still schedule `DigestFlushWorker`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add regression tests that reject forged digest lookup identity overrides** - `a0826f2` (`test`)
2. **Task 2: Harden accumulation to derive bucket identity only from durable delivery context** - `fb5ae6d` (`fix`)

## Files Created/Modified
- `lib/chimeway/digests/accumulation.ex` - Validates lookup identity overrides against persisted delivery context and rolls back with `{:invalid_lookup_attrs, mismatch}`.
- `test/chimeway/digests/accumulation_test.exs` - Locks the ownership boundary with explicit mismatch and no-side-effect assertions.
- `test/chimeway/digests/flush_scheduling_test.exs` - Verifies permitted helper `lookup_attrs` still drive the scheduled flush path.

## Decisions Made
- Anchored digest bucket identity to locked delivery, notification, and event facts instead of permitting caller-owned override semantics.
- Used a stable `{:invalid_lookup_attrs, mismatch}` rollback so audit closure can assert boundary failures directly.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first hardening patch used `case %{} ->` for the no-mismatch branch, which matched every map. Tightening that branch to `map_size(mismatch) == 0` restored the intended rollback behavior before the task commit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Digest accumulation now preserves recipient and rule ownership boundaries by construction.
- Phase `23-06` can focus on re-running closure gates and realigning audit artifacts without carrying this security gap forward.

## Self-Check: PASSED

- Found `.planning/phases/23-digest-flush-scheduling-audit-closure/23-05-SUMMARY.md`
- Found commits `a0826f2` and `fb5ae6d` in git history

---
*Phase: 23-digest-flush-scheduling-audit-closure*
*Completed: 2026-04-29*
