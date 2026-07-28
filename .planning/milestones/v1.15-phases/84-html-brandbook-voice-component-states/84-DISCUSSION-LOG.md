# Phase 84: HTML Brandbook, Voice & Component States - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-18
**Phase:** 84-html-brandbook-voice-component-states
**Mode:** assumptions
**Calibration:** minimal_decisive (`vendor_philosophy: opinionated`)
**Areas analyzed:** Logo rendering policy + drift control, Do/Don't misuse rendering, Guard-script enforcement shape

## Context

Phase 84 entered discuss with three approved upstream artifacts already in place (`84-UI-SPEC.md` verified 6/6 PASS, `84-RESEARCH.md` 41KB, `84-VALIDATION.md`). These lock nearly every content, visual, copy, state, and validation decision. The assumptions analysis therefore targeted only the genuinely-open *structural / implementation-shape* choices a planner still needs — not re-litigating decided material.

## Assumptions Presented

### Logo rendering policy + inline-SVG drift control
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Inline `<svg>` only theme-recoloring marks (mark-mono, logotype-mono, logotype-inverse); `<img src>` for the four fixed-color/raster assets; add a `<path d=…>` parity check to the guard script | Likely | RESEARCH Open-Q#2, Pitfalls 3/4; `brandbook/assets/logo/*.svg` on disk; mono/inverse carry `fill="currentColor"` |

### How the Do/Don't "don't" misuse is faked
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Render each "don't" via a scoped `.cwb-dont` CSS wrapper applying the offending treatment in CSS only; never commit a broken SVG | Likely | RESEARCH forbids baking a cage into the asset; milestone scope guard forbids new assets; UI-SPEC STATE-02 still requires a visual pair; logo-guards hex/hygiene checks |

### Guard scope-nonleak enforcement shape for `brandbook-guards.sh`
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Mirror `logo-guards.sh` idioms (`pass/fail/skip`, `--scope` git boundary, optional `xmllint`); run three grep families — file://-safety negatives, scope-nonleak audit, section-presence | Likely | VALIDATION under-specifies check (2) as "custom awk"; RESEARCH Validation table enumerates exact greps; logo-guards.sh provides scaffolding |

## Corrections Made

No corrections — all three assumptions confirmed via "Yes, proceed."

## External Research

None performed. RESEARCH is complete (§1 file:// matrix, §2 @scope Baseline, inline WCAG luminance formula, cross-corroborated sources); every open item was an internal implementation-shape choice resolvable at plan time, not an external-dependency gap.
