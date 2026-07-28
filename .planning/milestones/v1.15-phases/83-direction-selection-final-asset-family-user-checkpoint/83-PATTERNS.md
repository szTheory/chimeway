# Phase 83: Direction Selection & Final Asset Family (User Checkpoint) - Pattern Map

**Mapped:** 2026-07-18
**Files analyzed:** 13 (5 SVG marks + favicon.svg + og.svg = 7 SVG; 3 raster binaries; 1 guard MODIFY; 1 svgo config CREATE; 1 render helper CREATE; 1 decision-log MODIFY)
**Analogs found:** 11 / 13 (2 net-new tooling artifacts have no in-repo analog — use RESEARCH.md)

> This is a static brand-asset production phase, not app code. The role/data-flow taxonomy is adapted: "role" = asset/tooling kind (svg-mark, favicon, raster, guard-script, build-config, render-helper, decision-doc); "data flow" = production pipeline stage (author→optimize, raster-derive, gate, config, record). The strongest analogs are **in-repo, this-repo-specific** files (the Phase-82 embedded SVGs, `logo-guards.sh` itself, `tokens.css`, `decision-log.md`) — prefer them over RESEARCH.md's generic examples wherever they exist.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/logo-guards.sh` (MODIFY) | guard-script | gate | `scripts/logo-guards.sh` (self — extend in place) | exact (self) |
| `brandbook/assets/logo/chimeway-logotype.svg` | svg-mark (two-tone wordmark) | author→optimize | `notes/logo-options.md` L41 (primary logotype) | exact |
| `brandbook/assets/logo/chimeway-logotype-inverse.svg` | svg-mark (inverse) | author→optimize | `notes/logo-options.md` L45 (inverse) — minus baked rect | exact (w/ known edit) |
| `brandbook/assets/logo/chimeway-logotype-mono.svg` | svg-mark (mono) | author→optimize | `notes/logo-options.md` L41 + RESEARCH Pattern 2 (`currentColor`) | role-match |
| `brandbook/assets/logo/chimeway-logotype-stacked.svg` | svg-mark (stacked lockup) | author→optimize | `notes/logo-options.md` L41 + L49 (compose mark above wordmark) | role-match |
| `brandbook/assets/logo/chimeway-mark.svg` | svg-mark (icon two-tone) | author→optimize | `notes/logo-options.md` L49 (24×24 keystone) | exact |
| `brandbook/assets/logo/chimeway-mark-mono.svg` | svg-mark (icon mono) | author→optimize | `notes/logo-options.md` L49 + RESEARCH Pattern 2 | role-match |
| `brandbook/assets/favicon/favicon.svg` | favicon (simplified) | author→optimize | `notes/logo-options.md` L49 (simplified keystone) | role-match |
| `brandbook/assets/favicon/favicon.ico` | raster (binary) | raster-derive | RESEARCH Pattern 3 (Chrome→PNG→`magick .ico`) | no in-repo analog |
| `brandbook/assets/favicon/apple-touch-icon.png` | raster (binary) | raster-derive | RESEARCH Pattern 3 (180² paper bg) | no in-repo analog |
| `brandbook/assets/social/chimeway-og.svg` | svg-mark (OG source) | author→optimize | `notes/logo-options.md` L41+L49 on `#fffdf8` | role-match |
| `brandbook/assets/social/chimeway-og.png` | raster (binary) | raster-derive | RESEARCH Pattern 3 (Chrome 1200×630) | no in-repo analog |
| `svgo.config.mjs` | build-config | config | — (no `.mjs`/config in repo) | **NO ANALOG** — use RESEARCH Pattern 1 |
| `scripts/<render helper>` | render-helper | raster-derive | Phase-82 render loop (ephemeral, uncommitted) | **NO ANALOG** — use RESEARCH Pattern 3 |
| `notes/decision-log.md` (MODIFY) | decision-doc | record (append) | `notes/decision-log.md` (self — append new `##` section) | exact (self) |

## Shared Patterns

