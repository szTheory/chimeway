---
phase: 35-installer-task
plan: "03"
subsystem: testing
tags: [installer, golden-diff, idempotency, ci, exunit]

requires:
  - phase: 35-02
    provides: mix chimeway.gen.migrations Mix task and tmp-host integration tests
provides:
  - Chimeway.Test.InstallerFixture harness with subprocess runner and normalization
  - Committed golden fixture at test/fixtures/installer_golden/ (31 migrations + STDOUT)
  - golden_diff_test.exs and idempotency_test.exs contract tests (INST-02)
  - mix ci.install_golden alias and path-gated install_golden_contract CI job
affects:
  - Phase 36 (golden-path docs can reference proven installer contracts)
  - Phase 41 (GATE-01 doc-contract checks build on installer CI surface)

tech-stack:
  added: []
  patterns:
    - "Sigra-style committed tree golden fixture with TIMESTAMP normalization"
    - "MIX_INSTALLER_ACCEPT_GOLDEN=1 maintainer refresh gate"
    - "Path-gated install_golden_contract CI job (always on main push)"

key-files:
  created:
    - test/support/installer_fixture.ex
    - test/chimeway/install/golden_diff_test.exs
    - test/chimeway/install/idempotency_test.exs
    - test/fixtures/installer_golden/STDOUT.txt
    - test/fixtures/installer_golden/tree/priv/repo/migrations/TIMESTAMP_*.exs
  modified:
    - mix.exs
    - .github/workflows/ci.yml
    - CONTRIBUTING.md
    - .formatter.exs
    - .credo.exs

key-decisions:
  - "Golden dir at test/fixtures/installer_golden (not repo-root fixtures/) despite plan path typo"
  - "Pre-compile tmp host deps before run_install! to stabilize stdout for golden capture"
  - "Exclude test/fixtures from mix format and credo — golden snapshots are byte-stable installer output"
  - "ci.test and ci.install_golden use cmd env MIX_ENV=test for Elixir 1.19 nested-alias compatibility"

patterns-established:
  - "Chimeway.Test.InstallerFixture: tmp host scaffold, subprocess mix chimeway.gen.migrations, normalize_tree/stdout"
  - "Golden refresh: MIX_INSTALLER_ACCEPT_GOLDEN=1 mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors"
  - "CI path gate covers priv/chimeway_migrations/, lib/chimeway/install/, test/chimeway/install/, fixtures, mix.exs"

requirements-completed: [INST-02]

duration: 45min
completed: 2026-05-28
---

# Phase 35 Plan 03: Golden-Diff & Idempotency CI Summary

**Golden-diff and idempotency contract tests with committed 31-file fixture, `mix ci.install_golden` alias, and path-gated GitHub Actions job proving INST-02**

## Performance

- **Duration:** 45 min
- **Started:** 2026-05-28T20:40:00Z
- **Completed:** 2026-05-28T21:25:00Z
- **Tasks:** 5 completed
- **Files modified:** 40+

## Accomplishments

- Shipped `Chimeway.Test.InstallerFixture` harness: tmp host scaffold, subprocess `mix chimeway.gen.migrations`, timestamp/path normalization, and `MIX_INSTALLER_ACCEPT_GOLDEN=1` refresh gate
- Committed golden fixture with 31 normalized migration files + STDOUT under `test/fixtures/installer_golden/`
- Added golden-diff contract (D-11) and idempotency contract (D-12) proving second run zero diff and 31× unchanged stdout
- Wired `mix ci.install_golden` alias (D-13) and path-gated `install_golden_contract` CI job; documented in CONTRIBUTING.md

## Task Commits

Each task was committed atomically:

1. **Task 35-03-01: Create installer test harness** - `0d320d5` (feat)
2. **Task 35-03-02: Capture golden fixture and golden_diff_test.exs** - `ee96eb0` (test)
3. **Task 35-03-03: Implement idempotency_test.exs** - `b727f76` (test)
4. **Task 35-03-04: Add mix ci.install_golden alias** - `a6d5545` (chore)
5. **Task 35-03-05: Add path-gated CI job and CONTRIBUTING docs** - `cefb499` (ci)

**Plan metadata:** pending (docs commit)

## Files Created/Modified

