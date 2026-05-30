---
phase: 60-accrue-docs-release-gate
plan: 02
subsystem: testing
tags: [accrue, dunning, doc-contract, DOCS-09, exunit]

# Dependency graph
requires:
  - phase: 60-accrue-docs-release-gate
    plan: 01
    provides: guides/introduction/accrue-dunning-integration.md (DOCS-08 guide content to lock)
provides:
  - DOCS-09 doc-contract describe for Accrue dunning integration guide
  - CI drift protection for billing-event path, canonical signal naming, and required setup strings
affects: [60-03 GATE-05 CI, doc-contract lane]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Accrue integration guide doc-contract parallels mailglass integration guide describe (DOCS-06/07)"
    - "Extends ECOS-07 blueprint required strings with guide-specific coverage (ACCRUE_PATH, mix verify.accrue, dependencies section)"

key-files:
  created: []
  modified:
    - test/chimeway/doc_contract_test.exs

key-decisions:
  - "Reused @recipe_forbidden_strings and Chimeway.Workflow regex guard from existing describes"
  - "Dedicated payment_recovered forbid test enforces canonical invoice.paid Outcome Signal naming"

patterns-established:
  - "Guide doc-contract locks D-11 required strings plus billing-state split and dependencies section tests"

requirements-completed: [DOCS-09]

# Metrics
duration: 5min
completed: 2026-05-30
---

# Phase 60 Plan 02: Accrue Integration Guide Doc-Contract Summary

**Doc-contract describe locking Accrue dunning integration guide required strings, billing-state split language, and payment_recovered drift guard in CI**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-30T11:17:00Z
- **Completed:** 2026-05-30T11:21:45Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added `accrue dunning integration guide doc contract (DOCS-08 / DOCS-09)` describe block to `doc_contract_test.exs`
- Locked 14 D-11 required strings, billing-state split language, and dependencies section coverage against guide drift
- Forbids `payment_recovered` and fictional `Chimeway.Workflow` module references per D-12 and threat model T-60-04/T-60-05

## Task Commits

Each task was committed atomically:

1. **Task 1: Add accrue integration guide doc-contract describe (D-09..D-12)** - `c09b8b8` (test)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified

- `test/chimeway/doc_contract_test.exs` - New `@accrue_integration_guide` path and DOCS-08/09 describe with forbid/require tests

## Decisions Made

None - followed plan as specified.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DOCS-09 complete; guide text locked in CI doc-contract lane
- Ready for 60-03 GATE-05 Accrue CI job and MAINTAINING.md pre-ship update

## Self-Check: PASSED

- `describe "accrue dunning integration guide doc contract (DOCS-08 / DOCS-09)"` exists (grep: 1 match)
- `@accrue_integration_guide` points to `guides/introduction/accrue-dunning-integration.md`
- `payment_recovered` forbid test present
- All D-11 required strings have dedicated `requires` tests (14 entries + billing-state + dependencies)
- `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` — 200 tests, 0 failures, exit 0

---
*Phase: 60-accrue-docs-release-gate*
*Completed: 2026-05-30*
