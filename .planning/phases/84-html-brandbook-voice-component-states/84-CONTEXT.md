# Phase 84: HTML Brandbook, Voice & Component States - Context

**Gathered:** 2026-07-18 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Assemble the primary v1.15 deliverable — a standalone, scoped, `file://`-safe HTML brand book at `brandbook/index.html` — that **renders** the already-locked design system (Phase-81 tokens, Phase-83 logo family) alongside component states, brand voice/microcopy, and do/don't usage. The book proves the system works rather than describing it.

**Requirements:** BOOK-01/02/03, STATE-01/02, VOICE-01/02/03.

**This phase does not design a new visual language — it renders the already-locked one.** Tokens come from the Phase-81 SSOT `brandbook/tokens/tokens.css`; logos from the Phase-83 family in `brandbook/assets/logo/`; all copy examples lift verbatim from `prompts/chimeway-brand-book.md`. Scope is `brandbook/` + `scripts/brandbook-guards.sh` only — no runtime code, no new assets beyond the ratified logo family, no `chimeway_admin` re-theme (deferred to a future ADMIN-RETHEME-01 milestone).
</domain>

<decisions>
## Implementation Decisions

Nearly all decisions for this phase are already locked by three approved upstream artifacts, which downstream agents MUST treat as binding:
- **`84-UI-SPEC.md` (approved, 6/6 PASS)** — design system (zero-build vanilla HTML/CSS/inline-JS), font stacks, spacing scale, typography (4 sizes / 2 weights), color + accent-reservation list, status triads, full copywriting contract, all 9 component states with driving tokens, do/don't pairs, registry/security posture.
- **`84-VALIDATION.md`** — dependency-free `scripts/brandbook-guards.sh` (modeled on `scripts/logo-guards.sh`), run after every task/wave; file://-safety + scope-nonleak + section-presence negative-greps; manual browser checks enumerated.
- **`84-RESEARCH.md`** — `file://` safety matrix, `@scope`/`@layer` Baseline analysis, inline WCAG relative-luminance formula, and the resolved page/CSS structure.

The decisions below are the genuinely-open *structural / implementation-shape* choices that the artifacts above did **not** fully pin down — resolved here so the planner and executor do not re-open them.

### Structure (resolved by RESEARCH, restated as locked)
- **D-01:** Book is a **single `brandbook/index.html`** — one long scroll with anchor-nav chrome and RESEARCH's ~10-section order. No multi-page split (BOOK-01 requires `index.html` open directly via `file://`).
- **D-02:** Book CSS lives in a **separate, relatively-linked `brandbook/brandbook.css`** (`<link rel="stylesheet" href="brandbook.css">`), scoped via `@layer` + `@scope` under `.cw-brandbook` with `.cwb-*` demo classes. Tokens are consumed via a separate relative `<link>` to `tokens/tokens.css` — **read, never redefined**. (A `<link>` stylesheet is `file://`-safe; only `fetch()`/`<use href>` sprites are not.)
- **D-03:** All JavaScript is a **single inline classic `<script>`** (no `type="module"`, no external `src`) implementing only (a) the tri-state `light/dark/system` theme toggle writing `data-theme` on `document.documentElement` and (b) the live contrast matrix reading tokens via `getComputedStyle` on a painted probe with the inline WCAG luminance formula. This is the only JS that runs under `file://`.

### Logo rendering policy + drift control
- **D-04:** Inline as `<svg>` **only** the marks that must recolor with the theme — `chimeway-mark-mono.svg`, `chimeway-logotype-mono.svg`, `chimeway-logotype-inverse.svg` (the `currentColor` variants). Render the four fixed-color / raster assets (`chimeway-logotype.svg`, `chimeway-logotype-stacked.svg`, `chimeway-mark.svg`, favicon + OG previews) via `<img src>` so `currentColor` is isolated.
  - *Rationale:* RESEARCH Open-Q#2 + Pitfalls 3/4. `<img>` on a mono mark would render dark-on-dark and break the BOOK-03 theming demonstration.
- **D-05:** Add a **parity check** to `brandbook-guards.sh`: for each inlined mark, grep its `<path d=…>` and assert the same path appears in the corresponding `brandbook/assets/logo/*.svg`. Prevents the book's inlined marks from silently drifting from the Phase-83 SSOT assets after any later asset edit (Pitfall 4).

### Do/Don't "don't" rendering
- **D-06:** Render every "don't" misuse (logo background cage, icon-left/text-right split, brass-on-paper body text, cramped spacing) via a **scoped `.cwb-dont` CSS wrapper that applies the offending treatment in CSS only** around the correct shipped asset/token. **Never author or commit a deliberately-broken SVG.**
  - *Rationale:* RESEARCH forbids baking a cage into the asset; the milestone scope guard forbids new assets beyond the ratified family; STATE-02 still requires a visible visual pair. CSS-only misuse is the only approach that satisfies all three (and avoids tripping the asset hygiene/token-hex guards).

