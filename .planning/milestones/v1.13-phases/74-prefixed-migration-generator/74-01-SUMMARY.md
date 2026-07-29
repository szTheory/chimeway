---
phase: 74-prefixed-migration-generator
plan: 01
subsystem: installer
tags: [elixir, mix-task, ecto, migrations, postgres-prefix]

requires:
  - phase: 73-storage-prefix-contract
    provides: runtime prefix decisions and explicit public-schema legacy semantics
provides:
  - Strict `mix chimeway.gen.migrations` CLI parsing for default, chimeway, and public generation modes
  - Installer-core `prefix: :chimeway | :public` generation option
  - `render_template/3` hook composing host namespace rewrite with explicit prefix sentinel rendering
  - Focused ExUnit coverage for accepted/rejected CLI inputs and runtime-config-independent rendering
affects:
  - phase-74-prefixed-migration-generator
  - phase-74-wave-2-template-helper-conversion
  - phase-74-dual-fixture-proof

tech-stack:
  added: []
  patterns:
    - Strict `OptionParser.parse/2` closed-set CLI parsing
    - Generation mode passed explicitly from Mix task to installer core
    - Narrow sentinel replacement after namespace rewrite, with relation qualification deferred to template helpers

key-files:
  created:
    - .planning/phases/74-prefixed-migration-generator/74-01-SUMMARY.md
  modified:
    - lib/mix/tasks/chimeway.gen.migrations.ex
    - lib/chimeway/install/migrations.ex
    - test/chimeway/install/migrations_test.exs

key-decisions:
  - "[74-01]: Generator mode is selected only from CLI argv: default and `--prefix chimeway` normalize to `:chimeway`, while `--prefix public` normalizes to `:public`."
  - "[74-01]: Installer rendering replaces only the explicit `__CHIMEWAY_PREFIX__` sentinel after host namespace rewrite; table, index, reference, alter, drop, and raw SQL qualification remain template-helper work for later Phase 74 plans."

patterns-established:
  - "Mix task parser errors include the two accepted user-facing commands: `mix chimeway.gen.migrations --prefix chimeway` and `mix chimeway.gen.migrations --prefix public`."
  - "`Chimeway.Install.Migrations.run/1` accepts `prefix: :chimeway | :public` and defaults to `:chimeway` without reading runtime storage prefix config."

requirements-completed: [MIG-01, MIG-03]

duration: 4 min
completed: 2026-06-30
status: complete
---

# Phase 74 Plan 01: CLI/Core Generation-Mode Contract Summary

**Strict migration generator mode selection with argv-only prefix parsing and installer-core sentinel rendering.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-30T23:41:23Z
- **Completed:** 2026-06-30T23:45:44Z
- **Tasks:** 1
- **Files modified:** 4

## Accomplishments

- Added failing and then passing ExUnit coverage for the new generator-mode contract.
- Updated `mix chimeway.gen.migrations` to accept only default, `--prefix chimeway`, and `--prefix public` modes.
- Added actionable Mix errors for unsupported prefix values, unknown switches, and positional args.
- Added installer-core render plumbing that composes namespace rewrite with explicit prefix sentinel rendering.
- Verified generation mode is driven by command arguments/render arguments, not `config :chimeway, :prefix`.

## Task Commits

Each TDD step was committed atomically:

1. **Task 1 RED: generation-mode contract tests** - `78011c7` (test)
2. **Task 1 GREEN: generation-mode CLI and renderer** - `3ce9553` (feat)

## Files Created/Modified

- `lib/mix/tasks/chimeway.gen.migrations.ex` - Adds strict `--prefix` parsing, accepted-mode normalization, and actionable usage errors.
- `lib/chimeway/install/migrations.ex` - Adds `prefix: :chimeway | :public` option handling and `render_template/3` prefix sentinel rendering.
- `test/chimeway/install/migrations_test.exs` - Covers accepted/rejected CLI modes and render sentinel behavior.
- `.planning/phases/74-prefixed-migration-generator/74-01-SUMMARY.md` - Records execution evidence and plan metadata.

## Decisions Made

- Generator mode is an argv contract, not a runtime application config contract. Runtime `config :chimeway, :prefix` is deliberately not read by the Mix task or installer core.
- Rendering is intentionally narrow: replace `__CHIMEWAY_PREFIX__` and preserve the existing host namespace rewrite. Later template plans own helper-based relation qualification.

## Verification

- RED expected failure: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` failed with 4 expected failures before implementation (`render_template/3` missing, `--prefix` rejected, errors not actionable).
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` (16 tests, 0 failures)
- PASS: `mix format --check-formatted lib/mix/tasks/chimeway.gen.migrations.ex lib/chimeway/install/migrations.ex test/chimeway/install/migrations_test.exs`
- PASS: `bash -lc 'if rg -n "Application\\.(fetch|get)_env\\(:chimeway, :prefix|Chimeway\\.Storage\\.validate_prefix|Chimeway\\.Storage\\.repo_opts" lib/mix/tasks/chimeway.gen.migrations.ex lib/chimeway/install/migrations.ex; then exit 1; fi'`

## TDD Gate Compliance

- RED commit `78011c7` exists before GREEN commit `3ce9553`.
- RED failed for the intended missing behavior.
- GREEN passed all plan-level verification commands.
- No refactor commit was needed.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

The focused test command emitted known non-failing Threadline sandbox cleanup logs during subprocess-heavy tests. The suite completed green with 16 tests and 0 failures.

## Known Stubs

None. Stub-pattern scan only found test assertions and heredoc literals, not runtime/UI stubs or placeholder implementation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 74-02. Template conversion plans can now render `__CHIMEWAY_PREFIX__` through the installer core and rely on the Mix task to pass `:chimeway` or `:public` deterministically.

## Self-Check: PASSED

- Found summary file: `.planning/phases/74-prefixed-migration-generator/74-01-SUMMARY.md`.
- Found plan-owned files: `lib/mix/tasks/chimeway.gen.migrations.ex`, `lib/chimeway/install/migrations.ex`, `test/chimeway/install/migrations_test.exs`.
- Found task commits: `78011c7`, `3ce9553`.
- Stub scan found no placeholder/TODO/FIXME or runtime/UI stub content in plan-owned source and test files.
- No tracked file deletions were introduced by any 74-01 task commit.

---
*Phase: 74-prefixed-migration-generator*
*Completed: 2026-06-30*
