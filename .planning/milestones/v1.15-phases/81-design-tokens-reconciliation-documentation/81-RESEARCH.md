# Phase 81: Design Tokens (Reconciliation & Documentation) - Research

**Researched:** 2026-07-09
**Domain:** CSS custom-property token architecture + DTCG (Design Tokens Community Group) hand-authoring + light/dark theming reconciliation
**Confidence:** HIGH (inventory is verbatim from the repo; DTCG shapes verified against the 2025.10 spec)

## Summary

Phase 81 is a **reconciliation-and-documentation** phase, not a design phase. Every decision (D-01..D-12) is already locked in CONTEXT.md, so this research delivers the *concrete, verifiable inputs* the planner needs: (1) an exact line-numbered inventory of every `--cw-*` token in the shipped `chimeway_admin/priv/static/chimeway_admin.css`, split into "copy verbatim" vs "generalize (de-scope the `--cw-admin-*` alias layer)" vs "net-new (flag)"; (2) the exact DTCG 2025.10 `$type`/`$value` shapes for hand-authoring `tokens.json` — verified against the first stable spec, including the material fact that `dimension` and `duration` now use `{value, unit}` **objects**, not strings; (3) the precise spec-vs-shipped divergence ledger with both-side line refs; (4) a contrast-check method plus the key scoping insight that almost every dark value is a **verbatim copy of an already-shipped, already-verified value**, so the fresh-contrast burden is near-zero; and (5) a Validation Architecture built on `git diff --exit-code`, hex-equality diffing, JSON-parse + alias-resolution, and per-net-new-token contrast math.

The shipped CSS defines **88 distinct `--cw-*` names** across a theme-invariant primitive/non-color tier and a theme-shifting semantic/alias tier. Primitives never change across themes; only the `--cw-admin-*` alias layer, the generic control/surface layer, and the `--cw-status-*` triads remap in dark. The brandbook mirrors this structure minus the `.chimeway-admin` scope and minus the `@layer cw.tokens`-internal scoping, publishing on global `:root` (D-01).

