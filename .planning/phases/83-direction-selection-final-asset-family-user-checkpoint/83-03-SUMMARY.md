---
phase: 83-direction-selection-final-asset-family-user-checkpoint
plan: 03
subsystem: brand
tags: [brand, favicon, og, social, raster, decision-log, checkpoint, prefers-color-scheme, marcellus, ofl, keystone, svgo]

# Dependency graph
requires:
  - phase: 83-02
    provides: "Six-mark logo lockup family (chimeway-mark.svg favicon seed + chimeway-logotype.svg wordmark), Marcellus (OFL-1.1) re-cut wordmark geometry"
  - phase: 83-01
    provides: "scripts/logo-guards.sh --assets + --scope gates, svgo.config.mjs (pinned safe SVGO), scripts/render-svg-png.sh (Chrome-headless rasterizer)"
  - phase: 82
    provides: "Keystone finalist selected under D-14; token-hex color law"
provides:
  - "Deliberately-simplified dual-theme favicon.svg (prefers-color-scheme dark media query) + favicon.ico (16/32/48) + apple-touch-icon.png (180x180 paper bg)"
  - "chimeway-og.svg/.png (1200x630 mark-derived social card, no cage, ~21 KB PNG)"
  - "notes/decision-log.md '## Logo Direction Ratification' — Keystone RATIFIED, Marcellus/OFL-1.1 recorded, ship/defer/reject rationale, INTEG-03 wiring snippet"
  - "Human ratification of the Keystone/OFL direction at the blocking perceptual checkpoint"
