---
phase: 99-multi-installation-delivery-recovery
plan: "06"
subsystem: delivery-dispatch
tags: [elixir, ecto, target-adapter, durable-attempts, recovery]
requires:
  - phase: 99-multi-installation-delivery-recovery
    provides: Durable target claims and started-attempt authority from Plans 99-03 through 99-05
provides:
  - Typed target-adapter handoff classifications
  - Atomic, tenant-qualified closure of retryable and ambiguous target attempts
  - Focused regression coverage for duplicate and callback-failure outcomes
affects: [99-07-recovery-validation]
tech-stack:
  added: []
  patterns:
    - Explicit pre-handoff evidence is the sole automatic-retry authorization
    - All callback failures after attempt start close as possible provider handoff
key-files:
  created:
    - .planning/phases/99-multi-installation-delivery-recovery/99-06-SUMMARY.md
  modified:
    - lib/chimeway/target_adapter.ex
    - lib/chimeway/delivery_targets.ex
    - lib/chimeway/dispatch/executor.ex
    - test/chimeway/dispatch/target_worker_test.exs
key-decisions:
  - "[99-06]: Only {:error, :pre_handoff, reason} can return a claimed target to pending; all legacy, unexpected, raised, thrown, and possible-handoff outcomes are durable ambiguity."
  - "[99-06]: Failure finalization locks the exact tenant-qualified claimed target and attempt_started row, stores closed provider-code evidence only, and recomputes the parent delivery."
requirements-completed: [PUSH-02, PUSH-03, RECOV-02]
duration: 8 min
completed: 2026-08-19
status: complete
---

# Phase 99 Plan 06: Target Adapter Outcome Finalization Summary

**Target adapter outcomes now always close their exact durable attempt, distinguishing provably unsent retries from possible provider handoffs without retaining raw callback evidence.**

## Accomplishments

- Extended `Chimeway.TargetAdapter` with documented typed pre-handoff and possible-handoff error forms.
- Added tenant-qualified, row-locked `record_target_failure/4` finalization for retryable and ambiguous outcomes.
- Normalized legacy errors, unexpected results, raises, throws, and exits to terminal `:ambiguous_handoff` after callback entry.
- Added regression evidence for retry numbering, safe facts, claim closure, duplicate execution, and no automatic ambiguity resend.

## Verification

Passed:

```bash
mix format --check-formatted lib/chimeway/target_adapter.ex lib/chimeway/delivery_targets.ex lib/chimeway/dispatch/executor.ex test/chimeway/dispatch/target_worker_test.exs
env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs test/chimeway/delivery_target_test.exs --warnings-as-errors
```

Result: 12 tests, 0 failures.

## TDD Gate Compliance

- RED: `8a1de47` — failing adapter outcome contract returned raw errors before durable closure.
- GREEN: `d848419` — typed normalization and atomic finalization satisfy the contract.
- Refinement: `3fd528d` — explicit claim-timestamp closure assertions remain green.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Required source and focused regression files exist.
- TDD RED and GREEN commits exist in git history.
- Focused formatting and test verification passes with warnings treated as errors.
