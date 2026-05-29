---
phase: 54-mailglass-adapter-core
plan: 03
subsystem: testing
tags: [mailglass, adapter, contract-test, executor, error-classification, ECOS-02]

requires:
  - phase: 54-02
    provides: deliver/2 implementation, error classification, Fake test harness
provides:
  - Chimeway.Adapter.ContractTest coverage for Mailglass with simulate_error?/0
  - Explicit temporary/bounced/permanent classification test matrix (D-14, D-15)
  - Executor run_delivery routing proof for email → Chimeway.Adapters.Mailglass
  - custom-adapter recipe Mailglass section (D-07, D-08)
affects: [phase-55, phase-56, phase-57]

tech-stack:
  added: []
  patterns: [ContractTest simulate_error config pass-through, classify_error_for_test test helper]

key-files:
  created:
    - test/chimeway/dispatch/executor_mailglass_adapter_test.exs
  modified:
    - test/chimeway/adapters/mailglass_adapter_test.exs
    - test/support/chimeway/adapter/contract_test.ex
    - lib/chimeway/adapters/mailglass.ex
    - guides/recipes/custom-adapter.md

key-decisions:
  - "ContractTest error shape test passes simulate_error: true in config when simulate_error?/0 is true"
  - "Permanent classification tested via classify_error_for_test/1 on TemplateError (test env only)"
  - "Executor integration test uses Chimeway.DataCase + shared Mailglass sandbox owner"

patterns-established:
  - "Mailglass adapter tests: @moduletag :mailglass for selective CI"
  - "Contract + classification + executor routing as ECOS-02 proof stack"

requirements-completed: [ECOS-02]

duration: 12min
completed: 2026-05-29
---

# Phase 54 Plan 03: Contract Tests & Executor Routing Summary

**ECOS-02 proof: Mailglass adapter passes shared ContractTest with simulate_error, classification matrix for all three error classes, and executor email routing to Chimeway.Adapters.Mailglass**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-29T20:36:00Z
- **Completed:** 2026-05-29T20:48:10Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Enabled `Chimeway.Adapter.ContractTest` on Mailglass with `simulate_error?/0` true and Application env mailables for success-shape tests
- Added happy-path Fake delivery proof and name-explicit classification tests for `:temporary`, `:bounced`, and `:permanent`
- Created `executor_mailglass_adapter_test.exs` proving `run_delivery/1` succeeds with Mailglass adapter_module and redacted provider meta
- Documented built-in Mailglass adapter registration in `guides/recipes/custom-adapter.md`

## Task Commits

Each task was committed atomically:

1. **Task 1–2: ContractTest suite + error classification matrix** - `3a3e498` (test)
2. **Task 3: Executor routing test** - `a83ad47` (test)
3. **Task 3: Recipe doc update** - `c5e25a5` (docs)

**Plan metadata:** pending (docs commit)

## Files Created/Modified

- `test/chimeway/adapters/mailglass_adapter_test.exs` — ContractTest, Fake happy path, classification matrix with D-15 moduledoc table
- `test/support/chimeway/adapter/contract_test.ex` — error shape test passes `simulate_error: true` when `simulate_error?/0`
- `lib/chimeway/adapters/mailglass.ex` — `merge_simulate_error_config/1`, `classify_error_for_test/1` (test env)
- `test/chimeway/dispatch/executor_mailglass_adapter_test.exs` — per-channel Mailglass routing via Executor
- `guides/recipes/custom-adapter.md` — optional Mailglass adapter section

## Decisions Made

- Combined Tasks 1–2 in one test commit because contract and classification tests share the same module and adapter helpers
- Fixed ContractTest macro to pass `simulate_error: true` config rather than relying solely on Application env (which would break success-shape test)
- Split Task 3 into separate test and docs commits for review clarity

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] ContractTest macro passed empty config for error simulation**
- **Found during:** Task 1 (ContractTest activation)
- **Issue:** Macro called `deliver(sample_delivery(), [])` for error shape test; Mailglass cannot simulate failure with empty config while success test also uses `[]`
- **Fix:** Updated `Chimeway.Adapter.ContractTest` error test to pass `[simulate_error: true]` when `simulate_error?/0` is true; added `merge_simulate_error_config/1` fallback for Application env
- **Files modified:** `test/support/chimeway/adapter/contract_test.ex`, `lib/chimeway/adapters/mailglass.ex`
- **Verification:** `mix test test/chimeway/adapters/mailglass_adapter_test.exs --warnings-as-errors` — 8 tests pass
- **Committed in:** `3a3e498`

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Macro fix is required for any adapter with `simulate_error?/0` true; no scope creep beyond ECOS-02 contract fidelity.

## Issues Encountered

None beyond deviation above.

## User Setup Required

None - no external service configuration required. Local Postgres needed for mailglass adapter tests (same as 54-01/02).

## Next Phase Readiness

- Phase 54 complete (3/3 plans) — ready for Phase 55 inbound webhook callbacks (ECOS-03/04)
- ECOS-02 satisfied: contract tests, classification matrix, executor routing, and recipe pointer in place

## Self-Check: PASSED

- `mix test test/chimeway/adapters/mailglass_adapter_test.exs test/chimeway/dispatch/executor_mailglass_adapter_test.exs --warnings-as-errors` — PASS (9 tests)
- `simulate_error?/0` returns true in mailglass adapter test module — PASS
- Contract describe tests pass (success shape + error shape) — PASS
- Fake deliveries list grows on happy path — PASS
- Three name-explicit classification tests (temporary, bounced, permanent) — PASS
- `executor_mailglass_adapter_test.exs` exists with succeeded Mailglass attempt — PASS
- `guides/recipes/custom-adapter.md` contains `Chimeway.Adapters.Mailglass` — PASS
- Key files exist on disk — PASS

---
*Phase: 54-mailglass-adapter-core*
*Completed: 2026-05-29*
