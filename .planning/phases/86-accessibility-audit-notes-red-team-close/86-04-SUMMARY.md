---
phase: 86-accessibility-audit-notes-red-team-close
plan: 04
subsystem: testing
tags: [red-team, scope-boundary, binary-budget, shell, git, brandbook, notes-03]

requires:
  - phase: 86-accessibility-audit-notes-red-team-close
    provides: 86-01 scripts/contrast-audit.sh (new calc path to add to the allowlist)
  - phase: 86-accessibility-audit-notes-red-team-close
    provides: 86-03 notes/accessibility-checks.md §6 owner-waived A11Y-03/A11Y-04 accepted-risk gap
provides:
  - scripts/brandbook-guards.sh --scope allowlist widened to the exact v1.15 milestone boundary (machine-enforced, deny-by-default)
  - notes/red-team.md — recorded skeptic pass closing with captured --scope audit + logo-guards --assets binary-budget PASS
affects: [phase-86-verification, milestone-v1.15-close]

tech-stack:
  added: []
  patterns:
    - Machine-enforced scope boundary via git-porcelain allowlist walk (deny-by-default *) branch) — re-runnable guard, not a pasted diff
    - Red-team record closes with verbatim captured command output (scope audit + binary budget), never asserted numbers in prose

key-files:
  created:
    - notes/red-team.md
  modified:
    - scripts/brandbook-guards.sh

key-decisions:
  - "[86-04]: Widened the existing --scope default allowlist (one source of truth) rather than adding a new --milestone-scope mode (CONTEXT OQ permitted either; single list is simpler and keeps the boundary un-duplicated)."
  - "[86-04]: Allowlist widened to EXACTLY brandbook/** + README.md + mix.exs + notes/** + the four named scripts + .planning/** — no bare scripts/* or top-level * glob, deny-by-default *) retained."
  - "[86-04]: Red-team record honestly carries the owner-waived A11Y-03/A11Y-04 manual attestation as an accepted-risk gap, NOT a pass — does not overstate the milestone as fully manually verified."

patterns-established:
  - "The scope boundary is enforced by a re-runnable guard walk, not a pasted git diff — a future stray edit outside the allowlist FAILs the check (closes the NOTES-03 vacuous-pass footgun)."

requirements-completed: [NOTES-03]

coverage:
  - id: D-SCOPE
    description: "Machine-enforced brandbook/-only scope boundary via widened --scope allowlist; passes on the milestone tree, fails on any stray path"
    requirement: "NOTES-03"
    verification:
      - kind: automated
        ref: "scripts/brandbook-guards.sh --scope exits 0 on the milestone tree; scratch STRAY-SCRATCH.tmp flips it to exit 1 (deny-by-default *)"
        status: pass
    human_judgment: false
  - id: D-BUDGET
    description: "Repo-size/binary budget captured: exactly 3 committed rasters, 38,579B <= 204,800B ceiling, PASS; no new binary this milestone"
    requirement: "NOTES-03"
    verification:
      - kind: automated
        ref: "scripts/logo-guards.sh --assets binary-budget PASS (favicon.ico 15,086B + apple-touch-icon.png 2,004B + chimeway-og.png 21,489B = 38,579B)"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-28
status: complete
---

# Phase 86 Plan 04: Milestone-Close Red-Team — Machine-Enforced Scope Boundary + Binary Budget Summary

**Widened the existing `scripts/brandbook-guards.sh --scope` allowlist to the exact v1.15 milestone boundary (`brandbook/**` + `README.md` + `mix.exs` + `notes/**` + the four named guard/render/calc scripts + `.planning/**`, deny-by-default retained, no broad glob) and recorded `notes/red-team.md` — the skeptic pass closing with the captured `--scope` audit and the `logo-guards.sh --assets` binary-budget PASS (3 rasters, 38,579B ≤ 204,800B), honestly carrying the owner-waived A11Y-03/A11Y-04 manual attestation forward as an accepted-risk gap, not a pass.**

## Performance

- **Duration:** ~8 min
- **Completed:** 2026-07-28
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- **Task 1 (commit `966afee`):** Widened the `--scope` `case "$path" in` allowlist in `scripts/brandbook-guards.sh` from `brandbook/*` + the guard + `.planning/*` to the exact milestone boundary — adding `README.md` (Phase 85 D-01 header lockup), `mix.exs` (Phase 85 D-02 ExDoc `:logo`/`:favicon`), `notes/*` (the record set incl. this red-team pass), `scripts/logo-guards.sh` (binary budget), `scripts/render-svg-png.sh` (render helper), and `scripts/contrast-audit.sh` (the Plan 86-01 calc). Updated the block's header comment to enumerate the boundary and the "no broad glob" rationale. Kept the deny-by-default `*)` stray branch verbatim. No new `--scope` mode was added — the default list is the single source of truth (CONTEXT OQ permitted either; single list chosen).
- **Task 2 (commit `c38ee47`):** Created `notes/red-team.md` in the established decision-log voice (sourced claim → disposition → proof line). It enumerates the boundary the milestone claims (a nine-row scope table), names the footgun NOTES-03 closes (a pasted diff asserts without enforcing), and a skeptic-challenge table pairing each red-team objection with its re-runnable machine answer. It closes with two verbatim captured outputs: (a) `brandbook-guards.sh --scope` showing the porcelain walk permitting the untracked record file and the `== scope OK ==` PASS line; (b) `logo-guards.sh --assets` binary-budget PASS. It records the owner-waived A11Y-03/A11Y-04 manual checks as a documented accepted-risk gap (NOT a pass), so phase verification sees the gap.

