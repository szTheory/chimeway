---
phase: 63-threadline-telemetry-bridge
plan: 01
subsystem: testing
tags: [threadline, telemetry, optional-dep, ecto, exunit, correlation-id]

requires:
  - phase: v1.9-adopter-complete
    provides: Accrue/Mailglass selective CI pattern, telemetry safe_meta spine
provides:
  - Optional threadline dep with THREADLINE_PATH override and ci.test exclude
  - Threadline TestRepo bootstrap and integration harness stub
  - planning_reason in @allowed_meta_keys for deferred policy spans
  - correlation_id on policy/dispatch/attempt outcome telemetry spans
affects: [63-02-threadline-reporter, phase-66-gate-07]

tech-stack:
  added: [threadline ~> 0.7 optional dep]
  patterns:
    - "@moduletag :threadline selective CI lane"
    - "Conditional Code.ensure_loaded?(Threadline) integration modules"
    - "test/support/threadline migration shim for hex artifact gap"

key-files:
  created:
    - test/support/threadline/test_repo.ex
    - test/support/threadline/data_case.ex
    - test/support/threadline/fixtures.ex
    - test/support/threadline/migrations/
    - test/chimeway/integrations/threadline_telemetry_harness_test.exs
  modified:
    - mix.exs
    - mix.lock
    - config/test.exs
    - test/test_helper.exs
    - lib/chimeway/telemetry.ex
    - lib/chimeway/policy.ex
    - lib/chimeway/dispatch/sync.ex
    - lib/chimeway/dispatch/oban_worker.ex
    - lib/chimeway/deliveries.ex
    - test/chimeway/telemetry_integration_test.exs
    - test/chimeway/telemetry_correlation_test.exs

key-decisions:
  - "Threadline.Test.Repo shim in test/support (hex artifact omits test/support — Mailglass 54-01 precedent)"
  - "Local migration copy in test/support/threadline/migrations when priv dir absent on hex package"
  - "ActorRef.new/2 tuple unwrapped in configure_threadline_reporter!/0 fixture"

patterns-established:
  - "Pattern: optional threadline dep + CHIMEWAY_SKIP_THREADLINE_DEP + THREADLINE_PATH mirror Accrue"
  - "Pattern: harness stub proves config + TestRepo without reporter attach (63-02 scope)"

requirements-completed: [ECOS-08]

duration: 25min
completed: 2026-05-30
---

# Phase 63 Plan 01: Threadline Harness + Telemetry Enrichment Summary

**Optional threadline dependency with selective CI exclusion, Threadline TestRepo integration harness, and telemetry meta gaps closed for planning_reason and correlation_id on outcome spans.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-05-30T09:38:00Z
- **Completed:** 2026-05-30T09:43:30Z
- **Tasks:** 5
- **Files modified:** 18

## Accomplishments

- Optional `{:threadline, "~> 0.7", optional: true, runtime: false}` dep with `THREADLINE_PATH` override and `--exclude threadline` on `ci.test` (no `verify.threadline` alias)
- Conditional Threadline TestRepo bootstrap in `test_helper.exs` with dual-repo DataCase, fixtures, and `@moduletag :threadline` harness stub
- `planning_reason` passes `Telemetry.safe_meta/1` for deferred policy outcomes (D-08)
- Reporter-target spans (`policy:evaluate`, `dispatch:sync|perform`, `attempts:record`) carry `correlation_id` from `delivery.metadata` (D-07)

## Task Commits

Each task was committed atomically:

1. **Task 1: Optional threadline dep + selective CI exclude** - `dae336f` (feat)
2. **Task 2: Threadline test config + test_helper bootstrap** - `619a09a` (feat)
3. **Task 3: Threadline DataCase, fixtures, and harness stub test** - `968a026` (test)
4. **Task 4: Add planning_reason to @allowed_meta_keys** - `0c5f4c2` (feat)
5. **Task 5: Enrich outcome spans with correlation_id** - `12fa2ea` (feat)

**Plan metadata:** `903df0b` (docs: complete plan)

## Files Created/Modified

