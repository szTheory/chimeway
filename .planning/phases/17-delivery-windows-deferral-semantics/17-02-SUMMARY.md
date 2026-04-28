---
phase: 17-delivery-windows-deferral-semantics
plan: 02
subsystem: api
tags: [elixir, ecto, policy, orchestration, quiet-hours, digest]
requires:
  - phase: 17-01
    provides: durable delivery orchestration fields, recipient time zones, and quiet-hours window math
provides:
  - explicit notifier/planner orchestration declarations for immediate vs digest-held delivery participation
  - durable planning-time deferral decisions for quiet hours on canonical delivery rows
  - policy contract updates that distinguish suppressive blocks from non-terminal deferrals
affects: [17-03, traces, dispatch, analytics]
tech-stack:
  added: []
  patterns:
    - notifier orchestration declarations normalized to explicit ready vs digest-held planning modes
    - planning decisions persisted through explicit delivery helpers on the canonical row
    - quiet-hours deferral limited to planning checkpoint until dispatch readiness gates land in 17-03
key-files:
  created:
    - test/chimeway/orchestration/planning_declarations_test.exs
    - test/chimeway/orchestration/delivery_planning_test.exs
  modified:
    - lib/chimeway/notifier.ex
    - lib/chimeway/deliveries.ex
    - lib/chimeway/delivery_planning.ex
    - lib/chimeway/policy.ex
    - lib/chimeway/policy/settings.ex
    - test/chimeway/notifier_contract_test.exs
    - test/chimeway/policy_settings_test.exs
    - test/chimeway/policy_test.exs
key-decisions:
  - "Normalize notifier orchestration declarations into a small explicit contract of immediate vs digest-held modes before persisting planning state."
  - "Persist quiet-hours deferrals through canonical delivery-row helpers instead of overloading suppression fields or metadata-only storage."
  - "Keep quiet-hours deferral planning-only until Phase 17-03 adds orchestration readiness gates to dispatch paths."
patterns-established:
  - "Use Deliveries.apply_planning_decision/2 for canonical row updates to orchestration_state, planning_reason, planning_context, and next_eligible_at."
  - "Pass checkpoint-aware policy options so planning can defer while perform-time callers remain on proceed/suppress semantics."
requirements-completed: [ORCH-01, ORCH-02]
duration: 11min
completed: 2026-04-28
---

# Phase 17 Plan 02: Delivery Windows & Deferral Semantics Summary

**Notifier-declared digest participation and quiet-hours deferral now persist durable orchestration facts on the canonical delivery row**

## Performance

- **Duration:** 11 min
- **Started:** 2026-04-28T09:22:30Z
- **Completed:** 2026-04-28T09:33:38Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Added an optional notifier orchestration callback plus planner override normalization so product teams can declare digest-held participation without breaking existing notifiers.
- Persisted `:ready`, `:deferred`, and `:digest_held` planning outcomes through explicit delivery helpers on the existing `(notification_id, channel)` row.
- Converted quiet-hours from terminal suppression into durable planning deferral facts with timezone, rule, and `next_eligible_at` context while keeping delivery-cap behavior suppressive.

## Task Commits

Each task was committed atomically through TDD gates:

1. **Task 1: Add the product-team declaration seam for orchestration participation**
   - `7b50f25` `test(17-02): add failing orchestration declaration coverage`
   - `b5a2634` `feat(17-02): persist notifier orchestration declarations`
2. **Task 2: Convert planning-time quiet-hours semantics from suppression to deferral**
   - `1c25b0f` `test(17-02): add failing quiet-hours deferral coverage`
   - `217d57c` `feat(17-02): defer quiet-hours at planning time`

## Files Created/Modified

- `lib/chimeway/notifier.ex` - Adds optional orchestration callback support and declaration normalization.
- `lib/chimeway/deliveries.ex` - Adds explicit canonical-row planning updates and timestamp normalization for deferred facts.
- `lib/chimeway/delivery_planning.ex` - Resolves notifier declarations and planning-time deferrals before returning the authoritative delivery row.
- `lib/chimeway/policy.ex` - Extends policy evaluation to surface planning deferrals alongside suppressive outcomes.
- `lib/chimeway/policy/settings.ex` - Converts quiet-hours into deferred decisions with safe planning context and checkpoint-aware behavior.
- `test/chimeway/notifier_contract_test.exs` - Covers backward-compatible notifier contract behavior plus digest declaration normalization.
- `test/chimeway/policy_settings_test.exs` - Verifies quiet-hours defer with timezone-aware `next_eligible_at` while delivery caps still suppress.
- `test/chimeway/policy_test.exs` - Proves planning persists deferred facts and keeps suppressive cases unchanged.
- `test/chimeway/orchestration/planning_declarations_test.exs` - Proves declared digest participation persists `:digest_held` on the canonical delivery row.
- `test/chimeway/orchestration/delivery_planning_test.exs` - Covers repeated planning for digest-held and deferred rows without duplicates.

## Decisions Made

- Normalized orchestration declarations to `:immediate` vs `:digest_held` so host input cannot inject arbitrary persisted planning state.
- Reused `Deliveries.apply_planning_decision/2` as the only write path for planning facts to preserve the `(notification_id, channel)` idempotency boundary.
- Treated quiet-hours as a planning-only deferral in this plan so existing perform-time callers stay compatible until Phase 17-03 adds explicit dispatch readiness guards.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Prevented perform-time callers from crashing on the new deferral contract**
- **Found during:** Task 2
- **Issue:** Existing perform-time policy callers only handled `{:ok, :proceed}` and `{:suppress, reason}`; introducing `{:defer, ...}` everywhere would have broken current dispatch paths before Phase 17-03.
- **Fix:** Made quiet-hours deferral checkpoint-aware so only planning-time evaluation emits `{:defer, ...}` while perform-time callers remain on the existing proceed/suppress surface.
- **Files modified:** `lib/chimeway/policy.ex`, `lib/chimeway/policy/settings.ex`, `lib/chimeway/delivery_planning.ex`
- **Verification:** `mix test test/chimeway/policy_settings_test.exs test/chimeway/policy_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace`
- **Committed in:** `217d57c`

**2. [Rule 1 - Bug] Normalized deferred timestamps for `:utc_datetime_usec` persistence**
- **Found during:** Task 2
- **Issue:** Persisting `next_eligible_at` with zero precision raised Ecto `:utc_datetime_usec` errors during planning updates.
- **Fix:** Normalized persisted planning datetimes to six-digit microsecond precision at the delivery helper boundary.
- **Files modified:** `lib/chimeway/deliveries.ex`, `lib/chimeway/policy/settings.ex`
- **Verification:** `mix test test/chimeway/policy_settings_test.exs test/chimeway/policy_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace`
- **Committed in:** `217d57c`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes were required for correctness and compatibility. No scope creep beyond the plan’s planning-layer boundary.

## Issues Encountered

- The plan’s documented `mix test ... -x` verification command is not supported by this Mix version; verification used the supported `--trace` flag instead.

## Auth Gates

None.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None.

## Next Phase Readiness

- Phase 17-03 can now gate Sync/Oban execution on `orchestration_state == :ready` and expand trace surfaces using persisted planning facts.
- Deferred and digest-held planning state is durable, idempotent, and safe to consume from later scheduler and explainability work.

## Self-Check

PASSED

- Found `.planning/phases/17-delivery-windows-deferral-semantics/17-02-SUMMARY.md`
- Verified commits `7b50f25`, `b5a2634`, `1c25b0f`, and `217d57c` exist in git history
