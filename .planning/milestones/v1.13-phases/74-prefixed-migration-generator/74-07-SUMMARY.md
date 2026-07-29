---
phase: 74-prefixed-migration-generator
plan: 07
subsystem: installer
tags: [elixir, ecto, migrations, postgres-prefix, raw-sql, workflow]

requires:
  - phase: 74-prefixed-migration-generator
    provides: 74-01 CLI/core generation-mode sentinel rendering
  - phase: 74-prefixed-migration-generator
    provides: 74-06 workflow helper conversion pattern
provides:
  - Prefix-helper based canonical templates for migrations 026-030
  - Fixed-helper raw SQL relation qualification for signal-spine and tenant/actor backfills
  - Public-mode helper branches that emit legacy unprefixed migration operations and bare SQL relation names
affects:
  - phase-74-wave-2-template-helper-conversion
  - phase-74-dual-fixture-proof
  - phase-74-static-db-proof

tech-stack:
  added: []
  patterns:
    - Rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel in workflow linkage, signal, adapter, provider, and tenant/actor migration templates
    - Local migration helper wrappers for Chimeway-owned tables, indexes, references, and alters
    - Fixed accepted relation helpers for raw SQL qualification in migrations 027 and 030

key-files:
  created:
    - .planning/phases/74-prefixed-migration-generator/74-07-SUMMARY.md
  modified:
    - priv/chimeway_migrations/026_alter_chimeway_deliveries_for_workflow_linkage.exs
    - priv/chimeway_migrations/027_create_chimeway_signals_and_spine.exs
    - priv/chimeway_migrations/028_add_adapter_module_to_chimeway_delivery_attempts.exs
    - priv/chimeway_migrations/029_add_provider_message_id_to_delivery_attempts.exs
    - priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs

key-decisions:
  - "[74-07]: Workflow linkage, signal spine, adapter, provider, and tenant/actor templates reuse the local helper/sentinel pattern from earlier Phase 74 template batches."
  - "[74-07]: Signal-spine and tenant/actor raw SQL is built through fixed `chimeway_relation/1` helpers that accept only the Chimeway-owned relations referenced by each template."
  - "[74-07]: Public generation stays legacy-unprefixed by rendering `@chimeway_prefix false`, returning bare Ecto opts, and emitting bare SQL relation names."

patterns-established:
  - "Workflow linkage and adapter/provider alter templates use `chimeway_table/2`, `chimeway_index/3`, and `chimeway_references/2` around Chimeway-owned operations."
  - "Raw SQL templates use fixed relation helpers for known Chimeway-owned relations instead of broad generated-file string rewriting."

requirements-completed: [MIG-02, MIG-03]

duration: 3 min
completed: 2026-07-01
status: complete
---

# Phase 74 Plan 07: Signal Spine and Tenant Backfill Helper Conversion Summary

**Migrations 026-030 now render schema-aware workflow linkage, signal spine, adapter/provider, and tenant/actor backfill operations with fixed-helper raw SQL qualification.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-01T00:51:31Z
- **Completed:** 2026-07-01T00:54:16Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments

- Added the rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel to migrations 026-030.
- Converted workflow linkage, signal spine, adapter, provider-message, and tenant/actor Ecto operations to local prefix helpers.
- Qualified `chimeway_workflow_runs`, `chimeway_deliveries`, and `chimeway_notifications` raw SQL references through fixed `chimeway_relation/1` helpers.
- Preserved public generation semantics by returning bare Ecto opts and bare SQL relation names when the sentinel renders to `false`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert signal spine and tenant backfill templates** - `f0bea41` (feat)

## Files Created/Modified

- `priv/chimeway_migrations/026_alter_chimeway_deliveries_for_workflow_linkage.exs` - Adds prefixed delivery workflow linkage alter, reference, and index helpers.
- `priv/chimeway_migrations/027_create_chimeway_signals_and_spine.exs` - Adds prefixed workflow-run alter helpers, signal table/index helpers, and fixed workflow-run raw SQL relation qualification.
- `priv/chimeway_migrations/028_add_adapter_module_to_chimeway_delivery_attempts.exs` - Adds prefixed delivery-attempt adapter-module alter helper.
- `priv/chimeway_migrations/029_add_provider_message_id_to_delivery_attempts.exs` - Adds prefixed provider-message alter and index helpers.
- `priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs` - Adds prefixed delivery alter helpers and fixed delivery, notification, and workflow-run raw SQL relation qualification.
- `.planning/phases/74-prefixed-migration-generator/74-07-SUMMARY.md` - Records execution evidence and plan metadata.

## Decisions Made

- Followed the existing per-template helper pattern instead of introducing a shared migration helper abstraction.
- Kept raw SQL qualification intentionally narrow: file 027 only accepts `:chimeway_workflow_runs`; file 030 only accepts `:chimeway_deliveries`, `:chimeway_notifications`, and `:chimeway_workflow_runs`.
- Kept every marker comment, migration direction, flush placement, index target, foreign-key target, and column option intact.
- Left dual golden fixtures, static generated-output proof, and DB migration proof to later Phase 74 plans as specified by the validation map.

## Verification

- PASS: `mix format --check-formatted priv/chimeway_migrations/026_alter_chimeway_deliveries_for_workflow_linkage.exs priv/chimeway_migrations/027_create_chimeway_signals_and_spine.exs priv/chimeway_migrations/028_add_adapter_module_to_chimeway_delivery_attempts.exs priv/chimeway_migrations/029_add_provider_message_id_to_delivery_attempts.exs priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs`
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` (16 tests, 0 failures)
- PASS: static spot-check found no bare `table(:chimeway_*)`, `index(:chimeway_*)`, `unique_index(:chimeway_*)`, `references(:chimeway_*)`, `UPDATE chimeway_*`, or `FROM chimeway_*` operations in migrations 026-030.

## TDD Gate Compliance

- The plan task was marked `tdd="true"`, but this sequential run was restricted to templates 026-030 plus summary/tracking artifacts.
- Existing focused installer tests were used as the behavioral gate; adding a RED test commit would have required editing files outside the allowed plan-owned set.
- GREEN implementation commit `f0bea41` exists and passed the required verification commands.

## Deviations from Plan

None - implementation stayed within the plan-owned template files and preserved the specified migration semantics.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change. The TDD RED gate limitation is documented separately above because it was caused by the allowed file boundary, not by an implementation change.

## Issues Encountered

The focused installer test command emitted known non-failing Threadline sandbox cleanup logs during subprocess-heavy tests. The suite completed green with 16 tests and 0 failures.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned template files. Empty array/map defaults in migration 027 are existing schema defaults preserved by this plan, not UI or runtime stubs.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 74-08. The next wave-2 template batch can continue applying the same helper pattern to webhook ingress template 031.

## Self-Check: PASSED

- Found plan-owned template files 026-030.
- Found summary file: `.planning/phases/74-prefixed-migration-generator/74-07-SUMMARY.md`.
- Found task commit: `f0bea41`.
- Stub scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned template files.
- No tracked file deletions were introduced by the 74-07 task commit.

---
*Phase: 74-prefixed-migration-generator*
*Completed: 2026-07-01*
