# Feature Research: Chimeway Brand Book / Design-System Package (v1.15)

**Domain:** Self-contained OSS brand book + design-token package for a small Elixir/Phoenix library (not a SaaS design org, not a multi-product company)
**Researched:** 2026-07-09
**Confidence:** HIGH for mature design-system precedent (verified against each system's official docs/brand pages via live web search); MEDIUM for Elixir-ecosystem-specific brand examples (Oban, Fly.io, Phoenix have thin or no public "brand book" documentation, so those citations are necessarily softer)

> Scope note: this file maps the **feature surface** of what a credible brand-book/design-system deliverable contains, categorized table stakes / differentiator / anti-feature, for `.planning/REQUIREMENTS.md` to draw from. It does not re-litigate brand strategy, voice, or color choices already locked in `prompts/chimeway-brand-book.md` — it evaluates what the **package structure and artifact set** should contain to operationalize that spec, per the milestone's hard constraints in `prompts/brand-book-pressure-test.md`.

## Reference Systems Surveyed

| System | What it's actually for | Scale | Why it's a useful precedent here |
|---|---|---|---|
| [GitHub Primer](https://primer.style/) ([Brand](https://primer.style/brand/) vs [Product](https://primer.style/product/)) | Splits a *product* design system (UI components, `--cw-*`-style tokens) from a *brand* system (marketing/identity) as two deliberately separate systems that share primitives | Enterprise, but the Brand/Product split is the exact shape Chimeway needs | Directly validates "brandbook is a new, separate artifact that *reconciles with*, not forks, `chimeway_admin`'s existing `--cw-*` tokens" |
| [Stripe](https://stripe.com/resources/more/what-is-a-visual-identity-for-a-brand-how-it-works-and-how-to-create-the-right-one) brand + [docs](https://stripe.com/blog/accessible-color-systems) | Near-monochrome palette (ink + one accent color), typography-led restraint, docs-site-as-brand-surface | Company, but visually minimal | Proof that "quiet, technical, one accent color, docs are the brand" reads as credible and premium — not generic |
| Tailwind CSS | Wordmark + one simple two-tone icon, brand assets page with light/dark SVGs, no elaborate brand book | Small-to-mid OSS | Proof that a tiny, well-executed logo system (not a big one) is what "good" looks like at OSS-library scale |
| [IBM Carbon](https://carbondesignsystem.com/) | Full primitive→semantic→component token architecture, exhaustive [disabled/hover/focus state docs](https://carbondesignsystem.com/patterns/disabled-states/) | Enterprise, dozens of products, multiple themes | Best citation for token/state **depth ceiling to avoid** — Carbon's component-level token granularity is explicitly over-engineered for one small library |
| [Atlassian Design System](https://atlassian.design/foundations/tokens/design-tokens) | `foundation.property.modifier` token naming convention, light/dark/high-contrast theming | Enterprise, multi-product | Validates Chimeway's existing `--cw-{category}-{name}` naming discipline; multi-product theming is the over-engineering line not to cross |
| [Shopify Polaris](https://polaris-react.shopify.com/content/fundamentals) content guidelines | Industry-leading voice/tone + [error-message](https://legacy.polaris.shopify.com/patterns/error-messages) guidance | Enterprise | Best citation for the CTA/microcopy rules already drafted in the written brand book (§9–11) |
| [Radix Colors](https://www.radix-ui.com/colors) | 12-step, APCA-contrast-verified, light/dark-paired accessible color scales | Small OSS (Radix/WorkOS) | Cite the *concept* (verified accessible light/dark pairs per semantic role) — not the tooling (a full 12-step scale generator is overkill for ~14 brand tokens) |
| [GOV.UK Design System](https://design-system.service.gov.uk/components/error-message/) | Canonical accessible [error-message pattern](https://design.homeoffice.gov.uk/accessibility/interactivity/error-messages) (what went wrong / why / how to fix), WCAG 2.2 AA compliance, "never color alone" rule | Government, but purely functional/restrained visual language | This is the single best citation for Chimeway's own "why wasn't this sent?" explainability voice — GOV.UK is doing, at doc scale, what Chimeway's brand book already prescribes in §21 |
| [Vercel Geist](https://vercel.com/geist/brands) | Modern dev-tool brand kit: logo usage rules, ~40 color tokens, 15 type styles, 9 radii, 12 spacing steps, bespoke typeface | Company, dev-tool audience closest to Chimeway's actual audience | Best citation for **token-count ceiling** appropriate to a modern minimal dev brand (dozens, not hundreds, of tokens); bespoke typeface commissioning is flagged as an anti-feature here |
| [Fly.io "Using Our Brand"](https://fly.io/docs/about/brand/) | A real, practical, non-bloated brand usage page: color/mono landscape lockup, portrait lockup, standalone brandmark for small sizes, low-contrast-background guidance | Infra dev-tool company, not enterprise | Closest scale/audience analog to Chimeway; its lockup variant set (landscape, portrait/stacked, mono, standalone small-size mark) maps almost 1:1 to what the milestone needs |
| Oban / Phoenix (Elixir ecosystem) | No public brand book; simple wordmark + occasional icon, no formal token system | Small OSS Elixir libraries | Validates that **most Elixir/Hex libraries ship zero formal branding** — Chimeway doing this well at all is itself the differentiator in this ecosystem, not an arms race against Stripe |

---

## Feature Landscape

### 1. Logo System

Hard constraints in force for every row below (from `prompts/brand-book-pressure-test.md`): no rectangular background cages (transparent by default); mark + wordmark visually unified (not "icon left of plain text"); ≥1 fully integrated typemark direction; multiple directions offered for the user to pick, each with rationale; no clipart/generic bell-and-notification-badge cliché imagery; primary lockup carries no subtitle/tagline.

| Feature | Why Expected (table stakes) | Complexity | Notes / Precedent |
|---|---|---|---|
| Primary horizontal lockup (mark + wordmark) | Every reference system ships this as the default usage form (Primer, Fly.io landscape lockup, Vercel) | MEDIUM | Must satisfy "unified" constraint — Fly.io's landscape lockup keeps mark and wordmark on one tight baseline, not spaced apart; use as the proximity/spacing precedent |
| Icon-only mark (logomark) | Needed for favicon, social avatar, small UI chrome, GitHub org avatar — every system studied ships one | MEDIUM | Must remain recognizable without wordmark per the existing brand doc §13 rule; Fly.io explicitly reserves its standalone brandmark for "extremely small dimensions" — same intended use here |
| Wordmark / logotype (type-only) | Needed for contexts where the mark is redundant (e.g., repeated nav headers, long-form docs) | LOW | Tailwind and Stripe both lean on clean wordmark-only usage in dense docs contexts |
| **Integrated typemark** (motif worked into the letterforms, not a mark bolted beside text) | Explicit hard constraint; also the single highest-differentiation logo asset in the whole package | HIGH | No major system studied does this in the "customized letterform with a worked-in motif" sense as far as public brand pages show — this is genuinely a differentiator, not table stakes elsewhere, but the user has made it a **hard requirement** here, so it is treated as table stakes for this project specifically |
| Stacked / vertical lockup | Needed for square contexts (social avatar with text, narrow sidebars, sticker layouts) | MEDIUM | Fly.io ships a portrait (stacked) lockup as a named, first-class variant alongside landscape — direct precedent |
| Monochrome / single-color version | Needed for constrained-color contexts: stamps, single-ink print, GitHub README badges on colored backgrounds | LOW | Fly.io ships "monochrome navy and white" landscape as its own named asset; existing brand doc §13 already requires "must work in one color" |
| Inverse (for dark backgrounds / dark mode) | Needed anywhere the site/docs/admin support `prefers-color-scheme: dark` — which Chimeway's own token system already does | LOW | Direct dependency: `chimeway_admin` already ships light/dark/system theme contracts (v1.11 DES-02) — the inverse lockup must be tested against that existing dark palette, not invented fresh |
| Favicon / small-size simplified mark | 16–32px browser tab and GitHub avatar contexts routinely break marks that work fine at 120px | MEDIUM | Primer/Octicons discipline (12/16/24px fixed sizes, no scaling a detailed mark down) is the right precedent: **a genuinely simplified variant, not just a scaled-down SVG**, is required |
| Optional tagline/subtitle lockup (secondary, not primary) | User explicitly wants this available but NOT as the default | LOW | Explicit hard constraint: this must be a clearly labeled secondary asset (e.g. `logo-with-tagline.svg`), never substituted for the primary in do/don't guidance |
| Clear-space rule (unit-based, e.g. "1x = cap-height of wordmark") | Every system studied defines this; without it, third-party embedding (README badges, social cards) crowds the mark | LOW | Already specified in written brand book §13 ("1x = height of the lowercase 'c'") — brandbook package just needs to visualize it, not invent it |
| Minimum size rules (digital px + print mm) | Prevents illegible shrinking; already drafted in §13 | LOW | Reuse existing numbers; verify at actual rendered SVG once finalist is chosen |
| Do/Don't usage grid | Universal across every system surveyed (Primer, Fly.io, Vercel, Carbon) | LOW–MEDIUM | Must explicitly codify the user's pet peeves as named "don't" cards: don't box the mark in a rectangle/background cage, don't separate mark and wordmark, don't add a subtitle to the primary lockup, don't stretch/skew, don't add drop shadows/gradients (already in §13) |
| Social/OG card crop of the mark | Needed for GitHub social preview (1280×640), Open Graph (1200×630), X/Twitter (1200×675) — sizes already specified in §30 | LOW | Reuse existing spec; this is asset production, not a new design decision |

**Complexity/cost driver worth flagging explicitly:** the milestone already commits to 3–5 "fully-worked" logo directions (`prompts/brand-book-pressure-test.md`), each needing its own mark, wordmark, and at least a horizontal lockup to be comparable. A full lockup set (10 variants × 3–5 directions) is the single largest line item in this milestone. This is the one place where "table stakes" and "milestone scope decision" collide — treat only the **finalist** direction as needing the complete 10-variant matrix; the non-selected directions need just mark + wordmark + one lockup to make an informed choice (this is a scoping note for `notes/decision-log.md`, not a contradiction of the milestone's "fully-worked" instruction — "fully worked" should mean "resolved as a coherent concept," not "every one of the 10 export variants produced 5 times").

---

### 2. Design Tokens

| Feature | Why Expected (table stakes) | Complexity | Notes / Dependency |
|---|---|---|---|
| Primitive color tokens (the 14-color palette already in §14) | Baseline for any token system (Primer, Carbon, Atlassian, Radix, Vercel all start here) | LOW | Already fully specified in `prompts/chimeway-brand-book.md` §14 — this is transcription/reconciliation work, not new design |
| Semantic state colors (success/warning/error/**info**) | Table stakes in every system surveyed (Carbon, Polaris, GOV.UK, Radix) | LOW–MEDIUM | **Gap found:** the written brand book defines `--cw-success`, `--cw-warning`, `--cw-danger` but no distinct `--cw-info` — it overloads `--cw-blue` for both "interactive secondary" and "info states." Brandbook token set should add an explicit `--cw-info` alias so intent is unambiguous (Radix/Carbon both keep interactive-blue and info-blue as separate semantic roles even when they share a hue) |
| Type scale tokens | Universal (already specified §15/§28) | LOW | Reuse `--cw-text-*` as-is |
| Spacing scale tokens | Universal (already specified §16/§28) | LOW | Reuse `--cw-space-*` as-is |
| Radius scale tokens | Universal (already specified §16/§28) | LOW | Reuse `--cw-radius-*` as-is |
| Border tokens | Table stakes (Primer, Atlassian both name border tokens distinctly from color primitives) | LOW | `--cw-line` exists; needs promotion to an explicit `--cw-border-*` semantic layer per Atlassian's `foundation.property.modifier` convention already implicitly followed by `--cw-radius-sm` etc. |
| Shadow/elevation tokens | Table stakes; already specified (`--cw-shadow-sm/md/focus`) | LOW | Reuse as-is; brand book already prefers borders over shadows (§16), which is the right restraint level — do not add a Carbon-style multi-layer elevation system |
| **Motion tokens** (duration/easing, not just the `prefers-reduced-motion` media query) | Table stakes in modern systems (Vercel Geist, Carbon both name duration/easing tokens) | MEDIUM | **Gap found:** §20 specifies motion *personality* and a reduced-motion override, but no named `--cw-motion-duration-*` / `--cw-motion-ease-*` tokens exist yet. Net-new but small (2–4 tokens is sufficient) |
| **Focus-ring token** | Table stakes for accessibility-forward systems (Carbon requires 3:1 contrast focus rings on all interactive elements; GOV.UK is uncompromising on this) | LOW | Already exists: `--cw-shadow-focus`. Brandbook should just document it as a first-class accessibility token, not bury it inside the shadow group |
| **Z-index scale** | Common but easy to skip; needed once dropdowns/modals/toasts exist anywhere in the ecosystem (`chimeway_admin`) | LOW–MEDIUM | **Gap found:** no z-index tokens exist yet anywhere in the written spec or (as far as this research can tell) in `chimeway_admin`. Small, cheap to add (5–6 layered values: base/dropdown/sticky/overlay/modal/toast) — worth including now since it's nearly free and prevents future ad-hoc `z-index: 9999` drift |
| Light/dark/system color-scheme mapping | Table stakes for any modern token set (Radix ships light/dark pairs per step; `chimeway_admin` already has light/dark/system theme contracts) | MEDIUM | Direct dependency on existing `chimeway_admin` v1.11 DES-02 theme contracts — the brandbook's `tokens.css` must map onto (not duplicate/diverge from) those existing `--cw-*` dark-mode values |

**Anti-features (over-engineering for this scale):**

| Feature | Why it looks appealing | Why it's wrong here | Do instead |
|---|---|---|---|
| Component-level tokens (e.g. `--cw-button-primary-bg-hover` distinct from a generic `--cw-interactive-hover`) | Carbon and Atlassian both do this at massive scale | One small library with one optional admin package does not have enough component surface area to justify a third token tier; it adds maintenance burden with no payoff | Two-tier system only: primitive → semantic. Let component CSS reference semantic tokens directly |
| Full 12-step perceptual color scale per hue (Radix Colors style, generated tooling) | Looks rigorous, "accessible by construction" | Chimeway has ~14 brand colors total; generating a 12-step scale per hue would produce 100+ tokens for a project with one optional UI package | Borrow the *concept* — verify each semantic pairing (fg/bg) against WCAG AA by hand or with a simple contrast checker, document the verified pairs, stop there |
| Automated token build pipeline (Style Dictionary or similar) transforming a single source into JSON/CSS/Tailwind/SCSS outputs | Common in larger orgs (Atlassian, Carbon) | No existing build tooling in this repo; introducing one purely for ~30–40 tokens is a new build system for no proportionate benefit, and the milestone constraints explicitly discourage "no new build system unless clearly justified" | Hand-author `tokens.json` and `tokens.css` in parallel (small enough to keep in sync manually); note the duplication risk in `notes/decision-log.md` |
| Multi-brand / multi-theme token layering (e.g. white-label theming) | Enterprise systems support many product brands off one token base | Chimeway has exactly one brand and one optional themed package | Skip entirely |

---

### 3. Color System

| Feature | Why Expected | Complexity | Notes |
|---|---|---|---|
| Brand primary + secondary/accent colors | Universal | LOW | Already specified (`--cw-teal` primary action, `--cw-brass` accent) |
| Semantic state colors with icon+label pairing (never color alone) | GOV.UK: "you should not use colour alone to identify an error"; already stated in brand book §14 accessibility rules | LOW | Reuse; verify the admin UI (`chimeway_admin`) actually pairs status pills with text labels, not just color, as it currently claims to (EXPL-01/02 from v1.11) |
| Verified AA contrast pairs for every documented fg/bg combination | Table stakes for any credible accessible system (Stripe's own [accessible-color-systems](https://stripe.com/blog/accessible-color-systems) post, Radix's APCA-verified scales, GOV.UK WCAG 2.2 AA compliance) | LOW–MEDIUM | Brand book §14 lists combinations but does not show computed contrast ratios — brandbook artifact should render actual ratios next to each swatch pair (this is where "generating screenshots of color palette" from the user's original prompt directly applies) |
| Light/dark/system parity | Table stakes for any 2026-era system; `chimeway_admin` already ships this | MEDIUM | **Gap found:** the written brand book's dark-mode guidance (§14/§29) is thin — only 3 dark combinations are named (`--cw-paper`/`--cw-night`, `--cw-brass`/`--cw-night`, `--cw-mint`/`--cw-night`). A credible dark theme needs the *same* semantic coverage as light (status colors, borders, focus rings) — this is real net-new design work, not just documentation, and should be flagged as a decision point requiring its own pass, reconciled against what `chimeway_admin`'s dark theme already renders today |
| Distinct `info` semantic slot | See Design Tokens section above | LOW | Same gap, same fix |

**Anti-features:**

| Feature | Why requested | Why problematic | Alternative |
|---|---|---|---|
| Full CMYK/Pantone print color specification | "Real" brand books often include this | No print production planned; Pantone licensing/verification is pure overhead for an OSS repo | Hex + RGB only; note CMYK approximation only if/when actual print swag is produced |
| Colorblind-simulation image gallery (deuteranopia/protanopia renders of every screen) | Feels thorough and accessibility-minded | High production cost for marginal incremental insight once "never color alone + verified AA contrast" rules are already enforced | State the rule, verify a couple of key status-pill screens, move on |

---

### 4. Brand Voice & UX Microcopy

Most of this category is **already written** in `prompts/chimeway-brand-book.md` §9–11, §21–26, §32–34 — this is the lowest-complexity area of the whole milestone. The job is to extract, structure, and cross-link existing content into the brandbook artifact, not invent new copy.

| Feature | Why Expected | Complexity | Notes |
|---|---|---|---|
| Voice principles (clear-before-clever, explain decisions, calm about failure, respect the recipient, developer-to-developer) | Table stakes for any credible OSS voice guide; matches Polaris's "sound human" and GOV.UK's plain-language mandate | LOW | Already fully drafted (§9) — transcribe |
| Tone-by-context matrix (README / docs / errors / admin UI / release notes / social) | Table stakes (Polaris explicitly separates tone by surface) | LOW | Already implicitly present across §25 "Voice examples" — brandbook should make this an explicit table, not scattered prose |
| **"What happened / why it matters / how to fix" error pattern, as a named, reusable template** | This is precisely GOV.UK's canonical [error-message component](https://design-system.service.gov.uk/components/error-message/) pattern, and Chimeway's own brand book already practices it in every "Good:" example without naming it as a pattern | LOW–MEDIUM | **Actionable gap:** promote from "implicit, only visible via examples" to an explicit, labeled pattern card in the brandbook (mirrors GOV.UK's dedicated component page) — this is a differentiator opportunity, not just documentation |
| CTA style rules (no "book a demo," no "start free trial") | Table stakes for OSS positioning; already thorough (§23) | LOW | Transcribe |
| Naming rules (product name casing, package naming, module naming, internal feature naming) | Table stakes; already exhaustive (§11) | LOW | Transcribe |
| Good/bad copy examples per surface | Universal pattern across GOV.UK, Polaris, and the existing brand book itself (§25) | LOW | Transcribe and lightly expand with 1–2 admin-UI-specific pairs if gaps exist |
| Actionable, verb-first, concise microcopy rule | Polaris: "actionable like 'do x' rather than permissive like 'you can x,'" concise ≤2 sentences | LOW | Add as an explicit rule alongside the existing voice principles — currently implied but not stated as a formal rule |

**Differentiator:** presenting the error pattern as a literal, fillable template (three labeled slots with a worked Chimeway example next to a generic template) rather than leaving it as prose-only guidance — this is cheap to build and elevates the artifact above "a page of adjectives," which is the most common failure mode of small-project brand docs.

**Anti-features:**

| Feature | Why requested | Why problematic | Alternative |
|---|---|---|---|
| Full localization / i18n voice guide (tone variants per market/language) | "Real" brand orgs do this | Chimeway is English-only OSS docs with no localization pipeline | Skip; revisit only if the project ever ships translated docs |
| Formal style-guide governance/approval workflow (submission process, style council) | Enterprise brand teams have this | One (or a few) maintainer(s); process overhead with no throughput to justify it | A single `notes/decision-log.md` with ship/reject/defer entries is sufficient governance |

---

### 5. Component States

| Feature | Why Expected | Complexity | Notes / Dependency |
|---|---|---|---|
| Hover / focus / active / disabled | Universal baseline (Carbon's [disabled-states](https://carbondesignsystem.com/patterns/disabled-states/) pattern page, GOV.UK component pages) | LOW–MEDIUM | Buttons/links/inputs already have implicit rules in §16 (borders>shadows) and §28 (focus shadow token) — needs static HTML/CSS demonstration, not new design |
| Loading / skeleton | Table stakes for any modern system with async UI (`chimeway_admin` has async trace/recovery flows) | MEDIUM | No existing skeleton pattern documented anywhere in the written brand book — this is genuinely net-new, though low-risk (a shimmer/pulse block using existing `--cw-porcelain`/`--cw-line` tokens is sufficient; do not invent a new animation language) |
| Error / empty | Table stakes; directly ties to the "why wasn't this sent?" signature feature already specified (§21) | LOW–MEDIUM | Reuse existing error-state copy examples; empty states need 1–2 new copy examples (e.g., "No traces yet") |
| Selected | Table stakes for any list/table UI (admin trace lookup, filters) | LOW | Straightforward extension of the existing status-pill/border system |
| Documenting states as their own dedicated page/section (not buried in a generic component gallery) | Carbon and GOV.UK both give disabled/error states first-class, separately linked documentation pages | LOW | Structural decision for the brandbook IA — cheap, high clarity payoff |

**Complexity/dependency flag:** `chimeway_admin` (v1.11 DES-01..04) already ships responsive shell primitives, theme contracts, and reduced-motion-safe interactions in production. The brandbook's job here is to **document and screenshot the states that already exist in `chimeway_admin`**, plus define the states that don't exist yet anywhere (loading/skeleton is the only clear gap) — not to redesign the admin console. This keeps the milestone's stated rollout boundary intact ("full `chimeway_admin` re-theme deferred to a follow-on milestone").

**Anti-feature:**

| Feature | Why requested | Why problematic | Alternative |
|---|---|---|---|
| A live, interactive Storybook/Ladle-style component library wired to real `chimeway_admin` component code | Feels like the "proper" way to document states | New build tooling + new dependency + real engineering scope that belongs to a `chimeway_admin` re-theme milestone, not a doc/asset-only brand milestone | Static HTML/CSS pages in `brandbook/examples/components.html` that *simulate* each state with class toggles — same visual value, zero new tooling, matches the milestone's "no new build system" constraint |

---

### 6. The Brandbook Document Itself (Information Architecture)

| Section | Why Expected | Complexity | Precedent |
|---|---|---|---|
| Overview / brand summary (one-line idea, positioning, what it is/isn't) | Universal opener across every brand page surveyed | LOW | Already written (§1–8) — transcribe |
| Logo & usage (variants, clear-space, min-size, do/don't) | Universal, and the section carrying the most net-new visual work this milestone | HIGH | Fly.io and Vercel Geist brand pages are the closest scale/audience analogs for structure |
| Color (palette + contrast notes + light/dark) | Universal | LOW–MEDIUM | Existing §14, needs computed contrast ratios added |
| Typography (scale, weights, line-heights, stack) | Universal | LOW | Existing §15, transcribe |
| Spacing / radius / shadow / motion tokens | Universal in modern token-based systems (Vercel Geist keeps this compact: 9 radii, 12 spacing steps — a good ceiling reference) | LOW | Existing §16/§28, plus small additions (motion, z-index, info color) |
| Iconography | Table stakes once any icon set is adopted (Primer's Octicons discipline: fixed sizes, MIT-licensed, no ad-hoc SVGs) | LOW | Already specified — Heroicons/Octicons recommendation exists in §17; reuse |
| Voice & content (voice principles, tone-by-context, error pattern, naming rules) | Universal, and the cheapest section (content already exists) | LOW | See Section 4 above |
| Component states | Universal | MEDIUM | See Section 5 above |
| Accessibility statement / checks | Table stakes for a system that claims "accessible by default" (GOV.UK publishes a dedicated [accessibility statement](https://design-system.service.gov.uk/accessibility-statement/)) | LOW | Maps directly to the milestone's planned `notes/accessibility-checks.md` |
| Do/Don't summary | Universal closing section across every system surveyed | LOW | Already drafted (§34), transcribe and pair with visual do/don't grids for the logo |
| Downloads / assets index | Table stakes for any brand page meant to be *used*, not just read (Fly.io, Vercel Geist both structure their brand pages this way) | LOW | Simple linked list to `assets/` |
| Credits / license / decision-log link | Good OSS hygiene; ties the visual artifact back to the reasoning artifacts | LOW | Links to `notes/decision-log.md`, `notes/logo-options.md` |

**Format decisions already correctly scoped by the milestone (validated, not re-litigated):**
- Standalone HTML, not PDF — matches the "web-based brand portals outperform PDFs for teams that update guidelines frequently" finding, and is dramatically easier to keep byte-accurate in git than a binary PDF.
- Self-contained `brandbook/` folder, vector-first (SVG/HTML/CSS/JSON/MD), no bundled font binaries — directly avoids the two failure modes competitive research turns up most often for small-project brand docs: repo bloat and stale, unmaintained PDFs.

**Anti-features:**

| Feature | Why requested | Why problematic | Alternative |
|---|---|---|---|
| Multi-page marketing microsite with a CMS/build pipeline | "Professional" brand sites (Stripe, Vercel) are multi-page | New hosting/build surface for a doc that needs to `file://` open per the user's explicit requirement | Single (or a small handful of) self-contained HTML file(s) with anchor-linked sections |
| Figma (or any design-tool) file as source of truth | Standard at every company studied | No design-tool workflow exists in this repo; introduces an external, non-git-native dependency for a project whose explicit value prop is local-first, self-contained tooling | SVG is the source of truth, versioned directly in git |
| Print collateral beyond stickers (business cards, letterhead, pitch decks) | "Real" brand books often include these | Chimeway is non-commercial OSS infrastructure with no sales function | Sticker ideas already scoped in §31; stop there |
| Formal trademark registration / legal usage-restriction apparatus (cf. Fly.io's "brand assets are exclusive property" legal language) | Companies with trademarks need this | Chimeway explicitly is not incorporated commercial IP requiring enforcement; brand doc §2 even flags the name isn't legally cleared | A short, friendly "please don't imply endorsement" usage note is sufficient — no legal boilerplate |
| Publishing the brandbook as a versioned Hex package | Chimeway publishes packages for code | It's documentation/assets, not runtime code; forcing it into the Hex release pipeline adds versioning overhead with no consumer need | Keep it in the main repo, referenced by README, not separately released |

---

## Feature Dependencies

```
Existing chimeway_admin --cw-* tokens (v1.11 DES-01..04, shipped)
    └──constrains/must-reconcile-with──> brandbook tokens.json / tokens.css
                                              └──requires──> Semantic color layer (add --cw-info, verify AA pairs)
                                              └──requires──> Motion tokens (net-new, small)
                                              └──requires──> Z-index scale (net-new, small)
                                              └──enables──> Component state documentation (Section 5)

Written brand spec (prompts/chimeway-brand-book.md, §1-35)
    └──feeds directly──> Brand voice & microcopy section (near-zero new authoring)
    └──feeds directly──> Color system palette + Typography (transcription + contrast verification)
    └──feeds directly──> Logo direction constraints (§13 rules -> hard constraints in brief)

Logo system (Section 1)
    └──independent of──> Design tokens / Color system (can be designed in parallel)
    └──feeds into──> Favicon, README header, social cards (already scoped as this-milestone rollout boundary)

Design tokens (Section 2) + Color system (Section 3)
    └──both required by──> Component states (Section 5) — cannot document hover/focus/disabled states credibly without finalized semantic + focus-ring tokens

All of the above (1-5)
    └──required by──> The brandbook HTML document itself (Section 6) — it is the assembly/presentation layer, has no independent content of its own

Component states (Section 5) ──documents, does not redesign──> existing chimeway_admin UI (out of scope to change this milestone)
```

### Dependency Notes

- **Design tokens require reconciliation with existing `--cw-*` tokens, not a fork:** this is the single most important dependency in the whole milestone. Primer's explicit Brand/Product design-system split (`primer.style/brand/` vs `primer.style/product/`) is the right mental model — the brandbook is a **new, brand-facing system that shares primitives with the existing product system**, not a competing token namespace.
- **Component states depend on tokens being finalized first:** hover/focus/disabled documentation is meaningless if the focus-ring or semantic-info tokens are still in flux. Sequence tokens before component-state documentation within the milestone's plan.
- **The brandbook HTML document is purely an assembly layer:** it has no content of its own and should be one of the last things finalized, once logo direction is chosen and tokens/voice/states are stable — assembling it early against unstable inputs risks rework.
- **Logo system is the one track that can run fully in parallel** with tokens/color/voice work, since it has no dependency on the token reconciliation work.

---

## MVP Definition

The milestone's target features (`.planning/PROJECT.md` "Current Milestone: v1.15") already constitute a well-scoped MVP validated by this research — the sections below annotate rather than override that scope.

### Launch With (v1 — matches milestone-committed scope)

- [ ] Logo system: 3–5 worked directions (full lockup matrix for the finalist; mark+wordmark+one lockup for the rest), no rectangular cages, ≥1 integrated typemark, unified mark+wordmark proximity, primary lockup with no subtitle — **essential**: this is the milestone's hardest, most differentiated deliverable and its explicit hard constraint set
- [ ] Design tokens: reconciled `tokens.json` + `tokens.css` covering color (incl. new `--cw-info`), type, spacing, radius, border, shadow, motion (net-new), focus-ring, z-index (net-new) — **essential**: everything downstream (components, brandbook, future admin re-theme) depends on this being right
- [ ] Standalone HTML brandbook (`brandbook/index.html`) — **essential**: this is the primary deliverable and the assembly point for everything else
- [ ] Brand voice & microcopy section, including a named, reusable "what happened / why it matters / how to fix" error-pattern template — **essential but cheap**: 90% already exists in the written spec, this is extraction + one small new pattern card
- [ ] Component states (hover/focus/active/disabled/loading/error/empty/skeleton/selected) as static documented examples — **essential**: named explicitly in the milestone's target features; loading/skeleton is the only genuinely net-new pattern
- [ ] Decision notes + red-team pass (`notes/decision-log.md`, `notes/logo-options.md`, `notes/accessibility-checks.md`) — **essential**: this is what makes the milestone's recommendations defensible and keeps future maintainers from re-litigating settled choices

### Add After Validation (v1.x — explicitly deferred per milestone framing)

- [ ] Full `chimeway_admin` `cw.tokens` re-theme to actually consume the reconciled brandbook tokens end-to-end — trigger: once the brandbook token set is chosen and stable, and once there's a concrete UI-polish need
- [ ] A live interactive component-states demo wired to real `chimeway_admin` LiveView code (vs. the static HTML documented this milestone) — trigger: only if `chimeway_admin` gets a dedicated UI-polish milestone
- [ ] Documented OSS webfont recommendation actually adopted as a loaded webfont (vs. system-font-stack default) — trigger: only if there's a concrete case where system fonts visibly hurt brand distinctiveness in a shipped surface (landing page, docs site)

### Future Consideration (v2+ / likely never, given non-commercial OSS scope)

- [ ] Print collateral beyond stickers — defer: no sales/marketing function exists
- [ ] Localization/i18n voice guide — defer: no localized docs pipeline exists
- [ ] Formal trademark/legal brand-usage apparatus — defer: name isn't legally cleared per the brand doc's own caveat, and the project has no commercial IP-enforcement need
- [ ] Bespoke commissioned typeface (Geist-style) — defer indefinitely: disproportionate cost for a small OSS library; system-font-stack + SVG-outlined wordmark already covers the differentiation need without font-licensing risk

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---|---|---|---|
| Logo system (multi-direction, hard-constraint-compliant) | HIGH | HIGH | P1 |
| Design tokens (reconciled, incl. info/motion/z-index gaps) | HIGH | MEDIUM | P1 |
| Standalone HTML brandbook document | HIGH | MEDIUM | P1 |
| Brand voice & microcopy extraction + error-pattern template | HIGH | LOW | P1 |
| Component states (static documentation) | MEDIUM–HIGH | MEDIUM | P1 |
| Decision notes + red-team pass | HIGH | LOW–MEDIUM | P1 |
| Dark-mode semantic color completeness (currently thin, flagged gap) | MEDIUM | MEDIUM | P1 (rolled into tokens/color work, not separable) |
| Live interactive component demo wired to real admin code | LOW–MEDIUM | HIGH | P3 |
| Bespoke webfont adoption | LOW | HIGH | P3 |
| Print collateral beyond stickers | LOW | MEDIUM | P3 |
| Multi-brand/theme token layering | LOW | HIGH | P3 (reject, not just defer) |
| Component-level token tier (Carbon-style) | LOW | HIGH | P3 (reject, not just defer) |

---

## Reference-System Feature Comparison

| Capability | Primer | Stripe | Tailwind | Carbon | Atlassian | Polaris | Radix | GOV.UK | Vercel Geist | Chimeway approach |
|---|---|---|---|---|---|---|---|---|---|---|
| Separate brand vs. product design system | Yes (explicit split) | Implicit | No (single small system) | Yes (multi-product) | Yes | Implicit | No | No | No | **Yes — brandbook is new, reconciled with existing `chimeway_admin` product tokens, not merged into one system** |
| Multiple logo directions shown for selection | No (single canonical logo) | No | No | No | No | No | No | No (gov crest, fixed) | No | **Yes — 3–5 directions, hard requirement** |
| Integrated typemark (motif in letterforms) | No | No (wordmark only) | Partial (icon+wordmark, not integrated) | No | No | No | No | No | No | **Yes — ≥1 direction required, genuine differentiator** |
| Formal error-message pattern (what/why/how-to-fix) | No (product-level only) | No | No | Partial | Yes (implicit) | Yes (explicit) | No | **Yes (canonical reference)** | No | Adopt GOV.UK/Polaris pattern, already implicit in written voice doc — make it explicit |
| Component-level token tier | No | No | No | **Yes** | Yes | No | No | No | No | Reject — two-tier (primitive/semantic) only |
| Token count (rough order of magnitude) | Dozens | Not published | Dozens (Tailwind config scale) | Hundreds+ | Hundreds+ | Dozens | ~12/scale × N hues | N/A (mostly CSS classes) | ~76 total across color/type/radius/space | **~40-50, closest to Vercel Geist's ceiling** |
| Bespoke commissioned typeface | No | Yes (Söhne, licensed) | No | Yes (IBM Plex, but OSS-licensed) | No | No | No | Yes (GDS Transport, gov-licensed) | Yes (Geist, custom-built) | **No — system stack + OSS webfont recommendation only** |
| HTML-first standalone brand document | Partial (multi-page site) | No (marketing site) | Partial | Partial (docs site) | Partial (docs site) | Partial | Partial | Partial (service manual site) | Partial (brand page) | **Yes — single self-contained, `file://`-openable HTML artifact, closest in spirit to Fly.io's single practical brand page** |

---

## Sources

- [GitHub Primer](https://primer.style/) — [Brand](https://primer.style/brand/) vs [Product UI](https://primer.style/product/) split; [Octicons usage guidelines](https://primer.style/octicons/usage-guidelines/) (fixed 12/16/24px sizing discipline)
- [Stripe — What is a visual identity for a brand?](https://stripe.com/resources/more/what-is-a-visual-identity-for-a-brand-how-it-works-and-how-to-create-the-right-one)
- [Stripe — Designing accessible color systems](https://stripe.com/blog/accessible-color-systems)
- [IBM Carbon Design System — Disabled states](https://carbondesignsystem.com/patterns/disabled-states/)
- [IBM Carbon Design System — Color overview](https://carbondesignsystem.com/elements/color/overview/)
- [Atlassian Design System — Design tokens](https://atlassian.design/foundations/tokens/design-tokens)
- [Atlassian Design System — Foundations overview](https://atlassian.design/foundations)
- [Shopify Polaris — Content fundamentals](https://polaris-react.shopify.com/content/fundamentals)
- [Shopify Polaris — Error messages pattern](https://legacy.polaris.shopify.com/patterns/error-messages)
- [Radix Colors](https://www.radix-ui.com/colors) — [GitHub](https://github.com/radix-ui/colors)
- [GOV.UK Design System — Error message component](https://design-system.service.gov.uk/components/error-message/)
- [Home Office (UK) Design Manual — Error messages](https://design.homeoffice.gov.uk/accessibility/interactivity/error-messages)
- [GOV.UK Design System — Accessibility statement](https://design-system.service.gov.uk/accessibility-statement/)
- [Vercel Geist — Brands](https://vercel.com/geist/brands)
- [Vercel Geist — Introduction](https://vercel.com/geist/introduction)
- [Fly.io — Using Our Brand](https://fly.io/docs/about/brand/)
- [Oban (GitHub)](https://github.com/oban-bg/oban) / [Oban Pro](https://oban.pro/) — no formal public brand book found, used as negative-space evidence for Elixir-ecosystem branding norms
- Internal: `.planning/PROJECT.md`, `prompts/chimeway-brand-book.md` (v0.1 written brand spec, §1–35), `prompts/brand-book-pressure-test.md` (milestone handoff, hard taste constraints, artifact structure)

---
*Feature research for: Chimeway v1.15 Brand Identity & Brand Book*
*Researched: 2026-07-09*
