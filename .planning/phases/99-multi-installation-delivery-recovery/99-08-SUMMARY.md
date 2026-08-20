---
phase: 99-multi-installation-delivery-recovery
plan: "08"
subsystem: operator-traces
tags: [elixir, ecto, tenant-scope, safe-evidence, delivery-targets]
requires:
  - phase: 99-multi-installation-delivery-recovery
    provides: tenant-safe durable delivery target and attempt records
  - phase: 98-privacy-safe-delivery-evidence
    provides: closed SafeEvidence projection vocabulary
provides:
  - Tenant-qualified target and attempt histories in recipient, correlation, full-event, and explanation traces
  - Closed target aggregate and histories on delivery explanations
  - Stable opaque target and attempt ordering with durable-ID tie-breakers
affects: [PUSH-02, operator-explainability]
tech-stack:
  added: []
  patterns:
    - Shared nested Ecto preload builder scoped by resolved tenant
    - Explanation fields derived from SafeEvidence.trace_delivery/1
key-files:
  created:
    - .planning/phases/99-multi-installation-delivery-recovery/99-08-SUMMARY.md
  modified:
    - lib/chimeway/traces.ex
    - lib/chimeway/traces/explanation.ex
    - lib/chimeway/safe_evidence.ex
    - test/chimeway/traces_target_test.exs
key-decisions:
  - "[99-08]: Every common trace loader shares a resolved-tenant target/attempt preload shape rather than independently risking hollow target histories."
  - "[99-08]: Delivery explanations reuse SafeEvidence.trace_delivery/1 for target fields, preserving one closed projection vocabulary."
metrics:
  duration: "~12 minutes"
  completed: "2026-08-20"
status: complete
---

# Phase 99 Plan 08: Common Operator Target Histories Summary

All operator trace shapes now return the same tenant-safe, closed target histories and ordered attempts as the full event trace.

## Tasks Completed

1. Projected multi-target history through recipient, correlation, and delivery explanation paths with TDD RED/GREEN commits.

## Verification

- `mix format --check-formatted lib/chimeway/traces.ex lib/chimeway/traces/explanation.ex lib/chimeway/safe_evidence.ex test/chimeway/traces_target_test.exs` — passed.
- `env MIX_ENV=test mix test test/chimeway/traces_target_test.exs test/chimeway/traces_test.exs test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors` — passed (57 tests, 0 failures).
- `git diff --check` — passed.
- `git diff -- mix.exs mix.lock` — no dependency changes.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Used the actual preloaded delivery when building explanations**
   - **Found during:** Task 1 GREEN verification
   - **Issue:** The explanation branch retained the pre-preload delivery binding, so its closed target projection was empty.
   - **Fix:** Bound and used the reloaded delivery carrying the tenant-qualified target history.
   - **Files modified:** `lib/chimeway/traces.ex`
   - **Verification:** Focused target, trace, and tenant-scope suites pass.
   - **Commit:** `7a27884`

2. **[Rule 2 - Missing critical functionality] Added durable-ID ordering tie-breakers to closed target evidence**
   - **Found during:** Task 1 implementation
   - **Issue:** The loader ordered database rows by durable ID on ties, but the final closed evidence mapper did not explicitly preserve the required tie-breaker.
   - **Fix:** Sorted target and target-attempt projections by `{primary_order, id}`.
   - **Files modified:** `lib/chimeway/safe_evidence.ex`
   - **Verification:** Focused target projection suite passes.
   - **Commit:** `7a27884`

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 2). **Impact:** Required safe ordering and complete explanation histories are now explicit across all trace shapes.

## Known Stubs

None.

## Self-Check: PASSED

- Required source and test files exist.
- TDD RED commit `927cba4` and GREEN commit `7a27884` exist in git history.
