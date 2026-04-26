---
phase: 13-policy-preference-maturity
plan: "02"
subsystem: policy
tags: [policy, quiet-hours, delivery-caps, ecto]

requires:
  - phase: 12-oban-transactional-dispatch-consistency
    provides: transactional Oban dispatch baseline
  - plan: 13-01
    provides: preference scope vocabulary used by policy evaluation
provides:
  - per-recipient quiet-hours and delivery-cap policy settings storage
  - settings-context evaluation helper returning fixed suppress atoms
affects:
  - phase 13-policy-preference-maturity (13-03 wiring)

tech-stack:
  added:
    - Ecto schema for policy settings
  patterns:
    - one policy-settings row per recipient
    - cap-window evaluation via prior-delivery counts

key-files:
  created:
    - lib/chimeway/policy/settings.ex
    - lib/chimeway/policy/settings/setting.ex
    - priv/repo/migrations/20260425000200_create_chimeway_policy_settings.exs
  modified:
    - test/chimeway/policy_settings_test.exs

key-decisions:
  - "Use one policy-settings row per recipient for quiet hours and delivery caps."
  - "Count prior deliveries in the configured cap window to enforce delivery caps without runtime atoms or caller input."

patterns-established:
  - "Single-row settings model: one row per recipient holds quiet-hours window + cap config."
  - "Fixed suppress reasons: settings evaluation returns a small, stable atom set only."

requirements-completed: ["POL-02"]

duration: ~9 min
completed: 2026-04-25
---

# Phase 13, Plan 02: Policy Settings Summary

**Chimeway now persists per-recipient quiet-hours and delivery-cap settings with a deterministic evaluation helper that returns only fixed suppress reasons.**

## Performance

- **Tasks:** 3/3
- **Files modified:** 4
- **Verification:** `mix compile --warnings-as-errors`, `mix test test/chimeway/policy_settings_test.exs`

## Accomplishments

- Added `chimeway_policy_settings` table with unique `recipient_id` index, quiet-hours window fields, and delivery-cap fields.
- Added `Chimeway.Policy.Settings.Setting` schema with bound validations on minute ranges, cap counts, and cap windows.
- Added `Chimeway.Policy.Settings` context with `upsert_settings/1`, `get_settings/1`, and `evaluate/1`.
- Implemented cap evaluation by counting prior deliveries inside the configured cap window — no caller input, no runtime atoms.
- Expanded `test/chimeway/policy_settings_test.exs` with persistence, default behavior, invalid bounds, and composite quiet-hours/cap evaluation cases.

## Task Commits

1. **Task 1+2+3 RED:** `97dc3c8` — `test(13-02): add failing policy settings tests`
2. **Task 1+2+3 GREEN:** `f931ca6` — `fix(13-02): add policy settings storage and evaluation helpers`

## Files Created/Modified

- `lib/chimeway/policy/settings/setting.ex` — Policy settings schema and changeset.
- `lib/chimeway/policy/settings.ex` — Settings context and evaluation helper.
- `priv/repo/migrations/20260425000200_create_chimeway_policy_settings.exs` — Table and unique index.
- `test/chimeway/policy_settings_test.exs` — Quiet-hours and cap regression coverage.

## Decisions Made

- One settings row per recipient — both quiet-hours and cap data live on the same record.
- Cap enforcement counts prior deliveries inside the configured window rather than tracking running totals in memory.
- All suppress reasons are fixed atoms returned by the settings evaluator.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Adjusted delivery-cap test ordering**

- **Found during:** Task 3 (`mix test test/chimeway/policy_settings_test.exs`)
- **Issue:** The first delivery was asserted after the second had already been inserted, making the cap check appear stricter than intended.
- **Fix:** Asserted the first delivery before inserting the second one.
- **Files modified:** `test/chimeway/policy_test.exs` (related delivery-cap fixture used by the policy suite during the same wave)
- **Verification:** Targeted suite re-run passed.
- **Committed in:** `f931ca6` (part of GREEN commit).

## TDD Gate Compliance

Compliant — `test(13-02)` commit precedes `fix(13-02)` commit.

## Verification Results

| Check | Result |
|-------|--------|
| `mix compile --warnings-as-errors` | PASS |
| `mix test test/chimeway/policy_settings_test.exs` | PASS |
| `rg "upsert_settings\|get_settings\|evaluate" lib/chimeway/policy/settings.ex` | matches present |

## Self-Check: PASSED

- Settings schema, migration, context, and evaluator exist on disk.
- All listed commits are present in git history.
- Phase-level `13-SUMMARY.md` corroborates this plan's outcomes (including the auto-fix above).
