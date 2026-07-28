---
phase: 86-accessibility-audit-notes-red-team-close
plan: 01
subsystem: testing
tags: [wcag, accessibility, contrast, shell, awk, brandbook, tokens]

requires:
  - phase: 81-design-tokens-reconciliation-documentation
    provides: brandbook/tokens/tokens.css frozen --cw-* SSOT (light/dark/system)
  - phase: 84-html-brandbook-voice-component-states
    provides: brandbook/index.html inline WCAG contrast matrix + status label+icon markup; brandbook.css focus/motion/target-size rules
provides:
  - scripts/contrast-audit.sh — dependency-free offline WCAG contrast calc over the token SSOT
  - notes/accessibility-checks.md — per-pairing ratio record (evidence of record) with verbatim-cited WCAG exemptions, A11Y-03 rendered-CSS evidence, A11Y-04 never-color-alone + CVD checklist
affects: [86-02-notes-research, 86-03-cvd-focus-operator-signoff, 86-04-scope-allowlist-widening]

tech-stack:
  added: []
  patterns:
    - Offline WCAG luminance+ratio reproduced in POSIX shell + awk (no strtonum; hex via ordered-alphabet index)
    - Per-theme token resolver following one/multi-level var(--cw-*) references with light-inheritance fallback and fail-loud on missing token
    - Calc stdout quoted verbatim into the record; re-run diff is the sync backstop

key-files:
  created:
    - scripts/contrast-audit.sh
    - notes/accessibility-checks.md
  modified: []

key-decisions:
  - "[86-01]: contrast-audit.sh is a standalone dependency-free script (RESOLVED OQ-1); its path is added to the --scope allowlist by Plan 04, not here."
  - "[86-01]: hex parsed via ordered-alphabet index() not gawk strtonum, so the calc runs on the macOS one-true-awk (BWK awk)."
  - "[86-01]: the offline calc is the A11Y-05 evidence of record; the 8-cell in-page live matrix is cited only as corroborating rendered-output proof."
  - "[86-01]: sub-threshold pairings recorded as DOCUMENTED WCAG EXEMPTIONS (disabled text SC 1.4.3 Incidental; borders SC 1.4.11 required-to-identify), never patched (TOKEN-01 zero-drift); primary button 4.95 recorded as a PASS watch-item."
  - "[86-01]: jump-nav ~26.9px vertical anchors recorded as a documented finding under SC 2.5.8 Inline/Spacing — no CSS/token change (A2, low risk)."

patterns-established:
  - "Verification tooling computes ratios (re-runnable), the record quotes the output — never asserts numbers in prose (anti vacuous-pass)."
  - "Fail-loud token resolver: absent/unparseable --cw-* hex => stderr message + non-zero exit, never a silent/bogus ratio."

requirements-completed: [A11Y-01, A11Y-02, A11Y-05]

coverage:
  - id: D1
    description: "Offline dependency-free WCAG contrast calc reproducing the in-page formula over the frozen token SSOT, emitting ratio + AA verdict for every D-01 pairing (light+dark)"
    requirement: "A11Y-05"
    verification:
      - kind: automated
        ref: "scripts/contrast-audit.sh (exit 0; spot values 3.92/4.95/1.29/4.78/1.47 reproduce RESEARCH)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Text contrast recorded: all load-bearing text >=4.5:1; disabled text 3.92 EXEMPT SC 1.4.3 Incidental; wordmark under Logotypes"
    requirement: "A11Y-01"
    verification:
      - kind: automated
        ref: "grep 'no contrast requirement' + disabled 3.92/4.92 rows in notes/accessibility-checks.md"
        status: pass
    human_judgment: false
  - id: D3
    description: "Non-text/UI contrast recorded: focus rings pass 3:1; status/panel borders EXEMPT SC 1.4.11 required-to-identify (label+icon)"
    requirement: "A11Y-02"
    verification:
      - kind: automated
        ref: "grep 'required to identify' + border ratio rows in notes/accessibility-checks.md"
        status: pass
    human_judgment: false
  - id: D4
    description: "A11Y-03 rendered-CSS evidence (focus-visible SC 2.4.7, focus-not-obscured SC 2.4.11 checklist, reduced-motion SC 2.3.3 AAA, target-size SC 2.5.8)"
    requirement: "A11Y-03"
    verification:
      - kind: manual_procedural
        ref: "keyboard-tab + DevTools checklist to be signed in Plan 03 (focus-not-obscured, jump-nav finding)"
        status: unknown
    human_judgment: true
    rationale: "Focus-not-obscured and CVD emulation require an operator-run browser pass; only the machine-evidenceable CSS geometry is recorded here."
  - id: D5
    description: "A11Y-04 never-color-alone architectural argument (grep-backed status = surface+text+label+icon) + CVD emulation checklist stub"
    requirement: "A11Y-04"
    verification:
      - kind: manual_procedural
        ref: "Chrome DevTools Emulate-vision-deficiencies checklist (protan/deuter/tritan/achromat) — operator sign-off Plan 03"
        status: unknown
    human_judgment: true
    rationale: "CVD emulation is inherently a manual operator pass (D-05, no CVD tooling/binaries); the architectural property is machine-grep-evidenced but CVD sign-off is human."

duration: 6min
completed: 2026-07-28
status: complete
---

# Phase 86 Plan 01: Accessibility Audit — Offline Contrast Calc + Record Summary

**Dependency-free POSIX shell+awk WCAG calc that reads the frozen `--cw-*` hexes and reproduces the in-page luminance/ratio formula for every D-01 pairing (light+dark), plus a per-pairing record quoting its output with verbatim-cited WCAG 1.4.3/1.4.11 exemptions and machine-evidenceable A11Y-03/04 sections.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-07-28T03:12:00Z
- **Completed:** 2026-07-28T03:18:00Z
- **Tasks:** 2
- **Files modified:** 2 (both created)

