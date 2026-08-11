---
phase: 95-accrue-billing-escalation-proof
plan: 03
subsystem: testing
tags: [elixir, accrue, hex, mix, provenance, release-gate]
requires:
  - phase: 95-accrue-billing-escalation-proof
    provides: packaged Accrue adoption guidance and artifact proof baseline
provides:
  - Real Accrue event-to-workflow lifecycle evidence from an unpacked consumer
  - Fail-closed exact Hex release and immutable Git compatibility provenance
affects: [release-gate, accrue-adoption-proof, phase-95-plan-04]
tech-stack:
  added: []
  patterns:
    - Generated consumer validates resolved dependency and module origin before emitting provenance
    - Monorepo Git dependencies use an explicit sparse package root
key-files:
  created:
    - .planning/phases/95-accrue-billing-escalation-proof/95-03-SUMMARY.md
  modified:
    - test/support/artifact_consumer_fixture.ex
    - test/chimeway/release_gate_contract_test.exs
key-decisions:
  - "[95-03]: Only an exact Hex 1.3.0 descriptor can emit released_package; an exact locked Git SHA emits compatibility only."
  - "[95-03]: The Accrue compatibility checkout is a monorepo, so its generated dependency uses sparse: \"accrue\" to resolve the package root."
patterns-established:
  - "Provenance classifiers compare SCM, lock data, app/metadata version, source containment, and loaded module origin before serialization."
requirements-completed: [ACCR-01, ACCR-02]
coverage:
  - id: D1
    description: Real generated-consumer Accrue lifecycle emits public wait and signal evidence.
    requirement: ACCR-01
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only accrue_artifact_proof --warnings-as-errors
        status: pass
    human_judgment: false
  - id: D2
    description: Exact Hex 1.3.0 release and exact immutable Git SHA compatibility provenance are mutually exclusive.
    requirement: ACCR-02
    verification:
      - kind: integration
        ref: test/chimeway/release_gate_contract_test.exs#accrue_artifact_proof
        status: pass
    human_judgment: false
duration: 34min
completed: 2026-08-10
status: complete
---

# Phase 95 Plan 03: Real Accrue Proof and Fail-Closed Provenance Summary

**Generated consumers now prove a real Accrue billing lifecycle and label provenance only after exact resolved dependency, metadata, source, and module-origin checks.**

## Performance

- **Duration:** 34 min
- **Completed:** 2026-08-10T01:55:32Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced fabricated lifecycle facts with an Accrue payment-failure-to-payment-success workflow observed through public workflow APIs.
- Added a binary-key resolved-dependency descriptor that permits only Hex Accrue 1.3.0 with matching metadata or the pinned full Git SHA as compatibility evidence.
- Executed generated release and compatibility consumers; compatibility excludes release-version fields and validates the CI-pinned monorepo package root.

## Task Commits

1. **Task 1: Execute one real Accrue event-to-public-workflow evidence path** - `8d1e5e5` (feat)
2. **Task 2: Classify exact release and immutable-SHA resolution fail closed** - `d758e53` (feat)

## Files Created/Modified

- `test/support/artifact_consumer_fixture.ex` - Builds resolved release or exact-ref consumers and emits only verified provenance.
- `test/chimeway/release_gate_contract_test.exs` - Covers compatibility execution plus fail-closed parser and provenance contracts.

## Decisions Made

- Git compatibility is explicitly selected and requires the entire CI-pinned SHA; it cannot fall back from an unverified release form.
- Accrue's compatibility ref is a monorepo checkout, so `sparse: "accrue"` is required for Mix to locate the package `mix.exs`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Resolved Accrue monorepo package root for compatibility proof**
- **Found during:** Task 2
- **Issue:** The exact CI-pinned Git SHA checks out the Accrue monorepo root, which has no `mix.exs`; a plain Git dependency cannot compile it.
- **Fix:** Added `sparse: "accrue"` to the explicitly selected generated-consumer compatibility dependency.
- **Files modified:** `test/support/artifact_consumer_fixture.ex`
- **Verification:** The exact-SHA generated compatibility contract passed.
- **Committed in:** `d758e53`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Required for the plan's exact-SHA generated-consumer contract; no runtime or adopter dependency behavior changed.

## Verification

- PASS: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only accrue_artifact_proof --warnings-as-errors` initially ran both generated Hex and exact-Git consumers green: 2 tests, 0 failures (154.1s).
- PASS: focused parser and negative provenance contracts at lines 1553, 1567, 1595, 1618, and 1660: 5 tests, 0 failures.
- The subsequent seven-test aggregate rerun was invalidated by shared PostgreSQL capacity (`FATAL 53300 too_many_connections`) during fixture database cleanup; this was not a classifier assertion failure.
- A full release-gate-file run also found three unrelated pre-existing Core/Mailglass artifact failures caused by missing Oban migrations under shared resource pressure. Those paths were not modified by this task.

## Known Stubs

None. The generated proof has no placeholder evidence or unwired data path.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 95's proof consumer now has exact release and compatibility evidence forms for downstream documentation and release-gate work.

## Self-Check: PASSED

- Found task files: `test/support/artifact_consumer_fixture.ex` and `test/chimeway/release_gate_contract_test.exs`.
- Found task commits: `8d1e5e5` and `d758e53`.
- No tracked file deletions were introduced by Task 2.
