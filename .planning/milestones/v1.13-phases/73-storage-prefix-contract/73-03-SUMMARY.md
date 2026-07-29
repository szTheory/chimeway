---
phase: 73-storage-prefix-contract
plan: 03
subsystem: docs
tags: [elixir, ecto, docs, postgres-prefix, contract-tests]

requires:
  - phase: 73-storage-prefix-contract
    provides: strict runtime prefix values and public legacy semantics from Plan 73-01
provides:
  - README runtime storage-prefix choice copy
  - Installation guide runtime storage-prefix choice copy
  - Golden path runtime storage-prefix choice copy
  - Doc contracts for accepted prefix snippets and public legacy no-move copy
  - Migration contract naming that frames current public checks as legacy compatibility
affects:
  - phase-74-prefixed-migration-generator
  - phase-75-runtime-prefix-propagation
  - phase-76-prefix-docs-demo-gates

tech-stack:
  added: []
  patterns:
    - Stable short-phrase doc contracts for adopter-facing configuration copy
    - Legacy public-schema compatibility named explicitly in DB-backed contracts

key-files:
  created:
    - .planning/phases/73-storage-prefix-contract/73-03-SUMMARY.md
  modified:
    - README.md
    - guides/introduction/installation.md
    - guides/introduction/golden-path.md
    - test/chimeway/doc_contract_test.exs
    - test/chimeway/migration_contract_test.exs

key-decisions:
  - "[73-03]: Public docs show `prefix: \"chimeway\"` for new isolated Chimeway schema installs and `prefix: false` only for existing public-schema legacy installs."
  - "[73-03]: `prefix: false` copy explicitly says Chimeway keeps existing public/unprefixed tables and does not move data."
  - "[73-03]: Current public migration contract remains a legacy compatibility proof; migration templates and generator behavior stay unchanged for Phase 74."

patterns-established:
  - "Doc contracts lock small stable phrases instead of full paragraphs."
  - "Public-schema DB contract tests are named as legacy compatibility, not new-install default behavior."

requirements-completed: [PFX-01, PFX-04, UPG-01]

duration: 6 min
completed: 2026-06-30
status: complete
---

# Phase 73 Plan 03: Storage Prefix Contract Summary

**Runtime prefix documentation now distinguishes new schema-isolated installs from explicit public-schema legacy compatibility, with contract tests locking the copy.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-30T18:48:07Z
- **Completed:** 2026-06-30T18:53:57Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added README, installation guide, and golden path copy for both accepted runtime snippets: `prefix: "chimeway"` and `prefix: false`.
- Framed `prefix: false` as only for an existing public-schema legacy install and stated that it keeps existing unprefixed tables and does not move data.
- Extended doc contracts to require stable storage-prefix phrases and forbid generator-prefix or automatic-move claims in the three adopter docs.
- Renamed the current DB migration contract tests so public-schema table/index/column checks are explicit legacy compatibility proof.

## Task Commits

Each TDD step was committed atomically:

1. **Task 1 RED: storage prefix doc contract** - `f7fbcc4` (test)
2. **Task 1 GREEN: runtime storage prefix docs** - `2d4e225` (docs)
3. **Task 2 RED: legacy migration label contract** - `886c26b` (test)
4. **Task 2 GREEN: public migration contract labels** - `39cbfc2` (test)

## Files Created/Modified

- `README.md` - Added compact runtime storage-prefix install copy.
- `guides/introduction/installation.md` - Added explicit storage-prefix choice and public legacy no-move copy.
- `guides/introduction/golden-path.md` - Added runtime storage-prefix choice before first trigger usage.
- `test/chimeway/doc_contract_test.exs` - Added required short phrases and forbidden drift phrases for storage-prefix docs.
- `test/chimeway/migration_contract_test.exs` - Added and satisfied a label contract for legacy public-schema compatibility checks.

## Decisions Made

- New docs present `prefix: "chimeway"` first as the new isolated Chimeway schema path.
- `prefix: false` remains a runtime compatibility path only for existing public-schema installs with unprefixed Chimeway tables.
- Migration generator flags, prefixed migration output, Oban prefix proof, demo-host schema proof, and automatic data movement remain out of Phase 73 Plan 03.

## Verification

- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` (397 tests, 0 failures)
- PASS: `bash -lc 'if rg -n -- "--prefix|automatic data move|automatically move|Oban prefix|oban prefix" README.md guides/introduction/installation.md guides/introduction/golden-path.md; then exit 1; fi'`
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix ecto.create`
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix ecto.migrate`
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/migration_contract_test.exs --warnings-as-errors` (3 tests, 0 failures)
- PASS: `git diff --exit-code -- priv/chimeway_migrations lib/chimeway/install/migrations.ex lib/mix/tasks/chimeway.gen.migrations.ex`
- PASS: `mix format --check-formatted test/chimeway/doc_contract_test.exs test/chimeway/migration_contract_test.exs`
- OUT OF SCOPE: full `mix format --check-formatted` still reports pre-existing unrelated format drift outside the 73-03 file list; no unrelated files were changed.

## TDD Gate Compliance

- RED commits exist before GREEN commits for both TDD tasks.
- GREEN verification passed after each implementation commit.
- No refactor commits were needed.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Full-repo `mix format --check-formatted` fails on unrelated pre-existing files outside this plan's file list. The plan-owned Elixir test files pass targeted format verification.

## Known Stubs

None. Stub-pattern scan found only existing contract-test text that forbids placeholder language, not a runtime or UI stub introduced by this plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Phase 74 migration generator work. Public docs and tests now distinguish the default `chimeway` schema path from explicit public legacy compatibility without changing migration generation or runtime propagation.

## Self-Check: PASSED

- Found created summary path: `.planning/phases/73-storage-prefix-contract/73-03-SUMMARY.md`.
- Found plan-owned files: `README.md`, `guides/introduction/installation.md`, `guides/introduction/golden-path.md`, `test/chimeway/doc_contract_test.exs`, `test/chimeway/migration_contract_test.exs`.
- Found commits: `f7fbcc4`, `2d4e225`, `886c26b`, `39cbfc2`.
- No tracked file deletions were introduced by any 73-03 task commit.

---
*Phase: 73-storage-prefix-contract*
*Completed: 2026-06-30*
