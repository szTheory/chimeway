---
phase: 58-accrue-dunning-core
plan: 01
subsystem: testing
tags: [accrue, exunit, optional-dep, dunning, ecto-sandbox]

requires:
  - phase: 57-docs-release-gates
    provides: Mailglass selective-CI pattern (verify.* alias, @moduletag exclusion)
provides:
  - Optional `{:accrue, "~> 1.2", optional: true}` dep with ACCRUE_PATH override
  - `mix ci.test` excludes `:accrue`; `mix verify.accrue` runs accrue-tagged tests only
  - Accrue TestRepo bootstrap + shared sandbox DataCase for Chimeway + Accrue repos
  - ECOS-06 wave-1 harness stub (`trigger_event` + dunning engine config round-trip)
affects: [58-02, 58-03, 60-docs-release-gates]

tech-stack:
  added: [accrue ~> 1.2 (optional, runtime: false)]
  patterns:
    - "Mailglass-parity selective CI lane with @moduletag :accrue"
    - "Runtime Code.compile_file for Accrue.Integrations.Chimeway when parent Chimeway present"
    - "Unconditional Accrue test config (config loads before dep compile — 54-01 precedent)"

key-files:
  created:
    - test/support/accrue/test_repo.ex
    - test/support/accrue/data_case.ex
    - test/support/accrue/fixtures.ex
    - test/chimeway/integrations/accrue_dunning_harness_test.exs
  modified:
    - mix.exs
    - mix.lock
    - config/test.exs
    - test/test_helper.exs

key-decisions:
  - "Accrue dep uses runtime: false to prevent OTP application boot from blocking default mix test"
  - "Accrue test config is unconditional (not Code.ensure_loaded? gated) mirroring Mailglass 54-01"
  - "verify.accrue prepends deps.compile accrue --force plus test_helper runtime compile of integration source"
  - "Dunning engine pinned to Accrue.Integrations.Chimeway in test_helper after runtime compile"

patterns-established:
  - "Pattern: optional ecosystem dep + verify.* alias + @moduletag selective CI (D-11)"
  - "Pattern: Accrue.DataCase shared sandbox owners for Accrue.TestRepo and Chimeway.Repo (D-12)"

requirements-completed: [ECOS-06]

duration: 45min
completed: 2026-05-30
---

# Phase 58 Plan 01: Accrue Selective CI + Test Harness Summary

**Optional Accrue dependency with `@moduletag :accrue` selective CI lane, TestRepo bootstrap, and wave-1 harness proving dunning engine config and `trigger_event/2` reachability without host glue.**

## Performance

- **Duration:** 45 min
- **Started:** 2026-05-30T01:28:00Z
- **Completed:** 2026-05-30T02:13:00Z
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments

- Added optional `accrue ~> 1.2` dep with `ACCRUE_PATH` path override, `--exclude accrue` on `ci.test`, and `mix verify.accrue` alias.
- Bootstrapped Accrue `TestRepo`, migrations from `:code.priv_dir(:accrue)`, Fake processor, and runtime compile hook for `Accrue.Integrations.Chimeway`.
- Delivered `Accrue.DataCase`, billing fixtures, and 4-test harness stub tagged `@moduletag :accrue`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Optional accrue dep + selective CI aliases** - `6daf4e3` (feat)
2. **Task 2: Accrue test config + test_helper bootstrap** - `3ff54f3` (feat)
3. **Task 3: Accrue DataCase, fixtures, and harness stub test** - `fad4c5c` (test)

**Plan metadata:** pending (docs commit follows this file)

## Files Created/Modified

- `mix.exs` - Optional accrue dep, `runtime: false`, `verify.accrue`, `ci.test` exclude
- `mix.lock` - Accrue 1.2.0 + transitive deps; igniter downgraded to 0.7.9 for resolution
- `config/test.exs` - Unconditional Accrue test config (ex_cldr, TestRepo, dunning defaults)
- `test/test_helper.exs` - Accrue DB bootstrap, runtime integration compile, dunning engine pin
- `test/support/accrue/test_repo.ex` - TestRepo shim (hex accrue has no test/support)
- `test/support/accrue/data_case.ex` - Shared sandbox for Accrue + Chimeway repos
- `test/support/accrue/fixtures.ex` - Customer/subscription/invoice helpers + engine config
- `test/chimeway/integrations/accrue_dunning_harness_test.exs` - Wave 1 harness (4 tests)

## Decisions Made

