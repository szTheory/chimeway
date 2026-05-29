---
phase: 41-release-verification-gates
plan: "02"
subsystem: infra
tags: [mix, gate-01, ci, maintaining, release-runbook]

requires:
  - phase: 41-release-verification-gates
    provides: "Adoption-surface doc-contract gates from plan 41-01"
provides:
  - "Named mix ci.verify_gates GATE-01 entrypoint (scoped doc-contract tests)"
  - "MAINTAINING.md pre-ship quartet mandate (ci, ci.docs, ci.verify_gates, verify.example)"
  - "Installer template conditional for mix ci.install_golden"
affects:
  - 41-03 (verify.example CI expansion)

tech-stack:
  added: []
  patterns:
    - "ci.verify_gates mirrors ci.install_golden scoped-test alias pattern"
    - "Pre-ship GATE-01 quartet documented separately from post-publish verify trio"

key-files:
  created: []
  modified:
    - mix.exs
    - MAINTAINING.md
    - .planning/phases/41-release-verification-gates/41-VALIDATION.md
    - test/chimeway/doc_contract_test.exs

key-decisions:
  - "ci.verify_gates runs doc_contract_test.exs only — does not bundle ci.docs or verify.example"
  - "Default mix ci alias unchanged — verify.example not added per D-09"
  - "Post-publish verify trio (verify.clean, verify.parity, verify.published) left untouched per D-16"

patterns-established:
  - "GATE-01 citeable entrypoint: mix ci.verify_gates for adoption-surface doc gates"
  - "MAINTAINING.md step 3 mandates four pre-ship commands; installer changes get separate subsection"

requirements-completed: [GATE-01]

duration: 18min
completed: 2026-05-29
---

# Phase 41 Plan 02: GATE-01 Entrypoint and Release Runbook Summary

**Named `mix ci.verify_gates` alias plus MAINTAINING.md pre-ship quartet documenting ci, ci.docs, verify_gates, and verify.example as mandatory before tagging**

## Performance

- **Duration:** 18 min
- **Started:** 2026-05-29T12:20:00Z
- **Completed:** 2026-05-29T12:38:00Z
- **Tasks:** 3 completed
- **Files modified:** 4

## Accomplishments

- Added `mix ci.verify_gates` alias running `test/chimeway/doc_contract_test.exs` only — fast, no Postgres, parallel to `ci.install_golden` pattern
- Expanded MAINTAINING.md step 3 with GATE-01 pre-ship quartet; added installer template conditional subsection; renumbered steps 4–8
- Post-publish verify trio in step 7 unchanged (`verify.clean`, `verify.parity`, `verify.published`)
- Wave 2 validation sign-off in 41-VALIDATION.md with partial `wave_0_complete: true`

## Task Commits

Each task was committed atomically:

1. **Task 41-02-01: Add mix ci.verify_gates alias** - `11bd974` (feat)
2. **Task 41-02-02: Update MAINTAINING.md release runbook** - `8f77f0f` (docs)
3. **Task 41-02-03: Update phase validation checklist** - `a89eaf8` (docs)

**Plan metadata:** pending (docs commit after this file)

## Files Created/Modified

- `mix.exs` - `ci.verify_gates` GATE-01 entrypoint after `ci.install_golden`
- `MAINTAINING.md` - Pre-ship quartet, installer conditional, renumbered release steps
- `.planning/phases/41-release-verification-gates/41-VALIDATION.md` - Wave 2 task sign-off and verification record
- `test/chimeway/doc_contract_test.exs` - Format fix (blank line after assert)

## Decisions Made

- `ci.verify_gates` does not bundle `ci.docs` — MAINTAINING.md mandates both separately (D-14 discretion resolved toward separation)
- Default `mix ci` remains `["ci.lint", "ci.test"]` — `verify.example` not added (D-09)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] doc_contract_test.exs format check failure**
- **Found during:** Task 41-02-03 (`mix ci` verification)
- **Issue:** Missing blank line after `assert triggers > 0` caused `mix format --check-formatted` to fail (introduced in 41-01)
- **Fix:** Ran `mix format` on `test/chimeway/doc_contract_test.exs`
- **Files modified:** test/chimeway/doc_contract_test.exs
- **Verification:** `mix ci` — 655 tests, 0 failures
- **Committed in:** a89eaf8

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Format fix unblocks `mix ci`; no scope creep.

## Issues Encountered

- `mix ci.docs` fails with pre-existing ex_doc warnings for relative links to `examples/chimeway_demo_host/README.md` and `chimeway_admin/` in guides — present before 41-02; deferred to separate fix

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 41-03: `verify.example` admin smoke expansion and `verify_example` CI job
- GATE-01 partial: doc-contract entrypoint and runbook complete; CI wiring for verify.example remains

## Self-Check: PASSED

- [x] `mix ci.verify_gates` exits 0 — 94 tests, ~0.08s
- [x] `mix help ci` does not list `verify.example`
- [x] MAINTAINING.md step 3 lists all four pre-ship commands
- [x] MAINTAINING.md step 7 post-publish verify trio unchanged
- [x] `grep ci.verify_gates mix.exs` ≥ 1
- [x] Step numbering sequential 1–8

---
*Phase: 41-release-verification-gates*
*Completed: 2026-05-29*
