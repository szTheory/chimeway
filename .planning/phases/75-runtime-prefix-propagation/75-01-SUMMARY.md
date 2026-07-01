---
phase: 75-runtime-prefix-propagation
plan: 01
subsystem: testing
tags: [elixir, ecto, postgres, prefix, runtime-prefix, tdd]
requires:
  - phase: 73
    provides: storage and trigger contracts used by runtime prefix tests
  - phase: 74
    provides: orchestration, worker, digest, webhook, and operator surfaces covered by integration proofs
provides:
  - Prefixed runtime test case with app-env prefix setup and schema-qualified row assertions
  - Repo.default_options guardrails for runtime prefix behavior
  - Tagged RED integration suite covering trigger, operator, worker, digest, webhook, preference, policy, and public legacy paths
affects: [runtime-prefix, repo-default-options, storage-prefix, oban-boundary]
tech-stack:
  added: []
  patterns:
    - ExUnit CaseTemplate for serialized prefixed runtime tests
    - RED guardrail tests that assert prefixed rows and public legacy mode
key-files:
  created:
    - test/chimeway/repo_prefix_test.exs
    - test/chimeway/runtime_prefix_integration_test.exs
  modified:
    - test/support/prefixed_runtime_case.ex
key-decisions:
  - "PrefixedRuntimeCase owns temporary :chimeway prefix application config and restores it on exit."
  - "Repo.default_options(:transaction) is asserted public while normal repo operations are expected to inherit runtime prefix in later plans."
  - "Runtime integration coverage is intentionally RED until Plans 75-02 through 75-06 implement prefix propagation."
requirements-completed: [RUN-01, RUN-02, RUN-03, RUN-04]
duration: 16min
completed: 2026-07-01
status: complete
---

# Phase 75 Plan 01: Wave 0 Runtime Prefix Guardrails Summary

**RED runtime prefix guardrails for Repo defaults and cross-surface storage placement**

## Performance

- **Duration:** 16 min
- **Started:** 2026-07-01T17:57:38Z
- **Completed:** 2026-07-01T18:13:11Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Added `Chimeway.PrefixedRuntimeCase` with serialized runtime prefix setup, app-env restoration, schema-qualified counts, and public/prefixed row reset helpers.
- Added `Chimeway.RepoPrefixTest` to lock the expected `Repo.default_options/1` contract before production changes.
- Added tagged runtime integration proofs for trigger, operators, Oban boundaries, workflow/signal paths, dispatch workers, digests, webhooks, preferences, policy evaluation, and public legacy mode.

## Task Commits

1. **Task 1: Create prefixed runtime test harness** - `7744b6a` (test)
2. **Task 2: Add repo default options guardrails** - `731f5ef` (test)
3. **Task 3: Add runtime prefix integration proof** - `7306a1c` (test)

## Files Created/Modified

- `test/support/prefixed_runtime_case.ex` - Prefixed runtime case template, schema preparation, row reset helpers, and prefixed/public row assertions.
- `test/chimeway/repo_prefix_test.exs` - RED guardrails for `Repo.default_options/1`, explicit prefix override precedence, and forbidden schema-prefix patterns.
- `test/chimeway/runtime_prefix_integration_test.exs` - RED integration coverage for runtime prefix propagation across public APIs, workers, and storage surfaces.

## Verification

- `MIX_ENV=test mix test test/chimeway/storage_test.exs --warnings-as-errors` - PASS, 8 tests, 0 failures.
- `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs --warnings-as-errors` - EXPECTED RED, 6 tests, 1 failure: `Repo.default_options/1` returns `%{}` for normal operations instead of `%{prefix: "chimeway"}`.
- `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` - EXPECTED RED, 10 tests, 9 failures: prefixed row counts are `0` because current production paths still write to `public`; public legacy mode passes.
- `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` - EXPECTED RED, 16 tests, 10 failures: 1 repo default-options failure plus 9 prefixed placement failures.

## Decisions Made

- Kept public legacy behavior explicit by asserting `Application.put_env(:chimeway, :prefix, false)` continues to write public rows.
- Kept Oban storage separate by asserting Chimeway rows should be prefixed while `oban_jobs` remains public and job args carry durable IDs only.
- Used direct runtime API calls without public `prefix:` options, matching the no-public-API-prefix decision for Phase 75.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Avoided sandbox migrator ownership failure in PrefixedRuntimeCase**
- **Found during:** Task 3 (runtime prefix integration proof)
- **Issue:** Running generated fixture migrations through `Ecto.Migrator` in `setup_all` spawned outside SQL Sandbox ownership, invalidating all integration tests before RED assertions ran.
- **Fix:** Kept the generated prefixed fixture as the contract presence check, but prepared the prefixed test schema with process-local SQL cloning from the already-migrated public Chimeway tables.
- **Files modified:** `test/support/prefixed_runtime_case.ex`
- **Verification:** `storage_test.exs` passes; `runtime_prefix_integration_test.exs` reaches expected prefix placement failures.
- **Committed in:** `7306a1c`

**2. [Rule 1 - Test Bug] Aligned guardrails with current API return shapes and validations**
- **Found during:** Tasks 2 and 3
- **Issue:** Initial guardrail assertions triggered warnings or non-prefix failures from current API shapes: keyword-list comparisons, required tenant IDs, digest rule required fields, inbox mark return values, and trace return shape.
- **Fix:** Normalized assertions with `Map.new/1`, supplied tenant and digest rule contract fields, and matched current return shapes so failures isolate to missing runtime prefix behavior.
- **Files modified:** `test/chimeway/repo_prefix_test.exs`, `test/chimeway/runtime_prefix_integration_test.exs`
- **Verification:** Task and combined verification commands fail only on expected default-options or prefixed row-placement assertions.
- **Committed in:** `731f5ef`, `7306a1c`

---

**Total deviations:** 2 auto-fixed (Rule 1: 1, Rule 3: 1)
**Impact on plan:** Guardrail scope stayed unchanged; fixes were required to make the intended RED tests executable and precise.

## Known RED Failures

- `Repo.default_options/1` does not yet delegate normal operations to `Chimeway.Storage.repo_opts/1`.
- Runtime APIs, workers, and contexts still write Chimeway rows into `public` while prefix config is `"chimeway"`.
- These RED failures are expected before production implementation in later Phase 75 plans.

## Known Stubs

None. Stub scan found only intentional empty-list assertions in tests.

## Threat Flags

None. Changes are test-only; no production endpoints, auth paths, or external file-access surfaces were added.

## User Setup Required

None.

## Next Phase Readiness

Plans 75-02 through 75-06 can now implement prefix propagation against precise failing tests. The highest-priority next failure is `Repo.default_options/1`, because the runtime integration suite depends on normal repo operations inheriting the configured storage prefix.

## Self-Check: PASSED

- Found `test/support/prefixed_runtime_case.ex`
- Found `test/chimeway/repo_prefix_test.exs`
- Found `test/chimeway/runtime_prefix_integration_test.exs`
- Found commits `7744b6a`, `731f5ef`, and `7306a1c`

---
*Phase: 75-runtime-prefix-propagation*
*Completed: 2026-07-01*
