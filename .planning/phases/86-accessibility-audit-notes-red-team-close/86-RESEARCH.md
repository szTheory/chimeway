# Phase 86: Accessibility Audit, Notes & Red-Team Close - Research

**Researched:** 2026-07-27
**Domain:** WCAG 2.2 accessibility verification of a rendered static HTML brand book (doc/asset-only); citation basis for `notes/research.md` + `notes/accessibility-checks.md` + `notes/red-team.md`
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 (contrast method):** The per-pairing table in `notes/accessibility-checks.md` is produced by a **small, dependency-free, re-runnable offline calc** (shell/awk, matching the repo's guard-script idiom) that reads hex values straight from `brandbook/tokens/tokens.css` and applies the **same WCAG relative-luminance formula already inlined** in `brandbook/index.html`. The in-page live contrast matrix is cited as *rendered-output* proof but is **not** the A11Y-05 evidence of record on its own (it scores only **8 text cells** and never covers status triads, borders, focus rings, or disabled states). The table must cover **light + dark** for: every text fg/bg pair, status triads (text/surface/border ×5), panel/card borders, focus rings, and both disabled pairs.
- **D-02 (findings → document-as-exempt, never patch tokens):** Sub-threshold pairings are recorded as **documented WCAG exemptions**, not fixed. No text pair forces a change (only sub-4.5 text is *disabled* text = 3.92:1 light, SC 1.4.3 exempts inactive components; dark disabled 4.92 passes anyway). All status borders fail 3:1 vs their own surface and panel borders are 1.29–1.91:1 — recorded as **decorative/non-required** boundaries under SC 1.4.11 because component identity is carried by surface fill + text + **label + icon**. All load-bearing pairs pass. Watch item (record, don't fix): primary button white-on-teal `#0e7c86` = 4.95:1.
- **D-03 (scope machine-enforced):** The red-team **extends the existing allowlist** in `scripts/brandbook-guards.sh --scope` so the audit passes on the correct milestone tree and fails on anything else. The allowlist must be widened to exactly: `brandbook/**` + the two integration edits (`README.md`, `mix.exs`) + `notes/**` + the guard/render scripts.
- **D-04 (red-team record):** The skeptic pass is recorded in a **new `notes/red-team.md`**, closing with the captured `git diff --stat` scope audit output and the repo-size/binary check result.
- **D-05 (CVD):** Colorblind safety (A11Y-04) is argued primarily from the architectural **"never color-alone"** property (every status = surface + text + **label + icon**), backed by a documented **manual pass through Chrome DevTools "Emulate vision deficiencies"** on the rendered `file://` page, recorded as a checklist. **No CVD tooling or binary/screenshot artifacts are added.**
- **D-06 (A11Y-03):** Focus visible/not-obscured (SC 2.4.7 / 2.4.11), reduced-motion (SC 2.3.3), target size ≥24px (SC 2.5.8) verified against **rendered** output. Known satisfactions: reduced-motion honored (`brandbook.css` `prefers-reduced-motion`), primary `.cwb-btn` ≥2.5rem. Borderline items to adjudicate against SC 2.5.8 spec text: inline jump-nav anchors and theme-toggle segments — apply inline/essential exceptions if they qualify, else record as a finding.
- **D-07 (research voice):** `notes/research.md` follows the established `notes/decision-log.md` voice — sourced claims with dispositions and confidence — citing WCAG 2.2 SC text plus 2–3 mature design-system analogues. Every major recommendation carries pros/cons/tradeoffs, an analogue, implementation cost, ship/reject/defer, and confidence (NOTES-01 cohesive, not a buffet).

### Claude's Discretion
- Exact filename/shape of the offline contrast calc (standalone `scripts/*.sh` vs a function in `brandbook-guards.sh`), provided it is dependency-free and its output is quoted into `notes/accessibility-checks.md`.
- Whether the red-team transcript lives in a dedicated `notes/red-team.md` (preferred, D-04) or is folded, provided the `git diff --stat` + binary check stay verbatim and machine-enforced.
- Whether the allowlist widening (D-03) is a change to the default `--scope` list or a new `--milestone-scope` mode, provided the boundary is enforced (not just asserted).

### Deferred Ideas (OUT OF SCOPE)
- **Token contrast improvements** (raising status-border ratios to 3:1, tightening the 4.95:1 primary-button pair) — deferred to **ADMIN-RETHEME-01**; editing tokens here violates the v1.15 zero-drift invariant.
- **Extending the in-page live matrix** to score all status/border/focus cells — possible future enhancement; not required (the offline calc is the phase's evidence of record).
- Any change to `brandbook/tokens/*` values; any new binary assets; any runtime `lib/` change.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| A11Y-01 | Every text fg/bg pairing meets SC 1.4.3 (4.5:1, or 3:1 large) — verified & recorded | Verbatim SC 1.4.3 text + Incidental/Large Text/Logotypes exceptions (§ WCAG Citation Basis); all text ratios re-computed & confirmed (§ Verified Contrast Findings) |
| A11Y-02 | Non-text/UI contrast — borders, focus rings, meaningful icons — meets SC 1.4.11 (3:1) — verified | Verbatim SC 1.4.11 text + "inactive components" / "essential" exception clauses; border ratios computed; "never color-alone" carries required-info identity |
| A11Y-03 | Focus visible & not obscured (SC 2.4.7 / 2.4.11), reduced motion honored (SC 2.3.3), targets ≥24×24px (SC 2.5.8) | Verbatim SC 2.4.7 / 2.4.11 / 2.3.3 / 2.5.8 incl. all five 2.5.8 exceptions; rendered CSS evidence located (§ A11Y-03 Adjudication Inputs) |
| A11Y-04 | Meaning never conveyed by color alone; palette colorblind-safe (CVD) | Design-system analogues for "never color-alone" + DevTools-emulation verification without binaries (§ Design-System Analogues) |
| A11Y-05 | `notes/accessibility-checks.md` records per-pairing ratios vs the *rendered* output | Offline-calc pattern reproducing the in-page WCAG formula; full pairing inventory (§ Verified Contrast Findings, § Validation Architecture) |
| NOTES-01 | Every major recommendation carries pros/cons/tradeoffs, analogue, cost, ship/defer/reject, confidence | `notes/logo-options.md` + `notes/decision-log.md` format precedent (§ Recommendation-Format Precedent) |
| NOTES-03 | Red-team pass closing with `git diff --stat` scope audit + repo-size/binary check | `--scope` allowlist machinery + logo-guards binary budget mapped (§ Scope-Boundary Machinery) |
| NOTES-04 | `notes/research.md` captures research basis + citations | This document is the citation basis; W3C authoritative sources catalogued (§ Sources) |
</phase_requirements>

## Summary

This is a **doc/asset-only verification phase**, not a build phase. Every implementation decision is already locked in `86-CONTEXT.md` (D-01..D-07): the contrast method, the document-as-exempt disposition, the guard-script reuse, the CVD approach, and the target-size adjudication are all decided. The research task is narrow and specific: supply the **verbatim WCAG 2.2 normative text** and **mature design-system analogues** that `notes/research.md` and the exemption arguments in `notes/accessibility-checks.md` will quote, and confirm that the locked numeric findings are provably correct.

Two things were verified in-session with HIGH confidence. First, the **WCAG relative-luminance + contrast-ratio formula** inlined in `brandbook/index.html` matches the W3C-published definition exactly, and re-running it against the token hexes **reproduces every headline number in D-02 to the hundredth** (disabled 3.92 light / 4.92 dark, primary button 4.95, panel borders 1.47 / 1.91, all five status borders 1.29–1.77, focus rings 4.78 / 4.86, all status text 5.88+). Second, the WCAG errata question (the spec lists linearization threshold `0.03928`; errata says the mathematically correct value is `0.04045`) is **immaterial to every verdict** — recomputing the borderline pairs under both thresholds yields identical ratios, so the in-page formula's choice cannot be attacked by a red-team as producing a wrong disposition.

The exemption arguments rest on exact normative wording now captured below: SC 1.4.3's **Incidental** exception ("inactive user interface component ... pure decoration ... no contrast requirement"), SC 1.4.11's **"except for inactive components"** clause and its **"required to identify"** scoping (which is why label+icon-carried status borders are non-required decoration), and SC 2.5.8's five exceptions (**Spacing, Equivalent, Inline, User agent control, Essential**) that adjudicate the borderline jump-nav anchors and theme-toggle segments.

**Primary recommendation:** Write `notes/accessibility-checks.md` from a dependency-free offline calc that mirrors the in-page formula (D-01), quote the verbatim SC text below to back each D-02 exemption, adjudicate the two A11Y-03 borderline targets against the SC 2.5.8 Inline/Spacing exceptions (both plausibly qualify — see § A11Y-03 Adjudication Inputs), and machine-enforce the scope boundary by widening the existing `brandbook-guards.sh --scope` allowlist (D-03). No token edits, no new binaries, no runtime changes.

## Architectural Responsibility Map

For a verification phase the "tiers" are the artifact under audit, the tooling that proves it, and the record that documents it. Mapping which tier owns each capability prevents the vacuous-pass footgun (asserting in prose what should be machine-enforced) and the token-drift footgun (fixing in the artifact what must be documented in the record).

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Per-pairing contrast ratios | Verification tooling (`scripts/` offline calc, D-01) | Record (`notes/accessibility-checks.md` quotes output) | Numbers must be *computed and re-runnable*, not asserted; the 8-cell in-page matrix is proof-of-rendering only, not evidence of record |
| Rendered-output proof (live matrix) | Rendered artifact (`brandbook/index.html`) | Record (cites it) | The live matrix proves the tokens paint correctly under the active theme; it is a corroborating witness, not the audit |
| Contrast exemption disposition | Record (`notes/accessibility-checks.md` + `notes/research.md`) | — | SC 1.4.3/1.4.11 exemptions are *documented*, never fixed (zero-drift invariant); the artifact must not change |
| Focus / motion / target-size checks (A11Y-03) | Rendered artifact (`brandbook.css` behavior) | Record (checklist) | These are properties of the shipped CSS verified against rendered output and recorded |
| CVD safety (A11Y-04) | Rendered artifact ("never color-alone" architecture) | Record (DevTools-emulation checklist) | Structural property (label+icon) is the defense; manual emulation is the corroborating check, no binaries |
| Scope boundary | Verification tooling (`brandbook-guards.sh --scope`) | Record (`notes/red-team.md` captures output) | Boundary must be *machine-enforced* (D-03), a pasted diff only asserts it |
| Repo-size / binary budget | Verification tooling (`logo-guards.sh` budget) | Record (red-team captures result) | Existing budget check (3 rasters ≤200KB) reused verbatim |

## WCAG 2.2 Citation Basis (verbatim normative text)

> These are the exact quotes `notes/research.md` and `notes/accessibility-checks.md` must reproduce (D-07 says quote, don't paraphrase). All from the W3C Recommendation / Understanding documents.

### SC 1.4.3 Contrast (Minimum) — Level AA  [CITED: w3.org/TR/WCAG22 §1.4.3]
> "The visual presentation of text and images of text has a contrast ratio of at least 4.5:1, except for the following:
> **Large Text:** Large-scale text and images of large-scale text have a contrast ratio of at least 3:1;
> **Incidental:** Text or images of text that are part of an inactive user interface component, that are pure decoration, that are not visible to anyone, or that are part of a picture that contains significant other visual content, have no contrast requirement.
> **Logotypes:** Text that is part of a logo or brand name has no contrast requirement."

**Backs D-02:** the only sub-4.5 text pair is *disabled* text (3.92:1 light) — an **inactive user interface component**, which "have no contrast requirement." The `chimeway` logotype SVG in the header is covered by **Logotypes**.

### SC 1.4.11 Non-text Contrast — Level AA  [CITED: w3.org/TR/WCAG22 §1.4.11]
> "The visual presentation of the following have a contrast ratio of at least 3:1 against adjacent color(s):
> **User Interface Components:** Visual information required to identify user interface components and states, except for inactive components or where the appearance of the component is determined by the user agent and not modified by the author;
> **Graphical Objects:** Parts of graphics required to understand the content, except when a particular presentation of graphics is essential to the information being conveyed."

**Backs D-02:** the operative test is "**required to identify** ... components and states." Where a status is identified by surface fill + text + **label + icon** (the "never color-alone" architecture), the border color is **not the information required to identify** the component/state — it is a decorative boundary, so the failing status/panel borders (1.29–1.91:1) are outside the 3:1 requirement. Focus rings, which ARE required to identify the focus state, all pass 3:1 (4.78+ light, 7.37+ dark).

### SC 2.4.7 Focus Visible — Level AA  [CITED: w3.org/TR/WCAG22 §2.4.7]
> "Any keyboard operable user interface has a mode of operation where the keyboard focus indicator is visible."

### SC 2.4.11 Focus Not Obscured (Minimum) — Level AA (new in 2.2)  [CITED: w3.org/TR/WCAG22 §2.4.11]
> "When a user interface component receives keyboard focus, the component is not entirely hidden due to author-created content."

### SC 2.3.3 Animation from Interactions — Level AAA  [CITED: w3.org/TR/WCAG22 §2.3.3]
> "Motion animation triggered by interaction can be disabled, unless the animation is essential to the functionality or the information being conveyed."

> Note: SC 2.3.3 is **Level AAA**. The prefers-reduced-motion handling in `brandbook.css` satisfies its intent, but the record should state it is honoring a AAA criterion (exceeding the AA bar), not that AA requires it.

### SC 2.5.8 Target Size (Minimum) — Level AA (new in 2.2)  [CITED: w3.org/WAI/WCAG22/Understanding/target-size-minimum]
> "The size of the target for pointer inputs is at least 24 by 24 CSS pixels, except when:
> **Spacing:** Undersized targets (those less than 24 by 24 CSS pixels) are positioned so that if a 24 CSS pixel diameter circle is centered on the bounding box of each, the circles do not intersect another target or the circle for another undersized target;
> **Equivalent:** The function can be achieved through a different control on the same page that meets this criterion;
> **Inline:** The target is in a sentence or its size is otherwise constrained by the line-height of non-target text;
> **User agent control:** The size of the target is determined by the user agent and is not modified by the author;
> **Essential:** A particular presentation of the target is essential or is legally required for the information being conveyed."

**Applies to D-06 borderline targets:** the two candidates for exemption are the **Inline** exception ("its size is otherwise constrained by the line-height of non-target text") and the **Spacing** exception (24px-circle non-intersection). See § A11Y-03 Adjudication Inputs for the measured rendered geometry.

### WCAG relative luminance + contrast ratio  [CITED: w3.org/WAI/GL/wiki/Relative_luminance ; w3.org/TR/WCAG22 dfn-contrast-ratio]
Relative luminance:
> `L = 0.2126 * R + 0.7152 * G + 0.0722 * B`
> where for each sRGB channel `C`: `if C <= 0.03928 then C/12.92 else ((C + 0.055)/1.055) ^ 2.4` (channel value first divided by 255).

Contrast ratio:
> `(L1 + 0.05) / (L2 + 0.05)`, where L1 is the relative luminance of the lighter color and L2 of the darker.

**Errata note (record this, it pre-empts a red-team objection):** the W3C errata states "the correct threshold for the piecewise equation is 0.04045 and not the 0.03928 that is listed" in the published formula. The in-page code in `brandbook/index.html` (line 826) uses `0.03928` — the WCAG-**published** value. **This choice is immaterial:** recomputing the borderline pairs under both `0.03928` and `0.04045` yields byte-identical ratios (primary button 4.9459 both; focus 4.7795 both; disabled 3.9203 both), because no token channel lands in the `[0.03928, 0.04045]` window. `[VERIFIED: in-session node calc, both thresholds]`

## Verified Contrast Findings (D-02 confirmation)

Re-computed in-session with the exact WCAG formula above, reading hexes from `brandbook/tokens/tokens.css`. **Every headline number in D-02 reproduces to the hundredth** — the locked findings are numerically correct. `[VERIFIED: in-session node calc reproducing brandbook/index.html:824-835 formula]`

| Pairing (light unless noted) | Ratio | SC | Disposition |
|------------------------------|-------|-----|-------------|
| ink `#102027` / paper `#fffdf8` (body) | 16.42 | 1.4.3 | PASS |
| muted `#5e6b72` / paper (caption) | 5.40 | 1.4.3 | PASS |
| link `#0e5f67` / paper | 7.24 | 1.4.3 | PASS |
| success text `#0b6b47` / surface `#e8f6ef` | 5.88 | 1.4.3 | PASS |
| warning text `#765000` / surface `#fff2cf` | 6.46 | 1.4.3 | PASS |
| danger text `#9f2424` / surface `#fdecec` | 6.68 | 1.4.3 | PASS |
| primary button white / teal `#0e7c86` | 4.95 | 1.4.3 | PASS (watch item — any token nudge breaks it; record, don't fix) |
| **disabled fg `#68757b` / disabled bg `#eee9dc`** | **3.92** | 1.4.3 | **EXEMPT** — Incidental / inactive UI component |
| disabled fg `#7f9298` / bg `#13242b` (dark) | 4.92 | 1.4.3 | PASS anyway |
| focus ring blue `#2d6cdf` / paper | 4.78 | 1.4.11 | PASS (≥3:1) |
| focus ring blue `#2d6cdf` / panel `#ffffff` | 4.86 | 1.4.11 | PASS |
| **line `#d8d3c7` / paper** (panel border) | **1.47** | 1.4.11 | **EXEMPT** — decorative boundary, not "required to identify" |
| **border-strong `#a9bebf` / paper** | **1.91** | 1.4.11 | **EXEMPT** — decorative boundary |
| **status success border `#9fd8bf` / surface** | **1.45** | 1.4.11 | **EXEMPT** — identity carried by label+icon |
| **status warning border `#e5c36d` / surface** | **1.53** | 1.4.11 | **EXEMPT** |
| **status danger border `#eda3a3` / surface** | **1.77** | 1.4.11 | **EXEMPT** |
| **status info border `#94d4d7` / surface** | **1.50** | 1.4.11 | **EXEMPT** |
| **status neutral border `#d8d3c7` / surface** | **1.29** | 1.4.11 | **EXEMPT** |

> The offline calc (D-01) must additionally cover the **dark** variants of every pair above and the dark focus rings (brass `#d6a84f`: CONTEXT cites 8.57/7.37) — the calc is the evidence of record; this table is the confirmation that the locked dispositions are correct, not the full deliverable.

## A11Y-03 Adjudication Inputs (rendered geometry located)

From `brandbook/brandbook.css` (read in-session):

- **Reduced motion (SC 2.3.3):** `@media (prefers-reduced-motion: reduce)` at `brandbook.css:465` sets `animation: none` for `.cwb-skeleton` and `.cwb-btn.is-loading` — the only two animations in the book (`cwb-shimmer`, `cwb-pulse`). **Satisfied.** `[VERIFIED: brandbook.css:446-470]`
- **Focus visible (SC 2.4.7):** `.cwb-btn:focus-visible` → `outline: var(--cw-focus-offset) solid var(--cw-focus); outline-offset: var(--cw-focus-offset)` (`brandbook.css:350-353`); `:scope a:focus-visible` and `.cwb-brandmark:focus-visible` also carry visible rings. **Satisfied.** Focus-ring contrast passes 1.4.11 (4.78+ / brass in dark). `[VERIFIED: brandbook.css:48,102,350-353]`
- **Focus not obscured (SC 2.4.11):** sticky `.cwb-nav` bar is the only fixed/sticky author content. The record should confirm by keyboard-tabbing the rendered page that no focused control is *entirely* hidden behind the sticky bar (the criterion is "**not entirely hidden**"). Recommend recording this as a manual checklist item. `[CITED: SC 2.4.11 wording above]`
- **Target size (SC 2.5.8) — primary `.cwb-btn`:** `min-block-size: 2.5rem; min-inline-size: 2.5rem` (`brandbook.css:319-320`) = 40×40px. **PASS outright.** `[VERIFIED: brandbook.css:314-321]`
- **Target size — theme-toggle segments:** `.cwb-theme-toggle .cwb-btn` has `min-block-size: 2rem` (=32px ≥24px) and `padding: 4px 16px` with `min-inline-size: 0` (`brandbook.css:405-408`). Height 32px passes; width = text + 32px padding comfortably exceeds 24px. **PASS outright** (CONTEXT's "borderline" flag resolves to a pass on measurement — record it as pass-on-measurement, no exception needed). `[VERIFIED: brandbook.css:405-416]`
- **Target size — inline jump-nav anchors:** `.cwb-anchors a` uses `padding: var(--cw-space-xs) var(--cw-space-sm)` (4px 8px), `font-size: 14px`, `line-height: 1.35` (`brandbook.css:113-120`). Rendered height ≈ (14×1.35=18.9) + 8 = **~26.9px vertical**, so the vertical dimension already meets 24px; horizontal depends on label length (short labels like "Voice" may be <24px wide). **Recommended disposition:** these anchors are **inline navigation in a horizontal wrapped list**, so the **Inline** exception ("its size is otherwise constrained by the line-height of non-target text") plausibly applies; additionally the `gap: 4px 8px` between them should be checked against the **Spacing** exception (24px-circle non-intersection). Record whichever applies; if neither clearly holds for the narrowest anchor, record as a documented finding (do NOT change tokens/CSS — out of scope). `[VERIFIED: brandbook.css:106-121]` `[CITED: SC 2.5.8 Inline/Spacing exceptions above]`

## Design-System Analogues (NOTES-01 / NOTES-04 precedent)

Three mature systems, for how they (a) document contrast/exemption reasoning and (b) verify "never color-alone" / CVD safety without shipping simulated-screenshot binaries.

| System | Contrast / exemption documentation | CVD / never-color-alone practice | Use as analogue for |
|--------|-----------------------------------|----------------------------------|---------------------|
| **U.S. Web Design System (USWDS)** | Publishes a color-token system with contrast built into the token pairings; states standard text needs 4.5:1, large text 3:1, and UI/state boundaries 3:1. | Explicit rule: **"do not rely on color alone"** to convey information, indicate an action, prompt a response, or distinguish elements; cites ~4.5% of the population (8% of men) with red-green CVD. Verification is a documented design rule + manual review, **not** committed simulation images. | D-05 "never color-alone" framing; the population-impact citation; NOTES-01 recommendation voice | `[CITED: designsystem.digital.gov/design-tokens/color/overview]` |
| **Carbon Design System (IBM)** | Documents contrast thresholds (4.5:1 text, 3:1 large/≥19px-semibold, 3:1 for state/boundary UI information) as explicit guidance tied to tokens. | Color guidance requires state/boundary information to reach 3:1 against adjacent color AND to not depend on color alone. | D-02 "required to identify" framing for status boundaries; threshold-by-role table | `[CITED: carbondesignsystem.com/guidelines/accessibility/color]` |
| **GOV.UK Design System** | Requires components meet WCAG 2.2 SC 1.4.3 AA; documents accessibility per-component and publishes an accessibility strategy/statement rather than per-pixel exemption prose. | Verifies via automated `@axe-core/puppeteer` contrast checks + `html-validate` in CI — i.e. **re-runnable tooling, not screenshots** — the same "machine-enforced, not asserted" philosophy as D-01/D-03. | D-01/D-03 "re-runnable check over asserted prose" precedent; NOTES-03 machine-enforcement rationale | `[CITED: design-system.service.gov.uk/accessibility]` |

**Key precedent takeaways for the notes:**
1. Mature systems verify contrast and color-independence with **re-runnable checks and documented design rules**, not committed simulated-screenshot binaries — this directly validates D-05 (DevTools emulation checklist, no binaries) and D-01/D-03 (offline calc + `--scope` guard over pasted assertions).
2. The **"never rely on color alone"** rule is a first-class, universally documented design-system principle — the chimeway status architecture (surface + text + label + icon) is the standard-of-practice implementation, and citing USWDS/Carbon gives the A11Y-04 argument named-precedent weight.
3. Documenting a sub-threshold value **with a WCAG exemption rationale** (rather than silently passing or force-fixing) matches how these systems handle boundary/decorative color — reinforcing D-02.

## Recommendation-Format Precedent (NOTES-01)

`notes/logo-options.md` is the in-repo format precedent (read in-session): each option carries **Pros / Cons / Recommendation / Verdict (Ship|Defer|Reject) / Confidence (High|Medium|Low)**. `notes/decision-log.md` is the divergence-ledger voice: **both-side refs + Disposition (DOCUMENTED|DEFERRED) + a proof line** (the zero-drift `git diff --exit-code` invariant). `notes/research.md` (D-07) should fuse these: sourced claim → disposition → analogue → cost → ship/defer/reject → confidence, cohesive not a buffet. `[VERIFIED: notes/logo-options.md, notes/decision-log.md]`

## Scope-Boundary Machinery (NOTES-03 / D-03)

The `--scope` mode already exists and does the right shape of work; only the allowlist needs widening.

- **`scripts/brandbook-guards.sh --scope`** (lines 82-114): runs `git diff --stat`, then walks `git status --porcelain --untracked-files=all` and FAILs on any path outside a `case` allowlist. **Current allowlist (lines 98-105) permits only:** `brandbook/*`, `scripts/brandbook-guards.sh`, `.planning/*`. `[VERIFIED: scripts/brandbook-guards.sh:82-114]`
- **Gap → false-FAIL as-is:** the two integration edits (`README.md`, `mix.exs`), the new `notes/**` files, and any new contrast-calc script are NOT in the allowlist, so the audit would incorrectly fail on the correct milestone tree. **Must widen to exactly:** `brandbook/**` + `README.md` + `mix.exs` + `notes/**` + `scripts/brandbook-guards.sh` + `scripts/logo-guards.sh` + `scripts/render-svg-png.sh` + (any new contrast-calc script the plan adds). D-03 permits either editing the default `--scope` list or adding a `--milestone-scope` mode. `[VERIFIED: allowlist case block]`
- **`scripts/logo-guards.sh` binary budget** (lines 265-284): asserts **exactly 3 committed rasters, total ≤ 204800 bytes (200KB)**; comment marks it "feeds NOTES-03." Reuse verbatim for the repo-size/binary check. Current rasters: `apple-touch-icon.png` 2004B + `favicon.ico` 15086B + `chimeway-og.png` 21489B = **38,579B, well under ceiling**; count = 3. **PASS.** `[VERIFIED: logo-guards.sh:265-284 + ls -la]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Contrast ratio math | A new color library / npm dep | The formula already inlined in `brandbook/index.html:824-835`, reproduced in shell/awk (D-01) | Zero deps, already proven correct in-session; adding a dep violates the file://-safe / no-node_modules milestone constraint |
| Scope-boundary audit | A hand-pasted `git diff` in the notes | Widen the existing `brandbook-guards.sh --scope` allowlist (D-03) | A pasted diff asserts without enforcing — the exact NOTES-03 footgun; the porcelain walk fails on stray edits |
| Repo-size / binary check | A new size-counting script | `logo-guards.sh` binary budget (lines 265-284) | Already implemented, already comments "feeds NOTES-03" |
| CVD verification | A CVD-simulation library or committed simulated screenshots | Architectural "never color-alone" + Chrome DevTools "Emulate vision deficiencies" manual checklist (D-05) | Milestone forbids binaries; USWDS/Carbon precedent verifies via rules + review, not images |
| Token fixes for sub-threshold pairs | Editing `tokens.css` to raise ratios | Document as WCAG exemption (D-02) | Editing tokens violates the TOKEN-01 zero-drift invariant → that's the deferred ADMIN-RETHEME-01 milestone |

**Key insight:** every capability this phase needs already exists in the repo (the in-page formula, the `--scope` walk, the binary budget). The work is *citation + wiring the allowlist + recording*, not building. The failure mode to guard against is the **vacuous pass** — asserting a boundary/ratio in prose that should be machine-computed or machine-enforced.

## Common Pitfalls

### Pitfall 1: Vacuous-pass via the 8-cell in-page matrix
**What goes wrong:** Treating the live in-page contrast matrix as the A11Y-05 evidence of record.
**Why it happens:** It's visible, live, and looks authoritative — but it scores only 8 text cells and silently omits every status triad, border, focus ring, and disabled pair (exactly the surfaces where the exemptions live).
**How to avoid:** The offline calc (D-01) is the evidence of record; cite the in-page matrix only as *rendered-output proof*. Ensure the calc covers light+dark for all pair classes.
**Warning signs:** An `accessibility-checks.md` whose ratio table has ~8 rows.

### Pitfall 2: Paraphrasing WCAG normative text
**What goes wrong:** Summarizing the exemption clauses instead of quoting them; a red-team then disputes whether the exemption actually applies.
**Why it happens:** The clauses are wordy.
**How to avoid:** Quote verbatim from § WCAG Citation Basis (D-07 explicitly requires this). The operative phrases are "inactive user interface component ... no contrast requirement" (1.4.3) and "**required to identify** ... except for inactive components" (1.4.11).

### Pitfall 3: Force-fixing a sub-threshold pair
**What goes wrong:** "Nudging" a token to clear 3:1 or to pad the 4.95:1 primary button.
**Why it happens:** Instinct to make the number pass.
**How to avoid:** D-02 + TOKEN-01 zero-drift — record as documented exemption/watch-item, defer any change to ADMIN-RETHEME-01. The tokens are verbatim from shipped `chimeway_admin.css`.
**Warning signs:** A diff touching `brandbook/tokens/tokens.css`.

### Pitfall 4: Asserting the scope boundary instead of enforcing it
**What goes wrong:** Pasting a `git diff --stat` into `red-team.md` without widening the guard allowlist; a future stray edit outside scope passes unnoticed.
**How to avoid:** Widen `--scope` (D-03) and capture its *output*; the guard, not the prose, is the enforcement.

### Pitfall 5: Claiming AA where the criterion is AAA
**What goes wrong:** Recording reduced-motion (SC 2.3.3) as an AA requirement.
**Why it happens:** It's grouped with the other A11Y-03 checks.
**How to avoid:** SC 2.3.3 is **Level AAA** — record that the book *exceeds* the AA bar by honoring it, don't imply AA mandates it.

## Code Examples

### Offline WCAG contrast calc — the formula to reproduce (D-01)
```javascript
// Source: brandbook/index.html:824-835 (verified against W3C relative-luminance dfn)
// Reproduce dependency-free in shell/awk for notes/accessibility-checks.md.
function _lin(c){ c/=255; return c <= 0.03928 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4); }
function luminance(rgb){ return 0.2126*_lin(rgb[0]) + 0.7152*_lin(rgb[1]) + 0.0722*_lin(rgb[2]); }
function ratio(fg,bg){ var l1=luminance(fg), l2=luminance(bg), hi=Math.max(l1,l2), lo=Math.min(l1,l2);
  return (hi+0.05)/(lo+0.05); }
// AA verdict: r>=4.5 normal text; r>=3 large text / non-text UI.
```

### Scope allowlist widening (D-03) — the `case` block to extend
```sh
# Source: scripts/brandbook-guards.sh:98-105 (current allowlist — widen for Phase 86)
case "$path" in
  brandbook/*)                  : ;;   # book scope
  README.md)                    : ;;   # ADD — Phase 85 D-01 header lockup
  mix.exs)                      : ;;   # ADD — Phase 85 D-02 ExDoc :logo/:favicon
  notes/*)                      : ;;   # ADD — this phase's record
  scripts/brandbook-guards.sh)  : ;;
  scripts/logo-guards.sh)       : ;;   # ADD — binary budget for NOTES-03
  scripts/render-svg-png.sh)    : ;;   # ADD — render helper
  # scripts/<new-contrast-calc>.sh)  : ;;  # ADD if the calc is a standalone script
  .planning/*)                  : ;;   # bookkeeping
  *) fail "scope: unexpected path outside milestone allowlist: $path" ;;
esac
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WCAG 2.1 (no target-size-minimum, no focus-not-obscured at AA) | WCAG 2.2 adds SC 2.5.8 Target Size (Minimum) AA and SC 2.4.11 Focus Not Obscured (Minimum) AA | WCAG 2.2 became a W3C Recommendation Oct 2023 | This phase audits against 2.2 — the two new AA criteria (2.5.8, 2.4.11) are exactly the borderline items in D-06 |
| Ship simulated CVD screenshots as proof | Document "never color-alone" as a design rule + re-runnable/manual review (USWDS, Carbon, GOV.UK) | Current design-system practice | Validates D-05's no-binary approach |
| Assert contrast passes in prose | Machine-computed ratios + CI/guard checks (GOV.UK axe-core; this repo's offline calc + `--scope`) | Current practice | Validates D-01/D-03 |

**Deprecated/outdated:**
- WCAG relative-luminance threshold `0.03928` vs errata `0.04045`: use either — proven immaterial to all verdicts here. Do not "correct" the in-page code (out of scope; would be a token/artifact edit).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `chimeway` header SVG counts as a "logo or brand name" under SC 1.4.3 Logotypes | WCAG Citation Basis | Low — it is literally the wordmark; even without the exemption the mono logotype on paper contrasts strongly |
| A2 | The narrowest jump-nav anchor qualifies for the SC 2.5.8 Inline or Spacing exception | A11Y-03 Adjudication Inputs | Low — if neither holds, D-06 says record it as a documented finding (no fix); the vertical dimension already ≥24px |
| A3 | The sticky `.cwb-nav` never *entirely* hides a focused control (SC 2.4.11) | A11Y-03 Adjudication Inputs | Low — must be confirmed by a keyboard-tab pass in the record; scroll-margin/anchor offsets typically keep targets visible |
| A4 | Dark-theme focus rings and status pairs pass (CONTEXT cites brass 8.57/7.37, status 11+) | Verified Contrast Findings | Low — light values all reproduced exactly; the offline calc will confirm dark in the deliverable |

**All A1–A4 are low-risk and self-resolving in the record** (the offline calc confirms A4; the manual checklist confirms A3; D-06 already prescribes the fallback for A2).

## Open Questions (RESOLVED)

1. **Standalone calc script vs a function inside `brandbook-guards.sh`?**
   - What we know: D-01 leaves the shape to Claude's discretion; it must be dependency-free and its output quoted into `accessibility-checks.md`.
   - Recommendation: A small standalone `scripts/contrast-audit.sh` (readable, re-runnable, one job) that reads `tokens.css`; add its path to the `--scope` allowlist. Keeps the guard script's `--scope` mode uncluttered.
   - **RESOLVED:** standalone `scripts/contrast-audit.sh` — implemented by Plan 86-01.

2. **Default `--scope` widening vs a new `--milestone-scope` mode (D-03)?**
   - What we know: either is acceptable if the boundary is enforced.
   - Recommendation: widen the default `--scope` allowlist (simplest, one source of truth). A separate mode risks the milestone check drifting from the default.
   - **RESOLVED:** widen the default `--scope` allowlist — implemented by Plan 86-04.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `git` | `--scope` porcelain walk (NOTES-03) | ✓ (repo is a git repo) | system | — |
| POSIX shell + `awk` | offline contrast calc (D-01) | ✓ (zsh/bash on darwin) | system | — |
| `node` | in-session verification (not required by deliverable) | ✓ | present | shell/awk calc is the deliverable |
| Chrome/Chromium DevTools "Emulate vision deficiencies" | manual CVD checklist (D-05, A11Y-04) | Operator-run (manual) | n/a | Record as a manual checklist; no automated fallback needed (milestone forbids CVD tooling/binaries) |
| `magick` (ImageMagick) | raster dimension checks in `logo-guards.sh` (optional) | SKIPs gracefully if absent | — | Guard degrades to SKIP; binary-budget byte check does not need it |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** the CVD check is inherently manual (by design, D-05) — recorded as a checklist, not automated.

## Validation Architecture

> `workflow.nyquist_validation` is enabled in `.planning/config.json`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Repo guard-script idiom (`pass`/`fail`/`skip`, `set -euo pipefail`) — NOT ExUnit; this phase touches no `lib/` |
| Config file | none — scripts are self-contained under `scripts/` |
| Quick run command | `scripts/brandbook-guards.sh` (check families) |
| Full suite command | `scripts/brandbook-guards.sh && scripts/brandbook-guards.sh --scope && scripts/logo-guards.sh --assets` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| A11Y-01 | Every text pair's ratio computed & recorded (incl. disabled exemption) | offline calc (re-runnable) | `scripts/contrast-audit.sh` (new, D-01) → output quoted into `notes/accessibility-checks.md` | ❌ Wave 0 (calc script) |
| A11Y-02 | Non-text/UI ratios (borders, focus rings) computed; exemptions documented | offline calc + record | `scripts/contrast-audit.sh` covers borders + focus rings | ❌ Wave 0 |
| A11Y-03 | Focus visible/not-obscured, reduced-motion, target size verified vs rendered | recorded manual checklist + CSS grep evidence | manual (DevTools/keyboard) + `grep prefers-reduced-motion brandbook/brandbook.css` | manual + ✅ CSS exists |
| A11Y-04 | Never-color-alone + CVD emulation pass | recorded manual checklist | Chrome DevTools "Emulate vision deficiencies" (manual, D-05) | manual |
| A11Y-05 | Per-pairing ratios recorded vs rendered output | doc-of-record | `notes/accessibility-checks.md` quotes calc output + cites in-page matrix | ❌ Wave 0 (notes file) |
| NOTES-01 | Recommendations carry pros/cons/analogue/cost/verdict/confidence | format review | manual vs `notes/logo-options.md` precedent | ✅ precedent exists |
| NOTES-03 | Red-team closes with `git diff --stat` scope audit + binary check | machine-enforced | `scripts/brandbook-guards.sh --scope` (widened) + `scripts/logo-guards.sh --assets` | ✅ scripts exist; allowlist needs widening |
| NOTES-04 | Research basis + citations recorded | doc-of-record | `notes/research.md` (quotes this document's citation basis) | ❌ Wave 0 (notes file) |

### Sampling Rate
- **Per task commit:** run `scripts/brandbook-guards.sh --scope` (fast; catches any stray out-of-scope edit immediately).
- **Per wave merge:** run the full suite command above + re-run `scripts/contrast-audit.sh` and diff its output against the quoted table in `accessibility-checks.md`.
- **Phase gate:** `--scope` PASS (widened allowlist) + binary budget PASS + the offline calc's numbers matching the recorded table + the manual A11Y-03/A11Y-04 checklists signed in the record.

### Wave 0 Gaps
- [ ] `scripts/contrast-audit.sh` (or a `brandbook-guards.sh` function) — dependency-free calc reproducing the in-page WCAG formula over `tokens.css`; covers A11Y-01/02/05.
- [ ] `notes/accessibility-checks.md` — the ratio table (light+dark, all pair classes) + A11Y-03 checklist + A11Y-04 CVD/never-color-alone checklist.
- [ ] `notes/research.md` — citation basis (quote § WCAG Citation Basis + § Design-System Analogues), recommendation-format per NOTES-01.
- [ ] `notes/red-team.md` — skeptic pass closing with captured `--scope` output + binary-budget result.
- [ ] Allowlist widening in `scripts/brandbook-guards.sh --scope` (add README.md, mix.exs, notes/*, logo-guards.sh, render-svg-png.sh, the new calc script).

## Security Domain

> `security_enforcement` is not disabled in config (absent = enabled). This is a doc/asset-only phase touching no runtime code, no network, no auth, no data — the security surface is limited to the static `file://` book and repo-scope discipline.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation / Output Encoding | Marginal | The book is static HTML opened via `file://`; the inline JS reads only `getComputedStyle` and `data-*` attributes it authored — no user input, no injection surface. Already gated by `brandbook-guards.sh` family 1 (no `fetch`/XHR/external `<use href>`). |
| V6 Cryptography | No | — |
| V2/V3/V4 Auth/Session/Access | No | No auth surface |
| V12 Files & Resources | Marginal | Binary budget (3 rasters ≤200KB) + scope allowlist prevent stray/oversized asset commits — enforced by `logo-guards.sh` / `--scope`. |

### Known Threat Patterns for this phase
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Scope creep / stray out-of-scope edit slipping into the milestone tree | Tampering | `brandbook-guards.sh --scope` porcelain allowlist (D-03) — machine-enforced, not asserted |
| Binary bloat / unreviewed raster committed | Tampering | `logo-guards.sh` binary budget (exactly 3 rasters, ≤204800B) |
| `file://` exfiltration via `fetch`/XHR/sprite `<use href>` | Info Disclosure | Already banned by guard family 1 over `brandbook/index.html` (verified pre-existing) |

## Sources

### Primary (HIGH confidence)
- `w3.org/TR/WCAG22/` — verbatim normative text for SC 1.4.3, 1.4.11, 2.4.7, 2.4.11, 2.3.3.
- `w3.org/WAI/WCAG22/Understanding/target-size-minimum.html` — SC 2.5.8 full text + five exceptions (Spacing, Equivalent, Inline, User agent control, Essential).
- `w3.org/WAI/GL/wiki/Relative_luminance` — relative-luminance formula, coefficients, linearization threshold, errata (0.04045).
- In-session `node` recomputation of all D-02 pairs (both luminance thresholds) — reproduces every headline number; confirms threshold choice is immaterial.
- Repo files read in-session: `brandbook/tokens/tokens.css`, `brandbook/index.html` (formula 824-835, matrix 483-526), `brandbook/brandbook.css` (focus/motion/target-size), `scripts/brandbook-guards.sh` (`--scope` 82-114), `scripts/logo-guards.sh` (binary budget 265-284), `notes/decision-log.md`, `notes/logo-options.md`.

### Secondary (MEDIUM confidence)
- `designsystem.digital.gov/design-tokens/color/overview` — USWDS "don't rely on color alone" + CVD population figures.
- `carbondesignsystem.com/guidelines/accessibility/color` — Carbon contrast thresholds by role + state/boundary 3:1.
- `design-system.service.gov.uk/accessibility` — GOV.UK WCAG 2.2 conformance + axe-core/html-validate re-runnable verification.

### Tertiary (LOW confidence)
- None — all claims are either W3C-authoritative or verified against the repo in-session.

## Metadata

**Confidence breakdown:**
- WCAG citation basis: HIGH — verbatim from w3.org Recommendation/Understanding docs.
- Contrast findings: HIGH (VERIFIED) — recomputed in-session, every D-02 number reproduces exactly; threshold-errata shown immaterial.
- A11Y-03 adjudication: HIGH — measured against the actual rendered CSS; primary/theme-toggle pass outright, jump-nav has a clear exception path + fallback.
- Design-system analogues: MEDIUM — official docs, but exemption-documentation practices are summarized rather than quoted verbatim.

**Research date:** 2026-07-27
**Valid until:** 2026-08-26 (WCAG 2.2 is a stable Recommendation; token hexes are frozen by the zero-drift invariant — findings do not decay unless the milestone re-opens ADMIN-RETHEME-01).
