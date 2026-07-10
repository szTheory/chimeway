# Requirements: Chimeway v1.15 — Brand Identity & Brand Book

**Defined:** 2026-07-09
**Core Value:** Every notification decision is explainable — and this milestone makes Chimeway *look* as credible as it behaves, so adopters trust it on sight (GitHub / HexDocs / landing pages) and future UI/docs/marketing work is accelerated.

Deliverable: a self-contained, repo-safe, zero-build `brandbook/` package plus two tiny repo-integration edits (README header, `mix.exs` `docs()` logo/favicon). Doc/asset-only — no runtime code, no CI changes, `chimeway_admin` untouched. Grounded in `.planning/research/SUMMARY.md`.

## Milestone v1.15 Requirements

Requirements for this milestone. Each maps to exactly one roadmap phase.

### Logo System (LOGO)

- [ ] **LOGO-01**: User is presented 3–5 distinct, fully-worked logo directions — each with rationale, pros/cons, and a ship/defer/reject recommendation + confidence — to choose from (a vetted shortlist, not a raw gallery).
- [ ] **LOGO-02**: At least one direction is a fully-integrated typemark — a custom motif/flourish worked *into* the wordmark's letterforms, not a mark placed beside a plain font.
- [ ] **LOGO-03**: The selected finalist ships a full lockup family — primary horizontal lockup, icon-only mark, wordmark, stacked lockup, mono, inverse, and a simplified favicon mark — as optimized SVGs.
- [ ] **LOGO-04**: Every shipped mark stays legible and recognizable at 16px, in single-color mono, and inverse (dark) — each verified against those tests before ship.
- [ ] **LOGO-05**: No logomark uses a rectangular/enclosing background cage; mark and wordmark read as one unified unit (not icon-left/text-right); the primary lockup carries no subtitle/slogan (a separate optional tagline lockup only if it genuinely adds value).
- [ ] **LOGO-06**: Directions avoid literal music/bell/clapper/note imagery, expressing the "chime" idea through the path / route / signal / trace metaphor set; clear-space, minimum-size, and a do/don't usage grid are documented.

### Design Tokens (TOKEN)

