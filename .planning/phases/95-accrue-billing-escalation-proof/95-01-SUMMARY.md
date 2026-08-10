---
phase: 95-accrue-billing-escalation-proof
plan: 01
subsystem: testing
tags: [elixir, accrue, oban, artifact-consumer, provenance]
requires:
  - phase: 93-hermetic-artifact-harness-core-trace-proof
    provides: unpacked-artifact consumer fixture and cleanup boundary
  - phase: 94-mailglass-transactional-email-proof
    provides: strict one-line evidence parser pattern
provides:
  - Accrue proof runner and generated consumer scaffold
  - Fixed lifecycle and provenance evidence parser contracts
affects: [phase-95-plan-02, adoption-proof]
tech-stack:
  added: []
  patterns:
    - Generated consumer proof uses an artifact-only Chimeway path dependency.
    - Untrusted proof records use fixed binary-key allowlists and exact provenance schemas.
key-files:
  created:
    - scripts/prove-accrue-consumer.exs
  modified:
    - test/support/artifact_consumer_fixture.ex
    - test/chimeway/release_gate_contract_test.exs
key-decisions:
  - "Accrue evidence distinguishes released_package from exact-SHA compatibility schemas."
  - "The proof runner accepts only one absolute unpacked-artifact root."
requirements-completed: [ACCR-01, ACCR-02]
coverage:
  - id: D1
    description: Accrue artifact proof runner and generated consumer scaffold
    requirement: ACCR-01
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors
        status: unknown
    human_judgment: true
    rationale: Shared PostgreSQL connection exhaustion prevented the full release-gate run.
  - id: D2
    description: Strict lifecycle and provenance parser boundary
    requirement: ACCR-02
    verification:
      - kind: unit
        ref: MIX_ENV=test mix compile --warnings-as-errors
        status: pass
    human_judgment: false
duration: 18 min
completed: 2026-08-09
status: complete
---

# Phase 95 Plan 01: Accrue Billing Escalation Proof Summary

**An unpacked-artifact Accrue proof runner with fixed lifecycle/provenance evidence schemas and adversarial disclosure contracts.**

## Accomplishments

- Added `prove_accrue!/1,2` and a committed absolute-path proof runner.
- Generated consumer configuration now includes direct Accrue 1.3.0 and manual Oban setup for the signal queue.
- Added strict released-package and compatibility evidence parsing, including sensitive-key and malformed-record rejection.

## Task Commits

1. Task 1 — `8be8451` feat(95-01): add Accrue artifact lifecycle proof
2. Task 2 — `9de149b` test(95-01): harden Accrue proof evidence boundary

## Verification

- Passed: `MIX_ENV=test mix compile --warnings-as-errors`
- Attempted: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors`
- Blocked by shared PostgreSQL: `FATAL 53300 (too_many_connections)`; existing Core/Mailglass integration cases could not obtain cleanup connections.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 3 - Blocking issue] Kept Accrue dependency generation isolated to the Accrue proof mode.
- Found during: Task 1
- Issue: adding Accrue to the shared generated consumer topology made pre-existing Core/Mailglass proofs resolve an unnecessary cyclic dependency graph.
- Fix: parameterized generated scaffold dependency/config generation so only `prove_accrue!/2` opts into Accrue.
- Files modified: `test/support/artifact_consumer_fixture.ex`
- Commit: `8be8451`

**Total deviations:** 1 auto-fixed. **Impact:** Existing proof modes retain their prior dependency topology.

## Known Stubs

- `test/support/artifact_consumer_fixture.ex`: generated Accrue proof uses placeholder workflow-state maps rather than public `Chimeway.Workflows.explain/2` and `list_traces/2` results. This must be replaced before release proof acceptance.

## Issues Encountered

The full release-gate command could not complete because the shared local PostgreSQL server exhausted its connection limit.

## Next Phase Readiness

Do not rely on the Accrue proof as release evidence until the generated consumer’s real fixture lifecycle and public workflow evidence are completed and the full release-gate command passes.

## Self-Check: PASSED

- Confirmed task commits `8be8451` and `9de149b` exist.
- Confirmed the runner and both modified test surfaces exist.
