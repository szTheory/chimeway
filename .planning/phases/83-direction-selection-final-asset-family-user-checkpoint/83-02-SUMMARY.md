---
phase: 83-direction-selection-final-asset-family-user-checkpoint
plan: 02
subsystem: brand
tags: [brand, logo, svg, wordmark, fonttools, ofl, marcellus, svgo, keystone]

# Dependency graph
requires:
  - phase: 83-01
    provides: "scripts/logo-guards.sh --assets file-level gate + widened --scope allowlist; svgo.config.mjs (pinned safe SVGO config); scripts/render-svg-png.sh"
  - phase: 82
    provides: "Keystone finalist geometry, keystone-i two-path construction, token-hex color law, embedded finalist SVGs in notes/logo-options.md (L41/45/49)"
provides:
  - "Six-mark chimeway logo lockup family as optimized SVGs under brandbook/assets/logo/"
  - "OFL-recut wordmark geometry (Marcellus, SIL OFL 1.1) — Optima retired for public-repo redistribution safety"
  - "chimeway-logotype.svg filename contract consumed by Phase 85 README wiring"
  - "chimeway-mark.svg two-tone keystone icon — the favicon seed for Plan 03"
affects: [83-03, 84-html-brandbook, 85-readme-wiring]

# Tech tracking
tech-stack:
  added: [Marcellus-Regular.ttf (SIL OFL 1.1, ephemeral build input — NOT committed)]
  patterns:
    - "fontTools SVGPathPen + TransformPen + BoundsPen to lay out a wordmark string as font-independent <path> outlines with per-glyph advance widths"
    - "Keystone-i = two overlaid wedge paths (ink body + teal facet at 65% width) fitted into the measured i-slot, x-height top to baseline"
    - "Derive mono via currentColor, inverse via ink->paper recolor on transparent bg, from one shared re-cut geometry"
    - "SVGO precision-2 (svgo@4.0.2 --config svgo.config.mjs -p 2 --multipass) as the single largest byte win on outlined wordmarks (-71.4%)"

key-files:
  created:
    - brandbook/assets/logo/chimeway-logotype.svg
    - brandbook/assets/logo/chimeway-logotype-mono.svg
    - brandbook/assets/logo/chimeway-logotype-inverse.svg
    - brandbook/assets/logo/chimeway-logotype-stacked.svg
    - brandbook/assets/logo/chimeway-mark.svg
    - brandbook/assets/logo/chimeway-mark-mono.svg
  modified: []

key-decisions:
  - "OFL FACE CHOSEN: Marcellus (SIL Open Font License 1.1, Astigmatic/Brian J. Bonislawsky). Flared humanist glyphic face whose tapered stroke terminals rhyme with the keystone wedge — the closest libre analog to Optima's category. OFL 1.1 explicitly permits redistributing outlined glyph paths in a public OSS repo. THIS IS THE FACE + LICENSE PLAN 03 MUST RECORD IN notes/decision-log.md."
  - "Optima retired: the Phase 82 macOS-Optima outlines were re-cut, not shipped (RESEARCH Pitfall 5 / Q1 redistribution risk resolved)."
  - "Mark teal facet set to right ~65% width (not the notes/logo-options.md L49 50%) for consistency with the keystone-i facet across the whole family."
  - "Stacked lockup composed with two <g transform> groups (mark scaled above wordmark); SVGO bakes the transforms into flat path coords on optimize."

patterns-established:
  - "Pattern: wordmark-to-outline via fontTools string layout (advance-width cursor + baseline transform), reproducible from the committed font name + FS/baseline/letter-spacing constants."
  - "Pattern: one re-cut geometry -> mono/inverse/stacked derivations, keeping viewBox/role/aria-label and token-hex/currentColor law."

requirements-completed: [LOGO-03, LOGO-04]

coverage:
  - id: D1
    description: "Primary chimeway logotype re-cut from Marcellus (OFL) via fontTools with the two-tone keystone-i, transparent bg, SVGO-optimized."
    requirement: "LOGO-03"
    verification:
      - kind: automated_ui
        ref: "bash scripts/logo-guards.sh --assets (logo-family: presence/token-hex/hygiene/xmllint/viewBox/inverse-backdrop all PASS)"
        status: pass
      - kind: other
        ref: "xmllint --noout + viewBox + aria-label + role + token-hex + no-var( checks on chimeway-logotype.svg"
        status: pass
    human_judgment: false
  - id: D2
    description: "Five derived family SVGs (mono, inverse, stacked, mark, mark-mono) with correct color expression and transparent inverse."
    requirement: "LOGO-04"
    verification:
      - kind: automated_ui
        ref: "bash scripts/logo-guards.sh --assets (six logo SVGs pass; favicon/rasters/og expected-red for Plan 03)"
        status: pass
      - kind: other
        ref: "per-file xmllint + viewBox + no-var( + inverse-no-#07131a-rect + mono/mark-mono currentColor checks"
        status: pass
    human_judgment: false
  - id: D3
    description: "Perceptual legibility of the family at 16px / mono / inverse and overall wordmark taste (elegance, keystone-i read)."
    requirement: "LOGO-03"
    verification:
      - kind: automated_ui
        ref: "Chrome-headless proof render of all six marks at 16/24/48px + inverse + mono (scratchpad/proof.png) — inspected, legible"
        status: pass
    human_judgment: true
    rationale: "Final perceptual sign-off (legibility + brand taste at small sizes) is the explicit Plan 03 human checkpoint; executor render is a pre-check, not the ratification."

# Metrics
duration: 12min
completed: 2026-07-18
status: complete
---

# Phase 83 Plan 02: Final Asset Family (Logo Lockup) Summary

