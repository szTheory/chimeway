---
phase: 98-privacy-safe-delivery-evidence
plan: 05
subsystem: adoption proof privacy boundary
tags: [elixir, privacy, proof, release-gates, mailglass]
requires:
  - phase: 98-privacy-safe-delivery-evidence
    provides: shared SafeEvidence projection
provides:
  - Closed Core and Mailglass lifecycle proof schemas
  - Non-atomizing proof parsers with exact value validation
  - Provider-handoff-only acceptance semantics
affects: [adoption-proof, release-gate-contracts]
tech-stack:
  added: []
  patterns:
    - Project proof fields through Chimeway.SafeEvidence.proof/1 before formatting
    - Parse untrusted binary proof keys with compile-time allowlists and exact shapes
key-files:
  created:
    - .planning/phases/98-privacy-safe-delivery-evidence/98-05-SUMMARY.md
  modified:
    - priv/adoption_proof/artifact_consumer_fixture.ex
    - test/chimeway/release_gate_contract_test.exs
key-decisions:
  - "[98-05]: Proof acceptance is expressed as provider_handoff=accepted only; it never claims device display, open, seen, read, or engagement."
  - "[98-05]: Core proof uses provider_handoff=not_applicable, while Mailglass proof records only successful provider handoff."
metrics:
  duration: 16 min
  completed: 2026-08-12
status: complete
---

# Phase 98 Plan 05: Privacy-Safe Delivery Evidence Summary

**Core and Mailglass proof output now emits a closed SafeEvidence projection with validated lifecycle/render facts and honest provider-handoff semantics.**

## Completed Tasks

- Core and Mailglass builders now pass their explicit proof maps through `Chimeway.SafeEvidence.proof/1` before serialization.
- Exact binary-key allowlists reject unknown, duplicate, incomplete, malformed, and sensitive forged proof values without atomizing caller-controlled keys.
- Mailglass no longer emits adapter-module or transport facts; `provider_handoff=accepted` is the only acceptance claim, while Core emits `provider_handoff=not_applicable`.

## Verification

- Passed: `mix format --check-formatted priv/adoption_proof/artifact_consumer_fixture.ex test/chimeway/release_gate_contract_test.exs`
- Passed: isolated parser contract under `MIX_ENV=dev`, including Core/Mailglass safe schemas and forged device-lifecycle handoff rejection.
- Attempted but blocked by concurrent PostgreSQL connection exhaustion: `env MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` exited during `test_helper` with PostgreSQL `FATAL 53300 (too_many_connections)`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Added value validation to the Core proof parser.**
- **Found during:** Task 1
- **Issue:** The prior Core parser enforced only its key set, permitting sensitive or semantically false values under otherwise valid keys.
- **Fix:** Shared exact-shape and value validation across Core and Mailglass proof parsers, including UUID, ordinal, timeline, classification, and handoff validation.
- **Files modified:** `priv/adoption_proof/artifact_consumer_fixture.ex`, `test/chimeway/release_gate_contract_test.exs`
- **Commit:** `9d3343e`

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed modified proof fixture and release-gate contract test exist.
- Confirmed task commits `1902189` and `9d3343e` exist.
