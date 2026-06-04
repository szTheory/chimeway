---
phase: 64-sigra-auth-flows-core
plan: 01
subsystem: testing
tags: [sigra, auth, optional-dep, ecto, exunit, redaction, sanitize_payload]

requires:
  - phase: 63-threadline-telemetry-bridge
    provides: Selective CI + optional dep harness pattern (THREADLINE_PATH, @moduletag exclude)
  - phase: v1.9-adopter-complete
    provides: Accrue/Mailglass test bootstrap precedent, telemetry safe_meta spine
provides:
  - Optional sigra dep with SIGRA_PATH override and ci.test --exclude sigra
  - Sigra TestRepo bootstrap, schema config, and harness stub tests
  - Extended @sensitive_keys for auth-flow defense-in-depth (url, code, raw_token, magic_link_url)
affects: [64-02-sigra-integration, phase-66-gate-07]

tech-stack:
  added: [sigra ~> 0.3 optional dep]
  patterns:
    - "@moduletag :sigra selective CI lane"
    - "Conditional Code.ensure_loaded?(Sigra) integration modules"
    - "test/support/sigra migration shim with integer PK harness schemas"

key-files:
  created:
    - test/support/sigra/test_repo.ex
    - test/support/sigra/user.ex
    - test/support/sigra/user_token.ex
    - test/support/sigra/data_case.ex
    - test/support/sigra/fixtures.ex
    - test/support/sigra/migrations/20260530000001_create_sigra_auth_tables.exs
    - test/chimeway/integrations/sigra_auth_harness_test.exs
    - test/chimeway/trigger_sanitization_test.exs
  modified:
    - mix.exs
    - mix.lock
    - config/test.exs
    - test/test_helper.exs
    - lib/chimeway/trigger.ex

key-decisions:
  - "sigra dep uses override: true to resolve mailglass optional sigra ~> 1.0 conflict"
  - "Harness user schemas use integer PKs (binary_id: false) — distinct from Sigra install golden"
  - "No mix verify.sigra alias in 64-01 — deferred Phase 66 GATE-07 (D-12)"

patterns-established:
  - "Pattern: optional sigra dep + CHIMEWAY_SKIP_SIGRA_DEP + SIGRA_PATH mirror Accrue/Threadline"
  - "Pattern: unconditional config/test.exs Sigra harness block before optional dep compile"

requirements-completed: [ECOS-09]

duration: 25min
completed: 2026-05-30
---

# Phase 64 Plan 01: Sigra Harness + Redaction Baseline Summary

**Optional sigra dependency with selective CI exclude, Sigra TestRepo harness stub, and extended trigger @sensitive_keys for auth-flow redaction before integration dispatch.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-05-30T14:10:00Z
- **Completed:** 2026-05-30T14:35:00Z
- **Tasks:** 4
- **Files modified:** 13

## Accomplishments

- Optional `{:sigra, "~> 0.3", optional: true, runtime: false}` dep with `SIGRA_PATH` / `CHIMEWAY_SKIP_SIGRA_DEP` gates and `--exclude sigra` on `ci.test`
- Unconditional Sigra harness config in `config/test.exs` plus conditional `Sigra.TestRepo` bootstrap in `test/test_helper.exs`
- `@moduletag :sigra` harness proving Sigra module load, TestRepo reachability, and schema config round-trip
- `@sensitive_keys` extended with `url`, `code`, `raw_token`, `magic_link_url` and unit tests proving payload/render_assigns stripping

## Task Commits

Each task was committed atomically:

1. **Task 1: Optional sigra dep + selective CI exclude** - `1781d0f` (feat)
2. **Task 2: Sigra test config + test_helper bootstrap** - `dcc791c` (feat)
3. **Task 3: Sigra DataCase, fixtures, migrations, harness stub** - `70d40a9` (feat)
4. **Task 4: Extend @sensitive_keys for auth-flow redaction** - `a65230c` (feat)

