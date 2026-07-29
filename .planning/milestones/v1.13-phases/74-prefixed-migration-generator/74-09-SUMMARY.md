---
phase: 74-prefixed-migration-generator
plan: 09
subsystem: installer
tags: [elixir, mix-task, migrations, postgres-prefix, fixtures, idempotency]

requires:
  - phase: 74-prefixed-migration-generator
    provides: 74-01 CLI/core generation-mode sentinel rendering
  - phase: 74-prefixed-migration-generator
    provides: 74-02 through 74-08 fully converted canonical migration templates
provides:
  - Mode-aware real subprocess installer fixture for default, explicit chimeway, and explicit public modes
  - Dual committed golden fixture roots for default prefixed and explicit public legacy output
  - Dual-mode golden diff and second-run idempotency proof
affects:
  - phase-74-static-db-proof
  - phase-74-ci-parity-proof

tech-stack:
  added: []
  patterns:
    - Real `mix chimeway.gen.migrations` subprocess fixture with explicit mode mapping
    - Mode-named fixture roots for reviewable generated host migration contracts
    - Golden and idempotency tests that exercise both default prefixed and explicit public modes

key-files:
  created:
    - .planning/phases/74-prefixed-migration-generator/74-09-SUMMARY.md
    - test/fixtures/installer_golden_prefixed/
    - test/fixtures/installer_golden_public/
  modified:
    - test/support/installer_fixture.ex
    - test/chimeway/install/golden_diff_test.exs
    - test/chimeway/install/idempotency_test.exs
    - test/fixtures/installer_golden/

key-decisions:
  - "[74-09]: `run_install!/2` keeps generation mode explicit: `:default` invokes the bare task, `:chimeway` passes `--prefix chimeway`, and `:public` passes `--prefix public`."
  - "[74-09]: The ambiguous single golden root was removed after `installer_golden_prefixed` and `installer_golden_public` became the committed product contracts."
  - "[74-09]: Public fixtures prove bare Ecto operations and bare raw SQL relation names without unsafe `prefix: false`; prefixed fixtures prove `\"chimeway\"` schema, table, index, reference, and raw SQL qualification."

patterns-established:
  - "Installer golden fixtures are mode-named and refreshed through the same real subprocess path used by the tests."
  - "Second-run idempotency is a product contract for both default prefixed generation and explicit public legacy generation."

requirements-completed: [MIG-01, MIG-02, MIG-03, MIG-04]

duration: 35 min
completed: 2026-07-01
status: complete
---

# Phase 74 Plan 09: Dual Fixture and Idempotency Proof Summary

**Installer fixture coverage now proves default prefixed generation and explicit public legacy generation through committed mode-named golden roots and second-run idempotency tests.**

## Performance

- **Duration:** 35 min
- **Completed:** 2026-07-01T01:52:11Z
- **Tasks:** 2
- **Files modified:** 6 logical paths plus generated fixture trees

## Accomplishments

- Extended `Chimeway.Test.InstallerFixture.run_install!/2` to drive the real Mix subprocess for default, explicit `chimeway`, and explicit `public` generation modes.
- Added mode-aware fixture helper behavior for selecting golden roots, loading golden trees/stdout, and refreshing fixtures.
- Updated golden diff tests to compare the generated prefixed and public outputs against separate committed fixture roots.
- Updated idempotency tests so both modes prove a second run creates no files and reports unchanged migrations.
- Replaced the old ambiguous `test/fixtures/installer_golden/` root with `test/fixtures/installer_golden_prefixed/` and `test/fixtures/installer_golden_public/`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend installer fixture and mode-loop tests** - `044cbb9` (test)
2. **Task 2: Commit dual golden fixture roots** - `4768031` (test)

## Files Created/Modified

- `test/support/installer_fixture.ex` - Adds explicit generation-mode handling while preserving real subprocess execution.
- `test/chimeway/install/golden_diff_test.exs` - Verifies default prefixed and explicit public generated output against mode-named fixture roots.
- `test/chimeway/install/idempotency_test.exs` - Verifies second-run unchanged behavior for both modes.
- `test/fixtures/installer_golden_prefixed/` - Committed default prefixed generated host migration fixture tree.
- `test/fixtures/installer_golden_public/` - Committed explicit public legacy generated host migration fixture tree.
- `test/fixtures/installer_golden/` - Removed ambiguous legacy fixture root.
- `.planning/phases/74-prefixed-migration-generator/74-09-SUMMARY.md` - Records execution evidence and plan metadata.

## Decisions Made

- Kept the real subprocess fixture as the single fixture refresh path so committed snapshots remain grounded in actual Mix task output.
- Made the golden fixture roots mode-named instead of keeping a generic root whose prefix semantics would require out-of-band knowledge.
- Treated public legacy generation as explicit `--prefix public` output and rejected unsafe generated `prefix: false` Ecto options in the fixture contract.

## Verification

- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs --warnings-as-errors`
- PASS: `MIX_INSTALLER_ACCEPT_GOLDEN=1 CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors`
- PASS: `mix format --check-formatted test/support/installer_fixture.ex test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs`

## TDD Gate Compliance

- RED coverage was added in `044cbb9` for the dual-mode fixture helper, golden diff, and idempotency contracts.
- GREEN fixture generation landed in `4768031` through the committed dual golden roots.
- The focused test commands above passed after both commits.

## Deviations from Plan

None - implementation stayed within the plan-owned fixture helper, installer tests, and fixture roots.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

- A previous executor left the implementation commits without the required summary artifact. This close-out adds the missing summary and state tracking without changing the implemented test or fixture behavior.
- The focused installer test command may emit known non-failing Threadline sandbox cleanup logs during subprocess-heavy tests; the suite completed green in the recorded verification.

## Known Stubs

None. The plan-owned test helper, tests, and committed fixture roots are concrete contracts, not placeholders.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 74-10. The final plan can consume the dual fixture roots for static generated-output proof, DB migration proof, verify aliases, and CI parity.

## Self-Check: PASSED

- Found task commits: `044cbb9` and `4768031`.
- Found summary file: `.planning/phases/74-prefixed-migration-generator/74-09-SUMMARY.md`.
- Found mode-named fixture roots: `test/fixtures/installer_golden_prefixed/` and `test/fixtures/installer_golden_public/`.
- Confirmed the old ambiguous `test/fixtures/installer_golden/` root is removed.
- Confirmed fixture roots contain 64 committed files across prefixed and public modes.

---
*Phase: 74-prefixed-migration-generator*
*Completed: 2026-07-01*
