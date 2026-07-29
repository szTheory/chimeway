---
phase: 73-storage-prefix-contract
plan: 01
subsystem: storage
tags: [elixir, ecto, config, postgres-prefix]

requires:
  - phase: v1.13-storage-isolation-and-upgrade-path
    provides: storage prefix decisions and public-schema compatibility requirements
provides:
  - Structured `Chimeway.ConfigError` for invalid prefix configuration
  - Internal `Chimeway.Storage.validate_prefix!/0` strict config validator
  - Internal `Chimeway.Storage.repo_opts/1` prefix-to-repo-options helper
  - Unit tests covering accepted values, invalid values, and repo option mapping
affects:
  - phase-74-prefixed-migration-generator
  - phase-75-runtime-prefix-propagation
  - phase-76-prefix-docs-demo-gates

tech-stack:
  added: []
  patterns:
    - Structured Elixir exception with stable metadata fields
    - Fetch-style Application env validation with missing config treated as invalid
    - Centralized Ecto repo option mapping via `Keyword.put_new/3`

key-files:
  created:
    - lib/chimeway/config_error.ex
    - lib/chimeway/storage.ex
    - test/chimeway/storage_test.exs
    - .planning/phases/73-storage-prefix-contract/deferred-items.md
  modified: []

key-decisions:
  - "[73-01]: Missing `:prefix` config is invalid and is represented as rejected value `:missing`."
  - "[73-01]: Runtime storage prefix config accepts only `\"chimeway\"` and `false`."
  - "[73-01]: `repo_opts/1` uses `Keyword.put_new/3` so explicit caller probes can preserve their own `:prefix`."

patterns-established:
  - "Storage prefix validation is centralized in `Chimeway.Storage.validate_prefix!/0`."
  - "Public-schema compatibility is represented by `prefix: false`, not by the string `\"public\"`."

requirements-completed: [PFX-01, PFX-02, PFX-03, PFX-04]

duration: 5 min
completed: 2026-06-30
status: complete
---

# Phase 73 Plan 01: Storage Prefix Contract Summary

**Strict static storage-prefix validation with a branded config error and one internal repo option helper.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-30T18:38:26Z
- **Completed:** 2026-06-30T18:43:10Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added `Chimeway.ConfigError` with stable `:type`, `:key`, and `:value` fields for invalid prefix configuration.
- Added `Chimeway.Storage.validate_prefix!/0` accepting only `prefix: "chimeway"` and `prefix: false`.
- Added `Chimeway.Storage.repo_opts/1` to map validated prefix config to Ecto repo options while preserving explicit caller prefixes.
- Added focused unit tests for accepted values, missing config, invalid static/dynamic-looking values, and repo option mapping.

## Task Commits

Each TDD step was committed atomically:

1. **Task 1 RED: ConfigError contract test** - `97ca0de` (test)
2. **Task 1 GREEN: ConfigError implementation** - `f0be00a` (feat)
3. **Task 2 RED: Storage helper tests** - `b537e89` (test)
4. **Task 2 GREEN: Storage helper implementation** - `ed6a8f5` (feat)

## Files Created/Modified

- `lib/chimeway/config_error.ex` - Branded structured config exception for invalid prefix configuration.
- `lib/chimeway/storage.ex` - Internal storage prefix validator and repo option helper.
- `test/chimeway/storage_test.exs` - Unit coverage for invalid prefix errors, validation matrix, and repo option mapping.
- `.planning/phases/73-storage-prefix-contract/deferred-items.md` - Tracks out-of-scope full-repo format drift discovered during verification.

## Decisions Made

- Missing `:prefix` config raises `Chimeway.ConfigError` with `value: :missing`, so runtime never silently defaults to public or chimeway schema mode.
- `"public"` is rejected; explicit public-schema compatibility is represented only by `prefix: false`.
- `repo_opts/1` applies the configured `"chimeway"` prefix using `Keyword.put_new/3` so explicit probe/debug caller options remain possible without creating a public dynamic-prefix API.

## Verification

- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/storage_test.exs --warnings-as-errors` (8 tests, 0 failures)
- PASS: `mix format --check-formatted lib/chimeway/config_error.ex lib/chimeway/storage.ex test/chimeway/storage_test.exs`
- PASS: `bash -lc 'if rg -n "@schema_prefix|schema_prefix|Process\.|Ecto.Adapters.SQL|Repo\." lib/chimeway/storage.ex; then exit 1; fi'`
- PASS: `git diff --exit-code -- mix.exs mix.lock`
- OUT OF SCOPE: `mix format --check-formatted` still reports pre-existing formatting drift in unrelated files outside the 73-01 plan file list; tracked in `deferred-items.md`.

## TDD Gate Compliance

- RED commits exist before GREEN commits for both TDD tasks.
- GREEN verification passed after each implementation commit.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Full-repo `mix format --check-formatted` fails on unrelated pre-existing files outside this plan's file list. I did not modify those files. Plan-owned files pass targeted format verification.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 73-02. Boot validation can now call `Chimeway.Storage.validate_prefix!/0`, and later runtime propagation can delegate repo option construction to `Chimeway.Storage.repo_opts/1`.

## Self-Check: PASSED

- Found created files: `lib/chimeway/config_error.ex`, `lib/chimeway/storage.ex`, `test/chimeway/storage_test.exs`.
- Found commits: `97ca0de`, `f0be00a`, `b537e89`, `ed6a8f5`.
- Stub scan found no placeholder/TODO/FIXME content in plan-owned source and test files.

---
*Phase: 73-storage-prefix-contract*
*Completed: 2026-06-30*
