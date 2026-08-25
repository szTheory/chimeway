---
phase: 102-alpha-digital-twin-hermetic-gate
plan: "01"
subsystem: testing
tags: [elixir, hex-package, crosswake, provenance, postgres]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: CrossWake notification-open resolver contracts
provides:
  - Immutable Chimeway archive validation and locked CrossWake provenance proof
  - Closed accepted-handoff/protected-open scenario ledger and bounded proof line
affects: [102-alpha-digital-twin-hermetic-gate, alpha-twin-ci]
tech-stack:
  added: []
  patterns: [validated Hex archive, detached CrossWake checkout, closed proof output]
key-files:
  created:
    - lib/mix/tasks/verify.alpha_twin.ex
    - scripts/prove-alpha-twin.exs
    - priv/alpha_twin/scenario-ledger.json
    - test/fixtures/alpha_twin/lib/alpha_twin/proof_summary.ex
    - test/chimeway/alpha_twin_runner_test.exs
  modified: []
key-decisions:
  - "The initial tracer binds its only proof line to a SHA-256 of the built archive and the canonical locked CrossWake SHA."
  - "CrossWake provenance is acquired in a fresh detached checkout, never from the sibling source tree."
patterns-established:
  - "Alpha twin proofs fail closed for mutable or dirty CrossWake provenance and never echo rejected values."
requirements-completed: [TWIN-01, TWIN-02]
coverage:
  - id: D1
    description: Immutable package and CrossWake provenance are validated before the accepted tracer proof is emitted.
    requirement: TWIN-01
    verification:
      - kind: integration
        ref: mix verify.alpha_twin
        status: pass
    human_judgment: false
  - id: D2
    description: The closed proof contract accepts only canonical immutable provenance and bounded safe output.
    requirement: TWIN-02
    verification:
      - kind: unit
        ref: test/chimeway/alpha_twin_runner_test.exs
        status: pass
    human_judgment: false
duration: 22 min
completed: 2026-08-25
status: complete
---

# Phase 102 Plan 01: Immutable Alpha Twin Tracer Summary

**A deterministic `mix verify.alpha_twin` proof now validates one built Chimeway archive and an exact detached CrossWake revision before emitting a single bounded accepted-handoff proof.**

## Performance

- **Duration:** 22 min
- **Tasks:** 1/1
- **Files modified:** 10

## Accomplishments

- Independently reverified the canonical remote serves `f2c502cdb1ce572a4a57257d9e3c051665704b90` to a fresh unauthenticated fetch.
- Added the `mix verify.alpha_twin` task, immutable archive validation, fresh detached CrossWake checkout, migration-copy check, and closed scenario ledger.
- Added RED/GREEN proof-contract coverage that rejects mutable provenance without echoing it.

## Task Commits

1. **Task 1: Trace one accepted notification from immutable package bytes to one authorized CrossWake activation** - `176abf7` (test RED), `19f8fed` (feat GREEN)

## Files Created/Modified

- `scripts/prove-alpha-twin.exs` - Immutable archive and canonical CrossWake provenance orchestrator.
- `lib/mix/tasks/verify.alpha_twin.ex` - Stable verification entrypoint.
- `priv/alpha_twin/scenario-ledger.json` - Closed versioned accepted-handoff scenario list.
- `test/fixtures/alpha_twin/` - Sanitized host fixture and bounded proof projection.
- `test/chimeway/alpha_twin_runner_test.exs` - Proof contract coverage.

## Decisions Made

- Used a fresh temporary detached checkout at the locked SHA rather than trusting the sibling repository's current worktree.
- Kept the proof line allowlisted: it includes only schema, scenario, artifact digest, locked CrossWake SHA, delivery outcome, and activation outcome.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the archive callback result shape**
- **Found during:** Task 1
- **Issue:** The validated archive callback nested an `{:ok, proof}` tuple, preventing the runner from printing the proof line.
- **Fix:** Returned the proof string directly from the archive callback.
- **Files modified:** `scripts/prove-alpha-twin.exs`
- **Verification:** `mix verify.alpha_twin`
- **Committed in:** `19f8fed`

---

**Total deviations:** 1 auto-fixed (Rule 1)

## Issues Encountered

The terminal policy rejected the plan's `rm -rf` cleanup syntax for the isolated fetch. The same isolated fetch/equality check was run without that shell cleanup clause and resolved the exact SHA successfully.

## User Setup Required

None - the prior credential-gated publication was independently verified before implementation.

## Next Phase Readiness

The immutable input and closed proof-line seam are ready for the remaining Alpha twin matrix and CI-gate work.

## Self-Check: PASSED

- Confirmed all Alpha twin files exist and both task commits are present in git history.
