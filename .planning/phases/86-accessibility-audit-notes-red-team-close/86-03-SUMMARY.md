---
phase: 86-accessibility-audit-notes-red-team-close
plan: 03
subsystem: testing
tags: [wcag, accessibility, cvd, focus-not-obscured, brandbook, waiver, accepted-risk]

requires:
  - phase: 86-accessibility-audit-notes-red-team-close
    provides: 86-01 notes/accessibility-checks.md A11Y-03/A11Y-04 checklist stubs + never-color-alone architectural argument
provides:
  - notes/accessibility-checks.md §6 operator run-book + A11Y-03/A11Y-04 sign-off blocks recorded as WAIVED (accepted-risk, not manually verified)
affects: [86-04-scope-allowlist-widening, phase-86-verification]

tech-stack:
  added: []
  patterns:
    - Manual-verification checkpoint resolved by an explicit owner risk-acceptance WAIVER recorded as a documented known gap (not a fabricated PASS)

key-files:
  created: []
  modified:
    - notes/accessibility-checks.md

key-decisions:
  - "[86-03]: The two manual browser checks (A11Y-04 CVD emulation, A11Y-03 focus-not-obscured) were WAIVED by the project owner on 2026-07-28 — risk accepted, manual verification not performed."
  - "[86-03]: Waiver recorded truthfully as a documented known gap in notes/accessibility-checks.md §6.1/§6.2 (WAIVED / accepted-risk / NOT PASS); operator sign-off NOT fabricated."
  - "[86-03]: A11Y-03/A11Y-04 are only PARTIALLY satisfied — corroborating machine/CSS evidence (never-color-alone architecture; RESEARCH A3 + §4 focus CSS) mitigates but does not substitute for the human attestation, so the requirements are NOT marked complete."

patterns-established:
  - "Owner-waived manual checks are recorded as accepted-risk known gaps, never as PASS — phase verification must see the gap, not a false green."

requirements-completed: []

coverage:
  - id: D-CVD
    description: "A11Y-04 CVD emulation (protanopia/deuteranopia/tritanopia/achromatopsia) on rendered brandbook — operator-attested"
    requirement: "A11Y-04"
    verification:
      - kind: manual_procedural
        ref: "notes/accessibility-checks.md §6.1 — WAIVED (owner accepted risk 2026-07-28); corroborated by §5 never-color-alone architecture"
        status: waived
    human_judgment: true
    rationale: "Manual CVD emulation waived by owner. Residual risk mitigated (not eliminated) by the grep-backed never-color-alone architecture: every status = surface + text + label + icon."
  - id: D-FOCUS
    description: "A11Y-03 focus-not-obscured (SC 2.4.11) keyboard-tab pass on rendered brandbook — operator-attested"
    requirement: "A11Y-03"
    verification:
      - kind: manual_procedural
        ref: "notes/accessibility-checks.md §6.2 — WAIVED (owner accepted risk 2026-07-28); corroborated by RESEARCH A3 + §4 focus CSS evidence"
        status: waived
    human_judgment: true
    rationale: "Manual keyboard-tab pass waived by owner. Residual risk mitigated (not eliminated) by RESEARCH A3 low-risk assessment and the rendered-CSS focus evidence in §4."

duration: 4min
completed: 2026-07-28
status: complete
---

# Phase 86 Plan 03: Operator CVD + Focus-Not-Obscured — WAIVED (Accepted Risk) Summary

**The two genuinely-manual browser accessibility checks (A11Y-04 CVD emulation and A11Y-03 focus-not-obscured) were WAIVED by the project owner on 2026-07-28 — risk accepted, manual verification not performed — and recorded truthfully in `notes/accessibility-checks.md` §6.1/§6.2 as documented known gaps (accepted-risk, NOT a PASS), corroborated by pre-existing machine/CSS evidence that mitigates but does not substitute for the human attestation.**

## Performance

- **Duration:** ~4 min
- **Completed:** 2026-07-28
- **Tasks:** 1 (checkpoint) — resolved by owner waiver, not by operator sign-off
- **Files modified:** 1 (`notes/accessibility-checks.md`)

## Accomplishments

- **Autonomous prep (commit `d570151`):** Added `notes/accessibility-checks.md` §6 — an unambiguous operator run-book with the exact DevTools "Emulate vision deficiencies" steps and keyboard-tab procedure, enumerating the interactive controls to tab (top brandmark link, 10 jump-nav anchors, 3 theme-toggle buttons, in-content links), plus empty A11Y-04/A11Y-03 sign-off blocks. Render target verified present (`brandbook/index.html`, `brandbook.css`, `tokens/tokens.css`), zero-drift held.
- **Waiver record (commit `fb75383`):** After the orchestrator relayed the owner's decision to accept the risk rather than run the manual checks, updated §6.1 (CVD) and §6.2 (focus-not-obscured) to **WAIVED / accepted-risk / NOT PASS**, dated 2026-07-28. Cited the corroborating evidence already on record for each — §5 never-color-alone architecture for CVD; RESEARCH A3 + §4 focus CSS evidence for focus-not-obscured — explicitly marking both as mitigating, not substituting. DevTools CVD boxes in §5 left deliberately **unticked**. No operator initials fabricated. No `tokens.css` / `brandbook.css` edits (zero-drift held, verified).

