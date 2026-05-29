---
phase: 54-mailglass-adapter-core
plan: 01
subsystem: testing
tags: [mailglass, optional-deps, adapter, exunit, ecto]

requires:
  - phase: v1.7
    provides: Chimeway.Adapter behaviour, Oban optional-dep pattern, contract test macro
provides:
  - Optional {:mailglass, "~> 1.3"} dependency in mix.exs
  - Conditional Chimeway.Adapters.Mailglass stub behind Code.ensure_loaded?(Mailglass)
  - Mailglass Fake adapter + TestRepo test harness with fixtures
affects: [54-02, 54-03, phase-55, phase-56]

tech-stack:
  added: [mailglass ~> 1.3 (optional)]
  patterns: [Code.ensure_loaded? file guard, Mailglass.TestRepo shim for hex dep tests]

key-files:
  created:
    - lib/chimeway/adapters/mailglass.ex
    - test/support/chimeway/mailglass_fixtures.ex
    - test/support/mailglass/test_repo.ex
    - test/support/mailglass/data_case.ex
    - test/chimeway/adapters/mailglass_adapter_test.exs
  modified:
    - mix.exs
    - mix.lock
    - config/test.exs
    - test/test_helper.exs

key-decisions:
  - "Mailglass test config is unconditional in config/test.exs (config loads before dep compile)"
  - "Shim Mailglass.TestRepo and Mailglass.DataCase in Chimeway test/support (not published on hex)"
  - "Defer Chimeway.Adapter.ContractTest to 54-03 while deliver/2 stub returns :not_implemented"

patterns-established:
  - "Optional Mailglass: mix.exs optional dep + entire adapter file wrapped in Code.ensure_loaded?(Mailglass)"
  - "Mailglass integration tests: Fake adapter, dedicated chimeway_mailglass_test DB, sandbox via TestRepo shim"

requirements-completed: [ECOS-01]

duration: 15min
completed: 2026-05-29
---

# Phase 54 Plan 01: Optional Mailglass Dependency & Test Harness Summary

**Optional mailglass ~> 1.3 packaging with conditional adapter stub and Fake/TestRepo test infrastructure for downstream deliver/2 work**

## Performance

- **Duration:** 15 min
- **Started:** 2026-05-29T21:00:00Z
- **Completed:** 2026-05-29T21:15:00Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Added `{:mailglass, "~> 1.3", optional: true}` without pulling Mailglass into host apps by default
- Created `Chimeway.Adapters.Mailglass` stub gated by `Code.ensure_loaded?(Mailglass)` with `not_implemented/0` deliver/2
- Bootstrapped Mailglass test stack: Fake adapter config, TestRepo migrations, fixtures, and stub compile test

## Task Commits

Each task was committed atomically:

1. **Task 1: Optional mailglass dependency (D-05, D-06)** - `3e93b00` (feat)
2. **Task 2: Conditional adapter module stub (D-04, D-07)** - `1b20803` (feat)
3. **Task 3: Mailglass test fixtures and config (D-13)** - `a62d928` (test)

**Plan metadata:** pending (docs commit)

## Files Created/Modified

- `mix.exs` / `mix.lock` — optional mailglass dependency
- `lib/chimeway/adapters/mailglass.ex` — conditional adapter stub with behaviour + deliver/2 placeholder
- `config/test.exs` — Mailglass Fake adapter + TestRepo connection to `chimeway_mailglass_test` DB
- `test/test_helper.exs` — Mailglass app start, DB create/migrate, TestRepo sandbox
- `test/support/mailglass/test_repo.ex` — hex-safe Mailglass.TestRepo shim
- `test/support/mailglass/data_case.ex` — hex-safe Mailglass.DataCase shim
- `test/support/chimeway/mailglass_fixtures.ex` — TestMailer mailable + sample delivery helpers
- `test/chimeway/adapters/mailglass_adapter_test.exs` — stub compiles test (ContractTest in 54-03)

## Decisions Made

- Unconditional Mailglass config in `config/test.exs` because `Code.ensure_loaded?/1` is false during config evaluation before dep compilation
- Shim `Mailglass.TestRepo` and `Mailglass.DataCase` in Chimeway test/support — mailglass hex package does not ship test/support modules
- Hold `Chimeway.Adapter.ContractTest` until 54-02/03 — stub `deliver/2` returns permanent `:not_implemented` which fails success-shape contract assertions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Mailglass test modules absent from hex package**
- **Found during:** Task 3 (Mailglass test fixtures and config)
- **Issue:** `Mailglass.TestRepo`, `Mailglass.DataCase`, and related test helpers exist only in mailglass source `test/support`, not in the published hex artifact
- **Fix:** Added `test/support/mailglass/test_repo.ex` and `data_case.ex` shims; test_helper creates DB via `storage_up/1` and runs migrations
- **Files modified:** `test/support/mailglass/test_repo.ex`, `test/support/mailglass/data_case.ex`, `test/test_helper.exs`
- **Verification:** `mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors` exits 0
- **Committed in:** `a62d928`

**2. [Rule 3 - Blocking] Config guard skipped Mailglass settings**
- **Found during:** Task 3 verification
- **Issue:** `if Code.ensure_loaded?(Mailglass)` in `config/test.exs` evaluated false at config load time, leaving TestRepo config nil
- **Fix:** Configure Mailglass test settings unconditionally in `config/test.exs` (mirrors existing Oban test config pattern)
- **Files modified:** `config/test.exs`
- **Verification:** test_helper `storage_up/1` succeeds; adapter test passes
- **Committed in:** `a62d928`

**3. [Rule 1 - Bug] ContractTest incompatible with deliver stub**
- **Found during:** Task 3 (plan action review)
- **Issue:** Plan action requested `use Chimeway.Adapter.ContractTest` but stub `deliver/2` returns `{:error, :permanent, ...}` — success-shape test would fail
- **Fix:** Defined `adapter_module/0` and `sample_delivery/0` helpers; deferred `use Chimeway.Adapter.ContractTest` to plan 54-03 per plan note "may skip contract assertions until 54-02/03"
- **Files modified:** `test/chimeway/adapters/mailglass_adapter_test.exs`
- **Verification:** stub compiles test passes; contract suite deferred intentionally
- **Committed in:** `a62d928`

---

**Total deviations:** 3 auto-fixed (1 missing critical, 1 blocking, 1 bug/scope alignment)
**Impact on plan:** All auto-fixes required for a working test harness on the hex-published mailglass package. No scope creep beyond D-13 test infrastructure.

## Issues Encountered

None beyond deviations above.

## User Setup Required

None - no external service configuration required. Local Postgres needed for mailglass adapter tests (same as existing Chimeway test suite).

## Next Phase Readiness

- Ready for 54-02: implement `deliver/2` (message build, tenancy stamp, Mailglass.Outbound call, error mapping)
- Test harness (`Fake`, TestRepo, fixtures) is wired; 54-03 can enable `Chimeway.Adapter.ContractTest` once deliver succeeds

## Self-Check: PASSED

- `mix compile --warnings-as-errors` — PASS
- `rg "optional: true" mix.exs` includes mailglass — PASS
- `mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors` — PASS (1 test)
- Key files exist on disk — PASS

---
*Phase: 54-mailglass-adapter-core*
*Completed: 2026-05-29*