### Guard-script enforcement shape
- **D-07:** Author `scripts/brandbook-guards.sh` mirroring `scripts/logo-guards.sh` idioms — the `pass`/`fail`/`skip` helpers, a `--scope` git-boundary mode allowing only `brandbook/**` + `scripts/brandbook-guards.sh`, and optional `xmllint` that SKIPs when absent. Run three grep families:
  1. **file://-safety negatives** over `index.html`: no `fetch(`, no `XMLHttpRequest`, no `type="module"`, no cross-file `<use href="*.svg#…">`, no `https?://` or root-absolute `/` asset refs.
  2. **scope-nonleak audit** over `brandbook.css`: assert `@layer` + `@scope` present; flag any bare element / `*` selector at column 0 (unscoped, not prefixed `.cwb-`/`.cw-brandbook`).
  3. **section-presence greps**: the nine `is-*` state tokens, `data-cwb-theme`, `luminance`, and voice/naming anchors (`docs`/`errors`/`marketing`/`cli`, "what happened", lowercase `chimeway` vs title-case `Chimeway`).
  - *Rationale:* VALIDATION under-specifies check (2) as "custom awk"; RESEARCH's Validation table enumerates the exact greps; `logo-guards.sh` provides copy-able scaffolding. A loose scope audit would make BOOK-02's non-leak guarantee vacuous — the exact vacuous-pass footgun to avoid.

### Claude's Discretion
- Exact section ordering within the ~10-section page, responsive breakpoints, and the visual layout of voice good/bad example blocks are left to the executor within the UI-SPEC's constraints (professional, responsive, token-driven).
- Whether the parity check (D-05) matches full `d=` strings or a normalized subset, provided it fails on real asset drift.

### Folded Todos
None — no pending todos matched this phase.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/phases/84-html-brandbook-voice-component-states/84-UI-SPEC.md` — approved design contract (binding, zero-drift source of truth for visuals/copy/states)
- `.planning/phases/84-html-brandbook-voice-component-states/84-RESEARCH.md` — `file://` safety matrix, `@scope`/`@layer` analysis, inline WCAG luminance formula, page/CSS structure, pitfalls
- `.planning/phases/84-html-brandbook-voice-component-states/84-VALIDATION.md` — guard-script validation strategy + manual browser checks
- `brandbook/tokens/tokens.css` — Phase-81 token SSOT (read via relative `<link>`, never redefine)
- `brandbook/tokens/tokens.json` — DTCG mirror
- `brandbook/assets/logo/` — Phase-83 logo family (6 SVGs); `brandbook/assets/favicon/`, `brandbook/assets/social/`
- `prompts/chimeway-brand-book.md` — canonical source for all voice/microcopy examples (lift verbatim; cited line refs throughout UI-SPEC)
- `scripts/logo-guards.sh` — model/scaffolding for `scripts/brandbook-guards.sh`
- `notes/decision-log.md` — token divergence ledger (DIV-1..DIV-7 are DOCUMENTED; do not "fix" them here)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Tokens** — `brandbook/tokens/tokens.css` (bare `:root` + `[data-theme]` + `@media` SSOT) and `tokens.json` already exist and are byte-frozen from Phase 81. Consume, never redefine.
- **Logo family** — all six SVGs plus favicon (`favicon.ico/.svg`, `apple-touch-icon.png`) and social (`chimeway-og.svg/.png`) already on disk under `brandbook/assets/`. `mark-mono`, `logotype-mono`, `logotype-inverse` carry `fill="currentColor"`.
- **Guard scaffolding** — `scripts/logo-guards.sh` provides `pass/fail/skip` helpers, a `--scope` git-boundary walk, and optional-`xmllint` SKIP pattern to copy for `brandbook-guards.sh`.

### Established Patterns
- Zero-build, dependency-free, `file://`-safe static artifact discipline (no CDN `<script src>`, no npm, no `fetch`, no ES-module `import`, no cross-file `<use href>` sprites) — this is the milestone's primary security property.
- Scoped CSS via `@layer` + `@scope` under a `.cw-brandbook` root with `.cwb-*` demo classes so nothing leaks into the repo or a host app copying a snippet (BOOK-02).
- Zero-drift-on-tokens milestone invariant: DOCUMENTED divergences (DIV-1..DIV-7) stay as-is.

### Integration Points
- `brandbook/index.html` (new) links `tokens/tokens.css` + `brandbook.css` (new) via relative paths; embeds Phase-83 logo assets.
- `scripts/brandbook-guards.sh` (new) is wired into the phase's per-task/per-wave validation loop and must be green before `/gsd-verify-work`.
- Phase 85 (README/HexDocs/favicon wiring) consumes the finalized asset filenames produced/confirmed here.
</code_context>

<specifics>
## Specific Ideas

- Demonstrated primary CTA label is `install chimeway` (developer-to-developer, never a sales CTA).
- Named error template (VOICE-02): "Chimeway error message pattern: what happened → why it matters → how to fix"; canonical example `Delivery suppressed: recipient disabled email for `invoice.paid`.`
- Theme toggle is tri-state `light` · `dark` · `system` where "system" removes `data-theme` and defers to `prefers-color-scheme`.
- All nine component states demoed twice — a live interactive control **and** a frozen `.is-*` copy labelled with its state name.
</specifics>

<deferred>
## Deferred Ideas

- `chimeway_admin` `cw.tokens` full re-theme — future ADMIN-RETHEME-01 milestone (out of v1.15 scope).
- Live LiveView/Storybook-wired interactive component demo (BRAND-STORYBOOK-01), print/marketing collateral + i18n voice guide (BRAND-COLLATERAL-01), publishing the brandbook as its own package (PKG-BRAND-01) — all explicitly out of scope.

### Reviewed Todos (not folded)
None — no pending todos matched this phase.
</deferred>
