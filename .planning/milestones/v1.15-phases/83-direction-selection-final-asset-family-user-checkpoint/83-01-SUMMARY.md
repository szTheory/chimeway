---
phase: 83-direction-selection-final-asset-family-user-checkpoint
plan: 01
subsystem: infra
tags: [brand, logo, svg, svgo, favicon, chrome-headless, tooling, bash]

# Dependency graph
requires:
  - phase: 82-logo-exploration-shortlist
    provides: scripts/logo-guards.sh (doc gate + --scope), notes/logo-options.md finalist SVGs, brandbook/tokens/tokens.css (--cw-* primitives)
provides:
  - "scripts/logo-guards.sh --assets: file-level acceptance gate over brandbook/assets/** (presence, token-hex, no-var(, hygiene, xmllint, viewBox, inverse-backdrop, raster-dims, binary-budget)"
  - "scripts/logo-guards.sh --scope: widened allowlist covering all Wave 2-3 asset paths"
  - "svgo.config.mjs: pinned (svgo@4.0.2) safe-plugin optimizer preserving viewBox/ids/aria+role"
  - "scripts/render-svg-png.sh: deterministic Chrome-headless SVG->PNG rasterizer with chromium fallback"
affects: [83-02, 83-03, brandbook-asset-production]

# Tech tracking
tech-stack:
  added: [svgo@4.0.2 (ephemeral npx, not committed), chrome-headless-screenshot, magick-identify]
  patterns:
    - "Early-dispatch guard modes: sibling `if [ \"$1\" = \"--flag\" ]` blocks that run and exit before the default doc gate"
    - "Reuse Phase-82 pass/fail/skip + ALLOWED_HEX + hygiene greps over real files (drop the doc's awk block-splitter)"
    - "Chrome-only rasterization via an exact-pixel HTML wrapper; ImageMagick reserved for .ico/resize only"

key-files:
  created: [svgo.config.mjs, scripts/render-svg-png.sh]
  modified: [scripts/logo-guards.sh]

key-decisions:
  - "svgo@4.0.2 pinned verbatim in the documented invocation (supply-chain control T-83-02/T-83-SC); nothing from node_modules committed"
  - "Binary budget ceiling set to 200 KB for exactly 3 committed rasters (RESEARCH benchmarks: favicon PNG ~5 KB, OG card <60 KB)"
  - "--assets mode is intentionally RED until Plan 03 ships the files (absent asset = fail, mirroring the doc-presence gate)"
  - "Render helper resolves Chrome from the macOS app path, then chromium, then PATH google-chrome"

patterns-established:
  - "Guard --assets mode: per-real-file checks reusing Phase-82 idioms, exiting with accumulated $FAILED"
  - "Transparent-background Chrome screenshot via --default-background-color=00000000"

requirements-completed: [LOGO-04]

coverage:
  - id: D1
    description: "scripts/logo-guards.sh --assets dispatches a file-level gate over brandbook/assets/** (presence + token-hex + no-var( + hygiene + xmllint + viewBox + inverse-backdrop + raster-dims + binary-budget)"
    requirement: LOGO-04
    verification:
      - kind: integration
        ref: "bash scripts/logo-guards.sh --assets 2>&1 | grep -q 'chimeway-logotype'"
        status: pass
    human_judgment: false
  - id: D2
    description: "scripts/logo-guards.sh --scope passes with the widened allowlist (brandbook/assets/**, notes/decision-log.md, svgo.config.mjs, scripts/render-svg-png.sh)"
    requirement: LOGO-04
    verification:
      - kind: integration
        ref: "bash scripts/logo-guards.sh --scope (exit 0)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Phase 82 doc gate `scripts/logo-guards.sh notes/logo-options.md` still passes (no regression)"
    verification:
      - kind: integration
        ref: "bash scripts/logo-guards.sh notes/logo-options.md (exit 0)"
        status: pass
    human_judgment: false
  - id: D4
    description: "svgo.config.mjs is valid ESM (multipass true, preset-default) and, when run, preserves viewBox, token hex and aria/role"
    verification:
      - kind: integration
        ref: "node -e import('./svgo.config.mjs') multipass check; npx svgo@4.0.2 run preserves viewBox/role/aria-label/#102027/#0e7c86"
        status: pass
    human_judgment: false
  - id: D5
    description: "scripts/render-svg-png.sh rasterizes an SVG to a non-blank PNG at a requested pixel size via Chrome headless"
    verification:
      - kind: integration
        ref: "bash scripts/render-svg-png.sh /tmp/cw_icon.svg 16 /tmp/cw_icon16.png; magick identify => 16x16, colors=25 mean=0.108"
        status: pass
    human_judgment: false

# Metrics
duration: 10min
completed: 2026-07-18
status: complete
---

# Phase 83 Plan 01: Wave-0 Asset Tooling Summary

**Extended logo-guards.sh with an `--assets` file-level gate and widened `--scope` allowlist, plus a pinned SVGO config and a Chrome-headless SVG→PNG render helper — the tooling Waves 2-3 need to produce and verify the brand-asset family.**

## Performance

- **Duration:** ~10 min
- **Tasks:** 2
- **Files modified:** 3 (1 modified, 2 created)

