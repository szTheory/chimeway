---
phase: 60-accrue-docs-release-gate
plan: 03
subsystem: infra
tags: [github-actions, accrue, release-gates, ci]

# Dependency graph
requires:
  - phase: 58-accrue-dunning-core
    provides: mix verify.accrue alias and ECOS-06 integration harness
  - phase: 59-accrue-blueprint-demo
    provides: DEMO-07 demo host :accrue proof tests
provides:
  - verify_accrue CI job with pinned szTheory/accrue sibling checkout
  - MAINTAINING.md pre-ship septet including mix verify.accrue (GATE-05 Accrue half)
affects:
  - phase 62 (inbox gate deferred; septet becomes octet later)
  - maintainers cutting releases

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mirror verify_mailglass job structure for ecosystem verify gates"
    - "ACCRUE_PATH sibling checkout in CI and local maintainer docs"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - MAINTAINING.md

key-decisions:
  - "Pin Accrue ref de7a3fef53247619d96a26eea60197d74fd14634 in CI (matches local sibling HEAD at plan time)"
  - "Use SHA-pinned actions/checkout for sibling repo (consistent with existing workflow pins)"
  - "mix verify.accrue alias unchanged per D-15 — env-only ACCRUE_PATH discovery"

patterns-established:
  - "Ecosystem verify jobs: Postgres service + sibling repo checkout + dedicated cache key + mix verify.*"

requirements-completed: [GATE-05]

# Metrics
duration: 12min
completed: 2026-05-30
---

# Phase 60 Plan 03: Accrue CI Gate & Maintainer Checklist Summary

**Formal `verify_accrue` CI job with pinned szTheory/accrue checkout and MAINTAINING pre-ship septet documenting `mix verify.accrue` as GATE-05 Accrue half**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-30T11:05:00Z
- **Completed:** 2026-05-30T11:17:32Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `verify_accrue` GitHub Actions job mirroring `verify_mailglass` with Postgres, pinned Accrue checkout to `accrue/accrue`, and `ACCRUE_PATH` env
- Extended MAINTAINING.md pre-ship checklist from six to seven gates with `mix verify.accrue` command, GATE-05 description, and Accrue sibling checkout subsection
- Existing `verify_mailglass`, `verify_journeys`, and default `ci` jobs unchanged (additive CI only)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add verify_accrue CI job (D-13, D-14)** - `a54a089` (feat)
2. **Task 2: Update MAINTAINING.md pre-ship septet (D-16)** - `4798a5b` (docs)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified

- `.github/workflows/ci.yml` - New `verify_accrue` job after `verify_mailglass` with sibling Accrue checkout and `mix verify.accrue` step
- `MAINTAINING.md` - Seventh pre-ship gate, ACCRUE_PATH documentation, pinned CI ref note

## Decisions Made

- Used existing SHA-pinned `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` for sibling repo checkout (consistent with workflow convention)
- Left `mix.exs` `verify.accrue` alias unchanged — CI layout at `accrue/accrue` satisfies demo host hardcoded `../../../accrue/accrue` path

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- GATE-05 Accrue half complete; Phase 60-02 (doc-contract DOCS-09) can proceed independently
- Phase 62 will add `mix verify.inbox` as eighth gate (GATE-05 inbox half)
- Maintainers should clone szTheory/accrue adjacent to chimeway for local pre-ship runs

## Self-Check: PASSED

- `[ -f .github/workflows/ci.yml ]` — PASS
- `[ -f MAINTAINING.md ]` — PASS
- `grep verify_accrue .github/workflows/ci.yml` — PASS (single job id)
- `grep szTheory/accrue .github/workflows/ci.yml` — PASS (pinned ref de7a3fef53247619d96a26eea60197d74fd14634)
- `grep 'mix verify.accrue' .github/workflows/ci.yml` — PASS
- `grep 'mix verify.accrue' MAINTAINING.md && grep -i seven MAINTAINING.md` — PASS
- `ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors` — PASS (11 root + 3 demo tests, 0 failures)
- `mix.exs` unchanged — PASS (0 diff lines)
- `verify_mailglass` job unchanged — PASS

---
*Phase: 60-accrue-docs-release-gate*
*Completed: 2026-05-30*
