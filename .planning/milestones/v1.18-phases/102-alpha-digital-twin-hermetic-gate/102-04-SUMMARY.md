---
phase: 102-alpha-digital-twin-hermetic-gate
plan: "04"
subsystem: testing
tags: [alpha-twin, provenance, crosswake, ci, physical-proof]
requires:
  - phase: 102-01
    provides: Locked public CrossWake SHA and immutable archive tracer
  - phase: 102-03
    provides: Closed Alpha scenario ledger and safe proof surface
provides:
  - Closed Chimeway physical-proof extension and malformed fixture corpus
  - Credential-free Alpha twin CI lane required by both aggregate gates
affects: [phase-103, release-gates, crosswake-integration]
tech-stack:
  added: []
  patterns: [closed proof schemas, pinned detached sibling checkout, aggregate result propagation]
key-files:
  created: [lib/chimeway/mobile_proof/extension.ex, lib/mix/tasks/verify.physical_proof_contract.ex]
  modified: [.github/workflows/ci.yml, mix.exs, test/chimeway/release_gate_contract_test.exs]
key-decisions:
  - "Physical evidence remains explicitly subjective/not-asserted; only hermetic executable facts are promotable in Phase 102."
  - "CrossWake assertion vocabulary is delegated to the pinned canonical validator rather than copied into Chimeway."
requirements-completed: [GATE-01, TWIN-01, TWIN-02]
coverage:
  - id: D1
    description: Closed provenance-bound physical-proof extension and malformed corpus
    requirement: GATE-01
    verification:
      - kind: integration
        ref: "CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/mobile_proof_extension_test.exs test/chimeway/alpha_twin_provenance_test.exs --seed 0 --warnings-as-errors && mix verify.physical_proof_contract && mix verify.alpha_twin"
        status: pass
    human_judgment: false
  - id: D2
    description: Required credential-free verify_alpha_twin CI topology
    requirement: GATE-01
    verification:
      - kind: integration
        ref: "mix ci.verify_gates"
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-08-25
status: complete
---

# Phase 102 Plan 04: Hermetic Physical-Proof Gate Summary

**Closed Alpha physical-proof bytes now bind immutable artifact/CrossWake provenance, while a credential-free required CI lane proves the twin without claiming device-alert evidence.**

## Performance

- **Duration:** 15 min
- **Completed:** 2026-08-25T22:00:47Z
- **Tasks:** 2/2
- **Files modified:** 9

## Accomplishments

- Added a versioned, closed `Chimeway.MobileProof.Extension` that validates provenance, scenario order, proof ownership/class, CrossWake reference, delegated canonical assertions, and safe subjective-observation boundaries.
- Added valid plus exhaustive ordered negative physical-proof fixtures and the argv-free `mix verify.physical_proof_contract` gate.
- Added a pinned, detached, clean CrossWake checkout to `verify_alpha_twin`, with PostgreSQL setup and both required Mix commands; both `pr-gate` and `ci-gate` now aggregate its result.

## Task Commits

1. **Task 1: Bind immutable provenance into a closed CrossWake-referencing mobile proof extension** - `5c51a66` (feat)
2. **Task 2: Require the credential-free Alpha lane in both aggregate gates** - `d33d599` (feat)

## Files Created/Modified

- `lib/chimeway/mobile_proof/extension.ex` - closed versioned proof validator with non-echoing rule/path failures.
- `lib/mix/tasks/verify.physical_proof_contract.ex` - committed-fixture validation gate.
- `test/fixtures/alpha_twin_physical_proof/` - valid proof and ordered malformed negative corpus.
- `.github/workflows/ci.yml` - required locked `verify_alpha_twin` lane and both aggregate links.
- `test/chimeway/release_gate_contract_test.exs` - topology and provenance contract coverage.

## Decisions Made

- Physical visible-alert observation is deliberately represented as `not_asserted`; hermetic CI never promotes it as iPhone evidence.
- The CrossWake physical assertion ordering and ownership contract is loaded from the pinned sibling checkout, avoiding a copied Chimeway vocabulary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected CI job-block extraction for hyphenated aggregate jobs**
- **Found during:** Task 2
- **Issue:** The release-contract helper captured following `pr-gate`/`ci-gate` blocks because its boundary expression excluded hyphens.
- **Fix:** Recognize hyphenated job IDs and regex-escape the requested ID.
- **Files modified:** `test/chimeway/release_gate_contract_test.exs`
- **Verification:** Focused Alpha lane contract and `mix ci.verify_gates` pass.
- **Committed in:** `d33d599`

**Total deviations:** 1 auto-fixed (Rule 1).

## Issues Encountered

None remaining. The physical-proof task uses the existing sibling CrossWake checkout and requires no credentials or Apple tooling.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 103 can consume the versioned extension as the machine-readable boundary while preserving the requirement for real device evidence outside this hermetic gate.

## Self-Check: PASSED

- Found all six Task 1 files, three Task 2 files, and both task commits.
- `mix verify.alpha_twin`, `mix verify.physical_proof_contract`, and `mix ci.verify_gates` passed.