affects: [84-html-brandbook, 85-readme-wiring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dual-theme SVG favicon: a <style> block with @media (prefers-color-scheme:dark) recolors the keystone body ink->paper on dark while keeping the teal facet, so the full silhouette reads on both light and dark tabs"
    - "SVGO media-query preservation: the pinned svgo@4.0.2 default config inlines <style> and drops media queries; re-optimize theme-aware SVGs through an inlineStyles:false / minifyStyles:false override (same pinned version) to keep the media query"
    - "Honest high-DPI perceptual gallery: render the review gallery at --force-device-scale-factor=3 so curve smoothness is judged from the vector, not a 1x aliasing artifact"
    - "Chrome-headless raster pipeline: render SVG->PNG via Chrome only, composite/assemble .ico and paper-backed apple-touch via ImageMagick (never ImageMagick's SVG renderer)"

key-files:
  created:
    - brandbook/assets/favicon/favicon.svg
    - brandbook/assets/favicon/favicon.ico
    - brandbook/assets/favicon/apple-touch-icon.png
    - brandbook/assets/social/chimeway-og.svg
    - brandbook/assets/social/chimeway-og.png
  modified:
    - notes/decision-log.md

key-decisions:
  - "Keystone direction RATIFIED (human checkpoint) — not re-opened; Phase 82 D-14 selected it. Recorded in notes/decision-log.md as the written record for ROADMAP Phase 83 Success Criterion #1."
  - "Wordmark typeface ratified as Marcellus (SIL Open Font License 1.1), retiring Optima to resolve the redistribution-licensing risk (only outlined paths ship in-repo)."
  - "favicon.svg is a deliberately-simplified, bolder keystone (larger fill of the 24x24 box, facet at right ~65%) tuned for 16px — NOT the wordmark lockup resized."
  - "favicon.svg made dual-theme via a gate-legal <style> media query (checkpoint fix 1); the .ico/.png rasters stay theme-static with an ink body for their paper-backed static contexts."
  - "INTEG-03 boundary: favicon assets + a ready-to-paste <link>/ExDoc docs() snippet ship here; the actual README/mix.exs wiring is deferred to Phase 85 (README/mix.exs untouched)."

patterns-established:
  - "Pattern: dual-theme SVG favicon via prefers-color-scheme <style> media query, re-optimized with inlineStyles disabled so SVGO keeps it."
  - "Pattern: diagnose 'faceting' complaints by rendering the vector at high resolution first — distinguish geometry defects from low-DPI render artifacts before touching SVGO precision or re-cutting outlines."

requirements-completed: [LOGO-03, LOGO-04, INTEG-03]

coverage:
  - id: D1
    description: "Simplified dual-theme favicon.svg (16px-legible keystone; reads on light AND dark via prefers-color-scheme) + favicon.ico (16/32/48) + apple-touch-icon.png (180x180 paper bg)."
    requirement: "LOGO-04"
    verification:
      - kind: automated_ui
        ref: "bash scripts/logo-guards.sh --assets (presence/token-hex/hygiene/xmllint/viewBox/raster-dims/binary-budget all PASS, exit 0)"
        status: pass
      - kind: other
        ref: "Chrome-headless render: body pixel = ink srgb(16,32,39) light-state, paper srgb(255,253,248) under --force-prefers-color-scheme=dark; 16px render 27 colors (non-blank)"
        status: pass
    human_judgment: false
  - id: D2
    description: "chimeway-og.svg/.png — 1200x630 mark-derived social card on paper, no cage, token hex only, ~21 KB PNG well under the ~60 KB budget."
    requirement: "LOGO-04"
    verification:
      - kind: automated_ui
        ref: "bash scripts/logo-guards.sh --assets (og.png = 1200x630, binary-budget 38579B <= 204800B, xmllint/token-hex PASS)"
        status: pass
    human_judgment: false
  - id: D3
    description: "notes/decision-log.md '## Logo Direction Ratification' — Keystone ratified (D-14 lineage, ROADMAP SC #1, LOGO-03/04), Marcellus/OFL-1.1 recorded, ship/defer/reject rationale, INTEG-03 wiring snippet, Validation Commands block."
    requirement: "INTEG-03"
    verification:
      - kind: other
        ref: "grep 'Logo Direction Ratification' && grep 'Marcellus' && grep 'OFL-1.1' notes/decision-log.md; bash scripts/logo-guards.sh --scope exit 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "Human perceptual ratification of the Keystone/OFL direction at the blocking checkpoint — 16px/mono/inverse/favicon(light+dark)/OG legibility confirmed."
    verification:
      - kind: manual_procedural
        ref: "Ephemeral file:// review gallery (rev 2: dual-theme favicon proof + 2000px smooth-curve proof); human ratified: 'yeah that looks good now approved'"
        status: pass
    human_judgment: true
    rationale: "Final brand-taste + small-size legibility sign-off is the explicit milestone quality lever; only a human can ratify the shipped identity."

# Metrics
duration: 33min
completed: 2026-07-18
status: complete
---

# Phase 83 Plan 03: Final Asset Family (Favicon + OG) & Direction Ratification Summary

**Dual-theme favicon set (prefers-color-scheme dark) + 1200x630 mark-derived OG card, with the Keystone/Marcellus(OFL-1.1) direction formally ratified by a human at the blocking perceptual checkpoint — closing LOGO-03/04 and INTEG-03.**

## Performance

- **Duration:** ~33 min (incl. one checkpoint change round-trip)
- **Started:** 2026-07-18T21:14:05Z
- **Completed:** 2026-07-18T21:47Z
- **Tasks:** 3 (2 auto + 1 blocking human-verify, ratified)
- **Files modified:** 5 created, 1 modified

## Accomplishments
- **Shipped the full finalist asset family** under `brandbook/assets/`: the six Plan-02 logo SVGs (logotype, -mono, -inverse, -stacked, mark, mark-mono) plus this plan's simplified `favicon.svg`, `favicon.ico` (16/32/48), `apple-touch-icon.png` (180x180 on solid `--cw-paper` bg), and the social card `chimeway-og.svg`/`.png` (1200x630, mark-derived, no cage).
- **favicon.svg is a deliberately-simplified keystone** tuned for 16px (bolder, larger fill of the 24x24 box, facet at right ~65%) — visibly not the wordmark lockup resized. Rasterized via Chrome only; `.ico`/`.png` assembled/composited with ImageMagick.
- **Recorded the formal direction ratification** in `notes/decision-log.md` (`## Logo Direction Ratification`): Keystone RATIFIED (Phase 82 D-14 / 82-01-SUMMARY, ROADMAP SC #1, LOGO-03/04); wordmark re-cut in **Marcellus (SIL OFL 1.1)**, Optima retired; ship/defer/reject rationale for the other explored directions; the INTEG-03 boundary + a ready-to-paste Phase 85 wiring snippet (`<link>` set + ExDoc `docs()` note); a Validation Commands block.
- **Human ratified at the blocking checkpoint** ("yeah that looks good now approved") after two checkpoint changes were applied — confirming 16px / mono / inverse / favicon(light+dark) / OG legibility and the smoothness of the wordmark curves.
- **Both gates fully green:** `scripts/logo-guards.sh --assets` (all seven SVGs + three rasters, incl. raster dims + binary budget) and `--scope` both exit 0.

## Task Commits

Each task was committed atomically:

1. **Task 1: Simplified favicon.svg + favicon.ico (16/32/48) + apple-touch-icon.png** - `7777db2` (feat)
2. **Task 2: OG/social card + Logo Direction Ratification in decision-log** - `4ac1611` (feat)
3. **Task 3: Human ratification + perceptual gate** - ratified at the blocking checkpoint (no code commit; gated Task 2's ship). Checkpoint fix committed as `769fe63` (fix) — favicon dual-theme legibility.

**Plan metadata:** `<this SUMMARY commit>` (docs: complete plan)

## Files Created/Modified
- `brandbook/assets/favicon/favicon.svg` - simplified dual-theme keystone; `<style>` `@media (prefers-color-scheme:dark)` recolors body ink->paper on dark, teal facet on both; SVGO precision-2 (inlineStyles disabled), viewBox/role/aria-label + token hex preserved.
- `brandbook/assets/favicon/favicon.ico` - multi-size 16/32/48 from Chrome-rendered PNGs (theme-static ink body).
- `brandbook/assets/favicon/apple-touch-icon.png` - 180x180, Chrome-rendered icon composited onto a solid `#fffdf8` field with safe padding (theme-static).
- `brandbook/assets/social/chimeway-og.svg` - 1200x630 card: keystone mark centered above the re-cut wordmark on `--cw-paper`, no cage, token hex only (nested-`<svg>` composition, SVGO-optimized).
- `brandbook/assets/social/chimeway-og.png` - 1200x630 Chrome render, stripped, ~21 KB (well under the ~60 KB / 200 KB-total budget).
- `notes/decision-log.md` - appended the `## Logo Direction Ratification` section (the written record for the human checkpoint + Success Criterion #1).

## Decisions Made
- **Keystone RATIFIED, not re-explored** — Phase 82 (D-14) already selected it; Phase 83's checkpoint is the formal, human-gated ratification.
- **Marcellus (OFL-1.1) recorded as the shipped wordmark face**, Optima retired (redistribution-safe; only outlined paths ship).
- **Dual-theme favicon over a theme-static one** — the human found the single-theme ink body vanished on dark tabs; the `prefers-color-scheme` media query is the cleanest gate-legal fix.
- **INTEG-03: assets + snippet only** — README/mix.exs wiring deferred to Phase 85 (left untouched this phase).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] favicon.svg illegible on dark surfaces**
- **Found during:** Task 3 (human checkpoint returned CHANGES)
- **Issue:** The single-theme favicon's ink keystone body (`#102027`) vanished into a dark tab-bar background, leaving only the teal facet — the mark looked broken/half-missing.
- **Fix:** Added a gate-legal `<style>` block with `@media (prefers-color-scheme:dark)` recoloring the body to `--cw-paper #fffdf8` on dark while keeping the `--cw-teal` facet, so the full keystone reads on both light and dark. Verified empirically (body = ink light-state, paper dark-state). The pinned svgo@4.0.2 default config's `inlineStyles` plugin dropped the media query, so re-optimized through the same pinned version with an ephemeral (uncommitted, scratchpad) `inlineStyles:false`/`minifyStyles:false` override.
- **Files modified:** brandbook/assets/favicon/favicon.svg
- **Verification:** `bash scripts/logo-guards.sh --assets` exit 0; dual-theme pixel proof; 16px non-blank (27 colors).
- **Committed in:** `769fe63` (fix)

**2. [Rule 1 - Bug] Gallery misrepresented wordmark curves as faceted**
- **Found during:** Task 3 (human checkpoint returned CHANGES)
- **Issue:** The human saw staircase/faceting on the wordmark curves. Diagnosed empirically by rendering `chimeway-logotype.svg` at 2000px — the vector is perfectly smooth (127 real Bézier ops). The faceting was a gallery render artifact (`--force-device-scale-factor=1`), NOT the geometry.
- **Fix:** Rebuilt the ephemeral gallery at `--force-device-scale-factor=3` with larger marks and an explicit 2000px smooth-curve proof. No SVG geometry change and no SVGO-precision change — the shipped vectors and byte budget are unchanged.
- **Files modified:** none committed (ephemeral scratchpad gallery only)
- **Verification:** 2000px render inspected (clean curves); byte/binary budget unchanged (`--assets` exit 0).
- **Committed in:** n/a (gallery is uncommitted by design — outside the `--scope` allowlist)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - bugs surfaced by the human checkpoint).
**Impact on plan:** Both fixes were legibility/honesty corrections within scope. Fix 1 changed only favicon.svg (gate-legal, gates stayed green); Fix 2 touched only the ephemeral gallery. No scope creep; no geometry or precision regression.

## Issues Encountered
- **SVGO strips `prefers-color-scheme` media queries by default:** the pinned `svgo@4.0.2` `preset-default` `inlineStyles` plugin inlined the base `.cw-body` rule onto the path and dropped the `@media` block. Resolved with an ephemeral scratchpad config override (`inlineStyles:false`, `minifyStyles:false`) run through the same pinned version — no committed config change, `--scope` stays clean.
- **Headless Chrome defaults `prefers-color-scheme` to dark here and ignores `--force-prefers-color-scheme` in old headless:** empirically confirmed both theme states by rendering the resolved light rule (base-only) and the dark rule separately, plus `--headless=new --force-prefers-color-scheme=dark`.

## User Setup Required
None - no external service configuration required. (INTEG-03 wiring — the favicon `<link>` set and ExDoc `docs()` config — is deferred to Phase 85; the ready-to-paste snippet is recorded in `notes/decision-log.md`.)

## Next Phase Readiness
- The full `brandbook/assets/` family is shipped and human-ratified. Phase 84 (HTML brandbook) can consume all seven SVGs + three rasters + the OG card. Phase 85 applies the recorded INTEG-03 wiring snippet to README/mix.exs.
- LOGO-03, LOGO-04, INTEG-03 and ROADMAP Phase 83 Success Criteria #1-#4 are satisfied.

## Self-Check: PASSED

- All five shipped assets + the SUMMARY exist on disk.
- All three commits (7777db2, 4ac1611, 769fe63) present in git history.
- `scripts/logo-guards.sh --assets` and `--scope` both exit 0.

---
*Phase: 83-direction-selection-final-asset-family-user-checkpoint*
*Completed: 2026-07-18*
