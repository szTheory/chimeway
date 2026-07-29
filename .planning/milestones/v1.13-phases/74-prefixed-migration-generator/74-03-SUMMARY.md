---
phase: 74-prefixed-migration-generator
plan: 03
subsystem: installer
tags: [elixir, ecto, migrations, postgres-prefix, raw-sql]

requires:
  - phase: 74-prefixed-migration-generator
    provides: 74-01 CLI/core generation-mode sentinel rendering
  - phase: 74-prefixed-migration-generator
    provides: 74-02 foundational local helper pattern
provides:
  - Prefix-helper based canonical templates for migrations 006-010
  - Fixed-helper raw SQL relation qualification for attempt-history backfill SQL
  - Public-mode helper branches that emit legacy unprefixed migration operations
affects:
  - phase-74-wave-2-template-helper-conversion
  - phase-74-dual-fixture-proof
  - phase-74-static-db-proof

tech-stack:
  added: []
  patterns:
    - Rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel in canonical migration templates
    - Local migration helper wrappers for Chimeway-owned tables, indexes, unique indexes, and alters
    - Fixed accepted relation helper for raw SQL qualification

key-files:
  created:
    - .planning/phases/74-prefixed-migration-generator/74-03-SUMMARY.md
  modified:
    - priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs
    - priv/chimeway_migrations/007_create_chimeway_category_preferences.exs
    - priv/chimeway_migrations/008_create_chimeway_policy_settings.exs
    - priv/chimeway_migrations/009_add_attempt_history_columns.exs
    - priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs

key-decisions:
  - "[74-03]: Early alter, category preference, policy setting, and delivery orchestration templates reuse the local helper/sentinel pattern from Plan 74-02."
  - "[74-03]: Attempt-history raw SQL is built through a fixed `chimeway_relation/1` helper that only accepts `:chimeway_delivery_attempts`."
  - "[74-03]: Public generation stays legacy-unprefixed by rendering `@chimeway_prefix false` and returning bare Ecto opts and relation names."

patterns-established:
  - "Alter templates use `chimeway_table/2` and index helpers instead of bare Chimeway table/index calls."
  - "Raw SQL templates use fixed relation helpers for known Chimeway-owned relations instead of broad string rewriting."

requirements-completed: [MIG-02, MIG-03]

duration: 3 min
completed: 2026-06-30
status: complete
---

# Phase 74 Plan 03: Early Helper and Attempt-History SQL Conversion Summary

**Migrations 006-010 now render schema-aware alters, preference tables, delivery orchestration indexes, and fixed-helper attempt-history SQL.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-01T00:02:14Z
- **Completed:** 2026-07-01T00:05:33Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments

- Added the rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel to migrations 006-010.
- Converted early alter, category preference, policy setting, attempt-history, and delivery orchestration operations to local helper wrappers.
- Qualified attempt-history raw SQL through a fixed `chimeway_relation/1` helper that only supports `:chimeway_delivery_attempts`.
- Preserved public generation semantics by returning bare Ecto opts and bare relation names when the sentinel renders to `false`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert early alter and attempt-history templates** - `6f92068` (feat)

## Files Created/Modified

- `priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs` - Adds prefixed event alter and correlation index helpers.
- `priv/chimeway_migrations/007_create_chimeway_category_preferences.exs` - Adds prefixed category preference table and unique index helpers.
- `priv/chimeway_migrations/008_create_chimeway_policy_settings.exs` - Adds prefixed policy setting table and unique index helpers.
- `priv/chimeway_migrations/009_add_attempt_history_columns.exs` - Adds prefixed attempt alter/index helpers and fixed-helper raw SQL relation qualification.
- `priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` - Adds prefixed delivery alter and orchestration index helpers.
- `.planning/phases/74-prefixed-migration-generator/74-03-SUMMARY.md` - Records execution evidence and plan metadata.

## Decisions Made

- Followed the Plan 74-02 per-template helper pattern instead of adding shared runtime/template abstractions.
- Kept raw SQL qualification intentionally narrow: `chimeway_relation/1` only accepts the known attempt-history table relation.
- Left golden fixture, static generated-output, and DB migration proof to later Phase 74 plans as specified by the validation map.

## Verification

- PASS: `mix format --check-formatted priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs priv/chimeway_migrations/007_create_chimeway_category_preferences.exs priv/chimeway_migrations/008_create_chimeway_policy_settings.exs priv/chimeway_migrations/009_add_attempt_history_columns.exs priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs`
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` (16 tests, 0 failures)
- PASS: rendered-template spot check confirmed file 009 renders `@chimeway_prefix "chimeway"` for prefixed mode, `@chimeway_prefix false` for public mode, includes the fixed `chimeway_relation(:chimeway_delivery_attempts)` helper, emits the quoted prefixed SQL expression branch, and keeps the bare relation branch for public mode.

## TDD Gate Compliance

- The plan task was marked `tdd="true"`, but this sequential run was restricted to templates 006-010 plus summary/tracking artifacts.
- Existing focused installer tests were used as the behavioral gate; adding a RED test commit would have required editing files outside the allowed plan-owned set.
- GREEN implementation commit `6f92068` exists and passed the required verification commands.

## Deviations from Plan

None - implementation stayed within the plan-owned template files and preserved the specified migration semantics.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change. The TDD RED gate limitation is documented separately above because it was caused by the allowed file boundary, not by an implementation change.

## Issues Encountered

The focused installer test command emitted known non-failing Threadline sandbox cleanup logs during subprocess-heavy tests. The suite completed green with 16 tests and 0 failures.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned template files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 74-04. The next wave-2 template batch can continue applying the same helper pattern to files 011-015.

## Self-Check: PASSED

- Found plan-owned template files 006-010.
- Found summary file: `.planning/phases/74-prefixed-migration-generator/74-03-SUMMARY.md`.
- Found task commit: `6f92068`.
- Stub scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned template files.
- No tracked file deletions were introduced by the 74-03 task commit.

---
*Phase: 74-prefixed-migration-generator*
*Completed: 2026-06-30*
