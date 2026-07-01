---
phase: 74-prefixed-migration-generator
plan: 04
subsystem: installer
tags: [elixir, ecto, migrations, postgres-prefix, digest]

requires:
  - phase: 74-prefixed-migration-generator
    provides: 74-01 CLI/core generation-mode sentinel rendering
  - phase: 74-prefixed-migration-generator
    provides: 74-02 foundational local helper pattern
  - phase: 74-prefixed-migration-generator
    provides: 74-03 early alter/helper conversion pattern
provides:
  - Prefix-helper based canonical templates for migrations 011-015
  - Helper-qualified digest rule, bucket, membership, and emission operations
  - Public-mode helper branches that emit legacy unprefixed migration operations
affects:
  - phase-74-wave-2-template-helper-conversion
  - phase-74-dual-fixture-proof
  - phase-74-static-db-proof

tech-stack:
  added: []
  patterns:
    - Rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel in canonical migration templates
    - Local migration helper wrappers for Chimeway-owned digest tables, indexes, unique indexes, references, and alters
    - Public generation returns bare Ecto opts instead of passing `prefix: false`

key-files:
  created:
    - .planning/phases/74-prefixed-migration-generator/74-04-SUMMARY.md
  modified:
    - priv/chimeway_migrations/011_add_time_zone_to_chimeway_policy_settings.exs
    - priv/chimeway_migrations/012_create_chimeway_digest_rules.exs
    - priv/chimeway_migrations/013_create_chimeway_digest_buckets.exs
    - priv/chimeway_migrations/014_create_chimeway_digest_memberships.exs
    - priv/chimeway_migrations/015_alter_chimeway_digest_buckets_for_emission.exs

key-decisions:
  - "[74-04]: Time-zone and digest templates reuse the local helper/sentinel pattern from Plans 74-02 and 74-03."
  - "[74-04]: Digest foreign keys use `chimeway_references/2` so generated prefixed migrations qualify referenced Chimeway tables."
  - "[74-04]: Public generation stays legacy-unprefixed by rendering `@chimeway_prefix false` and returning bare Ecto opts."

patterns-established:
  - "Digest create templates use `chimeway_table/2`, `chimeway_index/3`, `chimeway_unique_index/3`, and `chimeway_references/2` around every Chimeway-owned relation."
  - "Digest alter templates use `chimeway_table/2`, `chimeway_index/3`, and `chimeway_references/2` instead of bare Chimeway table/index/reference calls."

requirements-completed: [MIG-02, MIG-03]

duration: 5 min
completed: 2026-06-30
status: complete
---

# Phase 74 Plan 04: Digest Helper Conversion Summary

**Migrations 011-015 now render schema-aware policy time-zone and digest operations while preserving public legacy output.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-01T00:09:28Z
- **Completed:** 2026-07-01T00:14:19Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments

- Added the rendered `@chimeway_prefix __CHIMEWAY_PREFIX__` sentinel to migrations 011-015.
- Converted the policy time-zone alter and digest create/alter operations to local prefix helpers.
- Qualified digest foreign keys to rules, buckets, deliveries, and notifications through `chimeway_references/2`.
- Preserved public generation semantics by returning bare Ecto opts when the sentinel renders to `false`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert time-zone and digest templates** - `a32901d` (feat)

## Files Created/Modified

- `priv/chimeway_migrations/011_add_time_zone_to_chimeway_policy_settings.exs` - Adds prefixed policy-setting alter helper.
- `priv/chimeway_migrations/012_create_chimeway_digest_rules.exs` - Adds prefixed digest-rule table and index helpers.
- `priv/chimeway_migrations/013_create_chimeway_digest_buckets.exs` - Adds prefixed digest-bucket table, rule reference, unique index, and lookup index helpers.
- `priv/chimeway_migrations/014_create_chimeway_digest_memberships.exs` - Adds prefixed membership table, bucket/delivery/notification reference helpers, and index helpers.
- `priv/chimeway_migrations/015_alter_chimeway_digest_buckets_for_emission.exs` - Adds prefixed bucket alter, delivery reference, and emission index helpers.
- `.planning/phases/74-prefixed-migration-generator/74-04-SUMMARY.md` - Records execution evidence and plan metadata.

## Decisions Made

- Followed the existing per-template helper pattern instead of introducing a shared migration helper abstraction.
- Kept every table name, index name, foreign-key target, column option, migration direction, and marker comment intact.
- Left dual golden fixtures, static generated-output proof, and DB migration proof to later Phase 74 plans as specified by the validation map.

## Verification

- PASS: `mix format --check-formatted priv/chimeway_migrations/011_add_time_zone_to_chimeway_policy_settings.exs priv/chimeway_migrations/012_create_chimeway_digest_rules.exs priv/chimeway_migrations/013_create_chimeway_digest_buckets.exs priv/chimeway_migrations/014_create_chimeway_digest_memberships.exs priv/chimeway_migrations/015_alter_chimeway_digest_buckets_for_emission.exs`
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` (16 tests, 0 failures)
- PASS: static spot-check found no bare `table(:chimeway_*)`, `index(:chimeway_*)`, `unique_index(:chimeway_*)`, or `references(:chimeway_*)` calls in migrations 011-015.

## TDD Gate Compliance

- The plan task was marked `tdd="true"`, but this sequential run was restricted to templates 011-015 plus summary/tracking artifacts.
- Existing focused installer tests were used as the behavioral gate; adding a RED test commit would have required editing files outside the allowed plan-owned set.
- GREEN implementation commit `a32901d` exists and passed the required verification commands.

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

Ready for 74-05. The next wave-2 template batch can continue applying the same helper pattern to files 016-020.

---
*Phase: 74-prefixed-migration-generator*
*Completed: 2026-06-30*
