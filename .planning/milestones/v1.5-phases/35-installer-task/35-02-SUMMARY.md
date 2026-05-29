---
phase: 35-installer-task
plan: "02"
subsystem: database
tags: [ecto, migrations, installer, mix, mix-task]

requires:
  - phase: 35-01
    provides: Chimeway.Install.Migrations core and 31 templates
provides:
  - mix chimeway.gen.migrations Mix task (D-01)
  - Tmp-host integration tests for run/1 file generation and idempotency
  - Subprocess CLI smoke test proving app.config + task registration
affects:
  - 35-03 (golden-diff contract tests and ci.install_golden)

tech-stack:
  added: []
  patterns:
    - "Thin Mix task delegates to Chimeway.Install.Migrations after app.config"
    - "Tmp host scaffold with path dep + Oban for subprocess compile"
    - "Strict OptionParser rejects unknown CLI args"

key-files:
  created:
    - lib/mix/tasks/chimeway.gen.migrations.ex
  modified:
    - test/chimeway/install/migrations_test.exs
    - lib/chimeway/install/migrations.ex

key-decisions:
  - "Moduledoc includes shortdoc phrase so mix help chimeway.gen.migrations grep verify passes"
  - "Tmp host scaffold adds {:oban, ~> 2.17} so path-dep compile succeeds in subprocess test"

patterns-established:
  - "Mix.Tasks.Chimeway.Gen.Migrations: app.config → Migrations.run/1 → Mix.raise on repo_missing"
  - "Integration tests use File.cd! tmp host + ExUnit.CaptureIO for stdout contracts"

requirements-completed: [INST-01]

duration: 10min
completed: 2026-05-28
---

# Phase 35 Plan 02: Mix Task CLI Wrapper Summary

**`mix chimeway.gen.migrations` thin CLI wrapper with tmp-host integration tests proving 31-file generation, repo inference, idempotency, and subprocess Mix path**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-28T20:35:00Z
- **Completed:** 2026-05-28T20:38:21Z
- **Tasks:** 3 completed
- **Files modified:** 3

## Accomplishments

- Shipped `Mix.Tasks.Chimeway.Gen.Migrations` calling `app.config` then `Chimeway.Install.Migrations.run/1` (D-01, D-02, D-14)
- Added tmp-host integration tests: 31 files on first run, `InstallerHost.Repo.Migrations` namespace, slug idempotency with 31× `unchanged`
- Added subprocess smoke test via `System.cmd("mix", ["chimeway.gen.migrations"], ...)` proving full CLI path (INST-01)

## Task Commits

Each task was committed atomically:

1. **Task 35-02-01: Implement Mix.Tasks.Chimeway.Gen.Migrations** - `62b5850` (feat)
2. **Task 35-02-02: Add tmp-host integration tests for run/1 file generation** - `607f24c` (test)
3. **Task 35-02-03: Smoke-verify Mix CLI subprocess path** - `27d409f` (test)

## Files Created/Modified

- `lib/mix/tasks/chimeway.gen.migrations.ex` — documented CLI entrypoint, strict argv, repo_missing error
- `test/chimeway/install/migrations_test.exs` — tmp host scaffold, run/1 integration, subprocess test
- `lib/chimeway/install/migrations.ex` — fix run/1 with-clause returning `:ok` (not `{:ok, repo}`)

## Decisions Made

- Included shortdoc text in `@moduledoc` so plan verify grep on `mix help chimeway.gen.migrations` passes (Elixir shows moduledoc in detailed help)
- Tmp host deps include Oban so Chimeway path-dep compile succeeds in subprocess test (SignalRouterWorker requires Oban.Worker)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] run/1 with-clause returned {:ok, repo} instead of :ok**
- **Found during:** Task 35-02-02 (integration tests)
- **Issue:** `validate_repo!/1` returns `{:ok, repo}` but with expected `:ok`, causing run/1 to return `{:ok, InstallerHost.Repo}`
- **Fix:** Removed redundant `:ok <- validate_repo!(repo)` clause; resolve_repo already validates
- **Files modified:** `lib/chimeway/install/migrations.ex`
- **Verification:** All run/1 integration tests pass; Mix task matches on `:ok`
- **Committed in:** `607f24c`

**2. [Rule 3 - Blocking] Subprocess test failed without Oban dep**
- **Found during:** Task 35-02-03 (subprocess smoke test)
- **Issue:** Minimal tmp host could not compile chimeway path dep (`Oban.Worker` not found)
- **Fix:** Added `{:oban, "~> 2.17"}` to tmp host scaffold deps
- **Files modified:** `test/chimeway/install/migrations_test.exs`
- **Verification:** Subprocess test exit 0, 31 migrations generated
- **Committed in:** `27d409f`

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes required for INST-01 CLI proof. No scope creep.

## Issues Encountered

None beyond auto-fixed deviations above.

## Verification Results

```
mix compile --warnings-as-errors                                      → success
mix help chimeway.gen.migrations | grep 'Copy Chimeway migration'     → PASS
grep -r 'mix chimeway.install' lib/                                   → no matches (D-02)
mix test test/chimeway/install/migrations_test.exs --warnings-as-errors → 11 tests, 0 failures
mix test --warnings-as-errors                                         → 560 tests, 0 failures
```

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for **35-03**: golden-diff fixture, idempotency contract file, `mix ci.install_golden` alias, path-gated CI job
- INST-01 satisfied; INST-02 golden CI deferred to wave 3 per plan

## Self-Check: PASSED

- All 3 tasks committed atomically with 35-02 references
- All acceptance criteria verified
- Full test suite green

---
*Phase: 35-installer-task*
*Completed: 2026-05-28*
