---
phase: 73-storage-prefix-contract
plan: 02
subsystem: config
tags: [elixir, ecto, config, postgres-prefix, boot-validation]

requires:
  - phase: 73-storage-prefix-contract
    provides: ConfigError and Storage prefix validator from Plan 73-01
provides:
  - Early `Chimeway.Application.start/2` storage-prefix validation before child construction
  - Explicit repository public-schema runtime config via `prefix: false`
  - Boot-path tests for invalid and missing prefix config
  - Acceptance tests for explicit public-schema config under normal test runtime
affects:
  - phase-75-runtime-prefix-propagation
  - phase-76-prefix-docs-demo-gates

tech-stack:
  added: []
  patterns:
    - Boot-time config validation before supervised storage/job children are constructed
    - Explicit public-schema compatibility represented by `prefix: false`
    - Application env mutation tests snapshot and restore with `Application.fetch_env/2`

key-files:
  created:
    - .planning/phases/73-storage-prefix-contract/73-02-SUMMARY.md
  modified:
    - config/config.exs
    - lib/chimeway/application.ex
    - test/chimeway/application_validation_test.exs

key-decisions:
  - "[73-02]: This repository's current public-schema runtime is explicit with `config :chimeway, prefix: false`."
  - "[73-02]: Application boot validates storage prefix config before constructing Repo or Oban child specs."
  - "[73-02]: Missing prefix config tests delete `:prefix` explicitly and restore the prior application env snapshot."

patterns-established:
  - "`Chimeway.Application.start/2` keeps existing channel-render validation and then validates storage prefix before `children =`."
  - "Boot validation tests isolate global application env changes with `async: false`, `Application.fetch_env/2`, and `on_exit` restoration."

requirements-completed: [PFX-01, PFX-02]

duration: 10 min
completed: 2026-06-30
status: complete
---

# Phase 73 Plan 02: Storage Prefix Boot Contract Summary

**Application boot now rejects invalid storage-prefix config before Repo or Oban child specs are built, while this repository explicitly runs in public-schema legacy mode with `prefix: false`.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-06-30T18:56:00Z
- **Completed:** 2026-06-30T19:06:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `prefix: false` to the top-level `config :chimeway` block so current public-schema behavior is explicit.
- Wired `Chimeway.Storage.validate_prefix!/0` into `Chimeway.Application.start/2` before the supervised child list is constructed.
- Added boot-path tests proving invalid and missing prefix values raise `Chimeway.ConfigError` with stable structured fields.
- Added acceptance coverage proving the normal test config returns `false` through `Chimeway.Storage.validate_prefix!/0`.

## Task Commits

Each task step was committed atomically:

1. **Task 1 RED: boot prefix validation coverage** - `d6bddf5` (test)
2. **Task 1 GREEN: storage prefix boot validation** - `1abc925` (feat)
3. **Task 2: explicit public prefix acceptance coverage** - `0413be6` (test)

## Files Created/Modified

- `config/config.exs` - Adds explicit `prefix: false` to the repository's current Chimeway application config.
- `lib/chimeway/application.ex` - Calls `Chimeway.Storage.validate_prefix!/0` before `children =`.
- `test/chimeway/application_validation_test.exs` - Covers invalid/missing boot validation and accepted explicit public-schema config.

## Decisions Made

- Current repository/test behavior remains public-schema legacy mode, but it is represented by `prefix: false` instead of missing config.
- Prefix validation is part of application boot and runs before Repo/Oban child specs can be built.
- Missing-prefix tests use `Application.delete_env/2` directly so missing config cannot be hidden by defaults.

## Verification

- RED expected failure: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs --warnings-as-errors` failed with 2 expected failures before boot validation was wired.
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs --warnings-as-errors` (6 tests, 0 failures)
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/storage_test.exs --warnings-as-errors` (16 tests, 0 failures)
- PASS: `bash -lc 'if rg -n "Ecto.Adapters.SQL|information_schema|to_regclass|Repo\\." lib/chimeway/application.ex; then exit 1; fi'`
- PASS: `bash -lc 'if rg -n "prefix:" config/config.exs config/test.exs | rg "Oban"; then exit 1; fi'`
- PASS: `mix format --check-formatted config/config.exs lib/chimeway/application.ex test/chimeway/application_validation_test.exs`
- OUT OF SCOPE: `mix format --check-formatted` still fails on unrelated pre-existing formatting drift outside the 73-02 file list.

## TDD Gate Compliance

- Task 1 produced a RED test/config commit (`d6bddf5`) that failed before implementation, followed by a GREEN implementation commit (`1abc925`) that passed the focused tests.
- Task 2 was a test-only acceptance task. Its behavior was already satisfied by Plan 73-01 plus Task 1, so no GREEN source commit was needed.

## Deviations from Plan

None - plan scope executed as written.

## Issues Encountered

Full-repo `mix format --check-formatted` fails on unrelated pre-existing files outside this plan's declared file list. I did not modify those files. The plan-owned files pass targeted formatting.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Phase 74 and Phase 75. The prefix contract now fails early at boot, and runtime propagation work can rely on `Chimeway.Storage.validate_prefix!/0` and `Chimeway.Storage.repo_opts/1` without depending on missing config behavior.

## Self-Check: PASSED

- Found plan-owned files: `config/config.exs`, `lib/chimeway/application.ex`, `test/chimeway/application_validation_test.exs`.
- Found commits: `d6bddf5`, `1abc925`, `0413be6`.
- Stub scan found no placeholder/TODO/FIXME or hardcoded empty UI data patterns in plan-owned files.
- No tracked file deletions were introduced by any 73-02 task commit.

---
*Phase: 73-storage-prefix-contract*
*Completed: 2026-06-30*
