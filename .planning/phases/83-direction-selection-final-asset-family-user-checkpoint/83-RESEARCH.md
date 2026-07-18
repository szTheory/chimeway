# Phase 83: Direction Selection & Final Asset Family (User Checkpoint) — Research

**Researched:** 2026-07-18
**Domain:** Static SVG asset production (logo lockup family, favicon set, OG card), deterministic rasterization, asset-file legibility gating
**Confidence:** HIGH (toolchain, optimization, raster pipeline verified end-to-end this session); MEDIUM on font-licensing (a legal question the checkpoint must resolve)

## Summary

Phase 83 is a **production/tooling phase, not a taste phase** — the taste decision was already made in Phase 82 (Keystone direction → the `chimeway` logotype in Optima outlines, with the `i` replaced by a two-tone keystone wedge: `--cw-ink` body + `--cw-teal` facet at 65% width; the standalone two-tone keystone is the icon/favicon). Those SVGs exist today **embedded inside `notes/logo-options.md`** — nothing is in `brandbook/assets/` and no `.svg`/`.png`/`.ico` file is committed anywhere in the repo (verified: `git ls-files '*.svg' '*.png' '*.ico'` returns empty). The job is to (1) formally confirm the selection at a user checkpoint and record it in `notes/decision-log.md`, (2) promote the finalist into a complete, optimized-SVG lockup family under `brandbook/assets/`, (3) derive a deliberately-simplified favicon set and one social/OG card from the mark, and (4) prove every shipped **file** (not just the doc) reads at 16px / mono / inverse.

The toolchain is already present and was verified this session: **SVGO 4.0.2** (via `npx -y`, zero committed dependency) optimizes the bloated fontTools-outlined wordmark from 9,754 → 3,735 bytes (**−61.7%**) while preserving `viewBox`, `role`, `aria-label`, and the literal token hex; **Chrome 150 headless** deterministically renders SVG→PNG (the Phase 82 render-loop pattern); **ImageMagick 7** assembles a multi-size `favicon.ico` (16/32/48) from those PNGs; **fontTools 4.62.1** and **xmllint** are on PATH. No new heavy/committed dependency is needed — every raster tool is either already installed or run ephemerally via `npx`.

**Primary recommendation:** Reuse Phase 82's established patterns (fontTools outlines, Chrome-headless render loop, ephemeral `file://` gallery, `scripts/logo-guards.sh` as the automated gate). Add exactly one build-time optimizer — `npx -y svgo@4.0.2` with a safe-plugin config (`removeViewBox:false`, precision 2) — commit only the optimized SVGs plus the minimal justified raster binaries (`favicon.ico`, `apple-touch-icon.png`, one `og.png`). Extend `logo-guards.sh` to gate the shipped **asset files** and to widen its `--scope` allowlist to `brandbook/assets/**` + `notes/decision-log.md`. Two decisions carry real blast radius and belong at the checkpoint, not in silent execution: **(a) Optima font licensing** for a redistributed OSS-repo outline, and **(b)** whether Phase 83 re-opens or merely confirms the Phase 82 selection.

## Locked Inputs (inherited — no 83-CONTEXT.md exists yet)

> No `83-CONTEXT.md` exists (verified). These are **locked decisions inherited** from Phase 82's SUMMARY, the roadmap's Phase 83 Success Criteria, and REQUIREMENTS. The planner MUST honor them; they are not open for re-research.

### Locked Decisions (from Phase 82 D-14 lineage + roadmap)
- **Finalist is chosen:** `chimeway` wordmark in **Optima**, converted to font-independent SVG `<path>` outlines (fontTools). `[CITED: 82-01-SUMMARY.md]`
- **Integrated typemark (LOGO-02):** the `i` of `chimeway` **is** the keystone wedge — `--cw-ink #102027` body + `--cw-teal #0e7c86` facet at **65%** width. `[CITED: notes/logo-options.md §Selected]`
- **Icon/favicon seed:** the standalone two-tone keystone (`viewBox="0 0 24 24"`). `[CITED: notes/logo-options.md line 49]`
- **Color law:** committed marks use **literal token hex only**, never `var(--cw-*)` (does not resolve in standalone SVG). Allowed hex set: ink `#102027`, night `#07131a`, paper `#fffdf8`, teal `#0e7c86` (+ brass `#d6a84f`, mint `#9adbcf` reserved). `[VERIFIED: scripts/logo-guards.sh ALLOWED_HEX]`
- **Taste gates carry forward (LOGO-05):** no rectangular/enclosing cage; mark+wordmark read as one unit (not icon-left/text-right); primary lockup carries no subtitle. `[CITED: REQUIREMENTS.md LOGO-05]`
- **Metaphor lock (LOGO-06):** no literal bell/music/note/audio imagery. `[CITED: REQUIREMENTS.md LOGO-06]`
- **Scope discipline:** doc/asset-only; all work lands under `brandbook/` (this phase: `brandbook/assets/`) plus the allowed `notes/` decision record; `chimeway_admin` untouched; v1.14 doc-contract/release-gate tests stay green. `[CITED: ROADMAP.md milestone scope]`