- Used `runtime: false` on accrue dep because starting the Accrue OTP app blocked `mix test` indefinitely.
- Used unconditional Accrue config in `config/test.exs` (Mailglass 54-01 precedent) instead of `Code.ensure_loaded?/1` gate that fails during config evaluation.
- Added runtime `Code.compile_file/1` in test_helper for `Accrue.Integrations.Chimeway` because dependency compile order prevents the module from existing when Accrue builds as a Chimeway dep.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Fixed Mix path dep tuple format**
- **Found during:** Task 1 (deps.get)
- **Issue:** `{:accrue, {:path, path}, optional: true}` is invalid Mix syntax
- **Fix:** Changed to `{:accrue, path: path, optional: true}`
- **Files modified:** `mix.exs`
- **Verification:** `ACCRUE_PATH=... mix deps.get` exits 0
- **Committed in:** `6daf4e3`

**2. [Rule 3 - Blocking] Added runtime: false on accrue dep**
- **Found during:** Task 2 (mix test hung 7+ min)
- **Issue:** Accrue OTP application boot blocked entire test suite
- **Fix:** `runtime: false` on optional accrue dep; manual TestRepo bootstrap only
- **Files modified:** `mix.exs`
- **Verification:** `mix test --exclude accrue --exclude mailglass` completes in ~45s
- **Committed in:** `3ff54f3`

**3. [Rule 3 - Blocking] Runtime compile hook for Accrue.Integrations.Chimeway**
- **Found during:** Task 3 (verify.accrue — 0 tests, module absent)
- **Issue:** Accrue compiles before Chimeway parent; conditional integration module never defined in dep build
- **Fix:** test_helper `Code.compile_file/1` on `deps/accrue/lib/accrue/integrations/chimeway.ex` when Chimeway loaded
- **Files modified:** `test/test_helper.exs`
- **Verification:** `mix verify.accrue` — 4 tests, 0 failures
- **Committed in:** `3ff54f3`

**4. [Rule 1 - Bug] Unconditional Accrue config instead of Code.ensure_loaded? gate**
- **Found during:** Task 2 (config compile / ex_money boot)
- **Issue:** `if Code.ensure_loaded?(Accrue)` in config/test.exs excluded block at config eval time; ex_cldr missing when accrue booted
- **Fix:** Unconditional Accrue test config block (54-01 Mailglass precedent); dunning engine pinned in test_helper
- **Files modified:** `config/test.exs`, `test/test_helper.exs`
- **Verification:** `mix test --exclude accrue --exclude mailglass --warnings-as-errors` — 743 tests, 0 failures
- **Committed in:** `3ff54f3`

**5. [Rule 1 - Bug] verify.accrue includes deps.compile accrue --force**
- **Found during:** Task 1 (integration module missing after compile)
- **Issue:** Plan alias lacked accrue recompile step before accrue-tagged tests
- **Fix:** Prepended `deps.compile accrue --force` to `verify.accrue` alias
- **Files modified:** `mix.exs`
- **Verification:** `mix verify.accrue` exits 0
- **Committed in:** `6daf4e3`

---

**Total deviations:** 5 auto-fixed (2 blocking, 2 missing critical/bug, 1 bug)
**Impact on plan:** All auto-fixes required for cross-repo optional-dep compile order and test suite stability. No scope creep beyond harness infrastructure.

## Issues Encountered

- Hex resolution initially failed (igniter 0.8.0 vs accrue ~> 0.7.9); resolved after first successful `ACCRUE_PATH` deps.get downgraded igniter in lock.
- `start_campaign` smoke logs rendering warnings (DunningNotifier lacks `rendering/2` until 58-02) — expected; test asserts `:ok` return only.

## User Setup Required

None - no external service configuration required. Local Accrue cross-repo dev: `ACCRUE_PATH=/path/to/accrue/accrue mix deps.get`.

## Verification Results

| Check | Result |
|-------|--------|
| `mix compile --warnings-as-errors` | PASS |
| `mix test --exclude accrue --exclude mailglass --warnings-as-errors` | PASS (743 tests, 0 failures) |
| `mix verify.accrue` | PASS (4 tests, 0 failures) |
| `grep verify.accrue mix.exs` | PASS (line 105) |
| `grep @moduletag :accrue test/` | PASS (harness test) |
| No edits to `lib/chimeway/*` or Accrue `chimeway.ex` | PASS |

## Self-Check: PASSED

## Next Phase Readiness

- Ready for 58-02: start-path integration tests can use `Accrue.DataCase`, fixtures, and `trigger_event/2` harness.
- 58-02 must add `DunningNotifier.workflow/2` + `rendering/2` in Accrue sibling repo (out of scope for 58-01).
- Consider `CHIMEWAY_PATH` override in accrue `mix.exs` to eliminate runtime compile hook (optional polish).

---
*Phase: 58-accrue-dunning-core*
*Completed: 2026-05-30*
