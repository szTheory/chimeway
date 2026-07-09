# Stack Research: Brand Book Package Tooling & Formats

**Domain:** Programmatically-generated, vector-first OSS brand/design-system package (`brandbook/`)
**Researched:** 2026-07-09
**Confidence:** HIGH (versions verified via `npm view` against the live registry and cross-checked with 2025–2026 web sources; DTCG spec status confirmed against the official W3C Community Group announcement)

## Scope Note

This is a **format and generation-time tooling** stack, not a runtime application stack. The `brandbook/` package itself ships zero JavaScript build output and zero server — it is SVG + HTML + CSS + JSON + MD files that a browser opens directly (`file://`). Every tool below either (a) runs once, locally, to *generate* committed artifacts, or (b) is vendored as a single static file the HTML brandbook loads directly with no bundler. Nothing here becomes a project dependency of `chimeway` core or `chimeway_admin`.

The repo already has precedent for exactly this shape of tooling: root `package.json` carries `@playwright/test` as a devDependency used only for a one-off browser-smoke script (`smoke:admin`), not a build pipeline. The brand-book tooling below follows the same pattern — devDependencies used by a generation script, never shipped, never required to view the artifacts.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Plain Node.js script (ESM, `.mjs`) | Node >=18 (matches existing root `package.json` `engines`) | Programmatically emit SVG markup (logo directions, favicon, social card) as template-literal strings written to disk | Zero framework, zero SVG-builder dependency needed — SVG is just XML text. Node is already the repo's chosen tool for non-Elixir generation/tooling (Playwright precedent). Elixir/Mix could emit strings too, but the optimization step (SVGO) is npm-native with no maintained Elixir equivalent, so staying in Node avoids a two-language toolchain for one artifact family. |
| SVGO | **4.0.1** (verified via `npm view svgo version`) | Post-process generated/hand-tuned SVGs: strip editor cruft, collapse redundant groups, round floats, keep files small and diff-friendly | The de facto standard Node SVG optimizer (`svg/svgo` on GitHub, also powers SVGOMG). Run as a one-shot CLI/script step after generation, never at view-time. Config lives in a committed `svgo.config.mjs` so every run (and every contributor) produces byte-identical output — critical for clean diffs on a generated-asset folder. |
| Design Tokens Format Module (DTCG) | **2025.10 (first stable release, "v1")** — announced 2025-10-28 by the W3C Design Tokens Community Group | Shape for `brandbook/tokens/tokens.json` | This is now a real, stable, vendor-neutral spec (not a draft) with reference implementations in Style Dictionary, Tokens Studio, and Terrazzo, and adoption from Figma, Penpot, Sketch, Framer. Writing the JSON in DTCG shape (`$value`/`$type`, `.tokens.json` media type) costs nothing extra by hand and makes the file immediately usable by any future tool without a rewrite — but does **not** require adopting the Style Dictionary build tool itself (see Alternatives below). |
| Hand-authored CSS custom properties, cascade-layered | N/A (plain CSS3) | `brandbook/tokens/tokens.css` and the HTML brandbook's own `<style>` block | Matches the exact pattern already shipping in `chimeway_admin/priv/static/chimeway_admin.css`: `@layer cw.tokens, cw.base, cw.layout, cw.components, cw.utilities;` with `:where(.chimeway-admin) { --cw-*: ...; }` for zero-specificity scoping. Reusing this pattern verbatim (with a `.chimeway-brandbook` / `.cw-brandbook` root class instead) is the reconciliation mechanism — see "Reconciliation with `--cw-*`" below. |
| CSS `@scope` at-rule | Baseline since **Dec 2025** — Chrome/Edge 118+, Firefox 146+, Safari 17.4+ (all evergreen browsers as of this research date) | Contain "live component demo" blocks inside the HTML brandbook so their reset/example styles cannot bleed into the surrounding brandbook chrome (and vice versa) | `@layer` controls cascade **order**, it explicitly does *not* solve scoping/containment (confirmed via MDN/web.dev) — that's what `@scope` is for. The two are complementary, not redundant: `@layer` for macro precedence (mirrors `chimeway_admin`'s five layers), `@scope (.demo-block) to (.demo-block .no-style)` for micro-containment of embedded examples. This reached full baseline browser support in the last weeks of 2025, so it's now safe to rely on for an internal maintainer-facing artifact. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@resvg/resvg-js` (or `sharp`) | resvg-js **2.6.2** / sharp **0.35.3** | Rasterize the *generated* SVGs to PNG for the handful of surfaces that structurally require raster: Open Graph / social card image (`og:image` cannot be SVG on Twitter/Facebook/LinkedIn crawlers), Apple touch icon (180×180 PNG), and multi-res `favicon.ico`. | Only at generation time, only for these 2-3 specific raster exceptions — everything else in the package stays SVG. Pick one (resvg-cli is faster/smaller for pure SVG→PNG; sharp is more flexible if you also want format conversion elsewhere in the demo host). Both are devDependency-only; output is a small, already-optimized, checked-in binary (a handful of KB each), not a generated-on-demand pipeline. |
| Vendored `color.js` (colorjs.io) | **0.6.1** | Compute both WCAG 2.1 and APCA contrast ratios for every foreground/background pair in the palette, client-side, inside the HTML brandbook itself | Color.js is distributed as a plain ES module (`import Color from "./vendor/color.js"` or directly from `https://colorjs.io/dist/color.js`) with **no bundler required** — this is the key property that makes it fit a zero-build package. Vendor one file into `brandbook/assets/vendor/color.js` (pin the version, note provenance in a comment) rather than adding an npm dependency, so the brandbook keeps working from `file://` with no network fetch and no `node_modules`. It supports WCAG21, APCA, and several perceptual contrast methods in one library, which covers both the AA/AAA check the brand spec already commits to and the more accurate APCA method work is trending toward. |
| Hand-adapted SVG `feColorMatrix` filter set (e.g. the matrices published in `hail2u/color-blindness-emulation`) | N/A — a few dozen lines of SVG `<filter>` XML, not a package | Simulate protanopia/deuteranopia/tritanopia over the palette swatches and logo directly inside the HTML brandbook | These are Brettel/Viénot/Mollon (1997/1999) transform matrices expressed as native SVG `feColorMatrix` elements — copy the specific matrices needed (protanopia, deuteranopia, tritanopia — skip the achromatopsia/anomalous-trichromacy variants unless there's spare time) into a `<defs>` block once, then toggle `filter: url(#protanopia)` via a CSS class on a preview wrapper. Zero dependencies, zero JS required (a `<select>` + a few lines of vanilla JS to swap the class is enough), and it's the same technique used by the Colorblindly browser extension and Chromium's own DevTools vision-deficiency emulator, so the math is well-trusted. |
| MIT-licensed outline icon sets (Heroicons and/or Octicons) as source-of-truth references, **not** installed packages | Heroicons (MIT), Octicons (MIT) | Reference source for the handful of icon `<symbol>` shapes actually needed in the brandbook's iconography section | Do not `npm install @heroicons/react` or similar — that pulls in a component-framework wrapper you don't need. Copy only the specific SVG path data for the icons the brand spec calls out (event, route, recipient, inbox, bell/chime, database, delivery, clock, shield, etc.) into a single `brandbook/assets/icons.svg` `<symbol>` sprite, matching the brand book's 1.5–2px rounded-stroke spec, and keep the license/attribution note in `notes/`. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `svgo.config.mjs` (committed) | Deterministic SVGO settings so regenerating assets is idempotent | Set `removeViewBox: false` (breaks responsive/CSS-driven scaling if stripped), `floatPrecision: 2` for icon-scale marks / `3` for anything with finer curves (the wordmark outline), `multipass: true`. Commit the config next to the generation script, not globally, so it's obviously scoped to `brandbook/`. |
| A tiny local static server, used only for manual preview convenience | Not required to *view* the brandbook (it's designed to open via `file://`), but useful during authoring if you want relative-path `fetch()` of the vendored `color.js` module to behave identically to production | `npx serve brandbook` or Python's built-in `python3 -m http.server` — no dependency to add, already on every dev machine. Do not wire this into CI or make it a documented requirement; it's a "nice during editing" note, not part of the deliverable's contract. |
| `git diff` / file-size check as a manual pre-commit habit | Repo-size discipline | No new tooling needed — `git status`/`du -sh brandbook/` before committing is sufficient at this scale (dozens of small SVG/JSON/CSS files). Do not add a CI file-size gate for this milestone; PROJECT.md explicitly scopes this milestone as doc/asset-only and asks it not to touch CI. |

## Reconciliation with existing `--cw-*` tokens

`chimeway_admin/priv/static/chimeway_admin.css` already ships a working, scoped `@layer cw.tokens` system: primitive brand colors (`--cw-ink`, `--cw-teal`, `--cw-brass`, …), spacing scale (`--cw-space-*`), type tokens, radii, shadows, motion, and a full light/dark/system theming contract via `:where(.chimeway-admin[data-cw-theme="..."])`. The brand book prompt's own §14/§15/§28 tokens are a superset of this — same hex values, same naming convention, just not yet reconciled into one file.

Recommended approach for `brandbook/tokens/`:
1. **`tokens.json`** (DTCG-shaped, hand-authored) is the single source of truth for the *value* of every primitive (`--cw-ink: #102027`, etc.) and every semantic/status token, with `$type` (`color`, `dimension`, `fontFamily`, …) and `$description` per token.
2. **`tokens.css`** is generated by hand (not by a build tool) directly from `tokens.json`'s values, using the *exact same token names* already live in `chimeway_admin.css` for every token that overlaps (`--cw-ink`, `--cw-teal`, `--cw-space-md`, `--cw-radius-md`, etc.) — this is what makes it a reconciliation rather than a fork. New tokens the brandbook needs that `chimeway_admin` doesn't yet have (e.g. logo-specific clearspace units, marketing-only display type sizes) get added with the same `--cw-` prefix and naming grammar, so a future `chimeway_admin` re-theme (explicitly deferred per PROJECT.md) can adopt them without a rename pass.
3. Because both files are small (dozens, not hundreds, of tokens) and there are only two output targets (JSON + CSS), a Style Dictionary build step buys nothing here — see "What NOT to Use."

## Installation

```bash
# In brandbook/ (or reuse the existing root package.json as a devDependency home —
# either is fine; keeping it root-level matches the existing Playwright precedent
# and avoids a second package.json/node_modules tree).

npm install -D svgo@4.0.1

# Pick ONE rasterizer for the 2-3 raster exceptions (OG card, apple-touch-icon, favicon.ico):
npm install -D @resvg/resvg-js@2.6.2
# — or —
npm install -D sharp@0.35.3

# color.js is NOT npm-installed — vendor the single dist file instead:
curl -o brandbook/assets/vendor/color.js https://colorjs.io/dist/color.js
# (pin by checking in the file; note version 0.6.1 and source URL in a header comment)
```

No dependency is added to `mix.exs`, `chimeway_admin`'s asset pipeline, or the demo host. Nothing here runs in CI for this milestone (doc/asset-only, per PROJECT.md).

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| Hand-authored `tokens.json` (DTCG-shaped) + hand-authored `tokens.css` | Style Dictionary v5.5.0 as a real build step (it natively consumes DTCG format now) | If Chimeway later needs to generate tokens for a *third* platform (e.g. an iOS/Android client, or a Tailwind/daisyUI theme config) from one source of truth. At two hand-maintained targets (JSON + CSS) for a package this size, Style Dictionary's config/transform/plugin surface is pure overhead — it would be the first build tool in a repo that has deliberately avoided one for this artifact. Revisit at the point `chimeway_admin`'s full re-theme milestone lands, if a third consumer appears. |
| Plain Node script emitting SVG via template literals | An SVG-building library (e.g. a JSX-to-SVG or scene-graph library) | Only if the logo geometry becomes complex enough (many boolean path operations, bezier math) that hand-writing path `d` strings becomes error-prone. For the geometry described in the brand spec (rounded path + chime endpoint + signal arcs, simple monogram), plain string templates with a couple of small hand-rolled path helpers (arc/line segment builders) are enough and keep the generation script auditable in a code review. |
| Cascade layers (`@layer`) + `@scope` for CSS containment | Shadow DOM (`attachShadow`) for the HTML brandbook | If the brandbook ever needs to be *embedded* as a widget inside another page (not just opened standalone) where true DOM/style isolation from an unknown host page is required. For a standalone `file://`-opened document, Shadow DOM adds JS runtime complexity, breaks "view source and copy the CSS straight into your app," and solves a problem (isolation from a host page) this artifact doesn't have. Cascade layers + `@scope` solve the actual problem (internal example blocks not bleeding into brandbook chrome) declaratively. |
| Vendored single-file `color.js` for contrast math | `get-contrast` (npm, v3.0.0) or a hand-rolled WCAG-only formula | If a Node CLI script (not the browser-opened HTML page) is the preferred place to run contrast checks — e.g. as a one-off `node check-contrast.mjs` during design review rather than a live section of the brandbook. `get-contrast` is a fine, tiny, WCAG-only npm package for that CLI use case, but it doesn't do APCA, and pulling it via npm means the contrast proof isn't visible/re-runnable from the artifact itself the way an embedded vendored script is. |
| SVGO as a one-shot devDependency script | SVGOMG (browser GUI) for manual one-off optimization | Fine for spot-checking a single hand-tweaked SVG during design iteration, but not repeatable/scriptable — use the CLI/config for anything that needs to be regenerated deterministically (which is every asset in a "programmatically-generated" brand system). |
| Node + npm for the generation script | Elixir Mix task (`mix brandbook.gen`) | Defensible if the team wants a single-language toolchain and is comfortable hand-rolling SVG minification (Elixir has no maintained SVGO equivalent — you'd either shell out to the Node SVGO CLI anyway, defeating the point, or ship unoptimized SVG). Not recommended for this milestone: the ecosystem's actual optimizer lives in Node, and the repo already treats Node/npm as an acceptable devDependency-only tool (Playwright). |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|--------------|
| Style Dictionary / Tokens Studio CLI / Cobalt as a required build step | Adds a first build system to an artifact whose entire design goal is "no build system"; overkill for ~50-100 hand-maintained tokens with two output targets | Hand-authored `tokens.json` (DTCG-shaped) + hand-authored `tokens.css`, reconciled by name with `--cw-*` (see above) |
| Figma / Illustrator / Sketch source files (`.fig`, `.ai`, `.sketch`) checked into the repo | Proprietary binary formats: unreadable diffs, requires paid/proprietary software to open or edit, works against "programmatically-generated" and repo-size discipline simultaneously | SVG as the only source of truth, generated by the Node script; if visual sketching is wanted during ideation, do it outside the repo and throw the source away once the SVG is committed |
| Any bundler (Vite, Webpack, Parcel, esbuild) for the HTML brandbook | Defeats the "opens via `file://`" requirement (bundlers assume a dev server or a build output step), adds a `node_modules` tree for a static document, and creates a second place brand tokens could drift from `tokens.css` | Single self-contained `index.html` with an inline `<style>` block (or at most one sibling `.css` file loaded via `<link>`), and `<script type="module">` pointing at the one vendored `color.js` file — no transpilation, no minification step required to view it |
| Tailwind CSS / PostCSS pipeline for the brandbook page | Requires a build step to resolve utility classes and its own config-driven token abstraction, which would compete with (not reconcile with) the hand-written `--cw-*` custom-property system `chimeway_admin` already ships | Plain hand-authored CSS using the same `@layer` + custom-property pattern already proven in `chimeway_admin.css` |
| PDF export pipeline (Puppeteer print-to-PDF, WeasyPrint, Prince, wkhtmltopdf) | Explicitly rejected by the milestone's hard constraints (HTML is the primary deliverable, not PDF); a PDF pipeline is also a second, heavier build system and a source of binary-artifact bloat | If a PDF is ever genuinely wanted later, rely on the browser's native "Print to PDF" against a hand-written `@media print` stylesheet in the HTML brandbook — zero new tooling, on-demand, never checked into git |
| Bundled font binaries (`.woff2`/`.ttf`/`.otf`) committed to the repo | Violates the milestone's explicit font-strategy decision (system font stack + documented recommendation, no bundled font binary) and repo-size/licensing discipline | System font stack as primary (`Inter, ui-sans-serif, system-ui, ...`, already the exact stack live in `chimeway_admin.css`); document Inter / IBM Plex Mono / Source Serif 4 as a *recommended* self-host-or-Google-Fonts choice for consumers who want the closer match, without shipping the binary |
| Icon webfont (`@font-face`-based icon font, e.g. a Font Awesome-style kit) | Same font-binary problem as above, plus icon fonts are worse for accessibility (icons become "characters" to screen readers unless carefully ARIA-hidden) and worse for crisp rendering at arbitrary sizes than SVG | Inline SVG `<symbol>` sprite (`brandbook/assets/icons.svg`) referenced via `<use href="#icon-name">`, sourced from Heroicons/Octicons (MIT) |
| SVGO (or any generation-time tool) as a runtime/shipped dependency of the HTML brandbook itself | The brandbook must open via `file://` with no `node_modules` present; SVGO is a Node CLI, not a browser API | Keep SVGO strictly in the generation script's devDependency list; the *output* SVG files are what ship, already optimized, with no reference back to SVGO at view-time |
| Shadow DOM for internal component-demo isolation | Adds JS runtime complexity and breaks the "view source, copy the CSS" workflow that makes a static brand book useful as a reference; also unnecessary since there's no untrusted host page to isolate from | `@layer` (macro cascade order) + `@scope` (micro containment of demo blocks), both now Baseline-supported, both purely declarative CSS |
| axe-core / pa11y wired into CI as an automated gate for this milestone | PROJECT.md explicitly scopes v1.15 as doc/asset-only and states it should not touch CI/runtime code, to avoid worsening the 3 known-red CI lanes; adding a new CI lane here is out of scope | Manual, zero-install QA passes with the axe DevTools browser extension or Chrome DevTools Lighthouse panel during authoring, plus the embedded, vendored `color.js` contrast matrix living inside the brandbook itself as the durable, re-openable proof |

## Stack Patterns by Variant

**If a logo direction needs genuinely complex path geometry (not just arcs/lines/rounded terminals):**
- Sketch it in any vector tool you like as a one-off ideation step, then hand-transcribe/simplify the resulting path data back into the Node generation script's template literals (or a small hand-authored `.svg` that the script imports and re-emits variants of via string substitution for color/size).
- Because the source of truth must stay text-diffable and dependency-free, do not check in the vector-tool's native project file — only the resulting optimized SVG.

**If the HTML brandbook grows large enough that a single inline `<style>` block becomes hard to navigate:**
- Split into `index.html` + one sibling `brandbook/assets/brandbook.css` loaded via `<link rel="stylesheet">`. This is still zero-build (a `<link>` to a local file works identically to an inline `<style>` when opened via `file://`) — just better for editing ergonomics once the stylesheet exceeds a few hundred lines.

**If a future milestone adds a third token consumer (e.g. Tailwind theme config, mobile app):**
- Revisit Style Dictionary at that point — the `tokens.json` is already DTCG-shaped, so adopting Style Dictionary later is a config-writing exercise, not a data-migration one.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|------------------|-------|
| `svgo@4.0.1` | Node >=16 (engines field) | Root `package.json` already pins `engines.node >= 18`, comfortably above SVGO's floor |
| `color.js@0.6.1` (vendored) | Any evergreen browser with native ES module support (all target browsers already required for `@scope`) | No Node/npm coupling at all when vendored as a static file — this is a browser-runtime dependency, not a build-time one |
| CSS `@scope` | Chrome/Edge 118+, Firefox 146+, Safari 17.4+ | Fully Baseline as of December 2025; older browsers simply ignore the `@scope` block (unlayered/unscoped styles still apply), so it degrades gracefully rather than breaking — same posture the repo already accepts for `@layer` |
| `@resvg/resvg-js@2.6.2` / `sharp@0.35.3` | Node >=18 | Either is fine; do not install both — pick one to avoid two native-binary devDependencies for the same job |
| DTCG Design Tokens Format Module `2025.10` | Style Dictionary v5.x (native support), Terrazzo, Tokens Studio | Hand-authoring to this spec today costs nothing and is forward-compatible if any of these tools are adopted later |

## Sources

- [SVGO — GitHub](https://github.com/svg/svgo) — HIGH confidence, official repo, version cross-checked via `npm view svgo version` (4.0.1)
- [svgo — npm](https://www.npmjs.com/package/svgo) — HIGH confidence, registry source of truth
- [SVGOMG](https://jakearchibald.github.io/svgomg/) — HIGH confidence, official GUI reference for SVGO defaults/plugins
- [Design Tokens Specification Reaches First Stable Version — W3C Design Tokens Community Group](https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/) — HIGH confidence, primary source, dated 2025-10-28
- [Design Tokens Format Module 2025.10](https://www.designtokens.org/tr/drafts/format/) — HIGH confidence, the spec text itself
- [Design Tokens Community Group | Style Dictionary](https://styledictionary.com/info/dtcg/) — HIGH confidence, documents Style Dictionary's native DTCG support
- [style-dictionary — npm](https://www.npmjs.com/package/style-dictionary) — HIGH confidence, version cross-checked via `npm view style-dictionary version` (5.5.0)
- [MDN — Cascade layers](https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Styling_basics/Cascade_layers) — HIGH confidence, official reference; confirms layers control order, not scoping
- [MDN — @scope](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@scope) — HIGH confidence, official reference
- [Can I use — CSS Cascade Layers](https://caniuse.com/css-cascade-layers) / [Can I use — @scope](https://caniuse.com/css-cascade-scope) — HIGH confidence, browser-support ground truth
- [Master.dev — How to @scope CSS Now That It's Baseline](https://master.dev/blog/how-to-scope-css-now-that-its-baseline/) — MEDIUM confidence, corroborates Dec 2025 full-baseline timing
- [Evil Martians — How to Favicon in 2026: Three files that fit most needs](https://evilmartians.com/chronicles/how-to-favicon-in-2021-six-files-that-fit-most-needs) — MEDIUM-HIGH confidence, widely-cited practitioner reference for the favicon.svg + favicon.ico + apple-touch-icon pattern and the `sizes="any"` technique
- [DaltonLens — Accurate SVG filters for color blindness simulation](https://daltonlens.org/cvd-simulation-svg-filters/) — MEDIUM-HIGH confidence, explains the Brettel/Viénot/Mollon matrix math behind `feColorMatrix` CVD simulation
- [hail2u/color-blindness-emulation — GitHub](https://github.com/hail2u/color-blindness-emulation) — MEDIUM confidence, concrete SVG filter matrices to adapt
- [Color.js — Contrast docs](https://colorjs.io/docs/contrast) — HIGH confidence, official docs confirming WCAG21 + APCA support and browser-native ESM usage; version cross-checked via `npm view colorjs.io version` (0.6.1)
- `npm view <pkg> version` (local registry queries, 2026-07-09) — HIGH confidence, live registry ground truth for svgo, style-dictionary, get-contrast, colorjs.io, culori, sharp, @resvg/resvg-js
- `chimeway_admin/priv/static/chimeway_admin.css` (this repo) — HIGH confidence, primary source for the existing `--cw-*` token system and `@layer` scoping pattern this stack must reconcile with
- `prompts/chimeway-brand-book.md` §12–15, §17, §20, §28 (this repo) — HIGH confidence, primary source for the token values, logo constraints, iconography, and motion rules this stack must serve
- `prompts/brand-book-pressure-test.md` (this repo) — HIGH confidence, primary source for the hard constraints (self-contained folder, no build system, vector-first, HTML not PDF, no font binaries)

---
*Stack research for: Chimeway v1.15 Brand Identity & Brand Book — `brandbook/` package tooling*
*Researched: 2026-07-09*