- `mix.exs` / `mix.lock` — optional threadline dep, `threadline_dep/0`, `ci.test` exclude
- `config/test.exs` — unconditional `Threadline.Test.Repo` config
- `test/test_helper.exs` — conditional Threadline app bootstrap + migrations
- `test/support/threadline/*` — TestRepo shim, DataCase, fixtures, migration copy
- `test/chimeway/integrations/threadline_telemetry_harness_test.exs` — ECOS-08 wave 1 stub
- `lib/chimeway/telemetry.ex` — `planning_reason` allowed key + catalog updates
- `lib/chimeway/policy.ex`, `dispatch/sync.ex`, `dispatch/oban_worker.ex`, `deliveries.ex` — correlation_id span enrichment
- `test/chimeway/telemetry_integration_test.exs` — planning_reason + correlation assertions
- `test/chimeway/telemetry_correlation_test.exs` — outcome span correlation proof

## Decisions Made

- Copied Threadline priv migrations locally when hex package omits `priv/repo/migrations` (same class of fix as Mailglass 54-02)
- Shim `Threadline.Test.Repo` in Chimeway test/support because dependency compile path excludes Threadline's test/support
- Unwrap `{:ok, actor}` from `ActorRef.new/2` in reporter config fixture

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Threadline.Test.Repo shim + migration copy**
- **Found during:** Task 2 (test_helper bootstrap)
- **Issue:** Hex threadline artifact lacks `test/support` Test.Repo module and `priv/repo/migrations` path
- **Fix:** Added `test/support/threadline/test_repo.ex` and copied 8 migrations to `test/support/threadline/migrations/`
- **Files modified:** `test/support/threadline/test_repo.ex`, `test/support/threadline/migrations/*`
- **Verification:** `mix test .../threadline_telemetry_harness_test.exs --only threadline` green
- **Committed in:** `619a09a`, `968a026`

**2. [Rule 1 - Bug] ActorRef.new returns tuple**
- **Found during:** Task 3 (reporter config round-trip test)
- **Issue:** `ActorRef.new(:system, "chimeway")` returns `{:ok, %ActorRef{}}`, not bare struct
- **Fix:** Pattern-match `{:ok, actor}` in `configure_threadline_reporter!/0`
- **Files modified:** `test/support/threadline/fixtures.ex`
- **Verification:** harness reporter config test passes
- **Committed in:** `968a026`

**3. [Rule 3 - Blocking] planning_reason integration tests in Task 5 commit**
- **Found during:** Task 4 commit staging
- **Issue:** `telemetry_integration_test.exs` holds both planning_reason and correlation describe blocks; split staging impractical
- **Fix:** planning_reason describe committed alongside correlation tests in Task 5 commit `12fa2ea`
- **Verification:** `mix test test/chimeway/telemetry_integration_test.exs --warnings-as-errors` green
- **Committed in:** `12fa2ea`

---

**Total deviations:** 3 auto-fixed (1 missing critical, 1 bug, 1 blocking commit split)
**Impact on plan:** All necessary for harness bootstrap and test correctness. No scope creep beyond Mailglass/Accrue precedents.

## Issues Encountered

- Default CI lane (`mix test --exclude threadline --exclude accrue --exclude mailglass`) reports 5 pre-existing failures in `Chimeway.Webhooks.ProcessFeedbackWorkerTest` (DeliveryAttempt count isolation) — unrelated to Phase 63 changes; failures reproduce with `CHIMEWAY_SKIP_THREADLINE_DEP=1`

## Verification Results

| Command | Result |
|---------|--------|
| `mix compile --warnings-as-errors` | PASS |
| `mix test --exclude threadline --exclude accrue --exclude mailglass --warnings-as-errors` | 855 tests, 5 pre-existing failures (ProcessFeedbackWorkerTest) |
| `mix test test/chimeway/integrations/threadline_telemetry_harness_test.exs --only threadline --warnings-as-errors` | PASS (3 tests) |
| `mix test test/chimeway/telemetry_integration_test.exs test/chimeway/telemetry_correlation_test.exs --warnings-as-errors` | PASS (17 tests) |
| `grep -n "verify.threadline" mix.exs` | no matches (D-13) |
| `grep -rn "@moduletag :threadline" test/` | harness test only |

## Self-Check: PASSED

- All 5 tasks completed with individual commits
- Key artifacts exist on disk
- Threadline harness and telemetry enrichment tests green
- No `lib/chimeway/telemetry/threadline_reporter.ex` created (63-02 scope)

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for **63-02-PLAN.md**: `Chimeway.Telemetry.ThreadlineReporter` + lifecycle → audit row integration proof
- Harness provides `configure_threadline_reporter!/0`, dual-repo DataCase, and telemetry meta prerequisites (`planning_reason`, `correlation_id`)

---
*Phase: 63-threadline-telemetry-bridge*
*Completed: 2026-05-30*
