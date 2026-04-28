---
phase: 19-digest-data-model-accumulation
plan: 03
subsystem: database
tags: [ecto, digests, orchestration, planning, tdd]
requires:
  - phase: 19-digest-data-model-accumulation
    provides: explicit digest membership storage and transactional accumulation for held canonical deliveries
provides:
  - notifier normalization for explicit digest-key declarations without changing persisted held-mode semantics
  - planner-side accumulation wiring after policy-safe pending digest-held outcomes
  - orchestration tests proving one canonical delivery row and one digest membership under repeated planning
affects: [phase-20-digest-emission-explainability, digest-accumulation, explainability, planning]
tech-stack:
  added: []
  patterns: [normalized notifier orchestration metadata, planner-side accumulation gating, shared policy category lookup]
key-files:
  created: []
  modified:
    - lib/chimeway/notifier.ex
    - lib/chimeway/delivery_planning.ex
    - lib/chimeway/policy.ex
    - lib/chimeway/digests/accumulation.ex
    - test/chimeway/orchestration/planning_declarations_test.exs
    - test/chimeway/orchestration/delivery_planning_test.exs
key-decisions:
  - "Explicit digest declarations keep the persisted orchestration mode normalized to :digest_held and carry digest_key as separate planning metadata."
  - "DeliveryPlanning invokes digest accumulation only after policy evaluation returns the canonical delivery still pending and digest-held."
  - "Planner-side digest lookup snapshots category through Policy.delivery_category/1 so accumulation uses the same category resolution path as suppression checks."
patterns-established:
  - "Keep notifier normalization backward-compatible by preserving mode maps and storing optional digest keys in separate normalized fields."
  - "Pass planner-derived lookup facts into accumulation instead of re-deriving mutable grouping inputs later."
requirements-completed: [DIGEST-01]
duration: 7min
completed: 2026-04-28
---

# Phase 19 Plan 03: Digest Data Model & Accumulation Summary

**Planner-side digest accumulation wired through normalized digest-key declarations, policy-safe held-delivery gating, and row-plus-membership idempotency tests**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-28T14:37:00Z
- **Completed:** 2026-04-28T14:44:27Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added RED orchestration tests that lock explicit digest-key normalization, category snapshotting, planner-side gating, and one-row/one-membership idempotency.
- Extended notifier normalization so channel declarations can carry optional `digest_key` metadata while still persisting the canonical delivery row as `orchestration_state: :digest_held`.
- Wired `DeliveryPlanning` to call digest accumulation only after policy leaves the canonical delivery pending and held, using the shared policy category resolution path.

## Task Commits

Each task was committed atomically:

1. **Task 1: Lock planner-side digest accumulation behavior with RED orchestration tests** - `585fb0b` (`test`)
2. **Task 2: Normalize digest-key declarations and invoke accumulation only after held planning outcomes** - `64744c4` (`feat`)

## Files Created/Modified
- `lib/chimeway/notifier.ex` - Normalizes explicit digest-key orchestration declarations without widening the persisted mode contract.
- `lib/chimeway/delivery_planning.ex` - Gates planner-side accumulation on pending plus `:digest_held` outcomes and passes a lookup snapshot into accumulation.
- `lib/chimeway/policy.ex` - Exposes `delivery_category/1` as the shared category resolution helper for policy and accumulation.
- `lib/chimeway/digests/accumulation.ex` - Accepts optional planner lookup attrs while preserving the canonical delivery lock and membership idempotency boundary.
- `test/chimeway/orchestration/planning_declarations_test.exs` - Proves explicit digest-key declarations still persist held canonical delivery rows.
- `test/chimeway/orchestration/delivery_planning_test.exs` - Proves planner-side accumulation idempotency, category snapshotting, and non-accumulation for suppressed or immediate deliveries.

## Decisions Made
- Preserved the existing notifier resolution shape for `default` and `channels` so existing callers stay compatible while new digest-key metadata travels in separate normalized fields.
- Reused `Policy.delivery_category/1` instead of re-deriving category inside the planner hook so digest grouping stays aligned with suppression behavior.
- Kept `Chimeway.Digests.Accumulation.accumulate_delivery/2` as the single accumulation entry point and passed planner lookup attrs into it, avoiding planner-owned bucket logic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected planner lookup and digest-key normalization internals**
- **Found during:** Task 2 (Normalize digest-key declarations and invoke accumulation only after held planning outcomes)
- **Issue:** The first implementation returned the wrong normalized channel structure for digest-key declarations and initially sourced planner notification lookups from the wrong path, preventing rule matches.
- **Fix:** Corrected notifier channel normalization to emit stable mode and digest-key maps, and switched planner lookup facts to the persisted notification/event path before invoking accumulation.
- **Files modified:** `lib/chimeway/notifier.ex`, `lib/chimeway/delivery_planning.ex`
- **Verification:** `mix test test/chimeway/orchestration/planning_declarations_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace`
- **Committed in:** `64744c4`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The auto-fix was required for correct planner-side rule matching and did not expand scope beyond the plan.

## Issues Encountered

- The first RED run caught a test compilation mistake in the new query assertions; fixing that preserved a clean failing signal before the RED commit.
- The first GREEN pass exposed that planner lookup facts must come from the persisted event path, not delivery metadata, for repeated planning to match digest rules reliably.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 19 now resolves digest-held planning outcomes into durable memberships at the canonical planner choke point.
- Phase 20 can build digest emission and explainability on top of stable rule matches, bucket membership, and planner-carried digest grouping facts.

## Known Stubs

None.

## Self-Check: PASSED

- Verified `.planning/phases/19-digest-data-model-accumulation/19-03-SUMMARY.md` exists on disk.
- Verified task commits `585fb0b` and `64744c4` exist in git history.
- Re-ran `mix test test/chimeway/orchestration/planning_declarations_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace` successfully.

---
*Phase: 19-digest-data-model-accumulation*
*Completed: 2026-04-28*