## Accomplishments
- `scripts/logo-guards.sh --assets`: new early-dispatch mode running presence, token-hex subset, no-`var(`, seven SVG-hygiene greps (T-83-01), per-file `xmllint`, viewBox presence, inverse no-baked-backdrop (`#07131a`), raster dims via `magick identify`, and a 3-raster/200 KB binary budget over `brandbook/assets/**`. Intentionally RED until Plan 03 ships the files.
- `scripts/logo-guards.sh --scope`: allowlist widened for `brandbook/assets/*`, `notes/decision-log.md`, `svgo.config.mjs`, `scripts/render-svg-png.sh` so Wave 2-3 paths are not flagged stray (RESEARCH Pitfall 1).
- `svgo.config.mjs`: valid ESM, `multipass: true`, single `preset-default` keeping `viewBox` (Pitfall 2), human-readable ids, and aria/role. Documented invocation pins `svgo@4.0.2` (T-83-02). Verified live: −8.4% on the sample with viewBox/role/aria-label/token-hex all preserved.
- `scripts/render-svg-png.sh`: dependency-light Chrome-headless rasterizer taking `<in.svg> <size> <out.png>` or `<in.svg> <w> <h> <out.png>`; resolves Chrome (macOS app → chromium → PATH), Chrome-only rendering, transparent background. Produced a 16×16 non-blank PNG (25 colors, mean 0.108).
- Phase 82 doc gate (`notes/logo-options.md`) still exits 0 — no regression.

## Task Commits

1. **Task 1: Extend logo-guards.sh — widen --scope + add --assets mode** — `22345a9` (feat)
2. **Task 2: Add svgo.config.mjs + scripts/render-svg-png.sh** — `32a8b0f` (feat)

## Files Created/Modified
- `scripts/logo-guards.sh` — MODIFIED: widened `--scope` allowlist (4 new arms) + new `--assets` early-dispatch mode (~215 lines added), reusing Phase-82 pass/fail/skip, ALLOWED_HEX, hygiene and xmllint idioms per real file.
- `svgo.config.mjs` — CREATED: repo-root ESM SVGO config, `svgo@4.0.2` pinned in the header invocation.
- `scripts/render-svg-png.sh` — CREATED: Chrome-headless exact-pixel-box SVG→PNG helper (executable).

## Verify Command Results
- `bash scripts/logo-guards.sh --scope` → exit 0 (PASS, widened allowlist).
- `bash scripts/logo-guards.sh notes/logo-options.md` → exit 0 (PASS, Phase 82 gate unbroken).
- `bash scripts/logo-guards.sh --assets` → exit 1 (EXPECTED — files pending Waves 2-3); dispatches and prints per-file presence lines; grep for `chimeway-logotype` matches.
- `node -e import('./svgo.config.mjs')` multipass check → exit 0 (PASS).
- `npx -y svgo@4.0.2 --config svgo.config.mjs -p 2 --multipass` on sample → viewBox/role/aria-label/`#102027`/`#0e7c86` all PRESERVED.
- `render-svg-png.sh /tmp/cw_icon.svg 16 …` → 16×16 non-blank PNG (magick identify `16x16`, colors=25, mean=0.108).

## Decisions Made
- Inlined the hygiene greps and the token-hex loop inside the `--assets` block (rather than calling the `hygiene_check` function, which is defined after the early-dispatch blocks and would be undefined at that point). Behavior is byte-identical to the Phase-82 helper.
- Render helper adds `--default-background-color=00000000` for transparent output — needed so favicon/mark renders don't get an opaque white backdrop.

## Deviations from Plan
None - plan executed exactly as written. All checks specified in the plan (presence, token-hex, no-var(, hygiene, xmllint, viewBox, inverse-backdrop, raster-dims, binary-budget) are present and use the existing pass/fail/skip idiom.

## Threat Surface Notes
- T-83-01 (committed-SVG tampering): `--assets` hygiene greps applied per asset SVG — the phase's primary control, wired and passing over present files.
- T-83-02 / T-83-SC (SVGO supply chain): `svgo@4.0.2` pinned verbatim; ephemeral `npx -y`, zero committed dependency; xmllint validates output.
No new security surface introduced beyond the plan's `<threat_model>`.

## Known Stubs
None. The `--assets` mode reporting FAIL for absent files is intended behavior (the gate turns green when Plan 03 ships the assets), not a stub.

## Issues Encountered
None.

## Next Phase Readiness
- Wave 2 (Plan 02) can now author the six logo SVGs, optimize them with `svgo.config.mjs`, and validate with `--assets`.
- Wave 3 (Plan 03) can raster the favicon set + OG card via `render-svg-png.sh` and satisfy the raster-dims + binary-budget checks; `--assets` flips green once all 11 files exist.

## Self-Check: PASSED
- All created/modified files present: scripts/logo-guards.sh, svgo.config.mjs, scripts/render-svg-png.sh, 83-01-SUMMARY.md
- Both task commits present: 22345a9, 32a8b0f

---
*Phase: 83-direction-selection-final-asset-family-user-checkpoint*
*Completed: 2026-07-18*