**Six-mark chimeway logo lockup family shipped as SVGO-optimized SVGs, with the wordmark re-cut from Marcellus (SIL OFL 1.1) via fontTools and a two-tone keystone-i (ink body + teal facet at 65% width).**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-18T16:57Z
- **Completed:** 2026-07-18T17:08Z
- **Tasks:** 2
- **Files modified:** 6 created

## Accomplishments
- Selected and vetted **Marcellus** (SIL Open Font License 1.1) — a flared humanist glyphic face whose tapered terminals rhyme with the keystone wedge; the closest libre analog to Optima. OFL 1.1 permits redistributing outlined glyph paths in a public OSS repo, resolving the Optima redistribution risk (RESEARCH Pitfall 5 / Q1).
- Re-cut the `chimeway` wordmark from Marcellus into font-independent SVG `<path>` outlines via **fontTools** (SVGPathPen + TransformPen + BoundsPen), replacing the Phase 82 Optima outlines. The `i` is the two-overlaid-wedge keystone-i: `--cw-ink` (#102027) body + `--cw-teal` (#0e7c86) facet at ~65% width, fitted to the measured i-slot from x-height top to baseline.
- Derived all five remaining family members from the same geometry: mono (currentColor), inverse (paper glyphs + teal facet on transparent bg, no baked night rect), stacked (mark above wordmark, no cage), 24×24 icon mark (two-tone keystone), and mark-mono (currentColor).
- Every SVG SVGO precision-2 optimized (primary −71.4%: 13.4 KiB → 3.8 KiB), viewBox/role/aria-label and token-hex law preserved.
- `bash scripts/logo-guards.sh --assets` passes **every** logo-family check (presence, token-hex, hygiene, xmllint, viewBox, inverse-no-backdrop).

## Task Commits

1. **Task 1: Select+vet OFL face, re-cut wordmark, author primary logotype** — `4b40341` (feat)
2. **Task 2: Derive mono/inverse/stacked/mark/mark-mono** — `969aeac` (feat)

## Files Created/Modified
- `brandbook/assets/logo/chimeway-logotype.svg` — primary horizontal lockup = wordmark with two-tone keystone-i (Marcellus re-cut).
- `brandbook/assets/logo/chimeway-logotype-mono.svg` — single currentColor fill (drops teal).
- `brandbook/assets/logo/chimeway-logotype-inverse.svg` — paper glyphs + teal facet, transparent background (no #07131a rect).
- `brandbook/assets/logo/chimeway-logotype-stacked.svg` — two-tone keystone mark centered above the wordmark, no cage.
- `brandbook/assets/logo/chimeway-mark.svg` — standalone 24×24 two-tone keystone (ink body + teal facet ~65%).
- `brandbook/assets/logo/chimeway-mark-mono.svg` — single currentColor keystone.

## OFL Face Decision (for Plan 03 decision-log)

| Field | Value |
|-------|-------|
| **Face** | Marcellus |
| **License** | SIL Open Font License 1.1 (OFL-1.1) |
| **Author** | Brian J. Bonislawsky DBA Astigmatic (AOETI) |
| **Source** | Google Fonts `ofl/marcellus/Marcellus-Regular.ttf` |
| **Why** | Flared humanist glyphic terminals rhyme with the keystone wedge (Optima's category); OFL 1.1 explicitly permits redistributing outlined glyph paths in a public repo. |
| **Redistribution** | Only outlined `<path>` geometry ships in-repo; the `.ttf` was an ephemeral build input (scratchpad, never committed). |

Plan 03 must enter this into `notes/decision-log.md` as the ratified wordmark typeface + license.

## Decisions Made
- **Marcellus over Philosopher:** rendered both "chimeway" candidates (scratchpad/compare.png); Marcellus's flared terminals matched the keystone-wedge motif far better than Philosopher's plain humanist sans.
- **Facet at 65% across the family:** the standalone mark uses a 65% teal facet (vs the notes L49 50%) so the icon and the keystone-i share one facet ratio.

## Deviations from Plan

None - plan executed exactly as written. (The 65%-facet harmonization of the standalone mark is an in-spec application of the Task 2 instruction "ink body + teal facet at the right ~65%", not a deviation.)

## Issues Encountered
- fontTools `getBestCmap()` is keyed by codepoint (int), not character — fixed the layout script to use `cmap[ord(ch)]`. Local script fix only; no repo impact.

## Verification Results

- Task 1 automated verify (xmllint / viewBox / aria-label / role / no-var( / token-hex): **all PASS**.
- Task 2 automated verify (5 files: xmllint / viewBox / no-var(; inverse no #07131a rect; mono+mark-mono currentColor): **all PASS**.
- `scripts/logo-guards.sh --assets`: all six logo-family checks **PASS**. Remaining FAILs are exactly the expected `favicon.svg`, `favicon.ico`, `apple-touch-icon.png`, `chimeway-og.svg`, `chimeway-og.png`, and the raster binary-budget — all ship in Plan 03.
- `scripts/logo-guards.sh --scope`: **PASS** (working tree carries only allowed phase paths).

## Next Phase Readiness
- Six-mark family is ready. Plan 03 consumes `chimeway-mark.svg` as the favicon/raster seed and `chimeway-logotype.svg`/`-inverse` for the OG card, and must record the Marcellus / OFL-1.1 decision in `notes/decision-log.md`.
- The perceptual legibility/taste sign-off (D3) is the Plan 03 human checkpoint.

## Self-Check: PASSED

- All six logo SVGs exist on disk.
- 83-02-SUMMARY.md exists.
- Both task commits (4b40341, 969aeac) present in git history.

---
*Phase: 83-direction-selection-final-asset-family-user-checkpoint*
*Completed: 2026-07-18*