### Claude's Discretion (this phase)
- File naming and directory layout under `brandbook/assets/` (recommendations below — but must be **stable**, because Phases 84 and 85 reference these filenames).
- How mono/inverse are expressed (separate files vs `currentColor`).
- The exact SVGO plugin set (within the safe-plugin guardrails below).
- Whether the OG card is authored by hand or composed from the promoted mark files.

### Deferred (OUT OF SCOPE — do not build here)
- The scoped `file://` HTML brandbook that renders the family, the clear-space diagram, the minimum-size grid, and the do/don't usage grid as **rendered HTML** → **Phase 84** (BOOK-*). `[CITED: notes/logo-options.md §Scope note]`
- Applying the assets to the **README header** and **`mix.exs` `docs()` `:logo`/`:favicon`** wiring → **Phase 85** (INTEG-01/02). Phase 83 ships the assets and provides the wiring snippet; Phase 85 applies it. (See Open Questions Q3 for the INTEG-03 boundary.)
- Live admin re-theme (ADMIN-RETHEME-01).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **LOGO-03** | Ship the full lockup family — primary horizontal lockup, icon-only mark, wordmark, stacked lockup, mono, inverse, simplified favicon mark — as **optimized** SVGs. | §Standard Stack (SVGO safe config, verified −61.7%); §Architecture Patterns (file family + naming); §Pattern 2 (mono/inverse expression). Note: in this finalist "primary horizontal lockup" and "wordmark" **coincide** (the integrated typemark collapses the icon-left lockup) — see Open Questions Q2. |
| **LOGO-04** | Every shipped mark stays legible/recognizable at 16px, mono, and inverse — verified before ship. | §Validation Architecture (automatable file gates vs human perceptual gate); §Pattern 4 (extend logo-guards + Chrome render-and-inspect). |
| **INTEG-03** | Ship a deliberately-simplified `favicon.svg` (+ minimal raster fallback) — and wire it. | §Pattern 3 (2026 minimal favicon set, verified `.ico` assembly); Open Questions Q3 clarifies the 83↔85 wiring boundary. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Vector logo family (SVG source of truth) | Static assets (`brandbook/assets/`) | — | Zero-build, `file://`-safe, GitHub/HexDocs resolve relative SVG natively |
| Mono/inverse recoloring | Static assets (`currentColor` + consumer CSS) | — | One file recolors to any context; avoids N baked-color duplicates |
| Favicon `.svg` (modern) | Static assets | — | Modern browsers prefer SVG favicons; simplified keystone reads at 16px |
| Favicon `.ico` / apple-touch `.png` | Build-time raster (Chrome→PNG→ImageMagick) | Static assets (committed output) | Platforms still require raster; generated deterministically, committed as tiny binaries |
| OG/social card raster | Build-time raster (Chrome headless) | Static assets (committed `.png`) | Social scrapers don't render SVG reliably; one justified PNG |
| Asset-file legibility gate | Build/CI tooling (`scripts/logo-guards.sh`) | Human perceptual checkpoint | Well-formedness/token/hygiene are greppable; 16px "does it read" is perceptual |

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| SVGO | 4.0.2 | SVG optimization (precision, strip cruft) | The de-facto SVG optimizer; run via `npx -y` = **zero committed dependency** `[VERIFIED: npm registry — npm view svgo → 4.0.2 latest; github.com/svg/svgo]` |
| Google Chrome (headless) | 150.0.7871 | Deterministic SVG→PNG rasterization | Full SVG rendering fidelity; already the Phase 82 render-loop tool `[VERIFIED: --headless --version this session]` |
| ImageMagick | 7.1.1-44 | Assemble multi-size `.ico`, resize PNGs | Only tool that writes true multi-image `.ico`; already installed `[VERIFIED: magick identify favicon.ico → 3 sizes]` |
| fontTools | 4.62.1 | (Re)generate/repair Optima outlines if the wordmark is re-cut | Already used in Phase 82; on PATH `[VERIFIED: python3 -c import fontTools]` |
| xmllint (libxml2) | system | SVG well-formedness gate | Already wired into `logo-guards.sh` check 8 `[VERIFIED: /usr/bin/xmllint]` |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `scripts/logo-guards.sh` | in-repo | Automated acceptance gate | Extend to gate shipped asset files + widen `--scope` allowlist |
| Node.js / npx | 22.14.0 | Host for ephemeral `npx svgo` | Present; no `node_modules` committed to `brandbook/` `[VERIFIED]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SVGO via `npx` | Committed `svgo` devDependency | Adds `node_modules`/lockfile churn to a zero-build doc package — rejected by milestone scope ("no bundler/node_modules for a static doc") |
| SVGO | Pure-python precision rounder (regex/fontTools round) | Zero-network, fully reproducible, but reinvents SVGO's safe transforms; keep as **offline fallback** only |
| Chrome headless raster | `rsvg-convert` / `cairosvg` | Both **MISSING** this session (`rsvg-convert: MISSING`, `cairosvg: MISSING`); Chrome is present and already the established pattern |
| ImageMagick internal SVG renderer (MSVG) | — | MSVG is low-fidelity for outlined paths; **always rasterize via Chrome first**, then feed PNGs to ImageMagick for `.ico`/resize only |

**Ephemeral invocation (verified working this session):**
```bash
npx -y svgo@4.0.2 --config svgo.config.mjs --multipass -i in.svg -o out.svg
```

**Version verification (this session):**
- `npm view svgo version` → **4.0.2** (dist-tags: latest 4.0.2, v3 3.3.4, v2 2.8.3); repo `github.com/svg/svgo` `[VERIFIED]`
- `svgo@4` CLI note: config flag is `--config` (v4 renamed from older `-c`); precision via `-p <int>` or config. `[VERIFIED: svgo --help this session]`

## Package Legitimacy Audit

> The only external package this phase touches is SVGO (build-time, ephemeral via `npx`, never committed). All raster tooling is already installed system software (Chrome, ImageMagick, fontTools, xmllint).

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `svgo@4.0.2` | npm | mature (v1 since 2012; v4 line 2025) | very high (tens of M/wk range) | github.com/svg/svgo | OK | Approved — pin to `svgo@4.0.2`, run via `npx -y` |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none
**Note:** `svgo` is confirmed via the official SVG project org (`github.com/svg/svgo`) and returned `4.0.2` from `npm view`. Pin the exact version in the command so a supply-chain swap can't silently change optimizer behavior. Because it runs at authoring time and nothing from `node_modules` is committed, its blast radius is limited to the (human-reviewed, xmllint-gated) SVG output.

## Architecture Patterns

### System Architecture Diagram

```
notes/logo-options.md  (embedded finalist SVGs — current source of truth)
        │  extract finalist marks
        ▼