## Accomplishments

- `scripts/contrast-audit.sh`: dependency-free (no node/npm/network) offline WCAG calc. Reads the light `:root` and `[data-theme="dark"]` blocks from `brandbook/tokens/tokens.css` via awk field/substring extraction (never shell-eval), resolves `var(--cw-*)` references per-theme with light-inheritance fallback, reproduces the `brandbook/index.html:824-835` formula verbatim, and prints ratio (2dp half-up) + AA verdict for 19 pairings × 2 themes = 38 rows, grouped by pair class then light-before-dark. Fails loud (exit 3) on any missing/unparseable token; portable to the macOS one-true-awk (hex parsed via ordered-alphabet `index()`, no gawk `strtonum`).
- Every headline RESEARCH value reproduced exactly: disabled 3.92 light / 4.92 dark, primary button 4.95, focus ring 4.78 light / 8.57 & 7.37 dark, panel line/paper 1.47, border-strong 1.91, all five status borders 1.29–1.77, all status text 5.88+.
- `notes/accessibility-checks.md`: the calc stdout quoted verbatim as the A11Y-05 evidence of record; the 8-cell in-page live matrix cited only as corroborating rendered-output proof. D-02 dispositions carry the SC clause verbatim — disabled text EXEMPT under SC 1.4.3 Incidental ("no contrast requirement"), status/panel borders EXEMPT under SC 1.4.11 ("required to identify", identity carried by surface+text+label+icon), primary button 4.95 recorded as a PASS watch-item (record, don't fix).
- A11Y-03 section: focus-visible (SC 2.4.7), focus-not-obscured checklist (SC 2.4.11), reduced-motion honored as Level AAA (SC 2.3.3, exceeding AA), `.cwb-btn` 40×40 SC 2.5.8 PASS, theme-toggle 32px pass-on-measurement, jump-nav ~26.9px documented finding.
- A11Y-04 section: grep-backed never-color-alone argument (every `.cwb-badge` = surface + text + label + `aria-hidden` icon, index.html:176-183) plus a protan/deuter/tritan/achromat CVD-emulation checklist stub for Plan 03 operator sign-off.

## Task Commits

Each task was committed atomically:

1. **Task 1 (tracer): offline WCAG contrast calc** - `e239707` (feat)
2. **Task 2: record the audit — accessibility-checks.md** - `138d29d` (docs)

**Plan metadata:** committed separately with STATE/ROADMAP updates.

## Files Created/Modified

- `scripts/contrast-audit.sh` - new dependency-free re-runnable offline WCAG contrast calc over the token SSOT.
- `notes/accessibility-checks.md` - per-pairing ratio record (evidence of record), verbatim-cited exemptions, A11Y-03 checklist, A11Y-04 never-color-alone + CVD stub.

## Decisions Made

- Standalone `scripts/contrast-audit.sh` (not a function inside `brandbook-guards.sh`) — resolves RESEARCH OQ-1; keeps the guard `--scope` mode uncluttered. Adding its path to the `--scope` allowlist is Plan 04's job (not done here).
- Hex→RGB via ordered-alphabet `index()` rather than gawk `strtonum`, so the calc runs on the macOS default awk (BWK awk); exponentiation uses the portable `^` operator.
- Panel-border pairing modeled as `--cw-border` / `--cw-surface-bg` so the light row reproduces the RESEARCH line/paper 1.47 while the dark row uses the semantic dark border — one definition, correct per theme.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' automated `<verify>` blocks passed; the tracer feedback gate (re-run of the tracer `<verify>` end-to-end) passed before Task 2, and the backstop truth (fresh calc output byte-identical to the quoted table) was confirmed by diff.

## Issues Encountered

None. Portability was handled up front (no `strtonum`; `^` exponent), so the calc ran green on the first invocation and reproduced every RESEARCH headline value.

## User Setup Required

None - no external service configuration required. (The A11Y-03 focus-not-obscured pass and the A11Y-04 CVD-emulation checklist are operator-run browser checks deferred to Plan 03 by design, D-05/D-06.)

## Known Stubs

The A11Y-04 CVD-emulation checklist and the A11Y-03 focus-not-obscured item are intentional operator-sign-off checklists (unchecked boxes) deferred to Plan 03 per D-05/D-06 — not code stubs. No placeholder/TODO/FIXME or empty-data UI stubs were introduced. `scripts/contrast-audit.sh` computes real values from the real token file.

## Next Phase Readiness

- Ready for Plan 02 (`notes/research.md` citation basis) and Plan 03 (operator CVD/focus sign-off).
- Plan 04 must add `scripts/contrast-audit.sh` (plus `README.md`, `mix.exs`, `notes/**`, `logo-guards.sh`, `render-svg-png.sh`) to the `brandbook-guards.sh --scope` allowlist; until then `--scope` may false-FAIL on these paths (expected, per plan verification note).
- `brandbook/tokens/tokens.css` untouched — zero-drift TOKEN-01 held (`git diff --quiet` clean).

## Self-Check: PASSED

- Found `scripts/contrast-audit.sh` and `notes/accessibility-checks.md` on disk.
- Found summary file `86-01-SUMMARY.md`.
- Found task commits `e239707` (tracer calc) and `138d29d` (record).
- `git diff --quiet -- brandbook/tokens/tokens.css` clean (zero-drift held).
- No tracked file deletions introduced by either task commit.

---
*Phase: 86-accessibility-audit-notes-red-team-close*
*Completed: 2026-07-28*