- `test/support/installer_fixture.ex` — tmp host scaffold, subprocess runner, normalizers, golden refresh
- `test/chimeway/install/golden_diff_test.exs` — first-run tree + stdout vs committed fixture
- `test/chimeway/install/idempotency_test.exs` — second-run zero diff + unchanged stdout contract
- `test/fixtures/installer_golden/` — 31 TIMESTAMP_* migration files + STDOUT.txt
- `mix.exs` — `ci.install_golden` alias; explicit MIX_ENV=test for nested alias invocations
- `.github/workflows/ci.yml` — `install_golden_contract` path-gated job
- `CONTRIBUTING.md` — CI entrypoints table row for `mix ci.install_golden`
- `.formatter.exs`, `.credo.exs` — exclude golden fixtures from lint gates

## Decisions Made

- Fixed `@golden_dir` to `test/fixtures/installer_golden` (plan's `../../fixtures` resolved to repo root, not test/)
- Pre-compile tmp host before installer run to strip compile noise from golden stdout
- Exclude `test/fixtures/` from formatter and credo — fixtures must match raw installer output byte-for-byte
- Use `cmd env MIX_ENV=test` in `ci.test` and `ci.install_golden` for Elixir 1.19 nested-alias MIX_ENV behavior

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] @golden_dir path resolved to repo-root fixtures/**
- **Found during:** Task 35-03-02 (golden capture)
- **Issue:** `Path.expand("../../fixtures/installer_golden", __DIR__)` from `test/support/` wrote to `fixtures/` not `test/fixtures/`
- **Fix:** Changed to `Path.expand("../fixtures/installer_golden", __DIR__)`
- **Files modified:** `test/support/installer_fixture.ex`
- **Verification:** Golden files at `test/fixtures/installer_golden/`; acceptance grep paths pass
- **Committed in:** `ee96eb0`

**2. [Rule 3 - Blocking] mix ci failed on nested alias MIX_ENV in Elixir 1.19**
- **Found during:** Task 35-03-05 (mix ci acceptance)
- **Issue:** `ci: ["ci.lint", "ci.test"]` chain runs `mix test` in dev env when invoked via alias
- **Fix:** `ci.test` and `ci.install_golden` use `cmd env MIX_ENV=test mix test ...`
- **Files modified:** `mix.exs`
- **Verification:** `mix ci` → 562 tests, 0 failures
- **Committed in:** `cefb499`

**3. [Rule 3 - Blocking] Golden fixtures failed mix format and credo checks**
- **Found during:** Task 35-03-05 (mix ci acceptance)
- **Issue:** Installer output copies are not formatter/credo-clean; blanket `test/**` inputs included fixtures
- **Fix:** Narrow formatter inputs; add `test/fixtures/` to credo excluded patterns
- **Files modified:** `.formatter.exs`, `.credo.exs`
- **Verification:** `mix ci.lint` passes with 138 credo files (fixtures excluded)
- **Committed in:** `cefb499`

---

**Total deviations:** 3 auto-fixed (1 bug, 2 blocking)
**Impact on plan:** All fixes required for INST-02 CI proof and green default gate. No scope creep.

## Issues Encountered

None beyond auto-fixed deviations above.

## Verification Results

```
mix ci.install_golden                                              → 2 tests, 0 failures
mix ci                                                             → 562 tests, 0 failures
mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors → PASS (no refresh env)
ls test/fixtures/installer_golden/tree/priv/repo/migrations/*.exs | wc -l → 31
grep -r '^# chimeway_migration:' test/fixtures/installer_golden/tree/ | wc -l → 31
grep -c 'install_golden_contract' .github/workflows/ci.yml         → 1
grep 'ci:' mix.exs | grep -c install_golden                        → 0 (not in default ci)
```

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 35 complete — INST-01 (plans 01–02) and INST-02 (plan 03) satisfied
- Ready for **Phase 36**: golden-path docs and README/install semver alignment (DOCS-01, DOCS-02)
- Maintainer golden refresh: `MIX_INSTALLER_ACCEPT_GOLDEN=1 mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors`

## Self-Check: PASSED

- All 5 tasks committed atomically with 35-03 references
- All acceptance criteria verified
- `mix ci.install_golden` and `mix ci` green

---
*Phase: 35-installer-task*
*Completed: 2026-05-28*