**Plan metadata:** pending (docs commit after this file)

## Files Created/Modified

- `mix.exs` / `mix.lock` — optional sigra dep, ci.test exclude, override for mailglass conflict
- `config/test.exs` — unconditional Sigra.TestRepo + harness schema config
- `test/test_helper.exs` — conditional Sigra storage_up, migrate, sandbox bootstrap
- `test/support/sigra/*` — TestRepo shim, integer-PK schemas, migration, DataCase, fixtures
- `test/chimeway/integrations/sigra_auth_harness_test.exs` — wave 1 harness stub (@moduletag :sigra)
- `lib/chimeway/trigger.ex` — extended @sensitive_keys + moduledoc (D-08)
- `test/chimeway/trigger_sanitization_test.exs` — payload and render_assigns redaction proof

## Decisions Made

- Added `override: true` on sigra dep because mailglass declares optional `sigra ~> 1.0` while Chimeway pins `~> 0.3` for auth integration testing
- Harness schemas use integer primary keys to keep migration minimal; Sigra install golden uses binary_id
- Deferred `mix verify.sigra` and `Sigra.Integrations.Chimeway` to waves 64-02 / Phase 66 per plan

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] sigra dep override for mailglass conflict**
- **Found during:** Task 1 (Optional sigra dep)
- **Issue:** `mix deps.get` failed — mailglass optional `sigra ~> 1.0` conflicted with Chimeway `~> 0.3` path/hex dep
- **Fix:** Added `override: true` to `sigra_dep/0` tuple
- **Files modified:** mix.exs
- **Verification:** `SIGRA_PATH=../sigra mix deps.get` and `mix compile --warnings-as-errors` pass
- **Committed in:** 1781d0f

**2. [Rule 1 - Bug] Harness test loads Sigra.Auth before function_exported?/3**
- **Found during:** Task 3 verification
- **Issue:** `function_exported?(Sigra.Auth, :request_magic_link, 3)` returned false until Auth module loaded
- **Fix:** Assert `Code.ensure_loaded?(Sigra.Auth)` before export check
- **Files modified:** test/chimeway/integrations/sigra_auth_harness_test.exs
- **Verification:** `mix test .../sigra_auth_harness_test.exs --only sigra` passes (3 tests)
- **Committed in:** 70d40a9

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Required for deps resolution and accurate harness assertion. No scope creep.

## Issues Encountered

- Default CI lane `mix test --exclude sigra ...` reports 5 pre-existing failures in `ProcessFeedbackWorkerTest` (DeliveryAttempt count assertions) on this branch — unrelated to Phase 64 changes; verified failing before 64-01 edits via stash comparison
- ECOS-09 requirement traceability: wave 64-01 delivers infrastructure + redaction baseline only; full ECOS-09 lifecycle proof deferred to plan 64-02

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for **64-02**: `Sigra.Integrations.Chimeway`, magic link + confirmation notifiers, lifecycle + redaction integration tests
- Harness TestRepo, fixtures, and `@sensitive_keys` baseline in place
- No blockers for wave 2; use `SIGRA_PATH=../sigra` locally until coordinated hex release if needed

## Self-Check: PASSED

- [x] mix.exs contains sigra dep + ci.test exclude sigra
- [x] test/support/sigra/data_case.ex exists
- [x] test/chimeway/integrations/sigra_auth_harness_test.exs @moduletag :sigra
- [x] lib/chimeway/trigger.ex @sensitive_keys includes magic_link_url
- [x] Commits 1781d0f, dcc791c, 70d40a9, a65230c present
- [x] mix test sigra harness --only sigra: PASS
- [x] mix test trigger_sanitization_test.exs: PASS
- [x] mix compile --warnings-as-errors: PASS
- [x] grep verify.sigra mix.exs: no matches

---
*Phase: 64-sigra-auth-flows-core*
*Completed: 2026-05-30*
