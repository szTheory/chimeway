# Phase 84: HTML Brandbook, Voice & Component States - Research

**Researched:** 2026-07-18
**Domain:** Static, `file://`-safe HTML/CSS design-system documentation (scoped CSS, token-driven component states, inline-JS contrast/theming, brand-voice content authoring)
**Confidence:** HIGH (technical strategy) / HIGH (content — a canonical source already exists in-repo)

## Summary

This phase assembles finalized, already-shipped inputs — `brandbook/tokens/tokens.css` (Phase 81) and the six-mark logo family + favicon/social derivatives (Phase 83) — into a single standalone HTML brand book. Almost nothing here is a genuine unknown: the tokens are locked and copy-safe, the logos are self-contained inline-path SVGs (mono variants already use `fill="currentColor"`), and the brand-voice/microcopy content is already written in full at `prompts/chimeway-brand-book.md` (voice principles §9, copy vocabulary §10, naming rules §11, voice examples §25, brand-safe claims §26, do/don't summary §34, status-color mapping §14). The phase's real work is *assembly and authoring into HTML*, not discovery.

The three technical risks that will make or break the plan are all well-understood web-platform facts: (1) **`file://` safety** — under Chromium `file://`, `fetch()`/XHR, ES-module `import`, and cross-file SVG `<use href="sprite.svg#id">` are all CORS-blocked, while linked stylesheets, `<img src>`, CSS `background-image: url()`, inline `<svg>`, same-document `<use href="#id">`, and inline `<script>`/`<style>` all work; (2) **CSS scoping** — `@layer` is broadly Baseline (since 2022) and `@scope` reached Baseline Newly Available in late 2025, so both are usable, but a defensive descendant-selector fallback under `.cw-brandbook` is prudent because `@scope` has a long tail of older-browser non-support; (3) **static token-driven states** — every component state (hover/focus/active/disabled/loading/error/empty/skeleton/selected) must render *without interaction* via `.is-*` forcing classes that duplicate the real pseudo-class rules, plus a pure-CSS skeleton shimmer.

**Primary recommendation:** Ship `brandbook/index.html` as a single HTML file that `<link>`s the already-shipped `tokens/tokens.css` (relative path — `file://`-safe) plus one scoped `brandbook.css`, inlines the logo SVGs where theming/`currentColor` matters (and uses `<img src>` for fixed-color lockups + raster previews), and drives the theme toggle + live contrast matrix with a single inline `<script>` (no external module, no `fetch`). Author all voice/microcopy/do-don't content by lifting it verbatim-with-editing from `prompts/chimeway-brand-book.md`, which is the canonical brand source of truth. Mirror the Phase-81/83 house validation pattern: a dependency-free `scripts/*-guards.sh` gate (grep/sed/awk + optional `xmllint`) that proves `file://` safety and scope non-leakage automatically.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Token values (color/space/type) | CDN / Static (`tokens/tokens.css`) | — | Already shipped in Phase 81; the book consumes, never redefines |
| Logo rendering | CDN / Static (SVG assets) | Browser (inline `<svg>` for `currentColor` theming) | Fixed lockups = `<img>`; themeable/mono = inline in markup |
| Book layout + demo styles | Browser (scoped CSS) | — | `.cw-brandbook` root, `.cwb-*` demo classes, `@layer`+`@scope` |
| Component-state showcase | Browser (static CSS) | — | `.is-*` forcing classes render states without interaction |
| Theme toggle (light/dark/system) | Browser (inline JS) | Static (`[data-theme]` in `tokens.css`) | Flip `data-theme` on root; "system" defers to `prefers-color-scheme` |
| Live contrast matrix | Browser (inline JS) | — | Read token values via `getComputedStyle`, compute WCAG ratios at runtime |
| Brand voice / microcopy / do-don't | CDN / Static (authored HTML) | — | Pure content; source = `prompts/chimeway-brand-book.md` |

*No server/API/database tier participates — this is a zero-backend static artifact by design (BOOK-01).*

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BOOK-01 | `index.html` opens via `file://`, no server/build, all refs relative, no `fetch()` / no cross-file `<use href>` sprites (Chromium-safe) | §1 `file://` Safety Matrix — enumerates exactly what breaks and the safe embedding strategies; validated by a grep guard |
| BOOK-02 | Book CSS scoped (`@layer` + `@scope`, `.cw-brandbook` root, `.cwb-*` demo classes) — no leakage either direction | §2 CSS Scoping — `@layer`/`@scope` skeleton + Baseline status + descendant-selector fallback |
| BOOK-03 | Renders logo family, token/color swatches, type/spacing, component showcase, live light/dark/system toggle, live contrast matrix — responsive | §3 Token-Driven States, §4 Contrast Matrix + Theme Toggle; token names pulled from `tokens.css` |
| STATE-01 | Component states hover/focus/active/disabled/loading/error/empty/skeleton/selected as static token-driven HTML/CSS | §3 — `.is-*` forcing-class pattern + pure-CSS skeleton shimmer; status colors from `prompts:669-679` |
| STATE-02 | Do/don't brand-usage pairs (logo misuse, color misuse, spacing) as visual pairs | §5 Do/Don't — source lists at `prompts:574-582` (logo), `:661-667` (color), clearspace `:541-547` |
| VOICE-01 | Voice/tone documented by context (docs/errors/marketing/CLI) with good/bad examples | §6 — canonical examples already written at `prompts:251-311` (principles) + `:1349-1409` (per-context examples) |
| VOICE-02 | Named reusable "what happened / why it matters / how to fix" error-message template | §6 — derived from voice principle §2 "Explain decisions" (`prompts:265-275`) + error examples `:1371-1379` |
| VOICE-03 | CTA style + naming rules incl. lowercase `chimeway` graphic vs title-case "Chimeway" prose | §6 — naming rules `prompts:382-450`, graphic-vs-prose case rule `:509-519`, CTA/claims `:1411-1445` |
</phase_requirements>

> **Note:** No `84-CONTEXT.md` exists — the user chose to plan directly from ROADMAP + requirements. There are therefore no locked user decisions to honor beyond the ROADMAP Success Criteria and REQUIREMENTS IDs above, and the standing milestone scope guard (below). All design choices in this research are **Claude's discretion**, recommended prescriptively.

## Standing Scope Guard (from STATE.md / milestone invariants)

- **`brandbook/`-only.** This phase writes under `brandbook/` (+ a `scripts/*-guards.sh` validator). It must NOT edit `chimeway_admin/**`, `README.md`, or `mix.exs` — README/HexDocs wiring is **Phase 85** (INTEG-01/02/04); the favicon `<link>` snippet and ExDoc note are already staged in `notes/decision-log.md:165-184` for Phase 85, do not apply them here. `[VERIFIED: .planning/STATE.md:547, ROADMAP:150-163]`
- **Zero-drift on tokens.** `tokens.css` is the SSOT reconciled in Phase 81; consume it, never fork or re-hex it. The house hard gate is `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css` (unchanged). `[VERIFIED: notes/decision-log.md:103]`
- **Repo-size discipline.** The original brief explicitly warns against binary bloat — keep the book text/SVG; the only justified raster is the already-shipped OG PNG. `[CITED: prompts/brand-book-pressure-test.md]`

## Standard Stack

This phase deliberately uses **no external libraries, no build step, no framework** — that is a hard requirement (BOOK-01), not a preference. The "stack" is the web platform itself.

### Core
| Technology | Version / Baseline | Purpose | Why Standard |
|------------|-------------------|---------|--------------|
| HTML5 + CSS custom properties | Universal | Structure + token consumption | Tokens already published as `--cw-*` in `tokens.css` `[VERIFIED: brandbook/tokens/tokens.css]` |
| CSS `@layer` (cascade layers) | Baseline widely available (all engines since ~2022) | Deterministic cascade ordering so book styles never fight host styles | Baseline; no polyfill needed `[CITED: web.dev/blog/web-platform, MDN @layer]` |
| CSS `@scope` | Baseline Newly Available (Chrome 118+, Safari 17.4+, Firefox 146, late 2025) | Style isolation to `.cw-brandbook`, donut-scoping demos | Now cross-engine; use with a descendant-selector fallback for the older-browser tail `[CITED: frontendmasters.com/blog/how-to-scope-css-now-that-its-baseline, web-standards.dev/news/2026/01/scope-css-baseline]` |
| Inline `<script>` (no modules) | Universal | Theme toggle + contrast matrix | Only inline JS runs under `file://`; external `type="module"` is CORS-blocked `[CITED: chromium file:// CORS]` |
| Inline SVG / `<img src>` / CSS `url()` | Universal | Logo embedding | All three are `file://`-safe; cross-file `<use href>` is NOT `[CITED: bugs.chromium.org/470601]` |

### Supporting
| Asset | Location | Purpose | When to Use |
|-------|----------|---------|-------------|
| `brandbook/tokens/tokens.css` | relative `<link>` from `index.html` | Publishes all `--cw-*` tokens + theme blocks | Always — the single token source; never duplicated into the book |
| `brandbook/assets/logo/*.svg` | inline or `<img>` | 6-mark family | inline when `currentColor`/theming needed; `<img>` for fixed-color lockups |
| `brandbook/assets/favicon/*`, `assets/social/*` | `<img>` preview + `<link rel="icon">` | favicon + OG previews in the book | Show as static previews only |
| Inter / IBM Plex Mono / Source Serif 4 | `font-family` stacks in tokens | Type system | Already in `--cw-font-family-*`; fall back to system fonts — do NOT add `@font-face` web-font files (bloat + `file://` font-load caveats) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single `index.html` + linked `brandbook.css` + linked `tokens.css` | Fully inlined single file (CSS+JS in `<style>`/`<script>`) | Inlining is maximally robust for a copy-anywhere file, but linked stylesheets ARE `file://`-safe and keep the book editable + DRY with the SSOT tokens. **Recommend linked** for tokens (SSOT) + book CSS; inline only the JS. |
| Inline `<svg>` logos | `<img src="logo.svg">` everywhere | `<img>` is DRY (references the shipped asset file, no drift) but cannot inherit CSS `color`, so `currentColor` mono/theming demos won't recolor. **Use both:** inline where theming matters, `<img>` for fixed lockups + raster previews. |
| `@scope` isolation | Shadow DOM / iframe | Shadow DOM/iframe give hard isolation but break `file://` simplicity, single-scroll layout, and print. `@scope` + `@layer` + a root class is the right weight here. |
| Hand-authored voice HTML | Generate from `prompts/chimeway-brand-book.md` at build | No build step allowed (BOOK-01). Author the HTML by hand, lifting content from the prompt. |

**Installation:** None. `npm install` / `pip install` / `cargo add` are all **N/A** — this phase installs zero packages.

## Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.** The deliverable is static HTML/CSS/SVG with inline vanilla JS and no dependencies, no `package.json` addition, no CDN `<script src>`. There is therefore no supply-chain surface to audit. (This is itself a brand/security virtue worth stating in the book: the artifact has no third-party runtime code.)

## Architecture Patterns

### System Architecture Diagram

```
                          brandbook/index.html  (open via file://)
                                     │
        ┌────────────────────────────┼────────────────────────────────┐
        │ <link> (file://-safe)      │ inline <script> (only JS that   │
        ▼                            ▼   runs under file://)           ▼
  tokens/tokens.css           brandbook.css                  theme toggle + contrast
  (--cw-* SSOT, Phase 81)     @layer cwb.reset,              matrix
   :root / [data-theme]        cwb.tokens, cwb.book;          │
   / @media dark               @scope (.cw-brandbook){ … }    │ reads getComputedStyle(--cw-*)
        │                        .cwb-* demo classes          │ writes [data-theme] on root
        │                        .is-* state-forcing classes  │ respects prefers-color-scheme
        ▼                            ▼                          ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  RENDERED SECTIONS (all static HTML, token-driven)                     │
  │  logo family ── color/token swatches ── type/spacing ── component      │
  │  states (hover/focus/active/disabled/loading/error/empty/skeleton/     │
  │  selected) ── do/don't pairs ── voice by context ── error template     │
  └──────────────────────────────────────────────────────────────────────┘
        ▲                            ▲                          ▲
  logo SVGs:                   status colors:              WCAG pass/fail badges
  inline <svg> (currentColor,  --cw-status-*-{text,        computed live, no lib
  theming) OR <img src>        surface,border} triads
  (fixed lockups + rasters)    from tokens.css
```

Data flow to trace for the primary use case (a reader opening the file): the browser loads `index.html` from disk → resolves the two relative `<link>` stylesheets (allowed under `file://`) → `tokens.css` publishes `--cw-*` to `:root` and installs `[data-theme]`/`@media` theme blocks → `brandbook.css` reads those tokens inside `@scope (.cw-brandbook)` to lay out sections and render demo components → inline `<script>` reads the same tokens via `getComputedStyle` to render the contrast matrix and wires the theme toggle to `data-theme`. No network request ever fires.

### Recommended Project Structure
```
brandbook/
├── index.html            # single entry — open via file://; sections below
├── brandbook.css         # NEW — scoped book layout + demo/state styles (.cwb-*, @layer/@scope)
├── tokens/
│   └── tokens.css        # EXISTING (Phase 81) — linked, never edited
└── assets/
    ├── logo/*.svg        # EXISTING (Phase 83) — inline or <img>
    ├── favicon/*         # EXISTING — <link rel=icon> + <img> preview
    └── social/*          # EXISTING — <img> OG preview
scripts/
└── brandbook-guards.sh   # NEW — file://-safety + scope-leak grep gate (house pattern)
```

Recommended `index.html` section order (matches ROADMAP SC #3-#4 and the source prompt's own ordering):
1. Header + theme toggle (light / dark / system tri-state control)
2. Logo family (primary, wordmark, stacked, mark, mono, inverse) with clearspace + min-size notes
3. Color & token swatches (primitives, semantic aliases, status triads) — each swatch shows name + resolved value
4. Live contrast matrix (fg×bg WCAG pass/fail, recomputed on theme change)
5. Typography (Inter/IBM Plex Mono/Source Serif 4) + spacing scale
6. Component states showcase (the nine states, each shown static via `.is-*`)
7. Do/Don't visual pairs (logo misuse, color misuse, spacing misuse)
8. Brand voice by context (docs / errors / marketing / CLI) with good/bad
9. The named error-message template ("what happened / why it matters / how to fix")
10. Naming & CTA rules (lowercase `chimeway` graphic vs "Chimeway" prose)

### Pattern 1: Reuse the shipped tokens via a relative `<link>` (not a copy)
**What:** `index.html` links the Phase-81 token file directly.
**When to use:** Always — keeps a single source of truth; linked stylesheets load fine under `file://`.
```html
<!-- index.html <head> — relative path, file://-safe -->
<link rel="stylesheet" href="tokens/tokens.css">
<link rel="stylesheet" href="brandbook.css">
```
Note: `tokens.css` publishes `--cw-*` to a **bare `:root`** by design (D-01, global publication). That is intentional and does not conflict with BOOK-02 — it is the book's *own demo layout* CSS (`.cwb-*`) that must be scoped so a copied snippet can't leak, not the tokens.

### Pattern 2: `@layer` + `@scope` skeleton for the book CSS (BOOK-02)
**What:** Cascade-layered, scoped book styles that cannot leak into or be leaked into by a host app.
```css
/* brandbook.css */
@layer cwb.reset, cwb.book, cwb.demo;   /* explicit order; book styles lose to nothing accidental */

@layer cwb.book {
  @scope (.cw-brandbook) {
    :scope { color: var(--cw-fg); background: var(--cw-surface-bg); font-family: var(--cw-font-family-sans); }
    .cwb-section { padding: var(--cw-space-xl); }
    .cwb-swatch  { border: var(--cw-border-width) solid var(--cw-border); border-radius: var(--cw-radius-md); }
  }
}

/* Fallback for the older-browser tail that ignores @scope entirely:
   plain descendant selectors under the same root class. Harmless where @scope works. */
@layer cwb.book {
  .cw-brandbook .cwb-section { padding: var(--cw-space-xl); }
}
```
`<body class="cw-brandbook">` (or a wrapping `<div>`). `@scope` prevents book→host leakage (rules only match inside `.cw-brandbook`); `@layer cwb.*` keeps book rules in a low-priority layer so host styles win if the book is embedded, preventing host→book *and* book→host specificity fights. Donut-scoping (`@scope (.cw-brandbook) to (.cwb-live-demo)`) can exclude live-embed demo regions.

### Pattern 3: Static state-forcing classes (STATE-01)
**What:** Every interactive state is rendered *visibly without interaction* by a `.is-*` class that duplicates the real pseudo-class rule.
```css
@layer cwb.demo {
  @scope (.cw-brandbook) {
    .cwb-btn { background: var(--cw-button-primary-bg); color: var(--cw-button-primary-fg);
               border-radius: var(--cw-radius-md); transition: var(--cw-motion-fast); }
    .cwb-btn:hover,        .cwb-btn.is-hover     { background: var(--cw-control-hover); }
    .cwb-btn:active,       .cwb-btn.is-active    { background: var(--cw-control-active); }
    .cwb-btn:focus-visible,.cwb-btn.is-focus     { outline: var(--cw-focus-offset) solid var(--cw-focus);
                                                   outline-offset: var(--cw-focus-offset); }
    .cwb-btn:disabled,     .cwb-btn.is-disabled  { background: var(--cw-control-disabled-bg);
                                                   color: var(--cw-control-disabled-fg); cursor: not-allowed; }
    .cwb-btn.is-selected  { background: var(--cw-surface-active); box-shadow: inset 0 0 0 2px var(--cw-accent); }
  }
}
```
Show each state twice: a real interactive control **and** a `.is-*` frozen copy labelled with its state name, so the book proves the state visually on a static page.

### Anti-Patterns to Avoid
- **Cross-file SVG sprite (`<use href="icons.svg#id">`):** CORS-blocked under Chromium `file://` — the single most likely BOOK-01 failure. Inline the symbol or use `<img>`.
- **`fetch()` to load `tokens.json` or partials at runtime:** blocked under `file://`. Author content into the HTML.
- **External `<script type="module" src>` / ES `import`:** module scripts are fetched with CORS → blocked. Use one classic inline `<script>`.
- **Re-declaring `--cw-*` values in the book:** forks the SSOT and re-introduces the Phase-81 drift the whole milestone was built to eliminate. Link `tokens.css`; read, never redefine.
- **`filter: invert()` for dark mode:** explicitly forbidden by the token design (D-02/TOKEN-05); dark values are hand-authored in `tokens.css`. Toggle `data-theme`, don't invert.
- **Baking a rectangular background cage behind the logomark:** the user explicitly dislikes forced rectangular BGs on the mark (`brand-book-pressure-test.md`). Present marks on open field; the inverse mark must read with no backdrop.
- **`@font-face` web-font bloat:** adds binary weight the brief warns against; the token font stacks already fall back gracefully to system fonts.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Design tokens | A new color/space/type scale | Linked `brandbook/tokens/tokens.css` (`--cw-*`) | Already reconciled + locked in Phase 81; forking re-creates drift |
| Theme values | Dark-mode `filter: invert()` or JS recolor | `[data-theme]` blocks already in `tokens.css` | Hand-authored dark hexes exist (`tokens.css:144-234`) |
| Logo assets | New/traced SVGs | The 6 shipped `assets/logo/*.svg` | Ratified Keystone family (Phase 83); mono variants already `currentColor` |
| Brand voice/microcopy | Newly-invented examples | `prompts/chimeway-brand-book.md` §9/§10/§11/§25/§26/§34 | The canonical, user-authored voice — full good/bad pairs already written |
| Status colors | New status hexes | `--cw-status-{success,warning,danger,info,neutral}-{text,surface,border}` triads | Shipped triads; pill mapping documented at `prompts:669-679` |
| WCAG contrast check | A color-math library (chroma.js, etc.) | ~15 lines of inline JS (formula below) | Zero-dependency requirement; the sRGB→luminance→ratio formula is small and stable |
| Contrast reference values | Hard-coded ratios | Compute live from `getComputedStyle(root).getPropertyValue('--cw-*')` | Stays correct if a token changes; proves the matrix is live (BOOK-03) |

**Key insight:** For this phase, "hand-rolling" mostly means *re-authoring inputs that already exist elsewhere in the repo*. The single highest-leverage move is to treat `tokens.css`, the logo family, and `prompts/chimeway-brand-book.md` as read-only sources and assemble, not re-create.

## Runtime State Inventory

> This is a greenfield authoring phase (new HTML/CSS under `brandbook/`), not a rename/refactor/migration. No stored data, live-service config, OS-registered state, secrets, or build artifacts embed a string this phase changes. **None — verified:** the phase adds files under `brandbook/` and one `scripts/*-guards.sh`; it mutates no existing runtime state. Section retained for completeness; no migration tasks arise from it.

## Common Pitfalls

### Pitfall 1: `file://` breaks silently, not loudly
**What goes wrong:** A cross-file `<use href="sprite.svg#id">`, a `fetch('tokens.json')`, or an external module renders as *nothing* (blank/missing icon) with only a console CORS error — the page still "opens," so a superficial check passes.
**Why it happens:** `file://` origins are opaque; Chromium refuses cross-file loads for these APIs while allowing `<link>`/`<img>`/`background-image`.
**How to avoid:** Ban the three patterns by grep in `brandbook-guards.sh` (see Validation Architecture). Open the finished file via a real `file://` path in headless Chrome, not just a dev server (a server would hide the bug).
**Warning signs:** Icon/logo missing only when opened from disk; works when served over `http://`.

### Pitfall 2: `@scope` proximity/specificity surprises + older-browser tail
**What goes wrong:** `@scope` uses *proximity* in the cascade, and older browsers ignore the at-rule entirely, so scoped rules silently don't apply on the long tail.
**Why it happens:** `@scope` only reached Baseline in late 2025; cascade proximity differs subtly across engines.
**How to avoid:** Pair every scoped rule set with a plain `.cw-brandbook <sel>` descendant fallback in the same layer; keep the book usable (if less isolated) where `@scope` is absent. Don't rely on proximity for correctness.
**Warning signs:** Styles apply in current Chrome but vanish in an older engine; a nested demo picks up an outer rule unexpectedly.

### Pitfall 3: `<img src="mark-mono.svg">` won't theme
**What goes wrong:** The mono logo is `fill="currentColor"`; loaded via `<img>` it resolves `currentColor` against the SVG's own context (renders near-black), ignoring the page theme — so the "mono on dark" demo looks wrong.
**Why it happens:** `<img>` isolates the SVG from the host document's CSS `color`.
**How to avoid:** Inline the mono/inverse/themeable marks as `<svg>` in the markup so `currentColor` inherits `color: var(--cw-fg)` (or `--cw-accent`). Reserve `<img>` for the fixed-color primary lockups and raster previews.
**Warning signs:** Mono mark stays dark in dark theme.

### Pitfall 4: Inlined SVG drifts from the shipped asset file
**What goes wrong:** Copy-pasting logo SVG markup inline duplicates the Phase-83 asset; a later asset fix leaves the book stale.
**Why it happens:** Inline is required for theming but breaks the single-source link.
**How to avoid:** Add a parity check to the guard script (grep the inline `<path d=...>` or a hash against `assets/logo/*.svg`), or keep inline SVGs to the smallest marks and `<img>` the rest. Document the inline copies as intentional.
**Warning signs:** Book mark and `assets/logo/` mark differ after an asset edit.

### Pitfall 5: Contrast matrix using the wrong luminance formula
**What goes wrong:** Naive `(r+g+b)/3` "brightness" gives wrong pass/fail; the book then certifies inaccessible pairs.
**Why it happens:** WCAG contrast needs sRGB linearization + weighted relative luminance, not average brightness.
**How to avoid:** Use the exact WCAG relative-luminance formula (Code Examples below). Cross-check a couple of known pairs (e.g. `--cw-ink` on `--cw-paper` should be very high; `--cw-brass` on `--cw-paper` should FAIL body text — consistent with the brand rule "never brass text on paper for body," `prompts:661`).
**Warning signs:** Brass-on-paper shows as passing; ink-on-paper shows a middling ratio.

## Code Examples

### Live theme toggle (light / dark / system), inline JS
```html
<!-- Source: standard prefers-color-scheme pattern; tokens.css already defines
     [data-theme="light"], [data-theme="dark"], and @media(prefers-color-scheme:dark) -->
<script>
  (function () {
    const root = document.documentElement;          // tokens target :root
    function apply(mode) {
      if (mode === 'system') root.removeAttribute('data-theme'); // fall back to @media
      else root.setAttribute('data-theme', mode);   // 'light' | 'dark'
    }
    document.querySelectorAll('[data-cwb-theme]').forEach(btn =>
      btn.addEventListener('click', () => apply(btn.dataset.cwbTheme)));
    apply('system');                                 // start in system
  })();
</script>
```
For "system", removing `data-theme` lets `@media (prefers-color-scheme: dark)` in `tokens.css` govern — no JS media query needed, though the matrix below should re-run on `matchMedia('(prefers-color-scheme: dark)').addEventListener('change', ...)`.

### Live WCAG contrast matrix, inline JS (no library)
```js
// Source: WCAG 2.x relative luminance + contrast ratio
// [CITED: w3.org/TR/WCAG21 relative luminance; corroborated via web search]
function _lin(c){ c/=255; return c <= 0.03928 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4); }
function luminance([r,g,b]){ return 0.2126*_lin(r) + 0.7152*_lin(g) + 0.0722*_lin(b); }
function ratio(fg, bg){ const L1=luminance(fg), L2=luminance(bg);
  const hi=Math.max(L1,L2), lo=Math.min(L1,L2); return (hi+0.05)/(lo+0.05); }

// Resolve a --cw-* token to an [r,g,b] by painting it and reading back a computed color,
// so var() aliases and theme overrides resolve correctly under the current [data-theme].
function tokenRGB(varName){
  const probe = document.createElement('span');
  probe.style.color = `var(${varName})`; probe.style.display='none';
  document.querySelector('.cw-brandbook').appendChild(probe);
  const m = getComputedStyle(probe).color.match(/\d+/g).map(Number);
  probe.remove(); return [m[0], m[1], m[2]];
}
// AA: >=4.5 normal text, >=3 large text/UI. Render a badge per fg×bg cell; re-run on theme change.
```
Using a painted probe + `getComputedStyle` (rather than string-parsing hex) means the matrix automatically reflects `var()` aliases (e.g. `--cw-accent → --cw-teal`) and the active theme — proving it is *live* (BOOK-03), and correctly recomputes when `data-theme` flips.

### Pure-CSS skeleton / loading shimmer (STATE-01, no JS)
```css
@scope (.cw-brandbook) {
  .cwb-skeleton {
    background: linear-gradient(90deg,
      var(--cw-control-disabled-bg) 25%, var(--cw-surface-hover) 37%, var(--cw-control-disabled-bg) 63%);
    background-size: 400% 100%;
    border-radius: var(--cw-radius-sm);
    animation: cwb-shimmer 1.4s ease-in-out infinite;
  }
  @keyframes cwb-shimmer { 0%{background-position:100% 0} 100%{background-position:-100% 0} }
  @media (prefers-reduced-motion: reduce){ .cwb-skeleton{ animation: none } } /* a11y — Phase 86 gate */
}
```

## State of the Art

| Old Approach | Current Approach (2026) | When Changed | Impact |
|--------------|-------------------------|--------------|--------|
| BEM/utility-class isolation, hope-based | `@layer` + `@scope` native isolation | `@scope` Baseline late 2025 | Real style-leak protection with no JS/build; still keep a descendant fallback |
| SVG sprite `<use href="sprite.svg#id">` | Inline `<svg>` / per-icon `<img>` | Long-standing under `file://`; unchanged | Cross-file `<use>` never works from disk in Chromium — inline instead |
| chroma.js / color libs for contrast | ~15-line inline WCAG formula | — | Zero dependency; smaller than the import statement |
| Web-font `@font-face` payloads | System-font-first stacks (Inter/Plex/Source Serif with fallbacks) | — | No binary bloat; graceful degradation; already encoded in tokens |

**Deprecated/outdated for this phase:**
- Any `fetch`/XHR/module-based dynamic loading — incompatible with `file://` and the no-build rule.
- `filter: invert()` dark mode — forbidden by the token contract.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The error-template name is authored fresh this phase (VOICE-02 says "named … template" but the source prompt gives the *shape* — "say what happened and why", `prompts:265-275` — not a fixed name). | §6 / VOICE-02 | Low — planner/user picks the exact template name (e.g. "The Chimeway error triad"); content is settled, only the label is open |
| A2 | Single-file `index.html` + two linked stylesheets is acceptable as "no build step" (linked CSS is `file://`-safe). If the user wants a *literally* single self-contained file, inline the CSS. | §1 / BOOK-01 | Low — both satisfy BOOK-01; inlining is a mechanical change if preferred |
| A3 | Component-state *visual* mapping (which token drives loading/error/empty/selected surfaces) is inferred from the semantic/status tokens; `tokens.css` has explicit hover/active/disabled but no dedicated "empty/loading" tokens. | §3 / STATE-01 | Medium — "empty" and "loading" states compose existing tokens (muted fg + disabled bg); if a reviewer expects bespoke tokens, that's a Phase-81 change, out of scope here |
| A4 | Source Serif 4 is available in the font stack but not shipped as a web font (system fallback). | Stack | Low — matches the no-bloat rule; display font is "optional/sparingly" per `prompts:709-711` |

**These four are the only open items.** All are low/medium risk and resolvable at plan or discuss time; none blocks planning.

## Open Questions

1. **Exact name for the reusable error template (VOICE-02).**
   - What we know: the required *structure* is "what happened / why it matters / how to fix," grounded in voice principle §2 (`prompts:265-275`) and the good/bad error examples (`prompts:1371-1379`).
   - What's unclear: whether the user wants a specific branded name for it.
   - Recommendation: propose a plain descriptive name ("Chimeway error message pattern: what happened → why it matters → how to fix") and let the planner/user rename if desired. Not a blocker.

2. **Inline-vs-`<img>` policy for logos, and drift control.**
   - What we know: theming needs inline; DRY favors `<img>`.
   - What's unclear: appetite for a parity guard vs. accepting a documented inline copy.
   - Recommendation: inline only the marks that must theme (mono/inverse/primary-on-both-themes); `<img>` everything else; add a lightweight grep parity check to the guard. Decide at plan time.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| A Chromium browser (manual open) | BOOK-01 acceptance (`file://` render) | Assumed (dev machine) | — | Any Chromium/Safari/Firefox; Chromium is the strict target |
| `xmllint` | Optional SVG/HTML well-formedness in guard | Optional | — | Guard SKIPs the check when absent (house pattern, `logo-guards.sh:186`) |
| Headless Chrome (`scripts/render-svg-png.sh` exists) | Optional automated `file://` render/screenshot check | Present in repo tooling | — | Manual open if headless unavailable |
| Node / npm / build tools | — | **Not required** | — | N/A — no build step by design |

**Missing dependencies with no fallback:** none. The artifact is designed to require nothing but a browser.
**Missing dependencies with fallback:** `xmllint` (guard skips), headless Chrome (manual open).

## Validation Architecture

> `nyquist_validation: true` in config → this section is required. There is no JS/Elixir test framework covering static brand HTML; the house pattern (Phases 81/83) is a **dependency-free shell guard** (`scripts/*-guards.sh`, grep/sed/awk/git + optional `xmllint`) plus a manual/headless `file://` render. `[VERIFIED: scripts/logo-guards.sh]`

### Test "Framework"
| Property | Value |
|----------|-------|
| Framework | Shell guard script (house pattern), not a unit-test runner |
| Config file | none — self-contained `scripts/brandbook-guards.sh` (mirror `logo-guards.sh`) |
| Quick run command | `bash scripts/brandbook-guards.sh` |
| Full suite command | `bash scripts/brandbook-guards.sh && bash scripts/logo-guards.sh --assets && bash scripts/logo-guards.sh --scope` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BOOK-01 | No `fetch(`, no XHR, no `type="module"`, no cross-file `<use href="*.svg#` | grep-negative | `! grep -Eq 'fetch\(|XMLHttpRequest\|type=[\"'\'']module\|<use[^>]+href=[\"'\'']([^\"'\''#]+)\.svg#' brandbook/index.html` | ❌ Wave 0 |
| BOOK-01 | All asset refs are relative (no `http(s)://`, no leading `/`) | grep-negative | `! grep -Eq 'src=[\"'\'']https?://\|href=[\"'\'']/[^>]' brandbook/index.html` | ❌ Wave 0 |
| BOOK-01 | Opens + renders under real `file://` (logos visible) | manual / headless | open `file://…/brandbook/index.html` in Chrome; optional `render-svg-png.sh` screenshot | ❌ Wave 0 (manual) |
| BOOK-02 | Book CSS scoped: `@layer` + `@scope` present, `.cw-brandbook` root used, demo classes are `.cwb-*` | grep-positive | `grep -q '@scope' brandbook/brandbook.css && grep -q '@layer' brandbook/brandbook.css && grep -q 'cw-brandbook' brandbook/index.html` | ❌ Wave 0 |
| BOOK-02 | No un-prefixed leaky selectors at top level (every rule under a layer/scope or `.cwb-`/`.cw-brandbook`) | grep-audit | custom awk over `brandbook.css` asserting no bare element selectors outside `@scope` | ❌ Wave 0 |
| BOOK-03 | Nine component states each present | grep-positive | `for s in hover focus active disabled loading error empty skeleton selected; do grep -q "is-$s" brandbook/index.html; done` | ❌ Wave 0 |
| BOOK-03 | Theme toggle + live contrast matrix present | grep-positive | `grep -q 'data-cwb-theme' … && grep -q 'luminance' brandbook/index.html` | ❌ Wave 0 |
| STATE-02 | Do/don't pairs present (logo/color/spacing) | grep-positive | `grep -qi 'do' … && grep -qi "don" …` (assert paired blocks) | ❌ Wave 0 |
| VOICE-01/02/03 | Voice-by-context, error template, naming rule present | grep-positive | grep for the section anchors (`docs`,`errors`,`marketing`,`cli`, `what happened`, `Chimeway` vs `chimeway`) | ❌ Wave 0 |
| — | HTML well-formed | optional | `xmllint --noout brandbook/index.html` (SKIP if absent) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `bash scripts/brandbook-guards.sh` (fast grep gate).
- **Per wave merge:** full suite (`brandbook-guards.sh` + `logo-guards.sh --assets --scope`).
- **Phase gate:** full suite green + one manual/headless `file://` open confirming logos render and the theme toggle + contrast matrix work, before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `scripts/brandbook-guards.sh` — the `file://`-safety + scope-leak + section-presence grep gate (model on `scripts/logo-guards.sh`; dependency-free; `xmllint` optional/SKIP).
- [ ] (optional) a headless `file://` render check reusing `scripts/render-svg-png.sh` to screenshot the opened book for the perceptual gate.
- [ ] No framework install needed — pure shell.

## Security Domain

> Config has no explicit `security_enforcement` key (absent = enabled). This is a **static, zero-backend, zero-dependency** artifact, so most categories are structurally N/A; the relevant ones are noted.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface — static file |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | No server |
| V5 Input Validation | no | No user input is processed; the inline JS reads only same-document token values (`getComputedStyle`), never user or network data |
| V6 Cryptography | no | None used |
| V14 Config / Supply Chain | yes | **Zero third-party runtime code** — no CDN `<script>`, no npm deps. This is the primary security property and worth stating in the book: nothing to slopsquat, nothing to CSP-exempt. |

### Known Threat Patterns for a static brand book
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Injected 3rd-party script via CDN | Tampering | None used — inline classic script only; guard bans external `<script src>` |
| `file://` local-file exfiltration via `fetch` | Info disclosure | `fetch`/XHR banned by guard AND blocked by the platform under `file://` |
| Stored XSS via rendered user content | Injection | N/A — all content is author-static; no user/network data is interpolated into the DOM |

**Net:** the only meaningful security posture item is the *absence* of dependencies and dynamic loading — enforce it with the `brandbook-guards.sh` negative greps so a future edit can't silently add a CDN script or a `fetch`.

## Sources

### Primary (HIGH confidence)
- `brandbook/tokens/tokens.css` (read in full) — the exact `--cw-*` token names/values + theme blocks this book consumes.
- `brandbook/assets/logo/*.svg` (inspected) — self-contained inline-path SVGs; `chimeway-mark-mono.svg` / `chimeway-logotype-mono.svg` use `fill="currentColor"`.
- `prompts/chimeway-brand-book.md` (§9 voice principles :251-311, §10 vocabulary :313-381, §11 naming :382-450, §13 logo do/don't :561-582, §14 color rules + status pills :655-679, §15 typography :681-714, §25 voice examples :1349-1409, §26 claims :1411-1445, §34 do/don't :1781-1808) — the canonical brand-voice/content source.
- `notes/decision-log.md` (Logo Direction Ratification :121-199; INTEG-03 boundary :160-184) — locks the shipped asset family + the Phase-85 wiring boundary.
- `scripts/logo-guards.sh` (inspected) — the house dependency-free validation pattern to mirror.
- `.planning/ROADMAP.md:131-148` + `.planning/REQUIREMENTS.md:31-44` — phase Success Criteria + requirement text.

### Secondary (MEDIUM confidence)
- CSS `@scope` Baseline status — Frontend Masters, web-standards.dev, web.dev (multiple corroborating sources): Baseline Newly Available late 2025 (Firefox 146 / Safari 26.2). `[CITED]`
- Chromium `file://` CORS for SVG `<use>`/fetch — chromium bug 470601, CSS-Tricks, O'Reilly "Understanding CORS and SVG": cross-file blocked, Firefox more permissive. `[CITED]`
- WCAG relative-luminance / contrast-ratio formula — W3C WCAG 2.x. `[CITED]`

### Tertiary (LOW confidence)
- None relied upon. Web-search findings were cross-corroborated before use.

## Metadata

**Confidence breakdown:**
- Standard stack (no-deps web platform): HIGH — inputs are locked files in-repo; platform behaviors corroborated across authoritative sources.
- Architecture (single-file, linked tokens, scoped CSS, inline JS): HIGH — directly satisfies BOOK-01/02/03 with established patterns.
- Pitfalls: HIGH — the `file://` and `@scope` gotchas are documented platform facts, not speculation.
- Content (voice/microcopy/do-don't): HIGH — a complete canonical source already exists (`prompts/chimeway-brand-book.md`); this phase transcribes into HTML.

**Research date:** 2026-07-18
**Valid until:** 2026-08-17 (stable — web-platform facts + in-repo locked inputs; the only moving piece is browser-version Baseline creep, which only widens support).
