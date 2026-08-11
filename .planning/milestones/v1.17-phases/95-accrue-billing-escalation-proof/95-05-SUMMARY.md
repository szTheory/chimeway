---
phase: 95-accrue-billing-escalation-proof
plan: "05"
subsystem: documentation
tags: [accrue, package-provenance, release-gates, documentation-contracts]
requires:
  - phase: 95-accrue-billing-escalation-proof
    provides: Package-owned archive proof CLI and exact provenance classifier
provides:
  - Archive-plus-SHA packaged Accrue proof guidance
  - Contract-checked release and compatibility wording boundaries
affects: [phase-96-adoption-selector, release-gates, accrue-adoption-guide]
tech-stack:
  added: []
  patterns:
    - Guide commands mirror the package-owned CLI interface exactly.
    - Immutable compatibility refs are scoped to prose outside install and command regions.
key-files:
  created:
    - .planning/phases/95-accrue-billing-escalation-proof/95-05-SUMMARY.md
  modified:
    - guides/introduction/accrue-dunning-integration.md
    - test/chimeway/doc_contract_test.exs
    - test/chimeway/release_gate_contract_test.exs
key-decisions:
  - "[95-05]: The canonical adopter command accepts only an immutable archive plus lowercase SHA-256, never an arbitrary directory."
  - "[95-05]: Released-package proof requires exact Accrue 1.3.0 Hex metadata, integration origin, and exact Chimeway version; the pinned SHA is compatibility evidence only."
requirements-completed: [ACCR-01, ACCR-02]
coverage:
  - id: D1
    description: Package-valid Accrue proof guidance and safe non-terminal lifecycle evidence
    requirement: ACCR-01
    verification:
      - kind: unit
        ref: MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors
        status: pass
    human_judgment: false
  - id: D2
    description: Exact released-package and compatibility-only provenance boundaries
    requirement: ACCR-02
    verification:
      - kind: unit
        ref: MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors
        status: pass
      - kind: other
        ref: mix ci.verify_gates
        status: pass
    human_judgment: false
duration: 12min
completed: 2026-08-10
status: complete
---

# Phase 95 Plan 05: Package-Valid Accrue Documentation Summary

**The canonical Accrue guide now invokes the shipped archive-and-SHA proof CLI and mechanically confines release claims to its exact executable provenance schemas.**

## Accomplishments

- Replaced the obsolete directory argument with the package-owned archive-plus-SHA command, including archive validation, temporary host/database isolation, and cleanup semantics.
- Documented Accrue-owned billing event boundaries, public `Workflows.explain/2` / `list_traces/2` evidence, and the non-terminal meaning of `active / signal_received` without exposing sensitive proof data.
- Added positive and negative documentation contracts for exact Accrue 1.3.0 release classification, SHA-only compatibility evidence, safe schemas, and maintainer-only checkout mechanics.
- Corrected stale release-gate assertions so the package whitelist and source checks match the Plan 95-04 packaged runner and fixture.

## Task Commits

1. **Task 1: Replace the broken directory command with package-executed guidance** — `63b1410` (RED), `15a5c5b` (GREEN)
2. **Task 2: Lock exact release, compatibility, and overclaim boundaries** — `9b9ff0b` (RED), `59d7c12` (GREEN)
3. **Rule 1 correction: Align stale release contracts with the shipped CLI** — `72eae82`

## Verification

- PASS: `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` — 476 tests, 0 failures.
- PASS: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` — completed with only known non-failing Threadline sandbox cleanup logs.
- PASS: `mix ci.verify_gates` — completed after the stale package-whitelist and retired-CLI assertions were corrected.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Contract drift] Updated stale release-gate package and CLI expectations**
- **Found during:** Task 2 aggregate verification.
- **Issue:** The release gate still rejected packaged `scripts/`, expected the retired `--artifact-root` CLI, and read the pre-Plan-95-04 test-support fixture.
- **Fix:** Mirrored the actual package whitelist, archive-plus-SHA interface, and package-owned fixture location.
- **Files modified:** `test/chimeway/release_gate_contract_test.exs`
- **Commit:** `72eae82`

**Total deviations:** 1 auto-fixed (Rule 1).

## Known Stubs

None. The plan-owned guide and contracts contain no runtime or documentation stubs.

## Self-Check: PASSED

- Found the canonical guide and both documentation contract files.
- Found all task commits: `63b1410`, `15a5c5b`, `9b9ff0b`, `59d7c12`, and `72eae82`.
- No tracked file deletions were introduced by plan commits.