- [x] **TOKEN-01**: `brandbook/tokens/tokens.css` defines canonical `--cw-*` custom properties with the 15 primitive colors copied **verbatim** from the shipped `chimeway_admin.css` — one source of truth, no forked palette.
- [ ] **TOKEN-02**: `brandbook/tokens/tokens.json` mirrors the token set in DTCG (`$value`/`$type`/`$description`) shape, hand-authored, no build tool required.
- [x] **TOKEN-03**: Tokens cover color (primitive + generalized semantic tier + semantic state: success/warning/error/**info**), type scale, spacing, radius, border, shadow, motion, focus-ring, and z-index — two-tier primitive→semantic only (no component-token tier, no 12-step per-hue scales).
- [ ] **TOKEN-04**: Every sub-primitive divergence from shipped admin CSS (radius-sm 5px vs 4px; info/cancelled/sending/expired status triads; missing `--cw-info`; net-new motion + z-index tokens) is recorded in `notes/decision-log.md` as DOCUMENTED/DEFERRED — `chimeway_admin.css` is **not** modified this milestone.
- [x] **TOKEN-05**: Light/dark/system theming is supported and each new semantic token has an independently contrast-checked dark value (no `filter: invert()`).

### Standalone HTML Brandbook (BOOK)

- [ ] **BOOK-01**: `brandbook/index.html` opens directly via `file://` with no server and no build step — all asset references relative, no `fetch()` or cross-file `<use href>` sprite patterns (Chromium `file://` safe).
- [ ] **BOOK-02**: Brandbook CSS is scoped (`@layer` + `@scope`, `.cw-brandbook` root, `.cwb-*` demo classes) so it cannot leak into the repo or into a host app that copies a snippet.
- [ ] **BOOK-03**: The book renders the logo family, color/token swatches, type/spacing sections, component showcase, a live light/dark/system theme toggle, and a live contrast matrix — professional and responsive across viewports.

### Brand Voice & Microcopy (VOICE)

- [ ] **VOICE-01**: Voice and tone are documented by context (docs, errors, marketing, CLI) with concrete good/bad examples.
- [ ] **VOICE-02**: A named, reusable "what happened / why it matters / how to fix" error-message pattern template is provided.
- [ ] **VOICE-03**: CTA style and product/feature naming rules (incl. lowercase `chimeway` graphic vs title-case "Chimeway" prose) are documented with examples.

### Component States & Usage (STATE)

- [ ] **STATE-01**: Component states — hover / focus / active / disabled / loading / error / empty / skeleton / selected — are documented as static token-driven HTML/CSS.
- [ ] **STATE-02**: Do/don't brand-usage examples (logo misuse, color misuse, spacing) are shown as visual pairs.

### Accessibility (A11Y)

- [ ] **A11Y-01**: Every text foreground/background pairing meets WCAG 2.2 SC 1.4.3 (4.5:1, or 3:1 for large text) — verified and recorded.
- [ ] **A11Y-02**: Non-text/UI contrast — borders, focus rings, meaningful icons — meets SC 1.4.11 (3:1) — verified.
- [ ] **A11Y-03**: Focus is visible and not obscured (SC 2.4.7 / 2.4.11), reduced motion is honored (SC 2.3.3), and interactive targets are ≥24×24px (SC 2.5.8).
- [ ] **A11Y-04**: Status/semantic meaning is never conveyed by color alone, and the palette is colorblind-safe (verified against CVD simulation).
- [ ] **A11Y-05**: `notes/accessibility-checks.md` records per-pairing ratios and the verification of the above against the *rendered* brandbook output.

### Repo Integration (INTEG)

- [ ] **INTEG-01**: The README header shows the real primary lockup (relative-path SVG that GitHub resolves), replacing any placeholder.
- [ ] **INTEG-02**: `mix.exs` `docs()` wires ExDoc `:logo` and `:favicon` (SVG) so HexDocs shows the brand mark.
- [ ] **INTEG-03**: A deliberately-simplified `favicon.svg` (+ the minimal raster fallback the platforms require) is shipped and wired.
- [ ] **INTEG-04**: Integration edits stay in scope — changes limited to the README header region, docs config, and optional `package() files:`; `chimeway_admin` untouched; all v1.14 doc-contract/release-gate tests still pass.

### Decision Notes & Red-Team (NOTES)

- [ ] **NOTES-01**: Every major recommendation carries pros/cons/tradeoffs, an analogue, implementation cost, ship/reject/defer, and confidence (cohesive, not a buffet).
- [ ] **NOTES-02**: `notes/logo-options.md` documents all explored directions (including rejected, as inline SVG for repo-size discipline) with rationale.
- [ ] **NOTES-03**: A red-team/skeptic pass is recorded, closing with a `git diff --stat` scope-boundary audit that confirms changes are `brandbook/`-only plus the two allowed integration edits, and a repo-size/binary check.
- [ ] **NOTES-04**: `notes/research.md` captures the research basis and citations (Elixir/Phoenix idioms + mature design-system precedent).

## Future Requirements

Deferred to a future milestone. Tracked, not in this roadmap.

### Admin Re-theme (ADMIN)

- **ADMIN-RETHEME-01**: Re-theme `chimeway_admin` to consume the reconciled `tokens.css` (resolving the deferred sub-primitive conflicts live). Large; explicit follow-on per rollout boundary.

### Brand Expansion (BRAND+)

- **BRAND-WEBFONT-01**: Adopt and bundle a licensed OSS webfont for the wordmark (if the documented system-stack recommendation proves insufficient).
- **BRAND-STORYBOOK-01**: Live LiveView/Storybook-wired interactive component demo (vs. static HTML).
- **BRAND-COLLATERAL-01**: Print/marketing collateral beyond stickers; i18n voice guide.
- **PKG-BRAND-01**: Publish the brandbook as its own package.

## Out of Scope

Explicitly excluded this milestone. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Patching `chimeway_admin.css` sub-primitive conflicts | Rollout boundary = document/defer only; live admin re-theme is a separate milestone |
| Any build system / bundler (Vite, Webpack, Tailwind, PostCSS) in `brandbook/` | Defeats `file://`, adds `node_modules` for a static doc |
| Bundled font binaries (`.woff2`/`.ttf`/`.otf`) | System stack primary; wordmark ships as SVG outlines; webfont is a documented recommendation only |
| PDF pipeline (Puppeteer/WeasyPrint/Prince) | HTML is the deliverable; browser print-to-PDF suffices if ever needed |
| Figma/AI/Sketch source files, icon webfont, Shadow DOM | Vector SVG + inline paths + `@scope` cover the need at lower footprint |
| axe-core/pa11y wired into CI | Milestone is doc/asset-only and must not touch CI; a11y verified manually against named WCAG 2.2 criteria |
| Component-level token tier, 12-step per-hue scales, multi-brand theming | Over-engineering for an OSS dev-tool at this scale |
| Rewriting README beyond the header, or new HexDocs pages | Scope guard — touch only the header region + docs logo/favicon config |

## Traceability

Which phases cover which requirements. Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| TOKEN-01 | Phase 81 | Complete |
| TOKEN-02 | Phase 81 | Pending |
| TOKEN-03 | Phase 81 | Complete |
| TOKEN-04 | Phase 81 | Pending |
| TOKEN-05 | Phase 81 | Complete |
| LOGO-01 | Phase 82 | Pending |
| LOGO-02 | Phase 82 | Pending |
| LOGO-05 | Phase 82 | Pending |
| LOGO-06 | Phase 82 | Pending |
| NOTES-02 | Phase 82 | Pending |
| LOGO-03 | Phase 83 | Pending |
| LOGO-04 | Phase 83 | Pending |
| INTEG-03 | Phase 83 | Pending |
| BOOK-01 | Phase 84 | Pending |
| BOOK-02 | Phase 84 | Pending |
| BOOK-03 | Phase 84 | Pending |
| STATE-01 | Phase 84 | Pending |
| STATE-02 | Phase 84 | Pending |
| VOICE-01 | Phase 84 | Pending |
| VOICE-02 | Phase 84 | Pending |
| VOICE-03 | Phase 84 | Pending |
| INTEG-01 | Phase 85 | Pending |
| INTEG-02 | Phase 85 | Pending |
| INTEG-04 | Phase 85 | Pending |
| A11Y-01 | Phase 86 | Pending |
| A11Y-02 | Phase 86 | Pending |
| A11Y-03 | Phase 86 | Pending |
| A11Y-04 | Phase 86 | Pending |
| A11Y-05 | Phase 86 | Pending |
| NOTES-01 | Phase 86 | Pending |
| NOTES-03 | Phase 86 | Pending |
| NOTES-04 | Phase 86 | Pending |

**Coverage:**

- v1.15 requirements: 32 total
- Mapped to phases: 32 ✓
- Unmapped: 0 ✓

**Per-phase counts:** Phase 81 (5: TOKEN-01..05) · Phase 82 (5: LOGO-01/02/05/06, NOTES-02) · Phase 83 (3: LOGO-03/04, INTEG-03) · Phase 84 (8: BOOK-01..03, STATE-01/02, VOICE-01..03) · Phase 85 (3: INTEG-01/02/04) · Phase 86 (8: A11Y-01..05, NOTES-01/03/04)

---
*Requirements defined: 2026-07-09*
*Last updated: 2026-07-09 after roadmap creation (Phases 81-86 mapped, 100% coverage)*
