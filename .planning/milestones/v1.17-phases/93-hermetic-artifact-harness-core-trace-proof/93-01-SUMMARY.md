---
phase: 93-hermetic-artifact-harness-core-trace-proof
plan: 01
subsystem: testing
tags: [elixir, exunit, hex, ecto, postgresql, artifact-proof]
requires:
  - phase: 78-release-and-package-truth
    provides: unpacked Hex package release-gate helpers
provides:
  - Hermetic unpacked-artifact Core lifecycle proof in a temporary consumer host
  - Sanitized public explainability evidence and fixture boundary contracts
affects: [phase-94, phase-95, phase-96, release-gates]
tech-stack:
  added: []
  patterns: [temporary external consumer fixture, public trace evidence allowlist]
key-files:
  created: [test/support/artifact_consumer_fixture.ex]
  modified: [test/chimeway/release_gate_contract_test.exs]
key-decisions:
  - "Generated consumers directly opt into Oban because the published source compiles Oban workers."
  - "The host starts only its Repo; Mix starts Chimeway as a dependency application."
patterns-established:
  - "Artifact consumers must validate their single unpacked :chimeway path before subprocess commands."
  - "Public proof output is reduced to an explicit six-key allowlist."
requirements-completed: [PROOF-01, PROOF-02, PROOF-03, CORE-01]
coverage:
  - id: D1
    description: "A clean consumer installs the unpacked artifact, migrates a unique PostgreSQL database, and proves a terminal Core delivery."
    requirement: PROOF-01
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors"
        status: pass
    human_judgment: false
  - id: D2
    description: "The Core lifecycle uses public explainability evidence with strict provenance, ordering, sanitization, and cleanup contracts."
    requirement: PROOF-03
    verification:
      - kind: integration
        ref: "mix ci.verify_gates"
        status: pass
    human_judgment: false
duration: 11min
completed: 2026-08-08
status: complete
---

# Phase 93 Plan 01: Hermetic Artifact Harness Core Trace Proof Summary

**An unpacked Chimeway artifact now boots in a disposable Ecto host, completes one synchronous Core delivery, and emits only sanitized public trace evidence.**

## Performance

- **Duration:** 11 min
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Built a serialized release-gate contract that builds and unpacks the Hex artifact once before creating an isolated consumer.
- Added a fixture that owns consumer scaffolding, unique PostgreSQL lifecycle, artifact provenance validation, migration/boot commands, and exact cleanup.
- Locked safe proof evidence, ordered lifecycle behavior, provenance rejection, failure cleanup, and source/output disclosure boundaries.

## Task Commits

1. **Task 1: Prove one unpacked-artifact Core lifecycle end to end** — `e879809` (test)
2. **Task 2: Lock provenance, empty-evidence, ordering, concurrency, and cleanup edges** — `5b0a503` (test)

## Files Created/Modified

- `test/support/artifact_consumer_fixture.ex` — Generates, validates, runs, and cleans the isolated artifact consumer.
- `test/chimeway/release_gate_contract_test.exs` — Exercises the end-to-end proof and focused boundary contracts.

## Decisions Made

- The generated consumer explicitly depends on `{:oban, "~> 2.17"}`. Published Chimeway source uses `Oban.Worker`, so this is the honest current compiled-artifact contract while Chimeway keeps Oban optional downstream.
- The generated host supervises only `ArtifactConsumer.Repo`; Mix already starts `Chimeway.Application` as the dependency application.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Package compile boundary] Direct consumer Oban opt-in**
- **Found during:** Task 1
- **Issue:** The unpacked artifact could not compile with the planned direct dependencies because published source directly uses `Oban.Worker` while Chimeway declares Oban optional.
- **Fix:** Following the explicit architecture decision, the generated consumer declares `{:oban, "~> 2.17"}` without changing Chimeway production dependency semantics.
- **Files modified:** `test/support/artifact_consumer_fixture.ex`
- **Verification:** Focused release-gate contract and `mix ci.verify_gates` pass.

**2. [Rule 1 - Host boot] Correct dependency application startup shape**
- **Found during:** Task 1
- **Issue:** `Chimeway.Application` is not a supervisor child spec and cannot be placed directly in the generated host supervisor.
- **Fix:** The host supervises its Repo while normal Mix dependency startup owns Chimeway's application lifecycle.
- **Files modified:** `test/support/artifact_consumer_fixture.ex`
- **Verification:** Generated host boots and completes the public proof.

**Total deviations:** 2 auto-fixed. **Impact:** No production architecture changed; the fixture now accurately represents the published artifact's runtime contract.

## Verification

- PASS — `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` (92 tests, 0 failures)
- PASS — `mix ci.verify_gates` (543 tests, 0 failures)
- PASS — `git diff --name-only -- lib mix.exs .github/workflows` produced no changes.

## Issues Encountered

The existing Threadline cleanup task emits DB sandbox ownership errors during these release-gate commands. They are pre-existing test-process logs; both commands completed successfully with zero failures.

## User Setup Required

None.

## Next Phase Readiness

The Core artifact proof is reusable for later Mailglass, Accrue, and adoption-selector paths. A future package design may extract or conditionally compile Oban worker modules only if Chimeway promises sync-only hosts can compile without explicit Oban opt-in.

## Self-Check: PASSED

- Confirmed both task commits exist and both implementation files are present.
