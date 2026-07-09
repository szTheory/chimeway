# Project Research Summary

**Project:** Chimeway — v1.15 Brand Identity & Brand Book
**Domain:** Self-contained, vector-first OSS brand/design-system package (`brandbook/`) for an Elixir/Phoenix library — zero build step, opens via `file://`
**Researched:** 2026-07-09
**Confidence:** HIGH

## Executive Summary

This milestone ships a self-contained `brandbook/` folder — SVG logos, a reconciled `--cw-*` token file (JSON + CSS), a standalone HTML brand book, copy-paste component examples, and decision/accessibility notes — plus two tiny repo-integration edits (README header, `mix.exs` `docs()` logo/favicon). It is **doc/asset-only**: no runtime code, no CI changes, no touching `chimeway_admin`. The single most important reframing from the research is that the token work is **not** a design exercise — the shipped `chimeway_admin.css` primitive palette (15 `--cw-*` colors) already matches brand-book §14 **byte-for-byte, zero drift**. The real work is (a) *documenting* that agreement into a canonical, copy-safe `tokens.css`/`tokens.json`, and (b) *recording* the handful of sub-primitive conflicts as deferred decisions — not patching them into shipped admin CSS this milestone.

Experts build this kind of artifact the way Fly.io and Vercel Geist do at OSS/dev-tool scale: a small, practical, HTML-first brand page (not a PDF, not a Figma file, not a CMS microsite), a compact token set (~40-50 tokens, not Carbon's hundreds), a two-tier primitive→semantic token model (reject the third component tier), and a tight logo lockup family. The recommended approach here is deliberately zero-build: hand-authored SVG/CSS/HTML/JSON/MD, `svgo` used once during authoring as a throwaway CLI (never a repo dependency), and `color.js` vendored as a single ES module so the book's live contrast matrix works from a plain file open. The whole stack reuses patterns `chimeway_admin.css` already proves in production (`@layer` cascade order, `:where()` zero-specificity scoping, focus-visible, reduced-motion).

The two dominant risk clusters are **logo craft** and **token reconciliation discipline**. On logos, the user's hard taste constraints are non-negotiable and repeated across three source docs: no rectangular background cages, mark+wordmark visually unified (not "icon-left/text-right"), ≥1 genuinely integrated typemark (a modified letterform, not a font choice), multiple directions with rationale to choose from, no literal music/bell iconography (route "chime" through the path/signal/trace metaphor set), and every mark must survive mono, inverse, and 16px. On tokens, the trap is forking a second source of truth; the mitigation is to copy the 15 primitives verbatim and log every conflict (radius-sm 5px vs 4px; info/cancelled/sending/expired status triads; missing `--cw-info`; missing motion + z-index tokens) as DOCUMENTED/DEFERRED, not fixed. Accessibility is checked against named WCAG 2.2 criteria throughout, and a final red-team pass guards the `brandbook/`-only scope boundary.

## Key Findings

### Recommended Stack

The stack is generation-time tooling, not a runtime dependency — nothing here becomes a dependency of `chimeway` core, `chimeway_admin`, or the shipped Hex tarball. The brand book itself is plain files a browser opens directly. Tooling follows the existing repo precedent (root `package.json` carries Playwright as a devDependency for a one-off script, never a build pipeline). Confidence is HIGH: versions were verified against the live npm registry and the DTCG spec status confirmed against the W3C Community Group's official first-stable-release announcement (2025-10-28).

**Core technologies:**
- **Plain Node `.mjs` generation script** — emit SVG (logos, favicon, social card) as template-literal strings; zero framework, SVG is just XML text.
- **SVGO 4.0.1 (devDependency only)** — one-shot optimization of generated/hand-tuned SVGs via a committed `svgo.config.mjs` (`removeViewBox: false`, `floatPrecision: 2-3`, `multipass: true`) for byte-deterministic, diff-friendly output. Never a view-time dependency.
- **DTCG-shaped `tokens.json` + hand-authored `tokens.css`** — `tokens.json` (`$value`/`$type`/`$description`) is forward-compatible with Style Dictionary/Terrazzo without adopting a build tool now; `tokens.css` reuses the exact `--cw-*` names already live in `chimeway_admin.css`.
- **Hand-authored cascade-layered CSS (`@layer`) + `@scope`** — mirrors `chimeway_admin.css`'s five-layer pattern; `@scope` (Baseline since Dec 2025) contains live demo blocks. `@layer` = macro order, `@scope` = micro containment — complementary, not redundant.
- **Vendored `color.js` 0.6.1 (single ES module, not npm-installed)** — live WCAG 2.1 + APCA contrast matrix embedded in the book, works from `file://` with no `node_modules`.
- **One rasterizer — `@resvg/resvg-js` 2.6.2 OR `sharp` 0.35.3 (pick one)** — only for the 2-3 surfaces that structurally require raster (OG/social card, apple-touch-icon, `favicon.ico`).
- **SVG `feColorMatrix` CVD filters + MIT icon path data (Heroicons/Octicons)** — copy the specific matrices/paths needed into inline `<defs>`/a `<symbol>` sprite; no packages installed.

**What NOT to add (preserved verbatim as a hard boundary):**
- **No build system / bundler** (Vite, Webpack, Parcel, esbuild, Tailwind/PostCSS) — defeats `file://`, adds `node_modules` for a static doc.
- **No Style Dictionary/Tokens Studio as a required build step** — overkill for ~40-50 hand-maintained tokens with two output targets.
- **No font binaries** (`.woff2`/`.ttf`/`.otf`) — system font stack primary; Inter/IBM Plex Mono/Source Serif 4 documented as a *recommendation* only; wordmark/typemark shipped as SVG outlines.
- **No PDF pipeline** (Puppeteer/WeasyPrint/Prince) — HTML is the deliverable; native browser print-to-PDF against `@media print` if ever wanted.
- **No Figma/AI/Sketch source files, no icon webfont, no Shadow DOM, no axe/pa11y in CI** this milestone.

### Expected Features

The written brand spec (`prompts/chimeway-brand-book.md`, §1-35) already contains ~90% of the *content*; most of the milestone is extraction, visualization, and reconciliation — not net-new brand strategy. Confidence is HIGH against mature design-system precedent (Primer's Brand/Product split is the exact mental model: the brandbook is a new brand-facing system that *reconciles with*, not forks, the existing product tokens).

**Must have (table stakes for this project):**
- **Logo system** — primary horizontal lockup, icon-only mark, wordmark, integrated typemark, stacked lockup, mono, inverse, simplified favicon, optional-tagline secondary, clear-space + min-size rules, do/don't grid, OG crop. Full 10-variant matrix for the *finalist* only; mark+wordmark+one lockup for the non-selected directions.
- **Reconciled tokens** (`tokens.json` + `tokens.css`) covering color, type, spacing, radius, border, shadow, motion, focus-ring, z-index — the assembly point everything downstream depends on.
- **Standalone HTML brand book** (`index.html`) — the primary deliverable and assembly layer with no content of its own.
- **Brand voice & microcopy section** — transcribe §9-11/§21-26/§33, plus one net-new differentiator: a named, fillable "what happened / why it matters / how to fix" error-pattern template (GOV.UK/Polaris caliber).
- **Component states** (hover/focus/active/disabled/loading/error/empty/skeleton/selected) as *static* HTML/CSS that documents states already shipped in `chimeway_admin` (loading/skeleton is the only genuinely net-new pattern).
- **Decision + accessibility notes** (`decision-log.md`, `logo-options.md`, `accessibility-checks.md`) + red-team pass.

**Should have (differentiators at OSS scale):**
- The integrated typemark (no surveyed system does this — genuine differentiation; here it's a hard requirement).
- Multiple pre-vetted logo directions with rationale/ship-defer-reject recommendations (not a raw gallery).
- Live in-book contrast matrix + a real dark/light/system toggle (proves tokens work, not just static swatches).

**Defer (v1.x / v2+):**
- Full `chimeway_admin` re-theme to consume the reconciled tokens (explicitly deferred per PROJECT.md rollout boundary).
- Live Storybook/LiveView-wired component demo; adopted webfont; print collateral beyond stickers; i18n voice guide; trademark/legal apparatus; publishing the brandbook as a Hex package.

**Reject (not just defer):** component-level token tier (Carbon-style), full 12-step per-hue color scales, multi-brand/theme layering.

### Architecture Approach

Two CSS root scopes stay independent by design: `.chimeway-admin` (shipped, untouched) and `.cw-brandbook` (new, static showcase). They share the same primitive `--cw-*` *names and values* (that IS the reconciliation), but nothing in `brandbook/` overwrites, imports, or executes against `chimeway_admin/`. `tokens/tokens.css` is the *only* cross-boundary artifact — the single file designed to be imported by a future host app or the deferred admin re-theme, so that re-theme becomes a one-file dependency change. All `file://` references must be relative (never root-relative), and no `fetch()`/external `<use href="sprite.svg#id">` (Chromium blocks both under `file://`) — inline SVG markup instead.

**Major components:**
1. **`brandbook/tokens/tokens.css` (+ `tokens.json`)** — canonical, copy-safe `--cw-*` custom properties (primitive verbatim + a new *generalized* semantic tier: `--cw-surface`, `--cw-fg`, `--cw-border`, `--cw-focus`, `--cw-status-*`). Scoped to `:root` (declarations only). Reuses the literal `@layer cw.tokens` name so a hypothetical co-load with admin CSS merges to a no-op.
2. **`brandbook/index.html` + `assets/brandbook.css`** — primary deliverable; book chrome scoped to `.cw-brandbook` under its own `cw.brandbook.*` layer namespace; `.cwb-*` demonstrative components (distinct prefix from admin's real `.cw-*`).
3. **`brandbook/examples/*.html`** — copy-paste snippets that depend only on `tokens.css` (or nothing), deliberately *no* `@layer` wrapper so they behave predictably in any host app.
4. **`brandbook/assets/*.svg`** — only *shipped* final vectors; rejected candidate directions live as inline `<svg>` in `notes/logo-options.md` (repo-size discipline).
5. **Repo integration** — `README.md` header lockup (relative path, GitHub resolves natively); `mix.exs` `docs()` `:logo`/`:favicon` (ExDoc accepts SVG, copied from source tree at `mix docs` time — the correct HexDocs path, not a README hack); optional `package() files:` += `brandbook/assets` so Hex.pm's README preview resolves the image. `chimeway_admin/` untouched.

### Critical Pitfalls

The pitfalls research names 25 pitfalls across logo craft, token reconciliation, accessibility, and scope. The top clusters:

1. **Logo taste-constraint violations (Pitfalls 1-7)** — generic AI blob, illegible-at-16px, literal music/bell imagery, rectangular background cage, mono/inverse failure, "typemark = font choice," disconnected mark+wordmark. Avoid by anchoring every direction to a named brand metaphor primitive (§13), gating on the 16px + black-and-white tests before shortlisting, hard-rejecting any enclosing `<rect>`/`<circle>`, and requiring the integrated direction to modify ≥1 letterform.
2. **Token fork instead of reconciliation (Pitfalls 8-9)** — a second source of truth for "what teal is." Avoid by copying the 15 primitives verbatim, keeping the two-tier primitive→semantic taxonomy, and logging every divergence in `decision-log.md`.
3. **Accessibility misses against named WCAG 2.2 criteria (Pitfalls 11-17)** — text contrast (1.4.3), non-text/UI contrast (1.4.11, the commonly-skipped one), focus visible + not-obscured (2.4.7/2.4.11), reduced motion (2.3.3), colorblind-unsafe status (never color alone), touch targets ≥24×24px (2.5.8), and dark-mode contrast regressions on new tokens. Avoid by reusing `chimeway_admin.css`'s proven focus-visible/reduced-motion blocks, recording every real fg/bg pairing in `accessibility-checks.md`, and contrast-checking every new token's dark value independently (never `filter: invert()`).
4. **Scope creep beyond `brandbook/` (Pitfalls 21, 25)** — "just quickly" patching `chimeway_admin.css`, rewriting more of the README than the header, or drifting into the full admin re-theme. Avoid by running `git diff --stat` against the allowed file set before every commit and re-affirming the rollout boundary at each phase transition.
5. **Build-system / binary bloat (Pitfalls 10, 22, 23, 24)** — hardcoded values bypassing tokens, a `package.json`/`node_modules` in `brandbook/`, committed font binaries or oversized rasters, unscoped CSS. Avoid with zero-build discipline, `var(--cw-*)`-only demo CSS, and `:where(.chimeway-brandbook ...)` scoping.

## Implications for Roadmap

The research converges on a clear dependency-ordered build sequence. The logo-direction selection is a **user checkpoint**, and logo depth is the milestone's largest cost driver. Suggested phase structure (roadmapper to map onto numbers after the current highest phase):

### Phase 1: Design Tokens (Reconciliation + Documentation)
**Rationale:** Every downstream artifact (logo colors, HTML book, examples, component states) consumes the tokens; the primitives are already zero-drift so this is the highest-confidence, lock-it-first work.
**Delivers:** `tokens/tokens.json` + `tokens/tokens.css` (15 primitives verbatim + new generalized semantic tier); every sub-primitive conflict logged in `decision-log.md` as DOCUMENTED/DEFERRED (radius-sm 5px vs 4px; info/cancelled/sending/expired status triads; missing `--cw-info`; net-new motion + z-index tokens).
**Addresses:** Design-tokens table stakes; two-tier taxonomy.
**Avoids:** Pitfalls 8, 9, 11 (fork, sprawl, dark-mode regression). **Scope guard:** do NOT patch `chimeway_admin.css`.

### Phase 2: Logo Exploration (3-5 directions)
**Rationale:** Depends only on Phase 1 colors; independent of the HTML shell, so it can run largely in parallel.
**Delivers:** `notes/logo-options.md` with 3-5 worked directions (rationale, pros/cons, ship/defer/reject, confidence), rejected candidates inline as `<svg>`.
**Avoids:** Pitfalls 1-7 — anchored to a brand metaphor, no cage, no literal music, ≥1 integrated typemark, unified mark+wordmark, passes mono/inverse/16px gates before shortlisting.

### Phase 3: Direction Selection (USER CHECKPOINT)
**Rationale:** Human taste decision; the largest cost/quality lever in the milestone.
**Delivers:** chosen direction(s) promoted into `assets/` under canonical names; ship/defer entries in `decision-log.md`.

### Phase 4: Favicon + Social Derivatives
**Rationale:** Small derivatives of the *final* chosen mark, so must follow selection to avoid rework.
**Delivers:** `favicon.svg` (deliberately simplified, passes 16px test — not the primary mark resized), `social-card.svg` (+ the one justified `.png` raster export).
**Avoids:** Pitfall 2; integration gotcha on OG raster format.

### Phase 5: HTML Brandbook
**Rationale:** The primary deliverable and assembly layer; needs final tokens + final logos. Build the component-showcase `.cwb-*` conventions here once.
**Delivers:** `index.html` + `assets/brandbook.css`, live dark/light/system toggle, live contrast matrix, do/don't visual pairs.
**Uses:** hand-authored `@layer`+`@scope` CSS, vendored `color.js`. **Avoids:** Pitfalls 10, 14, 15, 22, 24 (hardcoded values, focus, reduced-motion, build system, unscoped CSS).

### Phase 6: Examples
**Rationale:** Reuses the `.cwb-*` patterns proven in Phase 5.
**Delivers:** `examples/components.html`, `examples/landing-page-section.html`, `examples/readme-header.md` (only `tokens.css`-dependent).

### Phase 7: Repo Integration (README + HexDocs + favicon wiring)
**Rationale:** Depends on final filenames; do last so config isn't revised mid-flight.
**Delivers:** README header lockup, `mix.exs` `docs()` `:logo`/`:favicon`, optional `package() files:` += `brandbook/assets`.
**Avoids:** Pitfall 21; integration gotcha (touch only the README header region; leave v1.14 doc-contract tests passing).

### Phase 8: Notes + Accessibility Audit + Red-Team
**Rationale:** `accessibility-checks.md` needs *rendered* output to audit; the red-team scope-boundary check is the milestone-close gate.
**Delivers:** `accessibility-checks.md` (per-pairing WCAG 1.4.3 + 1.4.11 ratios, focus/reduced-motion/touch-target/colorblind verification), `research.md`, final `git diff --stat` scope audit, banlist/CTA grep.
**Avoids:** Pitfalls 12, 13, 16-20, 25.

### Phase Ordering Rationale
- **Tokens first** because the primitive values are already settled (zero-drift) and everything downstream references them — locking them is cheap and de-risks all later work.
- **Logo is the one track that parallels tokens** (no dependency on token reconciliation), but its *finalization* (Phase 3 checkpoint) must precede favicon/social/README so those aren't redone.
- **The HTML book is the assembly layer with no content of its own** — it must come after tokens, logo, and voice content are stable, or it gets reworked against moving inputs.
- **Accessibility runs per-artifact and is *verified* (not discovered) at the end** — deferring all checks to a final pass is an explicit anti-pattern (rework across every finished example).
- Note: brand-voice extraction (Pitfalls 18-20) is cheap and content-ready; the roadmapper may fold it into Phase 5/6 or run it as a thin parallel track rather than a standalone phase.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2/3 (Logo):** genuinely hard, taste-driven, iterative — but this is *design* effort, not information research. The `deep-research` step won't help; budget iteration + user checkpoint time instead. Flag for extra planning depth, not extra research.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Tokens):** the diff is already done in ARCHITECTURE.md's conflict table — execute against it.
- **Phase 5-7 (HTML/Examples/Integration):** patterns are fully documented (reuse `chimeway_admin.css`, verified ExDoc `:logo`/`:favicon` config). No further research needed.
- **Phase 8 (Accessibility):** WCAG criteria are named and cited; it's a checklist execution, not research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Versions verified via live `npm view`; DTCG stable-release + `@scope` Baseline confirmed against primary sources; reuses in-repo Playwright precedent. |
| Features | HIGH (MEDIUM for Elixir-ecosystem brand examples) | Verified against Primer/Fly.io/Vercel/GOV.UK official pages; Oban/Phoenix have thin public branding so those are negative-space citations. |
| Architecture | HIGH | Token inventory + scoping rules read directly from shipped `chimeway_admin.css`/`mix.exs`; ExDoc `:logo`/`:favicon` verified against ExDoc docs. |
| Pitfalls | HIGH | WCAG 2.2 criteria verified against W3C primary sources; constraints sourced from PROJECT.md + both prompt files. |

**Overall confidence:** HIGH

### Gaps to Address / Open Decision Points
- **Logo-direction depth is the largest cost driver and the one genuinely open creative question.** "Fully worked" should mean "resolved as a coherent concept," not "all 10 export variants produced 5×." Full matrix for the finalist only. Resolve at the Phase 3 user checkpoint.
- **devDependency housing (root `package.json` vs a scoped `brandbook/package.json`).** Root-level matches the Playwright precedent and avoids a second `node_modules` tree; a scoped one keeps brand tooling self-contained but risks the "package.json inside brandbook/" smell (Pitfall 22). Recommend root-level. Confirm during Phase 1/5 planning.
- **OG raster export.** Social card authored as SVG, but OG images generally require PNG/JPEG. Ship the `.png` as the one justified raster exception and note in `decision-log.md`; don't claim OG "done" if only SVG exists.
- **Dark-mode semantic completeness.** The *written* brand book's dark guidance is thin (3 combinations); the shipped admin dark theme is richer. New brandbook semantic tokens each need an independently contrast-checked dark value — real (small) design work, not just transcription.
- **Rasterizer choice** (`resvg-js` vs `sharp`) — pick exactly one; don't install both.

## Sources

### Primary (HIGH confidence)
- `chimeway_admin/priv/static/chimeway_admin.css` — shipped `--cw-*` tokens, `@layer`/`:where()` scoping, focus-visible + reduced-motion patterns (the reconciliation source of truth).
- `mix.exs`, `lib/chimeway.ex`, `README.md` (this repo) — HexDocs/package integration points; confirms HexDocs `main` renders from moduledoc, not README.
- `prompts/chimeway-brand-book.md` §9-35, `prompts/brand-book-pressure-test.md`, `.planning/PROJECT.md` — brand content, hard taste constraints, rollout boundary, font strategy.
- [W3C WCAG 2.2 Understanding docs](https://www.w3.org/WAI/WCAG22/) — SC 1.4.3, 1.4.11, 2.4.7, 2.4.11, 2.3.3, 2.5.8 (verified primary sources).
- [Design Tokens Format Module 2025.10 (W3C DTCG)](https://www.designtokens.org/tr/2025.10/format/) — first stable spec release.
- [ExDoc `mix docs` config](https://hexdocs.pm/ex_doc/Mix.Tasks.Docs.html) — `:logo`/`:favicon` accept SVG.
- npm registry (`npm view`) — svgo 4.0.1, colorjs.io 0.6.1, style-dictionary 5.5.0, resvg-js 2.6.2, sharp 0.35.3.

### Secondary (MEDIUM confidence)
- [GitHub Primer](https://primer.style/) (Brand/Product split), [Fly.io brand](https://fly.io/docs/about/brand/), [Vercel Geist](https://vercel.com/geist/brands), [GOV.UK error-message](https://design-system.service.gov.uk/components/error-message/), [Stripe accessible color systems](https://stripe.com/blog/accessible-color-systems), [Radix Colors](https://www.radix-ui.com/colors) — design-system feature/scale precedent.
- [EightShapes — Naming Tokens](https://medium.com/eightshapes-llc/naming-tokens-in-design-systems-9e86c7444676), [NN/g — Error-Message Guidelines](https://www.nngroup.com/articles/error-message-guidelines/), favicon/logo craft + colorblind-safe palette syntheses, [MDN @scope](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@scope) / caniuse.

### Detailed research files
- `.planning/research/STACK.md` · `.planning/research/FEATURES.md` · `.planning/research/ARCHITECTURE.md` · `.planning/research/PITFALLS.md`

---
*Research completed: 2026-07-09*
*Ready for roadmap: yes*
