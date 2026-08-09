---
phase: 94-mailglass-transactional-email-proof
plan: 04
subsystem: testing
tags: [elixir, exunit, mailglass, release-gate, artifact-consumer, security]
requires:
  - phase: 94-mailglass-transactional-email-proof
    provides: Clean-consumer Mailglass proof with a fixed twelve-field trace-derived stdout schema
provides:
  - Complete value-level validation for the Mailglass proof boundary
  - Adversarial contracts for all allowlisted proof fields and timeline tokens
affects: [MAIL-02, release-gates, artifact-consumer]
tech-stack:
  added: []
  patterns:
    - Untrusted subprocess proof values are validated against a fixed binary schema before evidence is returned
    - Timeline validation remains string-based and never atomizes stdout-derived lifecycle text
key-files:
  created:
    - .planning/phases/94-mailglass-transactional-email-proof/94-04-SUMMARY.md
  modified:
    - test/support/artifact_consumer_fixture.ex
    - test/chimeway/release_gate_contract_test.exs
key-decisions:
  - "[94-04]: Mailglass evidence accepts only the stable fake-transport identity, exact succeeded lifecycle, canonical UUID shape, and numeric value 1."
  - "[94-04]: Timeline comparison uses a closed ordered binary list so untrusted tokens cannot become atoms."
patterns-established:
  - "A fixed external proof schema validates both key set and every value before crossing the adopter-facing evidence boundary."
requirements-completed: [MAIL-02]
coverage:
  - id: D1
    description: Complete fail-closed Mailglass stdout schema validation for fixed identities, numeric values, UUID-shaped delivery IDs, and lifecycle order.
    requirement: MAIL-02
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors
        status: pass
    human_judgment: false
  - id: D2
    description: Adversarial proof mutations reject forged or sensitive values without atomizing unknown timeline text.
    requirement: MAIL-02
    verification:
      - kind: unit
        ref: test/chimeway/release_gate_contract_test.exs#Mailglass proof evidence rejects forged values beneath every allowlisted key
        status: pass
      - kind: integration
        ref: mix ci.verify_gates
        status: pass
    human_judgment: false
duration: 7 min
completed: 2026-08-09
status: complete
---

# Phase 94 Plan 04: Mailglass Evidence Boundary Hardening Summary

**The clean-consumer Mailglass proof now accepts only its exact trace-derived fake-transport schema and fails closed for forged values beneath every approved key.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-09T16:45:00Z
- **Completed:** 2026-08-09T16:52:00Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Validated every emitted Mailglass proof value: fixed identity and succeeded-state strings, canonical positive numeric text equal to `1`, lowercase UUID-shaped delivery IDs, and the exact ordered lifecycle timeline.
- Preserved the generated consumer's trace-derived one-line proof and verified the real clean-consumer proof still crosses the hardened boundary.
- Added table-driven adversarial contracts for all twelve allowlisted keys, numeric aliases, malformed IDs, sensitive or reordered timeline values, and timeline atom safety.

## Task Commits

1. **Task 1: Trace one canonical proof and one forged value through the hardened boundary** - `d9402a6` (test), `bd65f1d` (feat)
2. **Task 2: Exhaust every allowlisted value with adversarial release-gate contracts** - `77ce859` (test)

## Files Created/Modified

- `test/support/artifact_consumer_fixture.ex` - Validates the complete fixed Mailglass evidence schema before returning a map.
- `test/chimeway/release_gate_contract_test.exs` - Covers canonical evidence plus adversarial values for every allowlisted key.

## Decisions Made

- Require the exact generated-proof numeric value `1`, not merely a positive integer, for version and attempt fields.
- Require the deterministic four-event timeline as an exact binary sequence; no subprocess-derived event text is atomized.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Direct focused-test attempts initially encountered a transient local PostgreSQL connection-capacity error. The project-managed database gate was rerun successfully, followed by a successful focused release-gate run.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

MAIL-02's proof-output boundary is covered by focused and aggregate release gates; no provider, credential, webhook, production runtime, or guide changes were introduced.

## Self-Check: PASSED

- Confirmed both modified test artifacts exist.
- Confirmed commits `d9402a6`, `bd65f1d`, and `77ce859` exist.
- Confirmed focused release-gate and aggregate `mix ci.verify_gates` commands passed.

---
*Phase: 94-mailglass-transactional-email-proof*
*Completed: 2026-08-09*
