---
phase: 96-adoption-front-door-proof-gate
plan: "02"
subsystem: adoption-docs-and-ci
tags: [elixir, exdoc, github-actions, postgresql, release-gate]
requires:
  - phase: 96-adoption-front-door-proof-gate
    provides: bounded Core, Mailglass, and Accrue artifact proof task
provides:
  - canonical three-path adoption selector with bounded focused commands
  - PostgreSQL adoption-proof lane wired into pr-gate and ci-gate
  - structural ExUnit contracts for selector and workflow topology
affects: [ADPT-01, ADPT-02, GATE-02, DOCS-01]
tech-stack:
  added: []
  patterns: [first ExDoc selector, safe proof-record examples, two-gate CI coupling]
key-files:
  created:
    - guides/introduction/adoption-paths.md
  modified:
    - README.md
    - mix.exs
    - .github/workflows/ci.yml
    - test/chimeway/doc_contract_test.exs
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "The selector compares only Core, Mailglass, and Accrue in progressive-complexity order and routes detailed setup to the existing guides."
  - "The aggregate artifact proof runs once in a serial PostgreSQL 15 lane on every CI event and gates both pr-gate and ci-gate through needs, environment, and aggregate arguments."
requirements-completed: [ADPT-01, ADPT-02, GATE-02, DOCS-01]
metrics:
  duration: "~20 minutes"
  tasks_completed: 2
  files_modified: 6
completed: 2026-08-10
status: complete
---

# Phase 96 Plan 02: Adoption Front Door & Proof Gate Summary

**A concise selector now directs adopters to one of three bounded clean-room proofs, while a PostgreSQL-backed CI lane continuously verifies the aggregate command on pull requests and full CI runs.**

## Accomplishments

- Added the first ExDoc Introduction guide, with comparable Core, Mailglass, and Accrue sections that pin ownership, exact commands, safe proof shapes, limits, and canonical next steps.
- Routed README users to the selector without duplicating its decision content and retained explicit packaged-runner membership.
- Added `verify_adoption_paths`, a serial PostgreSQL 15 job with a 30-minute limit, root cache/compile preparation, and `mix verify.adoption_paths` execution on every CI event.
- Wired the lane through both `pr-gate` and `ci-gate` needs, result environments, and aggregate-gate arguments.
- Extended established doc/release-gate contracts with selector, package surface, workflow topology, and mutation-oriented drift checks.

## Task Commits

1. **Task 1: Publish and contract-check the exact three-path adoption selector** — `0ebba28`
2. **Task 2: Add the single PostgreSQL adoption lane and couple every gate edge** — `5411f32`

## Verification

- PASS — focused selector contract: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --only adoption_paths_docs_contract --warnings-as-errors` (3 tests, 0 failures).
- PASS — focused CI topology contract: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only adoption_paths_ci_contract --warnings-as-errors` (2 tests, 0 failures).
- PASS — `mix ci.verify_gates`.
- PASS — `mix format --check-formatted mix.exs test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs`.
- PASS — `mix docs --warnings-as-errors`.
- PASS — exact-SHA GitHub Actions run `31449129603` executed `verify_adoption_paths` and its required `pr-gate` consumer successfully at `c13bae7c92c537f3e758330703168119703a301b`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Contract precision] Scope ExDoc extras assertion to the documentation list**
- **Found during:** Task 1
- **Issue:** The selector test matched both `extras` and `groups_extras`, so it did not unambiguously prove first position in the ExDoc extras list.
- **Fix:** Anchored the assertion to the indented documentation `extras` entry.
- **Files modified:** `test/chimeway/doc_contract_test.exs`
- **Verification:** Focused selector contract passed.

**2. [Rule 1 - Gate topology] Update the existing ci-gate lane count**
- **Found during:** Task 2
- **Issue:** The established pipeline-tiering contract still expected 14 `ci-gate` dependencies after the planned adoption lane made the total 15.
- **Fix:** Updated the count and explanation while preserving nightly-lane exclusions.
- **Files modified:** `test/chimeway/release_gate_contract_test.exs`
- **Verification:** `mix ci.verify_gates` passed.

**Total deviations:** 2 auto-fixed. **Impact:** The new selector and CI dependency are protected by precise contracts without changing product behavior.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed `guides/introduction/adoption-paths.md` exists.
- Confirmed task commits `0ebba28` and `5411f32` exist in git history.
