# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- ✅ **v1.1** — [Archived roadmap](.planning/milestones/v1.1-ROADMAP.md) (shipped 2026-04-27)
- ✅ **v1.2** — [Archived roadmap](.planning/milestones/v1.2-ROADMAP.md) (shipped 2026-04-29)
- ✅ **v1.3** — [Archived roadmap](.planning/milestones/v1.3-ROADMAP.md) (shipped 2026-04-30)
- ✅ **v1.4** — [Archived roadmap](.planning/milestones/v1.4-ROADMAP.md) · [Audit](.planning/milestones/v1.4-MILESTONE-AUDIT.md) (shipped 2026-05-08, closed 2026-05-28)
- ✅ **v1.5** — [Archived roadmap](.planning/milestones/v1.5-ROADMAP.md) · [Audit](.planning/milestones/v1.5-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.6** — [Archived roadmap](.planning/milestones/v1.6-ROADMAP.md) · [Audit](.planning/milestones/v1.6-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.7** — [Archived roadmap](.planning/milestones/v1.7-ROADMAP.md) · [Audit](.planning/milestones/v1.7-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.8** — [Archived roadmap](.planning/milestones/v1.8-ROADMAP.md) · [Audit](.planning/milestones/v1.8-MILESTONE-AUDIT.md) (shipped 2026-05-30)
- ✅ **v1.9** — [Archived roadmap](.planning/milestones/v1.9-ROADMAP.md) · [Audit](.planning/milestones/v1.9-MILESTONE-AUDIT.md) (shipped 2026-05-30)
- ✅ **v1.10 Ecosystem Completions** — [Archived roadmap](.planning/milestones/v1.10-ROADMAP.md) · [Audit](.planning/milestones/v1.10-MILESTONE-AUDIT.md) (shipped 2026-06-04)
- ✅ **v1.11 Operator Console Polish & Hardening** — [Archived roadmap](.planning/milestones/v1.11-ROADMAP.md) · [Audit](.planning/milestones/v1.11-MILESTONE-AUDIT.md) (shipped 2026-06-04)
- ✅ **v1.13 Storage Isolation and Upgrade Path** — [Archived roadmap](.planning/milestones/v1.13-ROADMAP.md) · [Audit](.planning/milestones/v1.13-MILESTONE-AUDIT.md) (shipped 2026-07-02)
- ✅ **v1.14 Public Truth and Verification Architecture** — [Archived roadmap](.planning/milestones/v1.14-ROADMAP.md) (shipped 2026-07-03)
- 🚧 **v1.15 Brand Identity & Brand Book** — active (Phases 81-86)

## Active Milestone

**v1.15 Brand Identity & Brand Book**

**Goal:** Pressure-test the written brand book and operationalize it into a self-contained, repo-safe, zero-build `brandbook/` package — reconciled `--cw-*` design tokens, a user-selected logo lockup family, a standalone `file://` HTML brand book (voice, component states, do/don't), plus two tiny repo-integration edits (README header, `mix.exs` `docs()` logo/favicon) — so Chimeway reads as credible on GitHub / HexDocs / landing pages.

**Scope discipline (applies to every phase):** doc/asset-only. No runtime code, no CI changes, `chimeway_admin` untouched (sub-primitive conflicts are DOCUMENTED/DEFERRED, never patched). All work lands under `brandbook/` except the two allowed integration edits (README header region + `mix.exs` `docs()`/optional `package() files:`). All v1.14 doc-contract and release-gate tests must stay green.

**Requirements:** [REQUIREMENTS.md](.planning/REQUIREMENTS.md) — 32 requirements (LOGO, TOKEN, BOOK, VOICE, STATE, A11Y, INTEG, NOTES)

**Research:** [research/SUMMARY.md](.planning/research/SUMMARY.md)

## Phases

### v1.15 Brand Identity & Brand Book

- [ ] **Phase 81: Design Tokens (Reconciliation & Documentation)** — Canonical copy-safe `--cw-*` tokens (CSS + JSON) reconciled with shipped admin CSS; divergences logged as DOCUMENTED/DEFERRED
- [x] **Phase 82: Logo Exploration & Shortlist** — 3-5 fully-worked directions with rationale + ship/defer/reject, each passing the hard-taste and mono/inverse/16px gates
- [ ] **Phase 83: Direction Selection & Final Asset Family (User Checkpoint)** — Human selects the finalist; promote to a full optimized-SVG lockup family + simplified favicon + social derivatives
- [ ] **Phase 84: HTML Brandbook, Voice & Component States** — The primary deliverable: scoped `file://`-safe HTML book assembling tokens, logos, component states, brand voice, and do/don't
- [ ] **Phase 85: Repo Integration (README + HexDocs + Favicon Wiring)** — Surface the real mark on GitHub/HexDocs via minimal in-scope edits, v1.14 contracts still green
- [ ] **Phase 86: Accessibility Audit, Notes & Red-Team Close** — Verify WCAG 2.2 against rendered output, complete decision/research notes, red-team the scope boundary

### Phase 81: Design Tokens (Reconciliation & Documentation)

**Goal:** Establish a canonical, copy-safe `--cw-*` token layer (CSS + JSON) that is the single source of truth every downstream artifact consumes — reconciled verbatim with the shipped `chimeway_admin.css` primitives, with every sub-primitive divergence recorded as a deferred decision rather than patched.

**Depends on:** Nothing (first phase of milestone)

**Requirements:** TOKEN-01, TOKEN-02, TOKEN-03, TOKEN-04, TOKEN-05

**Success Criteria** (what must be TRUE):

1. `brandbook/tokens/tokens.css` defines `--cw-*` custom properties with the 15 primitive colors copied verbatim from shipped `chimeway_admin.css` (zero drift), plus a generalized semantic tier (surface / fg / border / focus / status incl. `--cw-info`).
2. `brandbook/tokens/tokens.json` mirrors the set in hand-authored DTCG (`$value`/`$type`/`$description`) shape with no build tool, covering color, type scale, spacing, radius, border, shadow, motion, focus-ring, and z-index in a two-tier primitive→semantic model (no component tier, no 12-step scales).
3. Light/dark/system theming resolves and every new semantic token has an independently contrast-checked dark value (no `filter: invert()`).
4. `notes/decision-log.md` records every sub-primitive divergence (radius-sm 5px vs 4px; info/cancelled/sending/expired status triads; missing `--cw-info`; net-new motion + z-index tokens) as DOCUMENTED/DEFERRED, and `chimeway_admin.css` shows zero changes.

**Plans:** 3 plans

Plans:
**Wave 1**

- [x] 81-01-PLAN.md — Author brandbook/tokens/tokens.css (:root SSOT: 15 verbatim primitives, generalized semantic tier, light/dark/system theming) [Wave 1]
- [x] 81-02-PLAN.md — Author notes/decision-log.md (DIV-1..DIV-7 divergence ledger, DOCUMENTED/DEFERRED, zero-drift invariant) [Wave 1]

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 81-03-PLAN.md — Author brandbook/tokens/tokens.json (hand-authored DTCG mirror: alias refs, light/dark sibling groups) [Wave 2, depends 81-01]

**Cross-cutting constraints:**

- Both admin CSS files (chimeway_admin/priv/static/chimeway_admin.css + chimeway_admin/assets/css/chimeway_admin.css wrapper) show zero changes — TOKEN-04

### Phase 82: Logo Exploration & Shortlist

**Goal:** Produce a vetted shortlist of 3-5 fully-worked logo directions — each a coherent concept with rationale and a recommendation — that all satisfy the non-negotiable taste constraints and survive the legibility gates, so a human can make an informed pick.

**Depends on:** Phase 81 (consumes reconciled brand colors; independent of the HTML shell, so can run largely in parallel with later book work)

**Requirements:** LOGO-01, LOGO-02, LOGO-05, LOGO-06, NOTES-02

**Success Criteria** (what must be TRUE):

1. `notes/logo-options.md` presents 3-5 distinct, fully-worked directions — each with rationale, pros/cons, and a ship/defer/reject recommendation + confidence (a vetted shortlist, not a raw gallery), with rejected candidates preserved inline as `<svg>` for repo-size discipline.
2. At least one direction is a genuinely integrated typemark — a custom motif worked into the wordmark's letterforms, not a mark placed beside a plain font.
3. No direction uses a rectangular/enclosing background cage; mark and wordmark read as one unified unit (not icon-left/text-right); the primary lockup carries no subtitle; imagery routes the "chime" idea through the path/route/signal/trace metaphor set (no literal music/bell/clapper/note).
4. Every shortlisted mark is demonstrated legible and recognizable at 16px, in single-color mono, and inverse (dark) before shortlisting; clear-space and minimum-size intent is captured.

**Plans:** 1 plan

Plans:
**Wave 1**

- [x] 82-01-PLAN.md — Wave 0 guard script + author notes/logo-options.md (5 directions, ≥2 integrated typemarks, per-direction 16px/mono/inverse proof strips, rejected set) + ephemeral file:// gallery + human legibility/taste checkpoint

**UI hint**: yes

### Phase 83: Direction Selection & Final Asset Family (User Checkpoint)

**Goal:** Capture the human taste decision (the milestone's largest cost/quality lever) and promote the chosen finalist into a complete, optimized-SVG lockup family plus the small derivatives that depend on the final mark.

**Depends on:** Phase 82 (needs the shortlist to choose from)

**Requirements:** LOGO-03, LOGO-04, INTEG-03

**Success Criteria** (what must be TRUE):

1. The user selects a direction at an explicit checkpoint, and the choice (with ship/defer rationale) is recorded in `notes/decision-log.md`.
2. `brandbook/assets/` ships the full lockup family for the finalist — primary horizontal lockup, icon-only mark, wordmark, stacked lockup, mono, inverse, and a simplified favicon mark — as optimized SVGs.
3. Every shipped mark is verified legible and recognizable at 16px, in mono, and inverse before ship.
4. A deliberately-simplified `favicon.svg` (plus the minimal raster fallback platforms require) and a social/OG card (SVG + the one justified PNG raster) are derived from the final mark — not the primary lockup naively resized.

**Plans:** 3 plans

Plans:
**Wave 1**

- [x] 83-01-PLAN.md — Asset tooling: extend logo-guards.sh (`--assets` mode + widened `--scope`), add pinned svgo.config.mjs + Chrome render helper [Wave 1]

**Wave 2** *(depends 83-01)*

- [x] 83-02-PLAN.md — Six-mark lockup family in brandbook/assets/logo/: OFL-recut wordmark + keystone-i, mono/inverse/stacked/icon/icon-mono (optimized SVGs) [Wave 2]

**Wave 3** *(depends 83-02)*

- [x] 83-03-PLAN.md — Simplified favicon set (svg/ico/apple-touch) + OG card (svg/png), decision-log ratification, human perceptual checkpoint [Wave 3]

**UI hint**: yes

### Phase 84: HTML Brandbook, Voice & Component States

**Goal:** Assemble the primary deliverable — a standalone, scoped, `file://`-safe HTML brand book — that renders the finalized tokens and logos alongside component states, brand voice/microcopy, and do/don't usage, proving the system works rather than just describing it.

**Depends on:** Phase 81 (tokens), Phase 83 (final logo family). Voice/microcopy and component-state content is authored here (folded in per research: cheap, content-ready, reuses the book's `.cwb-*` conventions).

**Requirements:** BOOK-01, BOOK-02, BOOK-03, STATE-01, STATE-02, VOICE-01, VOICE-02, VOICE-03

**Success Criteria** (what must be TRUE):

1. `brandbook/index.html` opens directly via `file://` with no server and no build step — all asset references relative, no `fetch()` and no cross-file `<use href>` sprite patterns (Chromium `file://` safe).
2. Brandbook CSS is scoped (`@layer` + `@scope`, `.cw-brandbook` root, `.cwb-*` demo classes) so it cannot leak into the repo or a host app that copies a snippet.
3. The book renders the logo family, color/token swatches, type/spacing sections, the full component-state showcase (hover/focus/active/disabled/loading/error/empty/skeleton/selected) as static token-driven HTML/CSS, do/don't visual pairs (logo/color/spacing misuse), a live light/dark/system theme toggle, and a live contrast matrix — professional and responsive across viewports.
4. Brand voice and tone are documented by context (docs, errors, marketing, CLI) with good/bad examples, including the named reusable "what happened / why it matters / how to fix" error-pattern template and CTA/naming rules (lowercase `chimeway` graphic vs title-case "Chimeway" prose).

**Plans**: 4 plans
- [ ] 84-01-PLAN.md — Guard gate + scoped stylesheet foundation (brandbook-guards.sh + brandbook.css)
- [ ] 84-02-PLAN.md — index.html shell, theme toggle, logo family, token swatches, type/spacing
- [ ] 84-03-PLAN.md — Component-state showcase, do/don't pairs, live contrast matrix
- [ ] 84-04-PLAN.md — Brand voice/microcopy, error template, naming/CTA + final verification

**UI hint**: yes

### Phase 85: Repo Integration (README + HexDocs + Favicon Wiring)

**Goal:** Make the real brand mark visible on the surfaces adopters actually see — the GitHub README and HexDocs — through minimal, tightly-scoped edits that leave every v1.14 contract green.

**Depends on:** Phase 83 (final asset filenames). Done late so config isn't revised mid-flight.

**Requirements:** INTEG-01, INTEG-02, INTEG-04

**Success Criteria** (what must be TRUE):

1. The README header shows the real primary lockup via a relative-path SVG that GitHub resolves natively, replacing any placeholder.
2. `mix.exs` `docs()` wires ExDoc `:logo` and `:favicon` (SVG) so HexDocs renders the brand mark.
3. Integration edits stay in scope — limited to the README header region, docs config, and optional `package() files:` (+= `brandbook/assets`); `chimeway_admin` untouched.
4. All v1.14 doc-contract and release-gate tests still pass after the integration edits.

**Plans**: TBD

### Phase 86: Accessibility Audit, Notes & Red-Team Close

**Goal:** Verify accessibility against named WCAG 2.2 criteria on the *rendered* brand book (not discovered late), complete the decision/research record, and run the milestone-close red-team that locks the `brandbook/`-only scope boundary.

**Depends on:** Phases 84 and 85 (accessibility audits rendered output; the red-team `git diff --stat` covers the integration edits from Phase 85)

**Requirements:** A11Y-01, A11Y-02, A11Y-03, A11Y-04, A11Y-05, NOTES-01, NOTES-03, NOTES-04

**Success Criteria** (what must be TRUE):

1. `notes/accessibility-checks.md` records per-pairing ratios verified against the rendered brandbook — every text fg/bg meeting SC 1.4.3 (4.5:1, or 3:1 large) and non-text/UI (borders, focus rings, meaningful icons) meeting SC 1.4.11 (3:1).
2. Focus is visible and not obscured (SC 2.4.7 / 2.4.11), reduced motion is honored (SC 2.3.3), interactive targets are ≥24×24px (SC 2.5.8), and semantic meaning is never color-alone with a CVD-simulation-verified palette (SC 1.4.1 intent).
3. Every major recommendation carries pros/cons/tradeoffs, an analogue, implementation cost, ship/reject/defer, and confidence (cohesive, not a buffet), and `notes/research.md` captures the research basis and citations.
4. A recorded red-team/skeptic pass closes with a `git diff --stat` scope-boundary audit confirming changes are `brandbook/`-only plus the two allowed integration edits, and a repo-size/binary check.

**Plans**: TBD

<details>
<summary>✅ v1.14 Public Truth and Verification Architecture (Phases 77-80) — SHIPPED 2026-07-03</summary>

- [x] Phase 77: Truth Baseline and Package Model Decision (2/2 plans) — completed 2026-07-03
- [x] Phase 78: Release and Package Truth (3/3 plans) — completed 2026-07-03
- [x] Phase 79: Front Door and Docs IA (1/1 plan) — completed 2026-07-03
- [x] Phase 80: Verification Architecture and CI/DX (4/4 plans) — completed 2026-07-03

Full detail: [milestones/v1.14-ROADMAP.md](.planning/milestones/v1.14-ROADMAP.md)

</details>

<details>
<summary>✅ v1.13 Storage Isolation and Upgrade Path (Phases 73-76.1) — SHIPPED 2026-07-02</summary>

- [x] Phase 73: Storage Prefix Contract (3/3 plans) — completed 2026-06-30
- [x] Phase 74: Prefixed Migration Generator (10/10 plans) — completed 2026-06-30
- [x] Phase 75: Runtime Prefix Propagation (8/8 plans) — completed 2026-07-01
- [x] Phase 76: Prefix Docs, Demo, and Gates (3/3 plans) — completed 2026-07-02
- [x] Phase 76.1: Close gap: GATE-01 - generated prefixed migration runtime proof (1/1 plan) — completed 2026-07-02

Full detail: [milestones/v1.13-ROADMAP.md](.planning/milestones/v1.13-ROADMAP.md)

</details>

## Progress

| Milestone | Phases | Plans | Requirements | Status | Shipped |
|-----------|--------|-------|--------------|--------|---------|
| v1.15 Brand Identity & Brand Book | 81-86 | 0/TBD | 0/32 | In progress | - |
| v1.14 Public Truth and Verification Architecture | 77-80 | 10/10 | 14/14 | Complete | 2026-07-03 |
| v1.13 Storage Isolation and Upgrade Path | 73-76.1 | 25/25 | 20/20 | Complete | 2026-07-02 |
| v1.11 Operator Console Polish & Hardening | 68-72 | 12/12 | 18/18 | Complete | 2026-06-04 |
| v1.10 Ecosystem Completions | 63-67 | 13/13 | 8/8 | Complete | 2026-06-04 |

### v1.15 Phase Status

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 81. Design Tokens (Reconciliation & Documentation) | 3/3 | Complete    | 2026-07-10 |
| 82. Logo Exploration & Shortlist | 1/1 | Complete   | 2026-07-18 |
| 83. Direction Selection & Final Asset Family (User Checkpoint) | 3/3 | Complete   | 2026-07-18 |
| 84. HTML Brandbook, Voice & Component States | 0/TBD | Not started | - |
| 85. Repo Integration (README + HexDocs + Favicon Wiring) | 0/TBD | Not started | - |
| 86. Accessibility Audit, Notes & Red-Team Close | 0/TBD | Not started | - |

---
*Roadmap updated: 2026-07-09 — v1.15 Brand Identity & Brand Book milestone initialized (Phases 81-86)*