## Verification

- **PASS:** `scripts/brandbook-guards.sh --scope` exits 0 on the milestone tree (README.md, mix.exs, notes/**, and scripts/contrast-audit.sh no longer false-FAIL).
- **PASS:** deny-by-default holds — a scratch `STRAY-SCRATCH.tmp` at repo root flips `--scope` to `== scope FAILED ==` / exit 1.
- **PASS:** allowlist greps — `README.md`, `mix.exs`, `notes/*`, `contrast-audit.sh` all present in the guard.
- **PASS:** `scripts/logo-guards.sh --assets` → `binary-budget: 3 rasters, 38579B <= 204800B ceiling`, `== ASSET GATE PASSED ==` (exit 0). Exactly 3 rasters, boundary holds (a 4th raster or a total >204,800B would FAIL).
- **PASS:** `git diff --quiet -- brandbook/tokens/tokens.css` — TOKEN-01 zero-drift held; tokens.css touched by 0 of the two commits.
- **PASS:** only two files changed by this plan (`notes/red-team.md`, `scripts/brandbook-guards.sh`); the only file added is the text record — no binary/raster added.

## Task Commits

Each task was committed atomically:

1. **Task 1: widen --scope allowlist to milestone boundary** — `966afee` (feat)
2. **Task 2: record the red-team pass with captured scope + binary-budget output** — `c38ee47` (docs)

**Plan metadata:** committed separately with STATE/ROADMAP updates.

## Files Created/Modified

- `scripts/brandbook-guards.sh` — `--scope` allowlist widened to the exact milestone boundary; deny-by-default `*)` retained; no broad glob; header comment documents the boundary.
- `notes/red-team.md` — the recorded milestone-close skeptic pass, closing with the captured `--scope` audit + `logo-guards.sh --assets` binary-budget PASS; accepted-risk A11Y gap recorded honestly.

## Decisions Made

- Widened the single default `--scope` allowlist rather than adding a `--milestone-scope` mode — keeps the boundary un-duplicated and the audit un-bypassable (CONTEXT OQ permitted either).
- Enumerated exactly the six D-03 paths plus the retained originals; introduced no bare `scripts/*` or top-level `*` glob (an over-broad allowlist silently defeats the audit).
- Recorded the owner-waived manual A11Y-03/A11Y-04 attestation as an accepted-risk gap in the red-team record, matching the 86-03 waiver truth — the red-team does not claim full manual verification.

## Deviations from Plan

None — plan executed exactly as written. Both tasks' automated `<verify>` blocks passed; the scope boundary was additionally proven to FAIL on a stray scratch file (acceptance criterion), and the binary budget passed at exactly 3 rasters.

## Threat Model Follow-through

- **T-86-03 (allowlist over-permissiveness):** mitigated — exactly the six D-03 paths added, no broad glob, deny-by-default `*)` retained; a stray scratch file still FAILs `--scope`.
- **T-86-04 (porcelain-walk path parsing):** mitigated — reused the existing line-based porcelain walk verbatim (no NUL/eval; rename destinations handled; quoted expansions).
- **T-86-07 (new/oversized binary):** mitigated — `logo-guards.sh --assets` binary budget run and captured (3 rasters ≤ 204,800B); no new binary committed.

## Known Stubs

None introduced. No placeholder/TODO/FIXME or empty-data UI stubs. `notes/red-team.md` quotes real, re-runnable command output; `scripts/brandbook-guards.sh --scope` enforces a real boundary.

## Accepted-Risk Gap Carried Forward (FLAG FOR PHASE VERIFICATION)

A11Y-03 (focus-not-obscured, SC 2.4.11) and A11Y-04 (never-color-alone / CVD emulation) manual browser attestations were **WAIVED by the project owner on 2026-07-28** (Plan 86-03) — recorded as documented known gaps in `notes/accessibility-checks.md` §6.1/§6.2 and re-flagged in `notes/red-team.md`. This Plan 86-04 red-team covers NOTES-03 (scope boundary + binary budget) only; it does not substitute for the waived manual A11Y attestation. Phase 86 verification / the milestone audit should treat both as accepted-risk known gaps.

## Issues Encountered

None. Both guards ran green on first invocation; `xmllint` and `magick` were present so the `--assets` gate also confirmed SVG well-formedness and raster dimensions (16/32/48 ICO, 180×180 apple-touch, 1200×630 OG) alongside the budget.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- NOTES-03 satisfied — the `brandbook/`-only scope boundary is machine-enforced and the red-team record is committed.
- Ready for Phase 86 verification / v1.15 milestone close. Carry forward the owner-waived A11Y-03/A11Y-04 accepted-risk gap for a ship-time decision (close or schedule a follow-up manual pass).
- `brandbook/tokens/tokens.css` untouched — zero-drift TOKEN-01 held; no new binary committed.

## Self-Check: PASSED

- Found `scripts/brandbook-guards.sh` (widened) and `notes/red-team.md` on disk.
- Found task commits `966afee` (feat, guard widening) and `c38ee47` (docs, red-team record).
- `--scope` exits 0 on the milestone tree; a stray scratch file flips it to exit 1.
- `logo-guards.sh --assets` binary-budget PASS (3 rasters, 38,579B ≤ 204,800B).
- `git diff --quiet -- brandbook/tokens/tokens.css` clean (zero-drift held); no binary added.
- No tracked file deletions introduced by either commit.

---
*Phase: 86-accessibility-audit-notes-red-team-close*
*Completed: 2026-07-28*