### Token-hex color law (applies to EVERY committed SVG)
**Source of truth:** `brandbook/tokens/tokens.css` lines 12-21 (the `--cw-*` primitives).
**Enforced by:** `scripts/logo-guards.sh` line 25 `ALLOWED_HEX`.
Committed marks use **literal lowercase hex only**, never `var(--cw-*)` (does not resolve in standalone SVG). The allowed set and their token names:
```
--cw-ink   #102027   (wordmark/mark body)
--cw-night #07131a   (proof backdrop ONLY — never baked into a shipped mark)
--cw-paper #fffdf8   (inverse fill, OG background, apple-touch bg)
--cw-teal  #0e7c86   (the single accent / keystone facet)
--cw-brass #d6a84f   (reserved — not used this phase)
--cw-mint  #9adbcf   (reserved — not used this phase)
```
`ALLOWED_HEX="102027 07131a fffdf8 0e7c86 d6a84f 9adbcf"` — the guard's `--assets` mode reuses this exact string for the token-subset check.

### SVG hygiene (security control — applies to every committed SVG)
**Source:** `scripts/logo-guards.sh` lines 189-207 (`hygiene_check` helper + 7 pattern calls).
**Apply to:** all 7 SVGs. The `--assets` mode reuses these exact greps over each file:
```bash
hygiene_check "<script> element"      '<script[[:space:]>]'
hygiene_check "<foreignObject>"       '<foreignObject[[:space:]>]'
hygiene_check "<image> element"       '<image[[:space:]>]'
hygiene_check "on*= event handler"    '[[:space:]]on[a-z]+[[:space:]]*='
hygiene_check "javascript: scheme"    'javascript:'
hygiene_check "data: URI"             'data:'
hygiene_check "remote href/xlink:href" '(xlink:)?href[[:space:]]*=[[:space:]]*["'"'"']https?:'
```

