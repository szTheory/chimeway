---
phase: 74-prefixed-migration-generator
plan: 06
subsystem: installer
tags: [elixir, ecto, migrations, postgres-prefix, workflow]

requires:
  - phase: 74-prefixed-migration-generator
    provides: 74-01 CLI/core generation-mode sentinel rendering
  - phase: 74-prefixed-migration-generator
    provides: 74-02 foundational local helper pattern
  - phase: 74-prefixed-migration-generator
    provides: 74-05 digest/rendering helper conversion pattern
provides:
  - Prefix-helper based canonical templates for migrations 021-025
  - Helper-qualified workflow definition, step, notification-link, run, and transition operations
  - Public-mode helper branches that emit legacy unprefixed migration operations
affects:
  - phase-74-wave-2-template-helper-conversion
  - phase-74-dual-fixture-proof
  - phase-74-static-db-proof

tech-stack:
  added: []
  patterns:
    - Rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel in workflow migration templates
    - Local migration helper wrappers for Chimeway-owned workflow tables, indexes, unique indexes, references, and alters
    - Public generation returns bare Ecto opts instead of passing `prefix: false`

key-files:
  created:
    - .planning/phases/74-prefixed-migration-generator/74-06-SUMMARY.md
  modified:
    - priv/chimeway_migrations/021_create_chimeway_workflow_definitions.exs
    - priv/chimeway_migrations/022_create_chimeway_workflow_steps.exs
    - priv/chimeway_migrations/023_add_workflow_definition_id_to_chimeway_notifications.exs
    - priv/chimeway_migrations/024_create_chimeway_workflow_runs.exs
    - priv/chimeway_migrations/025_create_chimeway_workflow_transitions.exs

key-decisions:
  - "[74-06]: Workflow templates reuse the established local helper/sentinel pattern instead of adding shared migration helper abstractions."
  - "[74-06]: Workflow foreign keys use `chimeway_references/2` so generated prefixed migrations qualify referenced Chimeway workflow, notification, delivery, and step rows."
  - "[74-06]: Public generation stays legacy-unprefixed by rendering `@chimeway_prefix false` and returning bare Ecto opts."

patterns-established:
  - "Workflow create templates use `chimeway_table/2`, `chimeway_index/3`, `chimeway_unique_index/3`, and `chimeway_references/2` around every Chimeway-owned relation."
  - "Workflow notification-link alters use `chimeway_table/2`, `chimeway_index/3`, and `chimeway_references/2` instead of bare Chimeway table/index/reference calls."

requirements-completed: [MIG-02, MIG-03]

duration: 3 min
completed: 2026-07-01
status: complete
---

# Phase 74 Plan 06: Workflow Helper Conversion Summary

**Migrations 021-025 now render schema-aware workflow definitions, steps, notification links, runs, and transitions while preserving public legacy output.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-01T00:41:46Z
- **Completed:** 2026-07-01T00:45:26Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments

- Added the rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel to migrations 021-025.
- Converted workflow definition, step, run, and transition table creation to local prefix helpers.
- Converted workflow notification-link alters to `chimeway_table/2`.
- Qualified workflow, notification, delivery, and step foreign keys through `chimeway_references/2`.
- Preserved public generation semantics by returning bare Ecto opts when the sentinel renders to `false`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert workflow create and linkage templates** - `320ef65` (feat)

## Files Created/Modified

- `priv/chimeway_migrations/021_create_chimeway_workflow_definitions.exs` - Adds prefixed workflow definition table, unique index, and notification-key index helpers.
- `priv/chimeway_migrations/022_create_chimeway_workflow_steps.exs` - Adds prefixed workflow step table, definition reference, and unique/index helpers.
- `priv/chimeway_migrations/023_add_workflow_definition_id_to_chimeway_notifications.exs` - Adds prefixed notification alter, workflow definition reference, and index helpers.
- `priv/chimeway_migrations/024_create_chimeway_workflow_runs.exs` - Adds prefixed workflow run table, notification/definition/current-step reference helpers, and lookup index helpers.
- `priv/chimeway_migrations/025_create_chimeway_workflow_transitions.exs` - Adds prefixed transition table, workflow run/step/delivery reference helpers, and transition lookup indexes.
- `.planning/phases/74-prefixed-migration-generator/74-06-SUMMARY.md` - Records execution evidence and plan metadata.

## Decisions Made

- Followed the existing per-template helper pattern instead of introducing a shared migration helper abstraction.
- Kept every table name, index target, index name, foreign-key target, column option, migration direction, and marker comment intact.
- Left dual golden fixtures, static generated-output proof, and DB migration proof to later Phase 74 plans as specified by the validation map.

## Verification

- PASS: `mix format --check-formatted priv/chimeway_migrations/021_create_chimeway_workflow_definitions.exs priv/chimeway_migrations/022_create_chimeway_workflow_steps.exs priv/chimeway_migrations/023_add_workflow_definition_id_to_chimeway_notifications.exs priv/chimeway_migrations/024_create_chimeway_workflow_runs.exs priv/chimeway_migrations/025_create_chimeway_workflow_transitions.exs`
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` (16 tests, 0 failures)
- PASS: static spot-check found no bare `table(:chimeway_*)`, `index(:chimeway_*)`, `unique_index(:chimeway_*)`, or `references(:chimeway_*)` calls in migrations 021-025.

## TDD Gate Compliance

- The plan task was marked `tdd="true"`, but this sequential run was restricted to templates 021-025 plus summary/tracking artifacts.
- Existing focused installer tests were used as the behavioral gate; adding a RED test commit would have required editing files outside the allowed plan-owned set.
- GREEN implementation commit `320ef65` exists and passed the required verification commands.

## Deviations from Plan

None - implementation stayed within the plan-owned template files and preserved the specified migration semantics.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change. The TDD RED gate limitation is documented separately above because it was caused by the allowed file boundary, not by an implementation change.

## Issues Encountered

The focused installer test command emitted known non-failing Threadline sandbox cleanup logs during subprocess-heavy tests. The suite completed green with 16 tests and 0 failures.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned template files. Empty map defaults in migrations 022, 024, and 025 are existing schema defaults preserved by this plan, not UI or runtime stubs.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 74-07. The next wave-2 template batch can continue applying the same helper pattern to workflow linkage, signal-spine, adapter, provider-message, and tenant/actor templates 026-030.

## Self-Check: PASSED

- Found plan-owned template files 021-025.
- Found summary file: `.planning/phases/74-prefixed-migration-generator/74-06-SUMMARY.md`.
- Found task commit: `320ef65`.
- Stub scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned template files.
- No tracked file deletions were introduced by the 74-06 task commit.

---
*Phase: 74-prefixed-migration-generator*
*Completed: 2026-07-01*