**Primary recommendation:** Treat this as a transcription-with-proof task. Copy the primitive + non-color + brand-neutral semantic tiers byte-for-byte; mechanically rename only the 12 `--cw-admin-*` aliases into 7 generalized names (D-04); add exactly one net-new color token (`--cw-info: var(--cw-blue)`) plus any documented net-new dimension tokens (border-width); log every divergence; and prove zero-drift with `git diff --exit-code`.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `tokens.css` publishes all `--cw-*` on **global `:root`** (not a wrapper class / `@scope`). Prefix is the collision guard (Shoelace, Pico, Open Props, Primer, GitLab precedent).
- **D-02:** Theming = `@media (prefers-color-scheme: dark)` system default + optional explicit `[data-theme="dark"]` / `[data-theme="light"]` root attribute override, both writing the same `--cw-*` names. Mirrors shipped triple minus `.chimeway-admin`. No `filter: invert()`.
- **D-03:** 15 primitive colors copied **verbatim** (zero drift): ink, night, paper, porcelain, line, muted, teal, blue, brass, mint, violet, success, warning, danger, code.
- **D-04:** Generalize the shipped `--cw-admin-*` alias layer into brand-neutral names: `--cw-surface-bg`, `--cw-surface-panel`, `--cw-fg`, `--cw-fg-muted`, `--cw-border`, `--cw-accent`, `--cw-focus`. `--cw-admin-*` stays only in the untouched admin CSS.
- **D-05:** Copy already-brand-neutral semantic vars verbatim (no rename): `--cw-status-*` triads, `--cw-control-*`, `--cw-surface-hover/active`, `--cw-border-strong`, `--cw-focus-halo`, `--cw-button-*`, `--cw-row-*`, `--cw-link-fg`, `--cw-table-row-hover`.
- **D-06:** Add `--cw-info: var(--cw-blue)` (#2d6cdf) — net-new primitive **aliasing** existing blue, not a new hex. Logged DOCUMENTED.
- **D-07:** Keep `--cw-danger` / `--cw-status-danger-*` verbatim; "error" (TOKEN-03 wording) is a documented role mapping to `danger`, not a rename.
- **D-08:** Two-tier primitive→semantic only. Coverage: color, type scale, spacing, radius, border, shadow, motion, focus-ring, z-index. No component tier, no 12-step scales.
- **D-09:** `tokens.json` = hand-authored DTCG (`$value`/`$type`/`$description`), no build tool. Nested groups.
- **D-10:** Semantic→primitive links use DTCG alias references (`{color.primitive.teal}`), never duplicated hex.
- **D-11:** Light/dark = two sibling semantic groups (`color.semantic.light.*` / `color.semantic.dark.*`). "system" has NO JSON representation (CSS strategy only). NOT `$extensions` blobs, NOT mode-keyed `$value`, NOT `$themes`.
- **D-12:** Record every sub-primitive divergence as DOCUMENTED or DEFERRED; prove `chimeway_admin.css` zero changes via `git diff`.

### Claude's Discretion

- Exact file-internal ordering / comment style of `tokens.css` and `tokens.json`; precise `$description` wording; which net-new tokens (border tokens, motion/z-index gaps) get fresh values vs verbatim copy — favor verbatim copy and least-surprise defaults.
- Dark values for any net-new semantic token get an independently contrast-checked value; final verification against *rendered* output happens in Phase 86 (A11Y), but each new dark value is authored with a checked ratio here.

### Deferred Ideas (OUT OF SCOPE)

- Patching sub-primitive conflicts live (radius-sm 4px, blue info triad, status-pill remapping) → ADMIN-RETHEME-01, future milestone.
- DTCG Resolver Module adoption → note in `$description`, do not build.
- Bundled webfont (BRAND-WEBFONT-01) → system stack + documented recommendation only.
- Modifying `chimeway_admin.css`; any build tool/bundler; component-token tier; 12-step per-hue scales; bundled fonts.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TOKEN-01 | `tokens.css` defines `--cw-*` with 15 primitives copied verbatim, no forked palette | Exact primitive inventory below (lines 5-19); hex-equality validation defined |
| TOKEN-02 | `tokens.json` mirrors set in hand-authored DTCG (`$value`/`$type`/`$description`), no build tool | DTCG 2025.10 `$type`/`$value` reference verified below (incl. dimension/duration object shape) |
| TOKEN-03 | Cover color (primitive + generalized semantic + status incl. info), type, spacing, radius, border, shadow, motion, focus-ring, z-index; two-tier only | Full non-color inventory + net-new border-width gap flagged |
| TOKEN-04 | Every sub-primitive divergence recorded DOCUMENTED/DEFERRED; `chimeway_admin.css` unmodified | Divergence ledger with both-side line refs; `git diff --exit-code` proof |
| TOKEN-05 | Light/dark/system theming; each new semantic token has independently contrast-checked dark value; no `filter: invert()` | Theming block structure + contrast-check method + net-new scoping insight below |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Canonical color/dimension token values | Static asset (`tokens.css` on `:root`) | `tokens.json` (DTCG mirror) | CSS is the runtime consumption surface; JSON is the tool-portable mirror — both hand-authored, kept in sync by hand |
| Light/dark/system theme resolution | Browser / CSS cascade | — | `@media (prefers-color-scheme)` + `[data-theme]` attribute resolve entirely in CSS; no JS, no build |
| Divergence / decision provenance | Documentation (`notes/decision-log.md`) | — | Sub-primitive conflicts are recorded, not resolved this phase |
| Zero-drift enforcement | Git (diff/CI-adjacent check) | — | `git diff --exit-code chimeway_admin.css` + hex-equality diff prove the invariant |

**All tiers are static/authoring tiers.** There is no runtime code, no server, no client JS, no data layer, and no external service in this phase. This is a doc/asset authoring phase.

## Standard Stack

No packages are installed. This phase authors plain `.css`, `.json`, and `.md` files with zero build tooling (locked by D-09 and the Out-of-Scope table: no Vite/Webpack/Tailwind/PostCSS/Style Dictionary). Therefore:

- **No `## Package Legitimacy Audit` needed** — zero external packages. `[VERIFIED: REQUIREMENTS.md Out-of-Scope table]`
- **No `## Standard Stack` table needed** — the "stack" is the platform: CSS custom properties + the DTCG 2025.10 JSON format.

### Format specifications used (authoritative)

| Spec | Version | Purpose | Source |
|------|---------|---------|--------|
| Design Tokens Format Module | 2025.10 (first stable, 2025-10-28) | `tokens.json` hand-authoring shape | `[CITED: designtokens.org/tr/drafts/format/]` |
| CSS Custom Properties + `@media (prefers-color-scheme)` + `[data-*]` attribute selectors | CSS baseline | `tokens.css` theming | `[VERIFIED: shipped chimeway_admin.css:176]` |

## Exact Shipped-Token Inventory

> Source file: `chimeway_admin/priv/static/chimeway_admin.css` (1020 lines total). The token layer is `@layer cw.tokens` (lines 3-222). All line refs below are into this file. `[VERIFIED: read chimeway_admin.css]`
> Note: the `assets/css/chimeway_admin.css` copy merely `@import`s `../../priv/static/chimeway_admin.css` — the `priv/static` file is authoritative. `[VERIFIED: read assets/css/chimeway_admin.css]`

### 1. The 15 primitive colors (lines 5-19) — copy VERBATIM (D-03, TOKEN-01)

| Token | Hex | Brand-book use (chimeway-brand-book.md:605-619) |
|-------|-----|-------------------------------------------------|
| `--cw-ink` | `#102027` | Primary text, headings, logo on light |
| `--cw-night` | `#07131a` | Dark backgrounds, code frames, hero |
| `--cw-paper` | `#fffdf8` | Main page background |
| `--cw-porcelain` | `#f7f4ea` | Secondary background, docs panels |
| `--cw-line` | `#d8d3c7` | Borders, dividers |
| `--cw-muted` | `#5e6b72` | Secondary text on light |
| `--cw-teal` | `#0e7c86` | Primary action, links, route lines |
| `--cw-blue` | `#2d6cdf` | Interactive secondary, info states |
| `--cw-brass` | `#d6a84f` | Brand accent, highlights |
| `--cw-mint` | `#9adbcf` | Soft accent, diagrams, fills |
| `--cw-violet` | `#6d5df6` | Trace/debug accents, timeline highlights |
| `--cw-success` | `#0b7a50` | Success states |
| `--cw-warning` | `#8a5a00` | Warning states |
| `--cw-danger` | `#b83232` | Error/failure states |
| `--cw-code` | `#0b1720` | Code block background |

**Zero-drift note:** the brand book CSS block (lines 623-639) lists the identical 15 hexes (uppercase in the book, lowercase in shipped — a case-only difference; normalize to shipped lowercase and the values are byte-equal). Confirmed 15 primitives via `grep -c`. `[VERIFIED: read both files]`

### 2. Non-color tokens (lines 21-49) — copy VERBATIM (D-08, TOKEN-03)

| Family | Tokens (name → value) | DTCG `$type` |
|--------|------------------------|--------------|
| Spacing (line 21-27) | `--cw-space-xs:4px` · `-sm:8px` · `-md:16px` · `-lg:24px` · `-xl:32px` · `-2xl:48px` · `-3xl:64px` | `dimension` |
| Font family (28-29) | `--cw-font-family-sans: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif` · `--cw-font-family-mono: "IBM Plex Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace` | `fontFamily` |
| Font size (30-33) | `--cw-font-size-label:14px` · `-body:16px` · `-heading:20px` · `-display:28px` | `dimension` |
| Line height (34-37) | `--cw-line-height-label:1.35` · `-body:1.5` · `-heading:1.2` · `-display:1.15` | `number` |
| Font weight (38-39) | `--cw-font-weight-regular:400` · `-semibold:600` | `fontWeight` |
| Radius (40-42) | `--cw-radius-sm:5px` · `-md:8px` · `-pill:999px` | `dimension` |
| Shadow (43) | `--cw-shadow-panel: 0 16px 42px rgb(16 32 39 / 0.08)` | `shadow` |
| Focus (44-45) | `--cw-focus-ring: var(--cw-blue)` · `--cw-focus-offset:3px` | `color` / `dimension` |
| Z-index (46-47) | `--cw-z-sidebar:10` · `--cw-z-focus:50` | `number` |
| Motion (48-49) | `--cw-motion-fast: 120ms ease-out` · `--cw-motion-pressed: 80ms ease-out` | see note ↓ |

**Motion note (authoring gotcha):** the shipped motion values are CSS **transition shorthands** (`120ms ease-out`), not pure durations. DTCG has no "transition-shorthand" scalar. For `tokens.json`, split each into a `duration` token (`{value:120,unit:"ms"}`) and reference a shared easing. The shipped easing keyword `ease-out` maps to cubic-bezier `(0, 0, 0.58, 1)`; author it as a `cubicBezier` token `[0, 0, 0.58, 1]` **or** keep a `$description` noting the CSS keyword. Record the split as a DOCUMENTED net-new-representation decision (the CSS keeps the shorthand verbatim; only the JSON decomposes it). `[VERIFIED: shipped values]` + `[ASSUMED: ease-out ≈ (0,0,0.58,1)]`

### 3. Brand-neutral semantic vars — copy VERBATIM (D-05)

**Status triads (lines 51-65), light values:**

| Group | text / surface / border |
|-------|--------------------------|
| success | `#0b6b47` / `#e8f6ef` / `#9fd8bf` |
| warning | `#765000` / `#fff2cf` / `#e5c36d` |
| danger | `#9f2424` / `#fdecec` / `#eda3a3` |
| info | `#0e5f67` / `#e8f6f5` / `#94d4d7` *(teal-hued — see divergence ledger)* |
| neutral | `#425158` / `#f1eee4` / `#d8d3c7` |

**Generic control/surface layer (lines 80-96), light values — copy verbatim:**

`--cw-surface-hover:#eef8f7` · `--cw-surface-active:#dff1ef` · `--cw-control-bg:#ffffff` · `--cw-control-hover:#f7f4ea` · `--cw-control-active:#eef8f7` · `--cw-control-disabled-bg:#eee9dc` · `--cw-control-disabled-fg:#68757b` · `--cw-border-strong:#a9bebf` · `--cw-focus-halo:#dbe9ff` · `--cw-button-primary-bg:#0e7c86` · `--cw-button-primary-fg:#ffffff` · `--cw-button-danger-bg:#b83232` · `--cw-button-danger-fg:#ffffff` · `--cw-table-row-hover:#f4faf9` · `--cw-row-bg:#f7f4ea` · `--cw-row-hover:#eef8f7` · `--cw-link-fg:#0e5f67`

### 4. The `--cw-admin-*` alias layer (lines 67-78) → GENERALIZE (D-04)

The admin alias layer is a pure re-pointing tier. Generalize the color-bearing aliases into brand-neutral names; the `--cw-admin-*` names remain **only** in the untouched admin CSS.

| Shipped `--cw-admin-*` (light, line) | Points to | Brandbook generalized name (D-04) |
|--------------------------------------|-----------|-----------------------------------|
| `--cw-admin-bg` (67) | `var(--cw-paper)` | `--cw-surface-bg` |
| `--cw-admin-panel` (68) | `#ffffff` | `--cw-surface-panel` |
| `--cw-admin-panel-soft` (69) | `var(--cw-porcelain)` | `--cw-surface-panel-soft` *(optional — keep if used; verbatim value)* |
| `--cw-admin-fg` (70) | `var(--cw-ink)` | `--cw-fg` |
| `--cw-admin-muted` (71) | `var(--cw-muted)` | `--cw-fg-muted` |
| `--cw-admin-border` (72) | `var(--cw-line)` | `--cw-border` |
| `--cw-admin-accent` (73) | `var(--cw-teal)` | `--cw-accent` |
| `--cw-admin-focus` (74) | `var(--cw-focus-ring)` | `--cw-focus` |
| `--cw-admin-shadow` (75) | `var(--cw-shadow-panel)` | *(covered by `--cw-shadow-panel`; no new name needed)* |
| `--cw-admin-radius` (76) | `var(--cw-radius-md)` | *(covered by `--cw-radius-md`)* |
| `--cw-admin-radius-sm` (77) | `var(--cw-radius-sm)` | *(covered by `--cw-radius-sm`)* |
| `--cw-admin-transition` (78) | `var(--cw-motion-fast)` | *(covered by `--cw-motion-fast`)* |

**The 7 D-04 generalized color aliases** map to `surface-bg`, `surface-panel`, `fg`, `fg-muted`, `border`, `accent`, `focus` (the last four rows above are non-color pass-throughs already exposed under their primitive/scalar names).

### 5. Theming block structure to mirror (minus `.chimeway-admin` scope)

The shipped file uses a **theme-invariant primitive tier + theme-shifting semantic tier**. Primitives (lines 5-49) and status/control layers are declared once in the base block; only the alias layer + control/surface + status triads are re-declared per theme.

| Shipped block | Lines | Brandbook mirror |
|---------------|-------|------------------|
| `@layer cw.tokens { :where(.chimeway-admin) { … color-scheme: light } }` (base = light) | 3-99 | `:root { … color-scheme: light }` — all primitives + non-color + generalized-light semantics |
| `:where(.chimeway-admin[data-cw-theme="light"]) { … }` (explicit light override, restates light values) | 101-129 | `[data-theme="light"] { … }` — same light semantic values (explicit override contract, D-02) |
| `:where(.chimeway-admin[data-cw-theme="dark"]) { … color-scheme: dark }` | 131-174 | `[data-theme="dark"] { … color-scheme: dark }` — dark semantic overrides |
| `@media (prefers-color-scheme: dark) { :where(.chimeway-admin[data-cw-theme="system"]) { … } }` | 176-221 | `@media (prefers-color-scheme: dark) { :root { … } }` — same dark overrides as system default (D-02) |

**Dark generalized-semantic values (from shipped dark admin block, lines 132-140) — these are the D-04 dark values, copied verbatim:**

| Generalized name | Dark value | Shipped source |
|------------------|-----------|----------------|
| `--cw-surface-bg` | `var(--cw-night)` (#07131a) | `--cw-admin-bg` (132) |
| `--cw-surface-panel` | `#10232c` | `--cw-admin-panel` (133) |
| `--cw-surface-panel-soft` | `#0b1b23` | `--cw-admin-panel-soft` (134) |
| `--cw-fg` | `#fffdf8` | `--cw-admin-fg` (135) |
| `--cw-fg-muted` | `#b8c5c9` | `--cw-admin-muted` (136) |
| `--cw-border` | `#29414a` | `--cw-admin-border` (137) |
| `--cw-accent` | `var(--cw-mint)` (#9adbcf) | `--cw-admin-accent` (138) |
| `--cw-focus` | `var(--cw-brass)` (#d6a84f) | `--cw-admin-focus` (139) |

**Dark status triads (lines 158-172) and dark control/surface layer (lines 141-157) — copy verbatim.** Full dark status set: success `#b7f0d7/#0d2f24/#2d7a5d` · warning `#ffe0a0/#33260b/#8a6824` · danger `#ffd4d4/#3a1717/#984747` · info `#b8eee8/#0d3035/#397b83` · neutral `#d5dee1/#142832/#4b6972`.

**Critical structural insight:** the dark `[data-cw-theme="dark"]` block (131-174) and the `@media (prefers-color-scheme:dark)` system block (176-221) contain **byte-identical override lists**. The brandbook can DRY this by pointing both at one shared declaration, but the shipped file duplicates them — mirror whichever is cleaner (D-02 gives the same-names contract either way).

## DTCG Hand-Authoring Reference (verified against 2025.10)

> The first stable Design Tokens Format Module was published 2025-10-28. Verified shapes: `[CITED: designtokens.org/tr/drafts/format/]`

| `$type` string | `$value` shape | Notes for our tokens |
|----------------|----------------|----------------------|
| `color` | object (Color module) — hex string still accepted as legacy scalar `"#102027"` | Primitives + status triads |
| `dimension` | **object** `{ "value": <number>, "unit": "px" \| "rem" }` — **NOT a bare string** | space, font-size, radius, focus-offset, border-width |
| `fontFamily` | string **or** array of strings | sans/mono stacks (author as array) |
| `fontWeight` | number 1–1000 **or** keyword string (`"bold"`) | 400 / 600 |
| `duration` | **object** `{ "value": <number>, "unit": "ms" \| "s" }` | motion (decomposed from shorthand) |
| `cubicBezier` | array `[P1x, P1y, P2x, P2y]` | easing (`ease-out` → `[0,0,0.58,1]`) |
| `number` | JSON number | line-height, z-index |
| `shadow` | object (or array of objects) `{ color, offsetX, offsetY, blur, spread }` | `--cw-shadow-panel` |
| `border` | object `{ color, width, style }` | only if a composite border token is authored |
| `typography` | object `{ fontFamily, fontSize, fontWeight, lineHeight }` | not required (two-tier, D-08) — skip |

**Alias/reference syntax:** `{ "$value": "{color.primitive.teal}" }` — curly-brace path resolves to the target token's `$value` (D-10). `[CITED: format spec — References]`

**Inheritance:** both `$type` and `$description` are **inheritable from the closest parent group** — set `$type` once on a group (e.g. `color.primitive`) instead of on every token. `[CITED: format spec — Inheritance]`

**D-11 light/dark shape (locked, spec-valid):** two sibling groups `color.semantic.light.*` and `color.semantic.dark.*`, each a plain token aliasing the single primitive tier. "system" = CSS-only, no JSON node. This is the only hand-authorable, diff-legible, spec-valid option (mode-keyed `$value` is spec-invalid; `$extensions` mode blobs violate the "SHOULD only hold non-crucial data" rule; `$themes`/Resolver is build-time). `[VERIFIED: CONTEXT.md D-11 + spec]`

**Authoring gotcha:** hand-authors instinctively write `"$value": "16px"`. Under 2025.10 that is **invalid** for `$type: dimension` — it must be `{ "value": 16, "unit": "px" }`. Validation must catch bare-string dimensions. `[CITED: format spec — Dimension]`

## Divergence Ledger Inputs (for `notes/decision-log.md`, TOKEN-04 / D-12)

Each entry needs both-side line refs and a DOCUMENTED/DEFERRED disposition.

| # | Divergence | Shipped side | Brand-book / intent side | Disposition |
|---|-----------|--------------|---------------------------|-------------|
| DIV-1 | `--cw-radius-sm` = **5px** vs 4px brand intent | `chimeway_admin.css:40` (`5px`) | Brand intent 4px | **DEFERRED** — keep shipped 5px verbatim (TOKEN-01 zero-drift outranks); patch is ADMIN-RETHEME-01 |
| DIV-2 | Missing `--cw-info` primitive | absent in shipped (grep confirms zero matches) | Brand book maps info→blue (`chimeway-brand-book.md:612`) | **DOCUMENTED** — add `--cw-info: var(--cw-blue)` alias (D-06), no new hex |
| DIV-3 | `--cw-status-info-*` triad is **teal-hued**, not blue | `chimeway_admin.css:60-62` (`#0e5f67/#e8f6f5/#94d4d7`) | Brand book intends info = blue `#2d6cdf` (`:612`) | **DEFERRED** — copy teal triad verbatim; blue-info reconciliation is ADMIN-RETHEME-01 |
| DIV-4 | Status-pill mapping conflicts | Shipped groups Sending under existing triads; Cancelled/Expired fold into neutral/danger/warning | Brand book: Sending→**violet** (`:674`), Cancelled→**muted/neutral outline** (`:678`), Expired→**warning outline** (`:679`) | **DOCUMENTED/DEFERRED** — no `sending`/`cancelled`/`expired` triads exist in shipped; do not invent them this phase; log the intended mapping for STATE/component phases |
| DIV-5 | Net-new **motion** representation | shorthand `120ms ease-out` / `80ms ease-out` (`:48-49`) | DTCG needs duration+easing split | **DOCUMENTED** — CSS keeps shorthand verbatim; JSON decomposes; values sourced verbatim |
| DIV-6 | Net-new **z-index** JSON tokens | `--cw-z-sidebar:10` / `--cw-z-focus:50` (`:46-47`) exist in CSS | first time expressed in DTCG | **DOCUMENTED** — verbatim copy, `$type: number` |
| DIV-7 | Net-new **border-width** token | **no** `--cw-border-width` / generic `--cw-border` dimension in shipped (grep: only `--cw-line` color, `--cw-admin-border`, `--cw-border-strong`) | TOKEN-03 lists "border" as a required family | **DOCUMENTED** — if a border-*width* dimension is added it is net-new; recommend `1px` least-surprise default, flagged net-new. `--cw-border` (D-04) is a **color** alias (→line), distinct from any width token |

**Every divergence entry MUST close with the same invariant:** `chimeway_admin.css` is unmodified — proven by `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css`. `[VERIFIED: git status --porcelain shows file clean]`

## Contrast-Check Method (TOKEN-05) + net-new scoping insight

**Key scoping finding (reduces over-scoping):** almost every dark value in the brandbook is a **verbatim copy of an already-shipped, already-in-production dark value** (lines 131-174). Verbatim copies inherit the shipped file's existing verification — for those, the correct proof is **hex-equality to the shipped source**, not fresh contrast math. Fresh WCAG contrast math is required **only** for a token that has *no shipped dark equivalent*.

Enumerating genuinely net-new color-bearing tokens:

- `--cw-info: var(--cw-blue)` — a **primitive alias**; primitives are theme-invariant (blue `#2d6cdf` in both themes). No net-new *dark* value is authored. Its downstream on-surface pairing is deferred (DIV-3).
- Generalized D-04 names (`--cw-surface-bg`, `--cw-fg`, `--cw-accent`, `--cw-focus`, …) — dark values copied verbatim from the shipped dark admin block. **Not net-new.**
- `border-width`, `z-index`, `motion` net-new tokens — **not colors**; no contrast relevance.

**Conclusion:** the realistic net-new *dark color* set requiring fresh contrast math is **essentially empty** this phase. The planner should not scope a large contrast-audit task. Instead:

1. **For verbatim dark values:** assert hex-equality to the shipped source line (proves inheritance of existing verification).
2. **For any token that does turn out net-new (e.g. if a generalized name gains a dark value with no shipped source):** compute the WCAG 2.2 contrast ratio of its foreground/background pairing at authoring time and record it. Targets: **4.5:1** normal text, **3:1** large text (SC 1.4.3); **3:1** for non-text/UI (borders, focus rings — SC 1.4.11).
3. **Method (no tooling required, matches Out-of-Scope "no axe-core/pa11y in CI"):** use the WCAG relative-luminance formula (or a browser devtools contrast picker / any offline calculator) on the resolved hex pair; record the ratio in `notes/decision-log.md` (or a stub `notes/accessibility-checks.md` fed to Phase 86). **No `filter: invert()`** — dark values are hand-authored hexes, never derived by inversion (D-02, TOKEN-05).
4. Final verification against the **rendered** brandbook is Phase 86 (A11Y-05); this phase authors checked values only.

`[VERIFIED: inventory analysis]` + `[CITED: WCAG 2.2 SC 1.4.3 / 1.4.11]`

## Recommended File Structure (greenfield — `brandbook/` and `notes/` do not yet exist)

```
brandbook/
└── tokens/
    ├── tokens.css      # :root primitives + non-color + generalized/verbatim semantics; @media dark + [data-theme]
    └── tokens.json     # hand-authored DTCG mirror (nested groups, alias refs, light/dark sibling groups)
notes/
└── decision-log.md     # DIV-1..DIV-7 ledger, each closing with the git-diff zero-drift invariant
```

`[VERIFIED: ls confirms brandbook/ and notes/ absent]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Deriving dark values | `filter: invert()` or a JS/Sass color-transform | Hand-authored hexes copied verbatim from the shipped dark block | Explicitly forbidden (TOKEN-05); inversion breaks brand hues and contrast |
| Keeping JSON↔CSS in sync | A build/transform step (Style Dictionary, PostCSS) | Hand-authored DTCG with alias refs (D-09/D-10) | Build tooling is Out-of-Scope; alias refs keep it diff-legible by hand |
| "system" theme in JSON | A `$themes` manifest / Resolver `sets` | Nothing — "system" is CSS-only (D-11) | Resolver is build-time; JSON stays two sibling groups |
| Inventing missing status triads (sending/cancelled/expired) | New hex triads to match the brand book | Log the mapping as DOCUMENTED/DEFERRED (DIV-4) | Zero-drift invariant; those triads don't exist in shipped |

**Key insight:** in a reconciliation phase, "building" anything beyond transcription + one aliased token + documented net-new scalars is a scope violation. The value is provable fidelity, not new design.

## Common Pitfalls

### Pitfall 1: Case/format normalization silently "drifts" a primitive
**What goes wrong:** copying the brand-book uppercase hexes (`#07131A`) instead of the shipped lowercase (`#07131a`), or re-ordering, making a naive string diff fail.
**How to avoid:** copy from `chimeway_admin.css` (the SSOT), not the brand book; validate with a case-insensitive hex-equality check.
**Warning signs:** hex-equality validator reports a mismatch that is case-only.

### Pitfall 2: Bare-string `dimension` in tokens.json
**What goes wrong:** authoring `"$value": "5px"` — invalid under DTCG 2025.10.
**How to avoid:** always `{ "value": 5, "unit": "px" }`; add a JSON validation step that flags string-valued dimension tokens.

### Pitfall 3: Re-scoping leaks the admin class
**What goes wrong:** copying `:where(.chimeway-admin[data-cw-theme="dark"])` selectors verbatim into the brandbook, so tokens only apply under an admin wrapper.
**How to avoid:** strip `.chimeway-admin` and `@layer cw.tokens` internal scoping; publish on bare `:root` + `[data-theme]` + `@media` (D-01/D-02).

### Pitfall 4: Duplicating raw hex in JSON semantic tokens
**What goes wrong:** writing the primitive hex again inside a semantic token instead of an alias ref, so CSS and JSON drift.
**How to avoid:** semantic tokens use `{color.primitive.*}` alias refs (D-10).

### Pitfall 5: Over-scoping contrast checks
**What goes wrong:** treating every dark value as "net-new" and running a full contrast audit (Phase 86's job).
**How to avoid:** verbatim dark values → hex-equality proof; only truly net-new color pairings → fresh ratio. (See scoping insight above.)

## Validation Architecture

> `nyquist_validation: true` in config — this section is required. Frame each item as a testable acceptance criterion the planner lifts into Dimension-8.

### Test approach

No test framework is installed and none is warranted (doc/asset phase, no runtime, no CI changes per Out-of-Scope). Validation = deterministic shell + parser checks runnable locally. All are fast (<5s) and scriptable.

### Phase Requirements → Validation Map

| Req ID | Behavior to prove | Validation type | Concrete command / method | Pass condition |
|--------|-------------------|-----------------|---------------------------|----------------|
| TOKEN-04 (zero-drift) | `chimeway_admin.css` unmodified | git | `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css` | exit 0 |
| TOKEN-01 | 15 primitives in `tokens.css` byte-equal shipped | hex-equality diff | Extract `--cw-{ink,night,…,code}` from both files, lowercase, compare | all 15 equal |
| TOKEN-01/03 | Verbatim semantic/non-color tokens match shipped | hex/value-equality diff | Grep each verbatim token from both files; compare values | all equal |
| TOKEN-02 | `tokens.json` is well-formed JSON | JSON parse | `node -e "JSON.parse(require('fs').readFileSync('brandbook/tokens/tokens.json','utf8'))"` (or `jq . tokens.json`) | parses, exit 0 |
| TOKEN-02/D-10 | Every alias ref resolves to a real token path | alias-resolution check | Walk JSON; for each `$value` matching `{a.b.c}`, assert the path exists | zero unresolved refs |
| TOKEN-02/2025.10 | No bare-string `dimension`/`duration` values | DTCG shape lint | Walk JSON; assert every `$type:dimension`/`duration` `$value` is an object with `value`+`unit` | zero violations |
| TOKEN-05 | Light/dark/system theming resolves | resolution check | Confirm `tokens.css` defines `:root` (light), `[data-theme="dark"]`, `[data-theme="light"]`, and `@media (prefers-color-scheme:dark)` blocks writing the same `--cw-*` names; no `filter: invert(` anywhere | all 4 blocks present, zero `invert(` |
| TOKEN-05 | Net-new dark color values meet WCAG 2.2 | contrast math | For each net-new color pairing (if any), compute ratio; assert ≥4.5:1 text / ≥3:1 large+UI. Verbatim values: assert hex-equality to shipped instead | ratios pass or hex-equal |
| TOKEN-04 | Every divergence recorded | doc presence | `notes/decision-log.md` contains a DOCUMENTED/DEFERRED entry for DIV-1..DIV-7, each with a `git diff` invariant line | all 7 present |
| D-06 | `--cw-info` is an alias, not a new hex | grep | `--cw-info` value is `var(--cw-blue)` (CSS) / `{color.primitive.blue}` (JSON), not a hex literal | alias form only |

### Sampling rate

- **Per task commit:** the JSON parse + hex-equality quick checks for whatever file the task touched.
- **Per phase gate (before `/gsd-verify-work`):** run the full table top-to-bottom; the `git diff --exit-code` zero-drift check is the hard gate.

### Wave 0 gaps

- [ ] `brandbook/tokens/` directory — greenfield, must be created.
- [ ] `notes/` directory — greenfield, must be created.
- [ ] No framework install needed (validation is git + `jq`/`node` one-liners, both present — see Environment Availability).

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| git | zero-drift `git diff --exit-code` proof | ✓ | repo in use | — |
| node (JSON.parse) | JSON well-formedness / alias-resolution / DTCG-shape checks | ✓ | present (gsd-tools runs on node) | `jq .` |
| Browser or offline contrast calculator | net-new dark value ratio (if any) | ✓ (manual) | — | WCAG luminance formula by hand |

No missing dependencies. No build tooling required or permitted.

## Security Domain

`security_enforcement` is not disabled, so this section is included, but the phase authors **static CSS/JSON/Markdown with no runtime, no input handling, no auth, no crypto, no network, and no CI changes**. No ASVS category applies to inert token files. The only adjacent "control" is WCAG 2.2 contrast (an accessibility concern, handled above and in Phase 86), not a security control. **No STRIDE threat surface exists in this phase.**

| ASVS Category | Applies | Rationale |
|---------------|---------|-----------|
| V5 Input Validation | no | No inputs; the JSON is authored, not received |
| V6 Cryptography | no | No secrets/crypto |
| all others | no | No auth/session/access-control/runtime surface |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ease-out` ≈ cubic-bezier `[0, 0, 0.58, 1]` for the DTCG motion decomposition | Non-color inventory / DIV-5 | Low — CSS keeps the `ease-out` keyword verbatim; only the JSON easing token is affected, and it's DOCUMENTED as a net-new representation |
| A2 | A `border-width` dimension token (if authored) should default to `1px` | DIV-7 | Low — flagged net-new + DOCUMENTED; `--cw-border` color alias is unaffected |
| A3 | The realistic net-new *dark color* set is empty (all dark values are verbatim copies) | Contrast-Check Method | Medium — if planning introduces a generalized token with a novel dark value, that one needs fresh contrast math; the method covers this case |

**All other claims are VERIFIED against the repo files or CITED from the DTCG 2025.10 spec.**

## Open Questions (RESOLVED)

1. **Does the brandbook expose `--cw-surface-panel-soft` and the shadow/radius/transition pass-throughs under generalized names, or only the 7 core D-04 aliases?**
   - What we know: D-04 lists exactly 7 generalized names; the other 5 `--cw-admin-*` rows are non-color pass-throughs already available under primitive/scalar names.
   - **RESOLVED (81-01):** Expose only the 7 generalized D-04 names; the pass-throughs are reachable directly under `--cw-shadow-panel`/`--cw-radius-md`/`--cw-motion-fast` and no `--cw-admin-*` name is emitted. Implemented in 81-01 Task 1 (step 5) with an explicit `! grep -q -- '--cw-admin-'` guard.

2. **Author the motion easing as a `cubicBezier` token or keep the CSS keyword and only emit a `duration` in JSON?**
   - **RESOLVED (81-03 / DIV-5):** Emit a `duration` token in JSON, keep the CSS `120ms ease-out` / `80ms ease-out` shorthand verbatim, and note the `ease-out` easing keyword in the JSON `$description` rather than hard-coding a `cubicBezier` (least-surprise; keeps the A1 assumption non-load-bearing). Implemented in 81-03 Task 1 (`motion` group) and logged as DIV-5 DOCUMENTED.

## Sources

### Primary (HIGH confidence)
- `chimeway_admin/priv/static/chimeway_admin.css` lines 1-238 — full token layer, read directly; the authoritative SSOT.
- `prompts/chimeway-brand-book.md` lines 600-698 — palette table, status-pill mapping, type stack; divergence source.
- `.planning/phases/81-design-tokens-reconciliation-documentation/81-CONTEXT.md` — locked decisions D-01..D-12.
- `.planning/REQUIREMENTS.md` — TOKEN-01..05 + Out-of-Scope table.
- `git status --porcelain` / grep counts — confirmed 88 distinct `--cw-*` names, 15 primitives, zero `--cw-info`, zero `border-width`, file clean.

### Secondary (MEDIUM confidence)
- Design Tokens Format Module 2025.10 — https://www.designtokens.org/tr/drafts/format/ (verified `$type`/`$value` shapes incl. dimension/duration object form, alias syntax, inheritance).
- DTCG "first stable version" announcement (2025-10-28) — https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/

## Metadata

**Confidence breakdown:**
- Token inventory: HIGH — read verbatim from the authoritative shipped file with line numbers.
- DTCG shape: HIGH — verified against the 2025.10 stable spec (dimension/duration object form confirmed).
- Divergence ledger: HIGH — both-side line refs confirmed by grep.
- Contrast scoping: MEDIUM — reasoning-based; hinges on all dark values being verbatim (A3).

**Research date:** 2026-07-09
**Valid until:** 2026-08-09 (stable — shipped CSS is frozen this milestone; DTCG 2025.10 is the first stable spec)

Sources:
- [Design Tokens Format Module 2025.10](https://www.designtokens.org/tr/drafts/format/)
- [Design Tokens specification reaches first stable version](https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/)