## Task Commits

1. **Autonomous prep — operator run-book + pending sign-off blocks** — `d570151` (docs)
2. **Waiver record — CVD/focus checks marked WAIVED (owner accepted risk)** — `fb75383` (docs)

**Plan metadata:** committed separately with STATE/ROADMAP updates.

## Files Created/Modified

- `notes/accessibility-checks.md` — added §6 operator run-book; A11Y-04 (§6.1) and A11Y-03 (§6.2) sign-off blocks recorded as WAIVED / accepted-risk known gaps.

## Deviations from Plan

**1. [Owner decision — manual verification WAIVED] A11Y-04 CVD emulation + A11Y-03 focus-not-obscured not performed**
- **Found during:** Task 1 (the checkpoint itself)
- **Plan expectation:** An operator runs the DevTools CVD emulation and the keyboard-tab focus-not-obscured pass on the rendered `brandbook/index.html`, then signs off in `notes/accessibility-checks.md`.
- **What happened:** The project owner did not have time to run the manual browser checks and, via the orchestrator, chose to **accept the risk** rather than perform them.
- **Resolution:** Recorded the truth — both checks marked **WAIVED (accepted-risk / not manually verified)**, dated 2026-07-28, as documented known gaps. Operator sign-off was **NOT fabricated**; no PASS was invented. Corroborating machine/CSS evidence cited as mitigation only.
- **Files modified:** `notes/accessibility-checks.md` (§6.1, §6.2)
- **Commit:** `fb75383`

**Total deviations:** 1 (owner-authorized waiver). No auto-fixes; no scope changes; no token/CSS edits.

## Waiver / Accepted-Risk Gap (FLAG FOR PHASE VERIFICATION)

> **A11Y-03 (focus-not-obscured, SC 2.4.11) and A11Y-04 (never-color-alone / CVD) are PARTIALLY
> satisfied only.** The machine-evidenceable portions are complete and recorded in Plan 86-01
> (§1–§5). The **manual browser attestation each requirement also prescribes (D-05/D-06) was
> NOT performed** — the project owner accepted the risk on 2026-07-28. This is a real,
> documented gap, not a pass.**
>
> - **A11Y-04 residual risk:** Lowered by the grep-backed never-color-alone architecture (every
>   status = surface + text + label + icon, `brandbook/index.html:176-183`), but the human CVD
>   emulation across protanopia/deuteranopia/tritanopia/achromatopsia was not run.
> - **A11Y-03 residual risk:** Lowered by RESEARCH A3 (low risk) and the rendered-CSS focus
>   evidence in §4, but the human keyboard-tab focus-not-obscured pass was not run.
>
> Because the manual attestation is waived, **A11Y-03 and A11Y-04 are intentionally NOT marked
> complete** in this plan's `requirements-completed` (left empty). Phase 86 verification / the
> milestone audit should treat both as accepted-risk known gaps and decide whether to close
> them at ship time or schedule a follow-up manual pass.

## Known Stubs

None introduced. The §6 sign-off blocks are intentionally recorded as WAIVED known gaps (not code stubs, not placeholder UI). No TODO/FIXME/placeholder content added.

## Issues Encountered

- The cross-phase `.planning/WINDOWS.md` broken-windows ledger is not initialized in this repo (`windows_ledger_missing`), so the two accepted-risk gaps could not be appended there. Per the ledger's best-effort contract this is a non-blocking no-op; the gaps are instead flagged prominently in this SUMMARY (above) and in `notes/accessibility-checks.md` §6 so phase verification still sees them.

## User Setup Required

None. (The manual browser checks were the only operator action; they were waived by owner decision.)

## Next Phase Readiness

- Ready for Plan 86-04 (`brandbook-guards.sh --scope` allowlist widening for `scripts/contrast-audit.sh`, `notes/**`, etc.).
- Open accepted-risk gap carried forward: A11Y-03 / A11Y-04 manual attestation waived — revisit at Phase 86 verification / milestone audit / ship gate.
- `brandbook/tokens/tokens.css` and `brandbook/brandbook.css` untouched — zero-drift TOKEN-01 held.

## Self-Check: PASSED

- Found `notes/accessibility-checks.md` §6.1/§6.2 recorded as WAIVED on disk.
- Found task commits `d570151` (run-book) and `fb75383` (waiver record).
- `git diff --quiet -- brandbook/tokens/tokens.css brandbook/brandbook.css` clean (zero-drift held; no token/CSS edits).
- No operator PASS or sign-off initials fabricated; waiver recorded as a documented known gap.
- No tracked file deletions introduced.

---
*Phase: 86-accessibility-audit-notes-red-team-close*
*Completed: 2026-07-28*
