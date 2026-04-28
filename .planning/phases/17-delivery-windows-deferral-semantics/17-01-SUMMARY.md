---
phase: 17-delivery-windows-deferral-semantics
plan: 01
subsystem: database
tags: [delivery-orchestration, tzdata, ecto, postgres, timezone, quiet-hours]
requires:
  - phase: 16-integration-guides-hardening
    provides: documented delivery and policy seams this phase extends durably
provides:
  - durable orchestration fields on delivery rows
  - recipient time zone persistence and validation in policy settings
  - DST-safe quiet-hours window math backed by Tzdata
affects: [phase-18-scheduled-resume, phase-22-outcome-analytics, traces, delivery-planning]
tech-stack:
  added: [tzdata]
  patterns: [durable orchestration columns, validated recipient time zones, pure DST-safe window math]
key-files:
  created:
    - lib/chimeway/orchestration/window_math.ex
    - priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs
    - priv/repo/migrations/20260428093100_add_time_zone_to_chimeway_policy_settings.exs
  modified:
    - mix.exs
    - mix.lock
    - config/config.exs
    - lib/chimeway/delivery.ex
    - lib/chimeway/policy/settings.ex
    - lib/chimeway/policy/settings/setting.ex
    - test/chimeway/deliveries_test.exs
    - test/chimeway/policy_settings_test.exs
    - test/chimeway/orchestration/window_math_test.exs
key-decisions:
  - "Persist deferred-planning facts directly on chimeway_deliveries instead of hiding them in metadata."
  - "Validate recipient time zones against the configured Calendar time zone database at changeset time."
  - "Resolve DST ambiguity deterministically by choosing the later occurrence and gap transitions by choosing the first valid instant after the gap."
patterns-established:
  - "Delivery rows now carry orchestration_state, next_eligible_at, planning_reason, and planning_context as first-class columns."
  - "Recipient-local quiet-hours math lives in a pure orchestration module backed by Tzdata instead of UTC-only inline checks."
requirements-completed: [ORCH-01, ORCH-02]
duration: 5 min
completed: 2026-04-28
---

# Phase 17 Plan 01: Durable Orchestration Storage Summary

**Delivery rows now persist deferral-ready orchestration fields, policy settings own validated recipient time zones, and quiet-hours window math is DST-safe through Tzdata-backed calculations.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-28T09:15:58Z
- **Completed:** 2026-04-28T09:21:15Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- Added explicit orchestration storage on `chimeway_deliveries` without changing the `(notification_id, channel)` idempotency boundary.
- Persisted `time_zone` on recipient policy settings, validated against the configured time zone database, and included it in the durable upsert conflict path.
- Added a pure `Chimeway.Orchestration.WindowMath` module with deterministic DST gap and ambiguity handling plus focused regression coverage.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add failing timezone and persistence contract tests** - `c3456b1` (test)
2. **Task 2: Persist orchestration fields and recipient timezone** - `3f02160` (test)
3. **Task 2: Persist orchestration fields and recipient timezone** - `bacfe61` (test)
4. **Task 2: Persist orchestration fields and recipient timezone** - `d6f48d9` (feat)

## Files Created/Modified
- `lib/chimeway/orchestration/window_math.ex` - Recipient-local quiet-hours calculations with deterministic DST handling.
- `priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` - Adds durable orchestration columns and a deferred-query index.
- `priv/repo/migrations/20260428093100_add_time_zone_to_chimeway_policy_settings.exs` - Adds recipient `time_zone` storage.
- `lib/chimeway/delivery.ex` - Exposes orchestration fields on the canonical delivery schema and changeset.
- `lib/chimeway/policy/settings.ex` and `lib/chimeway/policy/settings/setting.ex` - Persist and validate `time_zone` through insert and conflict-update paths.
- `config/config.exs`, `mix.exs`, `mix.lock` - Wires `Tzdata.TimeZoneDatabase` and installs `tzdata`.
- `test/chimeway/deliveries_test.exs`, `test/chimeway/policy_settings_test.exs`, `test/chimeway/orchestration/window_math_test.exs` - Cover ready-state defaults, timezone validation/upserts, and DST-sensitive window math.

## Decisions Made
- Used first-class delivery columns for orchestration state and eligibility time so Phase 18 scheduling and Phase 22 analytics can query stable fields cheaply.
- Kept `time_zone` optional in policy settings, but enforced validity whenever present to satisfy the threat model at the host-input boundary.
- Chose a dedicated pure window-math module rather than embedding more logic in `Policy.Settings`, so future planning code can reuse the same DST-safe contract.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced the plan's invalid `mix test -x` verifier**
- **Found during:** Task 1 (Add failing timezone and persistence contract tests)
- **Issue:** The plan's verification command used unsupported `mix test -x` flags in this repo.
- **Fix:** Verified the same targeted suites with `mix test ... --trace` instead.
- **Files modified:** None
- **Verification:** Targeted tests failed in RED and passed in GREEN with the corrected command.
- **Committed in:** N/A

**2. [Rule 1 - Bug] Fixed newly added test assertions to match this repo's test helpers**
- **Found during:** Task 1 and Task 2
- **Issue:** The first RED test used a nonexistent `errors_on/1` helper, and the later invalid-time-zone assertion expected the wrong `traverse_errors/2` shape.
- **Fix:** Rewrote the assertions to inspect `Ecto.Changeset.traverse_errors/2` directly.
- **Files modified:** `test/chimeway/policy_settings_test.exs`
- **Verification:** Focused suite passed after the assertion fixes.
- **Committed in:** `c3456b1`, `d6f48d9`

**3. [Rule 2 - Missing Critical] Added a dedicated window-math module not enumerated in `files_modified`**
- **Found during:** Task 2 (Persist orchestration fields and recipient timezone)
- **Issue:** The plan required DST-safe, reusable recipient-local window math, but no implementation file was listed for that behavior.
- **Fix:** Added `lib/chimeway/orchestration/window_math.ex` and wired tests around it.
- **Files modified:** `lib/chimeway/orchestration/window_math.ex`
- **Verification:** `test/chimeway/orchestration/window_math_test.exs` passes for normal, gap, and ambiguous cases.
- **Committed in:** `d6f48d9`

---

**Total deviations:** 3 auto-fixed (1 blocking, 1 bug, 1 missing critical)
**Impact on plan:** All deviations were necessary to keep the TDD flow valid and to satisfy the phase's durability and DST-safety requirements. No architectural scope creep.

## Issues Encountered
- Formatting surfaced a reserved-word bug in the first `WindowMath` implementation (`after` in a pattern match); it was corrected before verification.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 18 can now resume deferred deliveries against durable `orchestration_state`, `planning_reason`, `planning_context`, and `next_eligible_at` fields.
- Outcome analytics and trace surfaces can build on stable orchestration columns instead of metadata-only inspection.
- Host apps will need to run the new migrations when adopting this phase.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/17-delivery-windows-deferral-semantics/17-01-SUMMARY.md`.
- Commits `c3456b1`, `3f02160`, `bacfe61`, and `d6f48d9` exist in git history.

---
*Phase: 17-delivery-windows-deferral-semantics*
*Completed: 2026-04-28*
