---
phase: 01-durable-core-spine
plan: "03"
subsystem: api
tags: [inbox, ecto, lifecycle, verification]
requires:
  - phase: 01-02
    provides: durable event/notification persistence and idempotent trigger execution
provides:
  - Recipient inbox query APIs with unread filtering and newest-first ordering.
  - Explicit seen/read/archive lifecycle transitions scoped by notification and recipient.
  - Phase validation and verification artifacts backed by executable command evidence.
affects: [phase-2-delivery-planning, phase-3-policy-fallback, operator-explainability]
tech-stack:
  added: []
  patterns: [explicit lifecycle mutations, read-side-effect-free inbox queries, evidence-backed verification docs]
key-files:
  created:
    - lib/chimeway/inbox.ex
    - test/chimeway/inbox_query_test.exs
    - test/chimeway/inbox_state_transition_test.exs
    - test/chimeway/inbox_integration_test.exs
    - .planning/phases/01-durable-core-spine/01-VALIDATION.md
    - .planning/phases/01-durable-core-spine/VERIFICATION.md
  modified:
    - lib/chimeway.ex
    - test/chimeway/trigger_pipeline_test.exs
    - test/chimeway_test.exs
key-decisions:
  - "Keep inbox reads side-effect free; lifecycle mutation is explicit through mark_seen/read/archive APIs."
  - "Scope all lifecycle updates by notification id plus recipient identity to prevent cross-recipient mutation."
  - "Treat verification artifacts as executable contracts by storing exact command evidence and PASS statuses."
patterns-established:
  - "Pattern 1: Inbox query defaults to newest-first ordering and optional unread filtering."
  - "Pattern 2: Verification docs track requirement status only after the matching command suite is green."
requirements-completed: [INBX-02, INBX-03]
duration: 9 min
completed: 2026-04-24
---

# Phase 01 Plan 03: Inbox Lifecycle and Verification Summary

**Inbox query/state APIs now provide explicit recipient-scoped lifecycle control with tests and verification evidence covering all Phase 1 CORE/INBX requirements.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-24T02:48:00Z
- **Completed:** 2026-04-24T02:56:37Z
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments
- Added `Chimeway.Inbox` list and lifecycle APIs, then exposed them through `Chimeway` delegates.
- Added inbox query, state transition, and integration tests that validate unread filtering, ordering, explicit transitions, and no implicit read mutation.
- Replaced stale phase validation/verification artifacts with command-backed PASS evidence for `CORE-01..04` and `INBX-01..03`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement inbox query and explicit lifecycle APIs** - `d83a8ee` (feat)
2. **Task 2: Add inbox behavior tests covering queries and state transitions** - `1387368` (feat)
3. **Task 3: Update validation and verification artifacts with command-backed evidence** - `7a94d76` (fix)

Additional verification compliance fix:

- `7a62125` (fix) - ensured `test/chimeway_test.exs` explicitly loads `Chimeway` before export assertions so full-suite verification is stable.

**Plan metadata:** Pending (included in this completion commit)

## Files Created/Modified
- `lib/chimeway/inbox.ex` - Recipient inbox query and explicit lifecycle transition implementation.
- `lib/chimeway.ex` - Public delegates for inbox query and lifecycle APIs.
- `test/chimeway/inbox_query_test.exs` - Unread filter and descending `inserted_at` ordering assertions.
- `test/chimeway/inbox_state_transition_test.exs` - Independent seen/read/archive lifecycle transition assertions.
- `test/chimeway/inbox_integration_test.exs` - End-to-end trigger-to-inbox behavior for `user:42`, including no implicit read mutation.
- `.planning/phases/01-durable-core-spine/01-VALIDATION.md` - Nyquist-compliant verification matrix updated with file and status evidence.
- `.planning/phases/01-durable-core-spine/VERIFICATION.md` - Goal achievement, requirements coverage table, and command evidence blocks.
- `test/chimeway/trigger_pipeline_test.exs` - Migrated to `DataCase` to satisfy DB ownership requirements in transactional trigger tests.
- `test/chimeway_test.exs` - Stabilized module export assertion by ensuring module load first.

## Decisions Made
- Enforced recipient isolation in all inbox update paths using both notification ID and recipient identity predicates.
- Kept lifecycle semantics explicit (`seen`, `read`, `archive`) and decoupled from list operations to align with INBX threat model constraints.
- Promoted verification docs from static narrative to executable evidence artifact with exact command references.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Trigger pipeline tests needed sandbox ownership setup**
- **Found during:** Task 3 verification command execution
- **Issue:** `mix test test/chimeway/notifier_contract_test.exs test/chimeway/trigger_pipeline_test.exs --seed 0` failed with DB ownership errors because trigger tests ran under `ExUnit.Case`.
- **Fix:** Switched `test/chimeway/trigger_pipeline_test.exs` to `Chimeway.DataCase`.
- **Files modified:** `test/chimeway/trigger_pipeline_test.exs`
- **Verification:** Plan command suite re-run passed (`6 tests, 0 failures`).
- **Committed in:** `7a94d76`

**2. [Rule 1 - Bug] Base API export test depended on implicit module loading**
- **Found during:** Plan-level `mix test` verification
- **Issue:** `test/chimeway_test.exs` produced a false negative for `function_exported?/3` when `Chimeway` was not loaded yet.
- **Fix:** Added `Code.ensure_loaded/1` assertion before export checks.
- **Files modified:** `test/chimeway_test.exs`
- **Verification:** Full suite `mix test` passed (`17 tests, 0 failures`).
- **Committed in:** `7a62125`

---

**Total deviations:** 2 auto-fixed (2 bug fixes)  
**Impact on plan:** Both fixes were required to satisfy hard verification gates and keep requirement evidence trustworthy; no scope creep.

## Issues Encountered
- Full-suite verification exposed two pre-existing test harness assumptions (DB sandbox ownership and implicit module loading); both were resolved with minimal targeted patches.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 1 now has executable evidence for all locked CORE/INBX requirements and can be closed from a verification standpoint.
- Phase 2 planning can rely on explicit inbox semantics and durable idempotent trigger behavior as stable inputs for outbound delivery work.

---
*Phase: 01-durable-core-spine*  
*Completed: 2026-04-24*
