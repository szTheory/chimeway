---
phase: 103-physical-iphone-adoption-truth
plan: "03"
subsystem: physical-proof-release-gate-and-docs
tags: [elixir, ci, crosswake, physical-proof, documentation, tdd]
requires:
  - phase: 103-physical-iphone-adoption-truth
    provides: Selected CrossWake SHA and closed physical-v1 bundle validator
provides:
  - Credential-free Threshold-A CI checkout pinned only by the selected-SHA authority file
  - Fail-closed physical iPhone runner with bounded preflight and explicit visible-alert inputs
  - Canonical mobile adoption and operations ExDoc guide with executable boundary contracts
affects: [103-04 physical promotion, TWIN-03, DOCS-01]
tech-stack:
  added: []
  patterns:
    - Stable rule-id-only physical prerequisite output
    - Authority-file SHA lookup in CI with named-ref advertisement and detached checkout
    - Single-authority operational guide linked shallowly from navigation surfaces
key-files:
  created:
    - lib/mix/tasks/chimeway.mobile_physical_proof.ex
    - test/chimeway/mobile_physical_proof_runner_test.exs
    - guides/introduction/mobile-adoption-operations.md
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
    - test/chimeway/doc_contract_test.exs
    - mix.exs
    - README.md
    - guides/introduction/adoption-paths.md
decisions:
  - "Threshold A stays credential-free and reports release readiness without claiming physical behavior."
  - "The physical runner never defaults visible presentation; only D-13's three exact labels are accepted."
  - "Mobile adoption/operations guidance has one ExDoc authority; README and Adoption Paths only navigate to it."
requirements-completed: [TWIN-03, DOCS-01]
metrics:
  duration: 32 min
  completed: 2026-08-26
  tasks: 2
  files: 9
status: complete
---

# Phase 103 Plan 03: Threshold-A Runner and Mobile Operations Guide Summary

**Credential-free release gating now proves only `release_ready_physical_pending`, while a bounded runner and one canonical guide keep physical iPhone support explicitly pending until signed-device evidence exists.**

## Accomplishments

- Added `mix chimeway.mobile_physical_proof` with strict JSON modes, stable non-echoing readiness IDs, explicit D-13 alert choices, CI refusal, and fail-closed promotion behavior.
- Replaced CI's duplicate CrossWake SHA with authority-file lookup plus canonical named-ref advertisement, detached HEAD, cleanliness, module/API/marker, fixture, and focused-test checks.
- Added the canonical Mobile Adoption and Operations ExDoc guide; README and Adoption Paths provide one shallow link each.
- Contract-tested the pending-state wording, provider-handoff boundary, commands, role entry points, heading order, cross-links, and explicit non-goals.

## Task Commits

1. **Task 1: Lock the two-threshold runner and Threshold-A release-gate parity**
   - `dd95c2f` — RED: failing physical runner contract
   - `65d58b1` — GREEN: fail-closed runner and authority-file CI checkout
2. **Task 2: Publish the canonical mobile adoption and operations guide with executable truth locks**
   - `59f46c2` — canonical guide, navigation, ExDoc registration, and docs contract

## Verification

- `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/mobile_physical_proof_runner_test.exs test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --max-failures 1 --warnings-as-errors` — passed.
- `mix test test/chimeway/doc_contract_test.exs --max-failures 1 --warnings-as-errors` — 482 tests, 0 failures.
- `mix ci.verify_gates` — passed.
- `mix verify.alpha_twin` — passed.
- `mix verify.physical_proof_contract` — passed.
- `mix chimeway.mobile_physical_proof --preflight --json` — returned only stable IDs/outcomes, with `blocked` external prerequisites and no evidence publication.

## TDD Gate Compliance

- RED commit `dd95c2f` established the runner's public bounded-output and explicit-attestation contract.
- GREEN commit `65d58b1` implements the runner and passes the focused contract suite.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] CI advertisement lookup initially addressed the wrong Git working directory**
- **Found during:** Task 1
- **Issue:** `git ls-remote origin` ran from Chimeway instead of the initialized CrossWake checkout.
- **Fix:** Scoped the command to `git -C ../crosswake` before committing the CI update.
- **Files modified:** `.github/workflows/ci.yml`
- **Commit:** `65d58b1`

**2. [Rule 1 - Bug] Documentation contract initially rejected non-goal wording itself**
- **Found during:** Task 2
- **Issue:** Negative assertions matched explicit statements that a capability is not delivered.
- **Fix:** Asserted unsupported affirmative claims instead, preserving the non-goal language.
- **Files modified:** `test/chimeway/doc_contract_test.exs`
- **Commit:** `59f46c2`

## Known Stubs

None. The runner deliberately returns bounded unavailable external prerequisites rather than placeholder evidence; no data is fabricated or promoted.

## Threat Flags

None. The new runner, CI pin, and guide surfaces implement the plan's T-103-08 through T-103-13 mitigations without adding an unmodeled trust boundary.

## Next Phase Readiness

Threshold A is releasable but physical support remains pending. Threshold B still requires Apple signing/provisioning, APNs sandbox, the selected iPhone, host activation authority, CrossWake Phase 162 reconciliation, and a separately supplied `Observed` visible-alert attestation.

## Self-Check: PASSED

- Found the runner, canonical guide, and both contract-test files.
- Found all three task commits: `dd95c2f`, `65d58b1`, and `59f46c2`.
- No tracked file deletions were introduced by this plan.
