---
phase: 74-prefixed-migration-generator
plan: 10
subsystem: installer
tags: [elixir, ecto, migrations, postgres-prefix, ci, verification]

requires:
  - phase: 74-prefixed-migration-generator
    provides: 74-09 dual prefixed/public installer fixture roots
provides:
  - Static generated-output prefix contract over committed prefixed fixtures
  - Database migration execution and rollback proof for generated prefixed and public fixture roots
  - Local `verify.install_golden` proof alias and `ci.install_golden` parity alias
  - GitHub Actions `install_golden_contract` PostgreSQL 15 parity job
affects:
  - phase-74-final-verification
  - installer-golden-contract-ci

tech-stack:
  added: []
  patterns:
    - Generated fixture migrations are copied to deterministic numeric temp filenames before `Ecto.Migrator` execution
    - Generated migration DB proof uses per-mode temporary PostgreSQL databases to avoid mutating the main test schema
    - `verify.install_golden` is the local proof command; `ci.install_golden` delegates to the same proof

key-files:
  created:
    - .planning/phases/74-prefixed-migration-generator/74-10-SUMMARY.md
    - test/chimeway/install/prefix_contract_test.exs
  modified:
    - test/chimeway/migration_contract_test.exs
    - mix.exs
    - .github/workflows/ci.yml
    - MAINTAINING.md

key-decisions:
  - "[74-10]: Static prefix proof scans the committed generated prefixed fixture output, not only canonical templates."
  - "[74-10]: Generated DB proof uses isolated temporary databases per mode so explicit public generated migrations can create public-schema objects without colliding with the repo test database."
  - "[74-10]: Timestamp-normalized fixture files are copied to deterministic numeric migration filenames based on fixture stdout order before normal `Ecto.Migrator` execution."
  - "[74-10]: `ci.install_golden` delegates to `verify.install_golden`, and the CI `install_golden_contract` job provisions PostgreSQL 15 before invoking the same proof."

patterns-established:
  - "Installer verification now covers golden diff, second-run idempotency, static prefix qualification, generated prefixed DB migration execution/rollback, generated public DB migration execution/rollback, and local/CI alias parity."
  - "Runtime compiler warnings from loading generated fixture migrations are captured inside the DB proof so logs stay focused while migration exceptions still fail tests."

requirements-completed: [MIG-01, MIG-02, MIG-03, MIG-04]

duration: 25 min
completed: 2026-07-01
status: complete
---

# Phase 74 Plan 10: Static, DB, Verify, and CI Parity Proof Summary

**Phase 74 now has static generated-output proof, database execution/rollback proof for both generated modes, and local/CI installer gate parity.**

## Performance

- **Duration:** 25 min
- **Completed:** 2026-07-01T02:07:00Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments

- Added `Chimeway.Install.PrefixContractTest` to scan committed prefixed generated migrations for the chimeway sentinel, unsafe false-prefix opts, missed bare Ecto Chimeway operations, missed bare raw SQL relations, and destructive schema cleanup.
- Extended `Chimeway.MigrationContractTest` to execute generated prefixed and generated public fixture roots through normal `Ecto.Migrator` up/down flows.
- Added deterministic temp migration materialization from `STDOUT.txt` order so timestamp-normalized fixture files can run as normal Ecto migrations.
- Added isolated temporary PostgreSQL databases per generated mode to avoid mutating or colliding with the root test schema.
- Added `mix verify.install_golden` and made `mix ci.install_golden` delegate to it.
- Updated the CI `install_golden_contract` job with PostgreSQL 15 service wiring, root DB setup, new path gates, and the shared proof command.
- Updated `MAINTAINING.md` with the mode-named fixture roots and required installer verification gate.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Add generated migration proof contracts** - `7109c27` (test)
2. **Task 1 GREEN: Add install golden verification parity** - `21bce82` (feat)

## Files Created/Modified

- `test/chimeway/install/prefix_contract_test.exs` - Adds static generated-output prefix and local/CI parity contracts.
- `test/chimeway/migration_contract_test.exs` - Adds generated prefixed/public `Ecto.Migrator` execution and rollback proof.
- `mix.exs` - Adds `verify.install_golden` and points `ci.install_golden` at it.
- `.github/workflows/ci.yml` - Adds PostgreSQL 15 service wiring and invokes `mix verify.install_golden` in the path-gated installer job.
- `MAINTAINING.md` - Documents the new fixture roots and installer verification gate.
- `.planning/phases/74-prefixed-migration-generator/74-10-SUMMARY.md` - Records execution evidence and plan metadata.

## Decisions Made

- Kept Oban prefix behavior separate; installer verification remains focused on generated Chimeway migrations.
- Used temporary databases instead of dropping public Chimeway objects in the root test database.
- Captured runtime compiler warnings from loading generated fixture migrations to keep DB proof output readable without weakening failure behavior.
- Kept `install_golden_contract` outside `ci-gate`, preserving the existing release-gate contract.

## Verification

- CONFIRMED RED: Before implementation, `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` failed on the planned missing alias/CI parity assertion (10 tests, 1 planned failure).
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` (10 tests, 0 failures).
- PASS: `mix verify.install_golden` (14 tests, 0 failures).
- PASS: `mix ci.install_golden` (14 tests, 0 failures).
- PASS: `mix format --check-formatted test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs mix.exs`.

## TDD Gate Compliance

- RED commit `7109c27` added the static, DB, and alias/CI parity contracts; the focused suite failed on the missing `verify.install_golden` alias before implementation.
- GREEN commit `21bce82` added the alias, CI, and docs wiring; all focused and alias gates passed afterward.

## Deviations from Plan

- The key-link helper reported two false negatives after implementation: an invalid regex parse for `Ecto\\.Migrator` and an escaped-pattern mismatch for `verify\\.install_golden`. Manual evidence exists in the source files and passing tests: `test/chimeway/migration_contract_test.exs` invokes `Ecto.Migrator`, while `mix.exs` and `.github/workflows/ci.yml` both contain `verify.install_golden`.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change; the source and executable tests prove the intended links.

## Issues Encountered

- Generated fixture migrations emit runtime compiler warnings for helper default arguments when loaded through `Ecto.Migrator`. The DB proof captures those warnings; migration failures still propagate normally.
- The focused and alias test commands still emit known non-failing Threadline sandbox cleanup logs during test application shutdown. All suites completed green.

## Known Stubs

None. The new contracts execute real generated fixture migrations against PostgreSQL.

## User Setup Required

Local `mix verify.install_golden` requires a reachable PostgreSQL test database, matching the DB-backed Chimeway test setup. CI provisions PostgreSQL 15 in the path-gated installer job.

## Next Phase Readiness

Ready for Phase 74 verification. All 10 Phase 74 plans are complete, and the installer gate now exercises deterministic generated output plus normal DB execution for prefixed and public modes.

## Self-Check: PASSED

- Found task commits: `7109c27` and `21bce82`.
- Found summary file: `.planning/phases/74-prefixed-migration-generator/74-10-SUMMARY.md`.
- Found `verify.install_golden` and `ci.install_golden` aliases in `mix.exs`.
- Found CI `install_golden_contract` PostgreSQL 15 service and `mix verify.install_golden` invocation.
- Verified roadmap plan checkbox update for 74-10.

---
*Phase: 74-prefixed-migration-generator*
*Completed: 2026-07-01*
