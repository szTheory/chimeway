---
phase: 95-accrue-billing-escalation-proof
plan: 02
subsystem: documentation
tags: [elixir, accrue, documentation-contracts, provenance]
requires:
  - phase: 95-accrue-billing-escalation-proof
    provides: executable Accrue clean-consumer proof vocabulary and provenance schemas
provides:
  - Canonical artifact-only Accrue event-to-outcome proof guidance
  - Contract-checked released-package and compatibility-only provenance language
affects: [adoption-proof, release-guidance]
tech-stack:
  added: []
  patterns:
    - Documentation contracts isolate clean-consumer proof wording from maintainer regression mechanics.
    - Released-package language is conditional on resolved source and module validation.
key-files:
  created: []
  modified:
    - guides/introduction/accrue-dunning-integration.md
    - test/chimeway/doc_contract_test.exs
key-decisions:
  - "active / signal_received ends the waiting escalation path and is not workflow completion."
  - "The immutable Accrue SHA is compatibility evidence only, never installation guidance."
requirements-completed: [ACCR-01, ACCR-02]
duration: 5 min
completed: 2026-08-10
status: complete
---

# Phase 95 Plan 02: Accrue Billing Escalation Proof Summary

**Canonical Accrue guidance now proves the natural event-to-outcome path from an unpacked artifact while separating verified release provenance from compatibility history.**

## Accomplishments

- Added an artifact-only clean-consumer proof command, safe fixed-schema record, and explicit non-terminal `active / signal_received` explanation.
- Reclassified `ACCRUE_PATH`, sibling checkout, CI checkout, DemoHost, and `mix verify.accrue` as repository-maintainer regression mechanics rather than packaged-consumer proof.
- Added documentation contracts for lifecycle ordering, disclosure exclusions, resolved-package validation, and SHA compatibility-only wording.

## Task Commits

1. Task 1 RED — `d7ecd56` test(95-02): add failing Accrue guide lifecycle contracts
2. Task 1 GREEN — `dfe2138` docs(95-02): document Accrue clean-consumer lifecycle proof
3. Task 2 RED — `39bfd77` test(95-02): add failing Accrue provenance contracts
4. Task 2 GREEN — `51e9a90` docs(95-02): distinguish Accrue release proof from compatibility

## Verification

- Passed: `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` (474 tests, 0 failures).
- Passed: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors`.
- Passed: `mix ci.verify_gates` using the project-scoped PostgreSQL container.
- Passed: no changed paths under `lib`, `mix.exs`, `priv`, or `.github/workflows`.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None introduced by this plan.

## Self-Check: PASSED

- Confirmed the guide, documentation contract, and all four task commits exist.
- Confirmed the clean-consumer command, non-terminal signal wording, and compatibility-only SHA wording are present in the guide.
