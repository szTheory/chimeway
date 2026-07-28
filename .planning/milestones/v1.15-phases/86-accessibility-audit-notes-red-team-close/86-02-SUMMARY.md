---
phase: 86-accessibility-audit-notes-red-team-close
plan: 02
subsystem: docs
tags: [wcag, accessibility, citations, notes, brandbook, recommendations]

requires:
  - phase: 86-accessibility-audit-notes-red-team-close
    provides: notes/accessibility-checks.md per-pairing ratio record (Plan 86-01) that these citations back
  - phase: 82-logo-exploration-shortlist
    provides: notes/logo-options.md NOTES-01 recommendation-format precedent
  - phase: 81-design-tokens-reconciliation-documentation
    provides: notes/decision-log.md established notes voice (sourced claim -> disposition -> proof line)
provides:
  - notes/research.md — WCAG 2.2 verbatim citation basis (SC 1.4.3/1.4.11/2.4.7/2.4.11/2.3.3/2.5.8) + design-system analogues (USWDS/Carbon/GOV.UK) + five cohesive NOTES-01 recommendations
affects: [86-03-cvd-focus-operator-signoff, 86-04-scope-allowlist-widening]

tech-stack:
  added: []
  patterns:
    - Verbatim WCAG normative text (quoted, not paraphrased) with per-SC w3.org source citations
    - Record vs recommendation separation — citation/analogue sections labeled record; NOTES-01 format applied only to recommendations
    - Cohesive single-verdict recommendations (Pros/Cons/Tradeoffs, analogue, cost, Ship|Defer|Reject, Confidence), never an options buffet

key-files:
  created:
    - notes/research.md
  modified: []

decisions:
  - Reproduced WCAG verbatim text from 86-RESEARCH.md § Citation Basis (HIGH/VERIFIED vs w3.org), with primary-source citations for independent re-check
  - Labeled the citation-basis and design-system-analogue sections as record (exempt from NOTES-01 format); applied Pros/Cons/Verdict/Confidence only to the five recommendations
  - Recorded SC 2.3.3 as Level AAA (book exceeds AA); recorded the 0.03928-vs-0.04045 errata as immaterial to every verdict
  - Deferred all actual ratio/token changes to ADMIN-RETHEME-01 (zero-drift TOKEN-01)

metrics:
  duration: ~10m
  completed: 2026-07-28
  tasks: 2
  files_created: 1
  files_modified: 0

status: complete
---

# Phase 86 Plan 02: Accessibility Research Basis & Citations Summary

WCAG 2.2 verbatim citation basis + design-system analogues + five cohesive NOTES-01
recommendations, captured in `notes/research.md` in the established notes voice — satisfying
NOTES-04 (research basis + citations) and NOTES-01 (cohesive recommendations, not a buffet).

## What was built

`notes/research.md` — the research basis of record for the Phase 86 accessibility audit:

- **WCAG 2.2 Citation Basis (record):** verbatim normative text for SC 1.4.3 (incl. Large Text /
  Incidental / Logotypes), SC 1.4.11 (User Interface Components / Graphical Objects), SC 2.4.7,
  SC 2.4.11, SC 2.3.3, and SC 2.5.8 (incl. all five exceptions: Spacing, Equivalent, Inline, User
  agent control, Essential), each with its w3.org source citation. Plus the relative-luminance +
  contrast-ratio formula and the `0.03928`-vs-`0.04045` errata note (proven immaterial to every
  verdict). SC 2.3.3 recorded as **Level AAA** (the book exceeds the AA bar).
- **Design-System Analogues (record):** USWDS, IBM Carbon, and GOV.UK — cited for how each
  documents contrast/exemption reasoning and verifies never-color-alone / CVD safety **without**
  shipping simulated-screenshot binaries, with what each is an analogue FOR.
- **Cohesive Recommendations (NOTES-01):** five recommendations (R-1..R-5), each carrying
  Pros/Cons/Tradeoffs, an analogue, an implementation cost, a Ship/Defer/Reject verdict, and a
  Confidence rating, in a stable topic order — never an options buffet.

## Tasks completed

| Task | Name | Commit |
|------|------|--------|
| 1 | research.md — WCAG verbatim citation basis + design-system analogues (NOTES-04) | 63e7661 |
| 2 | research.md — cohesive recommendations in the NOTES-01 format | 5976142 |

Final metadata commit adds this SUMMARY + STATE/ROADMAP updates.

## Key decisions

- **Record vs recommendation split:** the citation-basis and analogue sections are explicitly
  labeled *record* and exempt from the NOTES-01 format; the Pros/Cons/Verdict/Confidence format is
  applied only to the five recommendations (NOTES-01 empty-predicate honored).
- **Verbatim over paraphrase:** all SC text is quoted verbatim (D-07), reproduced from
  86-RESEARCH.md § Citation Basis (HIGH/VERIFIED against w3.org), with primary citations retained
  for independent re-check — pre-empting a red-team dispute over exemption applicability.
- **Zero-drift preserved:** no token edited, no binary committed; all actual ratio/token changes
  deferred to ADMIN-RETHEME-01.

## Recommendations recorded (R-1..R-5)

| # | Topic | Verdict | Confidence |
|---|-------|---------|------------|
| R-1 | Document sub-threshold pairs as WCAG exemptions, don't patch tokens | Ship | High |
| R-2 | Record 4.95:1 primary-button pair as a watch-item, don't pad it | Defer (fix) / Ship (record) | High |
| R-3 | Never-color-alone + CVD via architecture + DevTools emulation, no binaries | Ship | High |
| R-4 | Adjudicate A11Y-03 targets against SC 2.5.8 Inline/Spacing exceptions | Ship | Medium |
| R-5 | Machine-enforce scope via widened `--scope` allowlist, not a pasted diff | Ship | High |

## Deviations from Plan

None — plan executed exactly as written. Both tasks' automated `<verify>` blocks passed; tokens
untouched; no binary committed.

## Verification

- Task 1 verify: `test -f notes/research.md && grep 'no contrast requirement' && grep 'required to identify' && grep -E 'USWDS|GOV.UK|Carbon'` → PASS
- Task 2 verify: `grep -Ei 'ship|defer|reject' && grep -Ei 'confidence' && grep -Ei 'pros|cons|tradeoff'` → PASS
- Five `**Verdict:**` + five `**Confidence:**` entries present; all six SCs quoted verbatim with citations; three named analogues (USWDS, Carbon, GOV.UK).
- `git diff --exit-code brandbook/tokens/tokens.css` → clean (zero-drift preserved); no new binary.

## Known Stubs

None.

## Self-Check: PASSED
- FOUND: notes/research.md
- FOUND commit: 63e7661 (Task 1)
- FOUND commit: 5976142 (Task 2)
