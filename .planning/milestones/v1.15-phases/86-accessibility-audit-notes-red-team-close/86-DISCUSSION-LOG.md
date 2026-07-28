# Phase 86: Accessibility Audit, Notes & Red-Team Close - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-27
**Phase:** 86-accessibility-audit-notes-red-team-close
**Mode:** assumptions
**Areas analyzed:** Contrast verification method; Actual contrast findings (document-vs-patch); Red-team recording & scope/binary audit; CVD verification & research record

## Assumptions Presented

### Contrast verification method (A11Y-01/02/05)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Per-pairing table from a dependency-free offline calc reading `tokens.css` + reusing the in-page WCAG formula; live matrix is rendered-output proof but not sole A11Y-05 record | Likely | `brandbook/index.html` scores only 8 `.cwb-cell[data-fg]` text cells; status triads, borders, focus rings, disabled states unscored |

### Actual contrast findings — document-as-exempt (A11Y-01/02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No text pair forces a token change; sub-4.5 disabled text and sub-3:1 status/panel borders are WCAG-exempt → record as documented exemptions, don't patch tokens | Confident (ratios) / Likely (disposition) | Computed: disabled text 3.92:1 (light, 1.4.3-exempt); status borders 1.29–1.77 & panel border 1.47:1 (1.4.11 decorative); focus rings 4.78–8.57, status text/surface 5.88–11+ pass; primary button white/teal `#0e7c86` = 4.95:1 watch item. Tokens verbatim from shipped admin CSS (`tokens.css:3-7`, zero-drift invariant) |

### Red-team recording & scope/binary audit (NOTES-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Machine-enforce scope by extending the guard allowlist (add README.md, mix.exs, notes/**); record skeptic pass + captured audit in new `notes/red-team.md` | Confident (assets) / Likely (file location) | `scripts/brandbook-guards.sh --scope` does git diff --stat + allowlist walk; `scripts/logo-guards.sh` has binary budget (3 rasters ≤200KB, "feeds NOTES-03"); current allowlist omits the two integration edits + notes/ → would false-FAIL as-is |

### CVD verification & research record (A11Y-04/03, NOTES-01/04)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Argue CVD safety from "never color-alone" architecture + documented Chrome DevTools vision-deficiency emulation checklist; no binaries; `research.md` mirrors decision-log voice with WCAG + design-system citations | Unclear | `84-UI-SPEC.md` + `brandbook.css` enforce label+icon per status; no-binary/HTML-CSS-first discipline forbids daltonization tooling; `notes/decision-log.md` sets the citation format |

## Corrections Made

No corrections — user confirmed all assumptions ("Yes, proceed"). The Unclear CVD area was
resolved to the recommended default (architectural argument + DevTools emulation checklist,
no binaries) and accepted without correction.

## External Research

Not performed during discussion. Three citation-basis topics were flagged forward to the
phase-researcher (recorded in CONTEXT.md `<deferred>`), as they refine the *notes* rather than
change any locked decision:
- WCAG 2.2 normative exemption wording for SC 1.4.3 (disabled) and SC 1.4.11 (decorative).
- SC 2.5.8 (24px target) applicability to borderline inline nav anchors (~22px) and toggle segments.
- Mature design-system analogues for documenting contrast exemptions and CVD verification.