### xmllint well-formedness (applies to every committed SVG)
**Source:** `scripts/logo-guards.sh` lines 213-240 (check 8). Degrades to SKIP when xmllint absent. For `--assets`, run `xmllint --noout <file.svg>` per real file (simpler than the doc's block-extraction because assets are already one-SVG-per-file — drop the awk splitter at lines 217-221).

## Pattern Assignments

### `scripts/logo-guards.sh` (guard-script, gate) — MODIFY

**Analog:** itself. Two edits: (A) widen `--scope` allowlist; (B) add `--assets` mode. Reuse existing helpers (`pass`/`fail`/`skip` lines 32-34, `ALLOWED_HEX` line 25, hygiene/xmllint blocks).

**Edit A — widen `--scope` allowlist** (current allowlist, lines 27-29 + 58-61):
```bash
# lines 27-29 today — only two Phase-82 paths:
ALLOWED_DOC="notes/logo-options.md"
ALLOWED_GUARD="scripts/logo-guards.sh"
# ...
# lines 58-61 — the case that classifies each changed path:
    case "$path" in
      "$ALLOWED_DOC"|"$ALLOWED_GUARD") : ;;   # allowed committed deliverables
      .planning/*) : ;;                        # bookkeeping, out of phase scope
      *) stray="${stray}${path}\n" ;;
    esac
```
**Required change:** add `brandbook/assets/*` and `notes/decision-log.md` (and the authoring inputs `svgo.config.mjs`, the render helper if committed to `scripts/`) to the allowed case, e.g. a new glob arm `brandbook/assets/*) : ;;` and `notes/decision-log.md) : ;;`. Without this, every new asset falls into the `*) stray` branch and `--scope` fails (RESEARCH Pitfall 1, confirmed against these exact lines).

**Edit B — add `--assets` mode** — mirror the existing `--scope` early-dispatch block (lines 42-74) as a sibling `if [ "${1:-}" = "--assets" ]; then ... exit "$FAILED"; fi`. Inside it, per RESEARCH Pattern 4 / VALIDATION Wave 0:
- **presence:** assert the 7 named SVGs + 3 rasters exist (each missing file = `fail`, mirroring the doc-presence gate at lines 81-85 which proves the guard is wired).
- **token-hex subset:** reuse the ALLOWED_HEX loop (lines 146-164) but iterate over each real `.svg` file instead of the awk-extracted `$SVG_ONLY`.
- **no `var(`:** reuse check 6 (lines 170-175) per file.
- **hygiene:** reuse `hygiene_check` (lines 189-207) per file.
- **xmllint:** reuse check 8 (lines 213-240) per file (drop the awk splitter — assets are already single-SVG files).
- **viewBox present:** new — `grep -q 'viewBox' "$f" || fail` per logo SVG (RESEARCH Pitfall 2).
- **inverse has no baked bg:** new — assert no `<rect ... #07131a` in `*-inverse.svg` (RESEARCH Pitfall 4).
- **raster dims:** new — `magick identify` asserts `og.png` = 1200×630, `apple-touch-icon.png` = 180×180, `favicon.ico` carries the 16/32/48 sizes (RESEARCH Pattern 3 verified `magick identify` returns 3 ICO sizes).
- **binary budget:** new — count (=3) + total bytes of committed rasters under a documented ceiling (feeds NOTES-03). RESEARCH benchmark: favicon PNG ~5 KB @ 512², OG card well under ~60 KB.

**Reuse the exact PASS/FAIL/SKIP idiom** (lines 32-34) and the trailing summary line (lines 242-244) so `--assets` output matches the existing gate's shape.

---

### `brandbook/assets/logo/chimeway-mark.svg` (svg-mark icon, author→optimize) — CREATE

**Analog:** `notes/logo-options.md` line 49 — copy verbatim, then run through SVGO.
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="48" height="48" role="img" aria-label="chimeway mark"><path d="M6 5 L18 5 L15.5 19 L8.5 19 Z" fill="#102027"/><path d="M12 5 L18 5 L15.5 19 L12 19 Z" fill="#0e7c86"/></svg>
```
Two-tone keystone: `#102027` body + `#0e7c86` facet at the right ~65% width. Keep `viewBox`, `role`, `aria-label`. This is the cleanest analog (24×24, low precision, already legible) — the icon and favicon seed derive from it.

---

### `brandbook/assets/logo/chimeway-mark-mono.svg` (svg-mark icon mono) — CREATE

**Analog:** the mark above + RESEARCH Pattern 2 (mono via `currentColor`, drops the teal to a single path):
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" role="img" aria-label="chimeway mark">
  <path d="M6 5 L18 5 L15.5 19 L8.5 19 Z" fill="currentColor"/>
</svg>
```
One path, `fill="currentColor"` — consumer recolors with one CSS `color:`. Note `currentColor` is NOT a `#hex`, so it passes the token-hex check (which only inspects `#rrggbb`) and the no-`var(` check.

---

### `brandbook/assets/logo/chimeway-logotype.svg` (svg-mark primary wordmark, author→optimize) — CREATE

**Analog:** `notes/logo-options.md` line 41 (the two-tone Optima-outlined wordmark, `viewBox="30 10 172 46"`). This is the PRIMARY horizontal lockup AND the wordmark (they coincide — the keystone-`i` integrates the mark; RESEARCH Q2/A3).

**Two mandatory transforms before commit:**
1. **RE-CUT the outlines in a libre/OFL humanist face** (locked this session — NOT Optima). Regenerate the `<path>` geometry via fontTools from an openly-licensed font; the color law, keystone-`i` construction (ink body + teal facet at 65% width), `viewBox`, `role`, `aria-label` structure all carry over from the L41 analog. This resolves RESEARCH Pitfall 5 / Q1 (Optima redistribution) decisively.
2. **SVGO precision-2** — the raw L41 SVG carries 15-digit floats (`#102027 32.406Q53.906 30.875999999999998`); precision-2 is the single biggest byte win (RESEARCH Anti-Patterns, verified −61.7%).

The keystone-`i` is these two overlaid paths at the `i` position (from L41), re-fitted to the new face's `i` slot:
```svg
<path d="M77.83 27.27 L85.03 27.27 L83.83 44 L79.03 44 Z" fill="#102027"/>  <!-- i body -->
<path d="M80.35 27.27 L85.03 27.27 L83.83 44 L80.71 44 Z" fill="#0e7c86"/>  <!-- keystone facet, ~65% -->
```

---

### `brandbook/assets/logo/chimeway-logotype-inverse.svg` (svg-mark inverse) — CREATE

**Analog:** `notes/logo-options.md` line 45 (inverse wordmark) — but with the CRITICAL edit: **DELETE the baked background rect**. The L45 analog opens with:
```svg
<rect x="30" y="10" width="172" height="46" fill="#07131a"/>   <!-- DELETE THIS -->
```
That `#07131a` night rect is a proof-strip backdrop, not part of the mark. Ship inverse on transparent: `#fffdf8` paper glyph body + `#0e7c86` teal facet, no rect (RESEARCH Pattern 2 / Pitfall 4). The `--assets` guard asserts no `<rect ... #07131a` survives. Same re-cut geometry as `chimeway-logotype.svg`, recolored ink→paper.

---

### `brandbook/assets/logo/chimeway-logotype-mono.svg` (svg-mark mono) — CREATE

**Analog:** `chimeway-logotype.svg` geometry + RESEARCH Pattern 2. Collapse both the wordmark body and the keystone facet to a single `fill="currentColor"` (drops the teal); consumer supplies the color. No baked background.

---

### `brandbook/assets/logo/chimeway-logotype-stacked.svg` (svg-mark stacked lockup) — CREATE

**Analog:** compose `notes/logo-options.md` L49 (the 24×24 mark) ABOVE the re-cut wordmark from L41, in one square-ish `viewBox`. Two-tone (`#102027` + `#0e7c86`), transparent background, no enclosing rect/cage (LOGO-05 taste gate — RESEARCH Locked Decisions). Give it its own `viewBox` sized to the vertical stack; keep `role="img"` + `aria-label="chimeway"`.

---

### `brandbook/assets/favicon/favicon.svg` (favicon simplified) — CREATE

**Analog:** `notes/logo-options.md` line 49 (the standalone keystone) — NOT a resized lockup (RESEARCH Anti-Pattern; LOGO-04/INTEG-03 require a deliberately *simplified* mark). Start from the 24×24 two-tone keystone and tune the wedge so it reads at 16px (thicker facet / simpler silhouette if needed). Keep `viewBox`, `role`, `aria-label`; token-hex only.

---

### `brandbook/assets/favicon/favicon.ico` + `apple-touch-icon.png` (raster binaries) — CREATE

**No in-repo analog** (no `.ico`/`.png` committed anywhere — verified `git ls-files` empty). Follow RESEARCH Pattern 3 exactly (verified this session):
```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=512,512 --screenshot=fav512.png "file://$PWD/fav.html"
for s in 16 32 48; do magick fav512.png -resize ${s}x${s} fav${s}.png; done
magick fav16.png fav32.png fav48.png favicon.ico   # → 3-image .ico (verified 16/32/48)
```
- `favicon.ico` = multi-size 16/32/48 from the simplified `favicon.svg`.
- `apple-touch-icon.png` = 180×180, **solid `#fffdf8` paper background + safe padding** (iOS ignores SVG here and renders transparency poorly).
- Rasterize via **Chrome only** (never ImageMagick MSVG — low fidelity on outlined paths); feed PNGs to ImageMagick for `.ico`/resize only.

---

### `brandbook/assets/social/chimeway-og.svg` + `chimeway-og.png` (OG card) — CREATE

**Analog:** compose the re-cut wordmark (L41) + mark (L49) on a `#fffdf8` paper field at 1200×630. **No baked cage.** The `.svg` is the source; the `.png` is the ONE justified OG raster (social scrapers don't render SVG). Render via Chrome headless at exactly 1200×630 (RESEARCH Pattern 3), keep well under ~60 KB (flat-color card). Guard asserts `magick identify og.png` = 1200×630.

---

### `svgo.config.mjs` (build-config, config) — CREATE — NO IN-REPO ANALOG

No `.mjs` or JS config exists in the repo. Use RESEARCH Pattern 1 verbatim (verified −61.7%, viewBox/hex/a11y preserved). Keep at repo root or `scripts/` — NOT inside `brandbook/` (zero-build scope):
```js
// svgo.config.mjs
export default {
  multipass: true,
  plugins: [
    { name: 'preset-default', params: { overrides: {
      removeViewBox: false,        // CRITICAL: keep viewBox or the mark won't scale
      cleanupIds: false,           // keep human-readable ids
      removeUnknownsAndDefaults: { keepAriaAttrs: true, keepRoleAttr: true },
    } } },
  ],
};
// run: npx -y svgo@4.0.2 --config svgo.config.mjs -p 2 --multipass -i in.svg -o out.svg
```
Pin `svgo@4.0.2` in the invocation (supply-chain: RESEARCH Package Legitimacy Audit).

---

### `scripts/<render helper>` (render-helper, raster-derive) — CREATE — NO IN-REPO ANALOG

The Phase-82 Chrome render loop was ephemeral (never committed — confirmed: only `logo-options.md` + `logo-guards.sh` shipped). Use RESEARCH Pattern 3 / Code Examples: a tiny helper that writes an HTML wrapper pinning exact px, then screenshots via Chrome headless. For the 16px non-blank perceptual check:
```bash
printf '<!doctype html><meta charset=utf-8><style>html,body{margin:0}</style>\
<img src="favicon.svg" width="16" height="16">' > f16.html
"$CHROME" --headless --disable-gpu --force-device-scale-factor=1 \
  --window-size=16,16 --screenshot=fav16-real.png "file://$PWD/f16.html"
```
May live in `scripts/` (add to `--scope` allowlist) or scratchpad (ephemeral). Fallback binary: `chromium` at `/opt/homebrew/bin/chromium`.

---

### `notes/decision-log.md` (decision-doc, record) — MODIFY (append)

**Analog:** itself. Append a NEW top-level `## Logo Direction Ratification` section (existing `##` sections: Sources L13, Divergence Summary L22, Validation Commands L87, Scope Guard L106). Match the established structure:
- A dated intro paragraph (mirror L3-11 header block style).
- A **Sources** bullet list pattern (L15-19) citing `notes/logo-options.md` (finalist SVGs L41/45/49), `82-01-SUMMARY.md` (D-14 lineage), ROADMAP Phase 83 SC, REQUIREMENTS LOGO-03/04.
- The **ratification decision** itself: Keystone direction RATIFIED (not re-opened), wordmark RE-CUT in a libre/OFL humanist face (Optima retired to resolve licensing), with ship/defer rationale for the other directions.
- A **Validation Commands** fenced block (mirror L87-104 style) — e.g. the `bash scripts/logo-guards.sh --assets && --scope` gate.
Use the log's `- **Shipped side:** / - **Disposition:**` bulleted-decision idiom (L38-41) for consistency. This section is the human perceptual checkpoint's written record (VALIDATION Manual-Only + phase gate).

## No Analog Found

Files with no in-repo analog — planner should use RESEARCH.md patterns (all verified this session):

| File | Role | Data Flow | Reason | Use Instead |
|------|------|-----------|--------|-------------|
| `svgo.config.mjs` | build-config | config | No `.mjs`/JS config exists in repo | RESEARCH Pattern 1 (verbatim) |
| `scripts/<render helper>` | render-helper | raster-derive | Phase-82 render loop was ephemeral, never committed | RESEARCH Pattern 3 / Code Examples |
| `favicon.ico`, `apple-touch-icon.png`, `chimeway-og.png` | raster binary | raster-derive | Zero raster binaries committed anywhere (verified) | RESEARCH Pattern 3 (Chrome→PNG→ImageMagick) |

## Metadata

**Analog search scope:** `scripts/`, `brandbook/`, `notes/`, `.planning/phases/82-*`, repo-wide `git ls-files` for `*.svg`/`*.png`/`*.ico`/`*.mjs`.
**Files scanned:** `scripts/logo-guards.sh` (full), `notes/logo-options.md` (SVG region L35-63), `brandbook/tokens/tokens.css` (full), `notes/decision-log.md` (L1-60 + tail), `82-01-SUMMARY.md` (render-loop refs), `83-RESEARCH.md`, `83-VALIDATION.md`.
**Key finding:** the three strongest analogs are all this-repo files — `logo-guards.sh` (extend in place, reuse `ALLOWED_HEX`/hygiene/xmllint blocks by line number), the Phase-82 embedded finalist SVGs (L41/45/49 — copy geometry, re-cut the wordmark, strip the inverse's baked rect), and `decision-log.md`'s section idiom. Only the net-new build tooling (svgo config, render helper, raster binaries) has no in-repo precedent.
**Pattern extraction date:** 2026-07-18
```
