---
phase: 72-admin-docs-and-verification-gate
plan: 03
subsystem: ci
tags: [verify-admin, ci-gate, release-gate, admin, playwright]

requires:
  - 72-01
  - 72-02
provides:
  - Root `mix verify.admin` gate for admin integration verification
  - `verify_admin` CI job that invokes the same root gate
  - Release-gate parity contracts and MAINTAINING pre-ship checklist coverage
affects: [admin-console, ci-gate, release-gate, browser-smoke]

tech-stack:
  added: []
  patterns: [root verify alias, CI lane parity, release-gate contract]

key-files:
  modified:
    - mix.exs
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
    - MAINTAINING.md
    - examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs

key-decisions:
  - "`mix verify.admin` composes root admin tests, full `chimeway_admin` package tests, demo-host mounted admin tests, npm install, Chromium install, and Playwright smoke."
  - "`verify_admin` runs as a first-class CI lane and is required by `ci-gate`."
  - "Release-gate contracts now treat `verify.admin` as the eleventh pre-ship local command and twelfth CI lane."

patterns-established:
  - "New ecosystem verify gates must update root alias, CI job, ci-gate needs/env/loop, release contract lists, and MAINTAINING in one change."
  - "Mounted admin tests assert redacted recipient rendering while continuing to search by full recipient identity."

requirements-completed: [GATE-08, SMOKE-01]

duration: 18min
completed: 2026-06-04
---

# Phase 72: Admin Verification Gate Summary

**`mix verify.admin` is now the local and CI gate for the mounted admin console**

## Performance

- **Duration:** 18 min
- **Completed:** 2026-06-04
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added root `"verify.admin"` alias in `mix.exs` with the required command order: root admin tests, `chimeway_admin` package tests, demo-host mounted admin tests, `npm ci`, Playwright Chromium install, and browser smoke.
- Added `.github/workflows/ci.yml` `verify_admin` job with pinned checkout/setup-beam/cache/setup-node actions, PostgreSQL 15, and `mix verify.admin`.
- Added `verify_admin` to `ci-gate` `needs`, env aggregation, and required-lane loop.
- Updated release-gate contracts to include `verify.admin` in pre-ship command parity and `verify_admin` in CI lane parity.
- Updated `MAINTAINING.md` from ten to eleven pre-ship local commands and documented the admin gate coverage.
- Updated the demo-host admin LiveView test to expect redacted recipient display while still proving full recipient search works.

## Task Commits

1. **Task 72-03-01/02: Add Root Gate, CI Lane, and Release Contracts** - `726059e` (ci)
2. **Task 72-03 Verification Fix: Align Demo Test With Redaction** - `872efcb` (test)

## Files Modified

- `mix.exs` - Adds `"verify.admin"` alias.
- `.github/workflows/ci.yml` - Adds `verify_admin` job and ci-gate aggregation.
- `test/chimeway/release_gate_contract_test.exs` - Adds `verify.admin` / `verify_admin` parity expectations and updated counts.
- `MAINTAINING.md` - Documents the eleven-command pre-ship checklist and admin gate.
- `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` - Asserts redacted recipient output in mounted admin search results.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Demo-host mounted admin test expected unredacted recipient output**
- **Found during:** `mix verify.admin`.
- **Issue:** Admin search accepts full recipient IDs, but list rendering now correctly redacts recipient identity (`user:***est`). The test still expected full `user:*@teampulse.test` strings.
- **Fix:** Added `assert_redacted_recipient/2` helper to assert redacted output is present and full identity is absent.
- **Verification:** Demo-host admin test passed directly and inside `mix verify.admin`.
- **Committed in:** `872efcb`

---

**Total deviations:** 1 auto-fixed.
**Impact on plan:** The fix reinforces the privacy/redaction contract without changing gate behavior.

## Verification

- `mix help | grep -q "verify.admin" || grep -q '"verify.admin"' mix.exs` - passed; Mix logged `:epipe` after grep closed stdout, fallback grep confirmed the alias.
- `MIX_ENV=test mix test test/chimeway/admin_test.exs --warnings-as-errors` - passed, 6 tests.
- `grep -q "playwright test test/browser/admin_smoke.spec.ts" mix.exs && grep -q "test/demo_host_web/admin_trace_live_test.exs" mix.exs` - passed.
- `cd examples/chimeway_demo_host && env CHIMEWAY_SKIP_THREADLINE_DEP=1 CHIMEWAY_SKIP_SIGRA_DEP=1 MIX_ENV=test mix test test/demo_host_web/admin_trace_live_test.exs --warnings-as-errors` - passed, 4 tests.
- `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` - passed, 43 tests.
- `mix verify.admin` - passed, including 6 root admin tests, 51 package tests, 4 demo-host mounted admin tests, npm audit, and 2 Playwright Chromium projects.
- `mix ci.verify_gates` - passed, 404 tests.

## Next Phase Readiness

Phase 72 has docs, browser smoke, named local admin gate, CI parity, and release-gate contract coverage in place.

---
*Phase: 72-admin-docs-and-verification-gate*
*Completed: 2026-06-04*