[hand-author / re-cut source SVGs]  ──► literal token hex, viewBox, currentColor for mono
        │
        ▼
  npx svgo@4.0.2 (safe config)  ──► optimized SVG  ──►  brandbook/assets/logo/*.svg
        │                                                brandbook/assets/favicon/favicon.svg
        │                                                brandbook/assets/social/*-og.svg
        │  (raster derivatives only)
        ▼
  Chrome --headless --screenshot  ──►  PNG @ exact px
        │                               ├─► apple-touch-icon.png (180×180, paper bg)
        │                               ├─► og.png (1200×630)
        │                               └─► fav16/32/48.png ──► ImageMagick ──► favicon.ico
        ▼
  scripts/logo-guards.sh (extended)  ──►  gate the FILES: presence · xmllint · token-hex ·
        │                                  no var( · hygiene · viewBox · raster dims · --scope
        ▼
  ephemeral file:// gallery + Chrome 16px render  ──►  HUMAN CHECKPOINT (perceptual + decision-log)
```

### Recommended Project Structure
```
brandbook/assets/
├── logo/
│   ├── chimeway-logotype.svg           # PRIMARY horizontal lockup = wordmark w/ keystone-i (two-tone)
│   ├── chimeway-logotype-mono.svg      # single color via fill="currentColor" (no teal)
│   ├── chimeway-logotype-inverse.svg   # paper + teal, TRANSPARENT bg (for dark surfaces)
│   ├── chimeway-logotype-stacked.svg   # keystone above the wordmark (square-ish contexts)
│   ├── chimeway-mark.svg               # icon-only two-tone keystone (viewBox 0 0 24 24)
│   └── chimeway-mark-mono.svg          # icon in currentColor
├── favicon/
│   ├── favicon.svg                     # SIMPLIFIED keystone, tuned to read at 16px
│   ├── favicon.ico                     # 16/32/48 multi-size (binary — justified)
│   └── apple-touch-icon.png            # 180×180, solid paper bg, safe padding (binary — justified)
└── social/
    ├── chimeway-og.svg                 # 1200×630 source (mark + wordmark on paper)
    └── chimeway-og.png                 # 1200×630 raster (binary — the ONE justified PNG for OG)
```
**Naming is a contract:** Phase 85 wires `chimeway-logotype.svg` into the README header and `favicon.svg` into `mix.exs` `docs()`; Phase 84 references the whole family in the HTML book. Lock these names now; renames later cascade. Map to LOGO-03's seven named deliverables: primary horizontal lockup + wordmark = `chimeway-logotype.svg` (they coincide — see Q2), icon-only = `chimeway-mark.svg`, stacked = `chimeway-logotype-stacked.svg`, mono = `chimeway-logotype-mono.svg`, inverse = `chimeway-logotype-inverse.svg`, simplified favicon mark = `favicon.svg`.

### Pattern 1: Safe SVGO config for logos (preserve what matters)
**What:** SVGO's default preset is tuned for generic web SVGs and will destroy logo-critical attributes if run naively. The dangerous default is `removeViewBox` (breaks responsive scaling) and, situationally, id/precision handling.
**When:** Every optimized SVG this phase commits.
**Example (verified −61.7% on the wordmark, viewBox + token hex intact):**
```js
// svgo.config.mjs  — Source: svgo.dev plugin docs (preset-default overrides)
export default {
  multipass: true,
  plugins: [
    { name: 'preset-default', params: { overrides: {
      removeViewBox: false,        // CRITICAL: keep viewBox or the mark won't scale
      cleanupIds: false,           // keep human-readable ids (stacked/gradient refs)
      removeUnknownsAndDefaults: { keepAriaAttrs: true, keepRoleAttr: true }, // keep a11y
    } } },
  ],
};
// run: npx -y svgo@4.0.2 --config svgo.config.mjs -p 2 --multipass -i in.svg -o out.svg
```
Verified output preserved `viewBox="30 10 172 46"`, `role`, `aria-label`, and exactly `#102027` + `#0e7c86`; `xmllint --noout` → well-formed. `[VERIFIED: this session]`

### Pattern 2: Mono via `currentColor`, inverse as its own two-tone file, no baked background
**What:** Do not ship one file per (color × context). Ship:
- **two-tone** primary/stacked/icon with literal `#102027` + `#0e7c86`;
- **mono** as a single file whose fills are `fill="currentColor"` (drops the teal) so a consumer recolors it with one CSS `color:` — this is the standard mono pattern;
- **inverse** as its own file (paper `#fffdf8` + teal `#0e7c86`) with a **transparent background** (no `<rect>` fill).
**Why:** The Phase 82 *proof* SVGs baked a `#07131a` night rect for the inverse cell — correct for a proof strip, **wrong for a shipped asset**. A baked background is a de-facto cage (violates LOGO-05 spirit) and prevents the mark dropping onto arbitrary dark surfaces. Ship inverse on transparent; let the host provide the dark backdrop.
**Example (icon mono):**
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" role="img" aria-label="chimeway mark">
  <path d="M6 5 L18 5 L15.5 19 L8.5 19 Z" fill="currentColor"/>
</svg>
```

### Pattern 3: Modern (2026) minimal favicon set — derived from the *simplified* mark
**What:** The correct minimal 2026 set for a library/docs site (not a PWA):
- `favicon.svg` — modern browsers; the **simplified keystone**, not the full lockup naively resized.
- `favicon.ico` — multi-size 16/32/48; still required by legacy contexts and some crawlers/pinned tabs.
- `apple-touch-icon.png` — 180×180 for iOS home-screen (iOS ignores SVG here); give it a **solid paper background + safe padding** because iOS masks/rounds and renders transparency poorly.
- **No** web-app-manifest 192/512 icons (this is a dev-tool/docs, not an installable PWA) — keep the set minimal.
**Deterministic raster (verified this session):**
```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# render SVG at exact px via an HTML wrapper (crisp, deterministic)
"$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=512,512 --screenshot=fav512.png "file://$PWD/fav.html"
for s in 16 32 48; do magick fav512.png -resize ${s}x${s} fav${s}.png; done
magick fav16.png fav32.png fav48.png favicon.ico   # → 3-image .ico (verified)
```
`magick identify favicon.ico` confirmed three embedded sizes (16/32/48). `[VERIFIED: this session]`
**Wiring snippet (assets shipped here; applied in Phase 85):**
```html
<link rel="icon" href="/favicon.ico" sizes="any">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
```

### Pattern 4: Extend `logo-guards.sh` to gate the shipped files (not just the doc)
**What:** Phase 82's guard samples `notes/logo-options.md`. Phase 83 must add a mode/checks that run over `brandbook/assets/**`:
- **presence** — each of the seven named files exists;
- **xmllint** well-formedness per SVG (reuse check 8);
- **token-hex subset** — every `#rrggbb` in each SVG ∈ allowed set (reuse ALLOWED_HEX);
- **no `var(`** inside any committed SVG (reuse check 6);
- **SVG hygiene** — no `<script>`/`<foreignObject>`/`<image>`/`on*=`/`javascript:`/`data:`/remote `href` (reuse check 7 — this is also the phase's security control);
- **viewBox present** on every logo SVG;
- **raster dims** — `magick identify` asserts `og.png` = 1200×630, `apple-touch-icon.png` = 180×180, `favicon.ico` carries ≥ the 16/32/48 sizes;
- **binary budget** — count + total bytes of committed rasters under a documented ceiling (feeds NOTES-03 repo-size check).
**Critical `--scope` fix:** the current `--scope` allowlist is only `notes/logo-options.md` + `scripts/logo-guards.sh`; it will flag every `brandbook/assets/*` file as **stray**. Widen the allowlist to `brandbook/assets/**` and `notes/decision-log.md` or Phase 83's own scope check fails. `[VERIFIED: scripts/logo-guards.sh lines 58-61]`

### Anti-Patterns to Avoid
- **Naively resizing the primary lockup into a favicon.** LOGO-04/INTEG-03 explicitly require a *simplified* mark; the wordmark is illegible at 16px. Use the standalone keystone.
- **Baking a background `<rect>` into shipped marks.** Proof-strip habit; wrong for assets (see Pattern 2).
- **Running SVGO with defaults.** `removeViewBox` breaks scaling; always override.
- **Rasterizing via ImageMagick's MSVG renderer.** Low fidelity on outlined paths — go through Chrome.
- **Committing `node_modules`/a lockfile into `brandbook/`.** Violates the zero-build scope; use `npx -y`.
- **Leaving 15-digit float coordinates** in the fontTools-outlined wordmark (the raw embedded SVG has `#102027 32.406Q53.906 30.875999999999998`). Precision-2 optimization is the single biggest byte win.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SVG minification/precision | Custom regex path rewriter | `npx -y svgo@4.0.2` (safe config) | Path arithmetic, transform collapsing, and numeric rounding have many edge cases SVGO already handles; verified −61.7% |
| SVG→PNG raster | ImageMagick MSVG / manual canvas | Chrome `--headless --screenshot` | Full CSS/SVG fidelity, deterministic, already the Phase 82 pattern |
| Multi-size `.ico` | Byte-assembling ICO headers | `magick a.png b.png c.png out.ico` | ImageMagick writes true multi-image ICO (verified 3 sizes) |
| Font outlining (if re-cut) | Manual bézier tracing | fontTools (already used Phase 82) | Deterministic glyph→path conversion |
| Legibility/hygiene gate | New bespoke script | Extend `scripts/logo-guards.sh` | The gate, allowed-hex set, xmllint block, and scope check already exist |

**Key insight:** Every tool this phase needs is already installed or one `npx` away; the work is *authoring + wiring the pipeline*, not building tooling. The one genuinely new artifact is the extended guard checks.

## Common Pitfalls

### Pitfall 1: `logo-guards.sh --scope` flags every new asset as stray
**What goes wrong:** Phase 83's scope check fails immediately because the allowlist only knows the two Phase-82 files.
**Why:** Lines 58-61 hardcode `ALLOWED_DOC`/`ALLOWED_GUARD`; `brandbook/assets/*` falls into the `*) stray` branch.
**How to avoid:** First task in the phase widens the allowlist to `brandbook/assets/**` + `notes/decision-log.md`.
**Warning signs:** `scope: unexpected path(s) outside the two allowed files:` listing your new SVGs.

### Pitfall 2: SVGO strips `viewBox`, mark stops scaling
**What goes wrong:** Optimized favicon/README logo renders at a fixed tiny size or distorts.
**Why:** `removeViewBox` is in the default preset.
**How to avoid:** `removeViewBox:false` (Pattern 1). Guard asserts `viewBox` present on every logo SVG.
**Warning signs:** Guard's viewBox check fails; GitHub renders the README logo at wrong size.

### Pitfall 3: Committed rasters bloat the repo / trip the milestone binary check
**What goes wrong:** NOTES-03's red-team `git diff --stat` + binary check (Phase 86) flags oversized/too-many PNGs.
**Why:** OG cards and touch icons are raster; careless export produces 100s of KB.
**How to avoid:** Exactly **three** committed rasters (`favicon.ico`, `apple-touch-icon.png`, `og.png`); run each through ImageMagick strip/optimize; document the byte budget in the guard. The favicon test PNG this session was ~5 KB at 512²; a 1200×630 flat-color OG card should be well under ~60 KB.
**Warning signs:** Total `brandbook/assets` raster bytes over the documented ceiling.

### Pitfall 4: Inverse mark carries a baked dark background
**What goes wrong:** The inverse logo shows a hard night rectangle on a differently-colored dark host surface (a visible cage).
**Why:** Copied from the Phase 82 proof-strip inverse cell (`<rect ... fill="#07131a">`).
**How to avoid:** Ship inverse on transparent (Pattern 2); the night color is a *proof backdrop*, not part of the mark.
**Warning signs:** A `<rect ... fill="#07131a">` inside a shipped `*-inverse.svg`.

### Pitfall 5: Optima licensing surfaces late as a redistribution blocker
**What goes wrong:** The committed wordmark outlines are derived from macOS-bundled **Optima** (proprietary Monotype/Linotype face under Apple's system-font license); redistributing outlines in a public OSS repo may exceed that license.
**Why:** Outlining a font into paths is generally treated as artwork by many foundry EULAs, **but** Apple's bundled-font terms are device-scoped and foundry desktop EULAs vary on redistribution.
**How to avoid:** Resolve at the checkpoint (Open Questions Q1) — either confirm the license permits it, or re-cut the wordmark in an OFL/libre humanist face before committing. fontTools makes re-outlining cheap.
**Warning signs:** No license note accompanying the committed wordmark; reviewer asks "can we ship these outlines?"

## Code Examples

### Extract the finalist SVGs from the doc (starting point)
```bash
# The three finalist marks are embedded in notes/logo-options.md:
#   line 41 = primary wordmark (Optima outlines, two-tone keystone-i)
#   line 45 = inverse wordmark
#   line 49 = icon-only two-tone keystone (24x24)
sed -n '41p' notes/logo-options.md > brandbook/assets/logo/chimeway-logotype.raw.svg
# then: hand-adjust (transparent bg, currentColor variants) → svgo → commit
```

### Full optimize + verify one asset
```bash
npx -y svgo@4.0.2 --config svgo.config.mjs -p 2 --multipass \
  -i chimeway-logotype.raw.svg -o brandbook/assets/logo/chimeway-logotype.svg
xmllint --noout brandbook/assets/logo/chimeway-logotype.svg && echo "well-formed"
grep -oE '#[0-9a-f]{6}' brandbook/assets/logo/chimeway-logotype.svg | sort -u   # ⊆ token set
```

### Render an asset at 16px for the perceptual gate
```bash
# HTML wrapper pins exact px; screenshot is what the human eyeballs
printf '<!doctype html><meta charset=utf-8><style>html,body{margin:0}</style>\
<img src="favicon.svg" width="16" height="16">' > f16.html
"$CHROME" --headless --disable-gpu --force-device-scale-factor=1 \
  --window-size=16,16 --screenshot=fav16-real.png "file://$PWD/f16.html"
```

## State of the Art

| Old Approach | Current Approach (2026) | When Changed | Impact |
|--------------|--------------------------|--------------|--------|
| PNG favicons at many fixed sizes + long `<link>` list | `favicon.svg` + one multi-size `favicon.ico` + one `apple-touch-icon.png` | ~2020→ mainstream by 2023 | Minimal set; SVG scales crisply, `.ico` covers legacy |
| SVGO 3 `-c config` CLI | SVGO 4 `--config`, `preset-default` overrides API | 2025 (v4 line) | Update flags; `removeViewBox` still default-on — still must override |
| `filter: invert()` for dark logos | Ship a dedicated inverse file / `currentColor` | long-standing best practice | Correct colors, no muddy inversion (mirrors token-layer rule) |
| Rasterize SVG with ImageMagick MSVG | Chrome headless → PNG, ImageMagick for `.ico`/resize only | ongoing | Fidelity on outlined paths |

**Deprecated/outdated:**
- Web-app-manifest icon sets (192/512) for a plain docs/library site — unnecessary here.
- `browserconfig.xml` / MS tile images — obsolete.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Outlining macOS-bundled **Optima** and redistributing the paths in a public OSS repo is permissible as logo artwork | Pitfall 5 / Q1 | HIGH — legal exposure; may force a re-cut in a libre face. **Must be confirmed at checkpoint.** |
| A2 | Phase 83's checkpoint **confirms** (not re-opens) the Phase 82 Keystone/Optima selection | Q2 | LOW-MED — if the user wants to revisit, the family work restarts |
| A3 | A plain-font wordmark is NOT wanted separately (primary lockup == wordmark, since the typemark is integrated) | LOGO-03 mapping / Q2 | LOW — one extra file if desired |
| A4 | No PWA manifest icons needed (docs/library, not installable app) | Pattern 3 | LOW — add 192/512 PNGs later if a PWA ever ships |
| A5 | INTEG-03 "shipped and wired" = Phase 83 ships assets + provides the `<link>` snippet; actual README/`mix.exs`/HexDocs wiring is Phase 85 | Q3 | LOW-MED — if INTEG-03 expects real wiring now, scope crosses into Phase 85's allowed edits |
| A6 | Three committed raster binaries (`.ico`, apple-touch `.png`, `og.png`) is within the milestone's repo-size/binary discipline | Pitfall 3 | LOW — keep them tiny + documented for the Phase 86 red-team |

## Open Questions (RESOLVED)

> All three resolved with the user at the plan-phase checkpoint (2026-07-18). Each maps 1:1 to a session-locked decision now embedded in the Phase 83 plans.

1. **Optima font licensing for redistributed outlines. — RESOLVED: re-cut in a libre/OFL face.**
   - What we know: the finalist wordmark is Optima outlined via fontTools; Optima is proprietary (Monotype/Linotype), and the macOS copy is under Apple's device-scoped system-font license. `notes/logo-options.md` explicitly deferred "licensing finalization" to Phase 83.
   - **Decision:** Retire Optima. Re-outline the `chimeway` wordmark in an openly-licensed humanist/glyphic face with Optima-like flared character (fontTools re-run) so the committed asset is unambiguously redistributable in a public hex.pm/OSS repo. Keystone-`i` construction, token-hex color law, and a11y attributes carry over; only glyph geometry changes. The chosen face + its license are recorded in `notes/decision-log.md`. (Plan 02 Task 1.)

2. **Confirm vs re-open the selection (Success Criterion #1). — RESOLVED: ratify Keystone, do not re-explore.**
   - What we know: Phase 82 already ran a tournament + human checkpoint and selected Keystone + the keystone-`i` logotype; SUMMARY notes this "pre-stages Phase 83."
   - **Decision:** Phase 83's checkpoint is a formal **ratification**, not a new open selection — no metaphor tournament. Record the ratified Keystone decision (with the OFL re-cut + ship/defer rationale) in `notes/decision-log.md`. "Primary horizontal lockup" and "wordmark" ship as **one file** (`chimeway-logotype.svg`), since the integrated typemark makes them the same artwork; the standalone mono mark is the extra 7th family member. (Plan 03 Tasks 2–3.)

3. **INTEG-03 boundary between Phase 83 and Phase 85. — RESOLVED: Phase 83 ships assets + snippet only.**
   - What we know: INTEG-03 says the favicon is "shipped **and wired**"; INTEG-01/02 (README header, `mix.exs` `docs()` `:logo`/`:favicon`) are Phase 85; the milestone permits only two integration edits and Phase 85 owns them.
   - **Decision:** Phase 83 ships the favicon **assets** and the ready-to-paste `<link>`/`docs()` snippet in the decision record; Phase 85 performs the actual `mix.exs`/README edits. No README/`mix.exs` edits in Phase 83 — keeps the two-edit budget and "don't revise config mid-flight" intent intact. (Plan 03; verified by the plan-checker: no plan's `files_modified` touches README or mix.exs.)

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node/npx (for `npx svgo`) | SVG optimization | ✓ | node 22.14.0 / npx | Pure-python precision rounder (offline) |
| SVGO | SVG optimization | ✓ (ephemeral) | 4.0.2 via `npx -y` | python round + strip comments |
| Google Chrome headless | SVG→PNG raster | ✓ | 150.0.7871 | `chromium` at `/opt/homebrew/bin/chromium` (also present) |
| ImageMagick | `.ico` assembly, PNG resize | ✓ | 7.1.1-44 | — |
| fontTools | (optional) re-cut wordmark outlines | ✓ | 4.62.1 | — |
| xmllint | SVG well-formedness gate | ✓ | system libxml2 | guard already SKIPs if absent |

**Missing dependencies with no fallback:** none.
**Missing (with fallback):** `rsvg-convert`, `cairosvg`, `scour`, `picosvg` — all MISSING, all superseded by the Chrome+ImageMagick+SVGO path above; no action needed.

## Validation Architecture

> `workflow.nyquist_validation: true` (verified in `.planning/config.json`). This section maps Phase 83's success criteria to automatable gates vs human perceptual gates so a VALIDATION.md can be derived.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `scripts/logo-guards.sh` (bash + grep/awk + xmllint + `magick identify`) — no ExUnit; this is asset tooling, kept out of the Elixir suite and out of CI (milestone is doc/asset-only) |
| Config file | none — the guard is self-contained; extend it in-place |
| Quick run command | `bash scripts/logo-guards.sh --assets` (new mode over `brandbook/assets/**`) |
| Full suite command | `bash scripts/logo-guards.sh --assets && bash scripts/logo-guards.sh --scope` |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | File Exists? |
|-----|----------|-----------|-------------------|-------------|
| LOGO-03 | Seven named optimized SVGs present + well-formed + token-hex only + viewBox present | automated | `bash scripts/logo-guards.sh --assets` | ❌ Wave 0 (new `--assets` mode) |
| LOGO-03 | SVGs are optimized (precision-reduced, no editor cruft) | automated (proxy) | byte-ceiling + `grep -c` long-float check in guard | ❌ Wave 0 |
| LOGO-04 | 16px favicon renders non-blank and recognizable | **hybrid** | Chrome render at 16px → non-blank pixel check (auto) + human "reads as keystone" (perceptual) | ❌ Wave 0 |
| LOGO-04 | Mono variant survives without teal | **human perceptual** | render mono → checkpoint | manual gate |
| LOGO-04 | Inverse reads on dark, no baked bg | automated (no `#07131a` rect) + human | guard grep + checkpoint | ❌ Wave 0 |
| INTEG-03 | `favicon.svg` + `favicon.ico`(16/32/48) + `apple-touch-icon.png`(180²) shipped | automated | `magick identify` dim/size assertions in guard | ❌ Wave 0 |
| INTEG-03 | Simplified favicon is the keystone, not a resized lockup | **human perceptual** | visual diff at 16px | manual gate |
| Scope | Working tree carries only allowed paths | automated | `bash scripts/logo-guards.sh --scope` (allowlist widened) | ✅ exists; needs allowlist edit |
| OG card | `og.png` = 1200×630, derived from mark | automated (dims) + human (derivation) | `magick identify` + checkpoint | ❌ Wave 0 |

### Sampling Rate
- **Per asset commit:** `bash scripts/logo-guards.sh --assets` (presence/xmllint/token/hygiene/viewBox for what exists).
- **Per wave merge:** `--assets && --scope` (full file gate + scope boundary).
- **Phase gate:** all automated guards green **and** the human perceptual checkpoint (16px/mono/inverse + selection ratified) recorded in `notes/decision-log.md` before Phase 83 closes.

### Wave 0 Gaps
- [ ] Extend `scripts/logo-guards.sh` with an `--assets` mode (presence, xmllint, token-hex, no-`var(`, hygiene, viewBox, raster dims, binary budget).
- [ ] Widen `--scope` allowlist to `brandbook/assets/**` + `notes/decision-log.md`.
- [ ] `svgo.config.mjs` (safe-plugin config) — authoring input, not committed to `brandbook/` (keep at repo root or scripts/).
- [ ] A tiny Chrome-render helper (render an SVG at N px to PNG) for the 16px non-blank check — may live in scratchpad (ephemeral) or `scripts/`.

## Security Domain

> `security_enforcement` is not set in config (treat as enabled), but this phase ships **static vector/raster assets** — no auth, session, access-control, or crypto surface. The only meaningful control is **SVG content hygiene**, already enforced.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input/Output Validation | **yes** | SVG hygiene: committed SVGs contain presentation elements only — no `<script>`, `<foreignObject>`, `<image>`, `on*=` handlers, `javascript:`/`data:` URIs, or remote `href` (enforced by `logo-guards.sh` check 7; extend to asset files) |
| V6 Cryptography | no | — |

### Known Threat Patterns for static SVG assets
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious/active SVG (script, external fetch) shipped in repo & rendered in a browser context | Tampering / Info-disclosure | Hygiene grep gate over every committed SVG (no active/remote content) |
| Supply-chain swap of the optimizer | Tampering | Pin `svgo@4.0.2`; nothing from `node_modules` is committed; xmllint + human review of output |
| Repo bloat via binaries | (DoS-ish / hygiene) | Three-file raster budget + byte ceiling; Phase 86 red-team binary check |

## Sources

### Primary (HIGH confidence)
- Live toolchain probes this session — `npm view svgo` (4.0.2), Chrome `--headless --version` (150), `magick identify` (ICO 16/32/48), `fontTools 4.62.1`, `xmllint`, end-to-end SVGO run (−61.7%, viewBox/hex preserved), Chrome→PNG→`.ico` assembly.
- `scripts/logo-guards.sh` — allowed-hex set, hygiene checks, xmllint block, `--scope` allowlist (lines 58-61).
- `notes/logo-options.md` — finalist SVGs (lines 41/45/49), token legend, scope note.
- `.planning/phases/82-logo-exploration-shortlist/82-01-SUMMARY.md` — locked finalist decisions (D-14 lineage).
- `.planning/ROADMAP.md` (Phase 83/84/85), `.planning/REQUIREMENTS.md` (LOGO-03/04, INTEG-03), `.planning/config.json`, `brandbook/tokens/tokens.css`.

### Secondary (MEDIUM confidence)
- SVGO v4 `preset-default` override semantics and `removeViewBox` default — verified behaviorally this session (config produced correct output); cross-referenced to svgo.dev plugin docs.
- 2026 minimal favicon set convention — established best practice; corroborated by the verified `.ico`/apple-touch mechanics.

### Tertiary (LOW confidence)
- Optima / macOS-bundled-font redistribution licensing — **not adjudicated**; flagged as A1/Q1 for the checkpoint.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every tool probed and the full optimize+raster+`.ico` pipeline run successfully this session.
- Architecture (file family, mono/inverse, favicon set): HIGH — grounded in the verified finalist SVGs and standard conventions.
- Pitfalls: HIGH — scope-allowlist and `removeViewBox` risks confirmed against the actual guard/SVGO.
- Font licensing: LOW — genuine legal open question; must be resolved at the human checkpoint.

**Research date:** 2026-07-18
**Valid until:** ~2026-08-17 (stable; SVGO/Chrome versions may bump but the pipeline shape holds). Re-verify `svgo` pin if regenerating assets after that.

## RESEARCH COMPLETE
