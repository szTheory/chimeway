---
phase: 19-digest-data-model-accumulation
plan: 02
subsystem: database
tags: [ecto, postgres, digests, transactions, tdd]
requires:
  - phase: 19-digest-data-model-accumulation
    provides: durable digest rule and bucket schemas plus matching-rule lookup
provides:
  - explicit digest membership storage keyed uniquely by source delivery
  - transactional digest accumulation for held canonical deliveries
  - fixed-window and boundary-window bucket derivation with DB-level idempotency
affects: [phase-19-plan-03, phase-20-digest-emission-explainability, digest-accumulation, explainability]
tech-stack:
  added: []
  patterns: [repo-transact accumulation, insert-all membership idempotency, persisted window snapshots]
key-files:
  created:
    - lib/chimeway/digests/digest_membership.ex
    - lib/chimeway/digests/accumulation.ex
    - priv/repo/migrations/20260428102200_create_chimeway_digest_memberships.exs
  modified:
    - lib/chimeway/digests/digest_bucket.ex
    - test/chimeway/digests/accumulation_test.exs
key-decisions:
  - "Digest accumulation stays anchored on the canonical delivery row and inserts one membership row per delivery_id instead of using queue-level uniqueness."
  - "Bucket counters advance only after a membership insert succeeds, using database uniqueness plus atomic updates to avoid retry drift."
  - "Boundary windows reuse the project’s DST-safe local-time conversion pattern and persist explicit UTC window boundaries independent from deliveries.next_eligible_at."
patterns-established:
  - "Use Repo.transact/1 with a locked delivery reload to gate digest accumulation on pending + digest_held canonical state."
  - "Use Repo.insert_all(on_conflict: :nothing, conflict_target: [:delivery_id]) for race-safe membership idempotency."
requirements-completed: [DIGEST-01]
duration: 9min
completed: 2026-04-28
---

# Phase 19 Plan 02: Digest Data Model & Accumulation Summary

**Digest membership persistence and a race-safe accumulation transaction that snapshots grouping and fixed/boundary window facts on durable buckets**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-28T14:26:00Z
- **Completed:** 2026-04-28T14:35:13Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Added RED tests that lock held-delivery gating, one-membership-per-delivery idempotency, category snapshotting, and fixed/boundary window derivation.
- Implemented `Chimeway.Digests.Accumulation.accumulate_delivery/2` with a transaction that reloads and locks the canonical delivery row, finds a matching rule, derives the concrete bucket window, and inserts membership atomically.
- Added explicit `digest_memberships` storage plus bucket associations so Phase 20 can inspect durable bucket membership without relying on Oban or payload blobs.

## Task Commits

Each task was committed atomically:

1. **Task 1: Lock accumulation idempotency and gating with RED tests** - `cf40f5d` (`test`)
2. **Task 2: Implement explicit membership storage and transactional accumulation** - `cc223c3` (`feat`)

## Files Created/Modified
- `lib/chimeway/digests/accumulation.ex` - Transactional accumulation service with held-row gating, grouping resolution, and fixed/boundary window math.
- `lib/chimeway/digests/digest_membership.ex` - Explicit membership schema linking digest buckets, deliveries, and notifications.
- `lib/chimeway/digests/digest_bucket.ex` - Membership association for bucket inspection.
- `priv/repo/migrations/20260428102200_create_chimeway_digest_memberships.exs` - Digest membership table and unique `delivery_id` boundary.
- `test/chimeway/digests/accumulation_test.exs` - TDD contract proving idempotent membership insertion and window derivation.

## Decisions Made
- Kept digest accumulation as an explicit service instead of queue-owned state so the canonical delivery row remains the source work item and durable audit trail.
- Used `insert_all` with `on_conflict: :nothing` on `delivery_id` for membership insertion because the inserted-row count is the clearest way to decide whether counters should advance.
- Reused the project’s existing DST-safe local-boundary conversion approach for boundary windows so daily bucket edges remain stable through ambiguous or gap local times.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized accumulation timestamps and transaction return shape for Ecto**
- **Found during:** Task 2 (Implement explicit membership storage and transactional accumulation)
- **Issue:** Initial accumulation writes passed second-precision UTC datetimes into `:utc_datetime_usec` columns, and the first `Repo.transact/1` callback returned bare values instead of explicit `{:ok, ...}` tuples.
- **Fix:** Normalized all persisted accumulation timestamps to microsecond-precision UTC values and returned explicit ok tuples from the transaction callback.
- **Files modified:** `lib/chimeway/digests/accumulation.ex`
- **Verification:** `mix test test/chimeway/digests/digest_rule_test.exs test/chimeway/digests/accumulation_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace`
- **Committed in:** `cc223c3`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The auto-fix was required for correct Ecto persistence semantics and did not expand scope.

## Issues Encountered

- The new accumulation service initially failed on `:utc_datetime_usec` precision and `Repo.transact/1` callback expectations; both were corrected before the implementation commit and covered by the green test run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 19 now has durable one-row-per-delivery membership storage and a tested accumulation transaction that later planning hooks can call safely.
- Phase 19-03 can now wire accumulation into `DeliveryPlanning` after policy-safe held outcomes without inventing new digest state primitives.

## Known Stubs

None.

## Self-Check: PASSED

- Verified all created and modified implementation files exist on disk, including `.planning/phases/19-digest-data-model-accumulation/19-02-SUMMARY.md`.
- Verified task commits `cf40f5d` and `cc223c3` exist in git history.
- Re-ran `mix test test/chimeway/digests/digest_rule_test.exs test/chimeway/digests/accumulation_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace` successfully.

---
*Phase: 19-digest-data-model-accumulation*
*Completed: 2026-04-28*
