# Chimeway Accessibility Audit — Research Basis & Citations

**Date:** 2026-07-28
**Phase:** 86 — Accessibility Audit, Notes & Red-Team Close (v1.15 Brand Identity & Brand Book)
**Decision status:** research record — sourced claims with dispositions and confidence; no artifact patched
**Scope:** the citation basis for the WCAG 2.2 audit of the rendered static `file://` brand book (`brandbook/index.html` + `brandbook/brandbook.css` + `brandbook/tokens/tokens.css`)

This document is the **research basis of record** for the Phase 86 accessibility audit
(NOTES-04). It follows the established `notes/decision-log.md` voice — **sourced claim →
disposition → proof line** — and closes with cohesive Ship/Defer/Reject recommendations in
the `notes/logo-options.md` format (**Pros / Cons / Recommendation / Verdict / Confidence**),
one verdict per recommendation, never a buffet (NOTES-01).

It exists to pre-empt a red-team dispute: every exemption the audit claims is backed by the
**verbatim** WCAG 2.2 normative text (quoted, not paraphrased) plus a named mature
design-system analogue. The `notes/accessibility-checks.md` record consumes these same quotes
to justify each per-pairing disposition.

> **How to read this file.** The **§ WCAG 2.2 Citation Basis** and **§ Design-System
> Analogues** sections below are a **record** (verbatim quotes and cited precedent), NOT
> recommendations — the NOTES-01 Pros/Cons/Verdict/Confidence format applies only to the
> **§ Cohesive Recommendations** section at the end. Pure-record sections are labeled as such
> and are exempt from the recommendation format (NOTES-01 empty-predicate).

## Sources

### Primary (HIGH confidence — W3C authoritative)
- `w3.org/TR/WCAG22/` — verbatim normative text for SC 1.4.3, 1.4.11, 2.4.7, 2.4.11, 2.3.3.
- `w3.org/WAI/WCAG22/Understanding/target-size-minimum.html` — SC 2.5.8 full text + its five exceptions (Spacing, Equivalent, Inline, User agent control, Essential).
- `w3.org/WAI/GL/wiki/Relative_luminance` and `w3.org/TR/WCAG22/#dfn-contrast-ratio` — relative-luminance formula, coefficients, linearization threshold, and the `0.04045` errata.

### Secondary (MEDIUM confidence — official design-system docs)
- `designsystem.digital.gov/design-tokens/color/overview` — USWDS "don't rely on color alone" + CVD population figure.
- `carbondesignsystem.com/guidelines/accessibility/color` — IBM Carbon contrast thresholds by role + state/boundary 3:1.
- `design-system.service.gov.uk/accessibility` — GOV.UK WCAG 2.2 conformance + `@axe-core/puppeteer` + `html-validate` re-runnable verification.

### In-repo (HIGH confidence — read/verified in-session)
- `.planning/phases/86-accessibility-audit-notes-red-team-close/86-RESEARCH.md` — the § WCAG 2.2 Citation Basis, § Design-System Analogues, and § Sources this file reproduces; RESEARCH marks the citation basis HIGH/VERIFIED against w3.org.
- `notes/decision-log.md` — established notes voice (sourced claim → disposition → proof line; the zero-drift invariant).
- `notes/logo-options.md` — NOTES-01 recommendation-format precedent (Pros / Cons / Recommendation / Verdict / Confidence).
- `notes/accessibility-checks.md` — the per-pairing ratio record (Plan 86-01) these citations back.
- `brandbook/tokens/tokens.css`, `brandbook/index.html` (formula 824-835), `brandbook/brandbook.css` (focus/motion/target-size), `scripts/brandbook-guards.sh` (`--scope`), `scripts/logo-guards.sh` (binary budget).

---

## WCAG 2.2 Citation Basis (verbatim normative text) — RECORD

> **This section is a record, not a recommendation.** These are the exact quotes the audit
> reproduces (D-07: quote, don't paraphrase). Each carries its w3.org source citation. The
> **assumption** (planner_assumptions, NOTES-04): the verbatim text is reproduced from
> 86-RESEARCH.md § WCAG 2.2 Citation Basis, which RESEARCH marks HIGH/VERIFIED against the
> W3C Recommendation; primary-source citations are included for independent re-check (low risk).

### SC 1.4.3 Contrast (Minimum) — Level AA  `[CITED: w3.org/TR/WCAG22 §1.4.3]`

> "The visual presentation of text and images of text has a contrast ratio of at least 4.5:1, except for the following:
> **Large Text:** Large-scale text and images of large-scale text have a contrast ratio of at least 3:1;
> **Incidental:** Text or images of text that are part of an inactive user interface component, that are pure decoration, that are not visible to anyone, or that are part of a picture that contains significant other visual content, have no contrast requirement.
> **Logotypes:** Text that is part of a logo or brand name has no contrast requirement."

**Backs D-02 (proof line):** the only sub-4.5:1 text pair is *disabled* text (3.92:1 light) — an
**inactive user interface component**, which by the Incidental exception has **no contrast
requirement**. The `chimeway` header wordmark SVG is covered by **Logotypes** ("no contrast
requirement"). All load-bearing text pairs pass ≥4.5:1 (see `notes/accessibility-checks.md`).

### SC 1.4.11 Non-text Contrast — Level AA  `[CITED: w3.org/TR/WCAG22 §1.4.11]`

> "The visual presentation of the following have a contrast ratio of at least 3:1 against adjacent color(s):
> **User Interface Components:** Visual information required to identify user interface components and states, except for inactive components or where the appearance of the component is determined by the user agent and not modified by the author;
> **Graphical Objects:** Parts of graphics required to understand the content, except when a particular presentation of graphics is essential to the information being conveyed."

**Backs D-02 (proof line):** the operative test is "**required to identify** ... components and
states." Where a status is identified by surface fill + text + **label + icon** (the
"never-color-alone" architecture), the border color is **not** the information required to
identify the component/state — it is a decorative boundary, so the sub-3:1 status/panel borders
(1.29–1.91:1) fall outside the requirement. Focus rings, which **are** required to identify the
focus state, all pass ≥3:1 (4.78+ light).

### SC 2.4.7 Focus Visible — Level AA  `[CITED: w3.org/TR/WCAG22 §2.4.7]`

> "Any keyboard operable user interface has a mode of operation where the keyboard focus indicator is visible."

### SC 2.4.11 Focus Not Obscured (Minimum) — Level AA (new in 2.2)  `[CITED: w3.org/TR/WCAG22 §2.4.11]`

> "When a user interface component receives keyboard focus, the component is not entirely hidden due to author-created content."

**Note (proof line):** the criterion is "**not entirely hidden**" — a partially overlapped
control still conforms. The only sticky/fixed author content is the `.cwb-nav` bar; the record
confirms by keyboard-tab pass that no focused control is *entirely* hidden behind it.

### SC 2.3.3 Animation from Interactions — Level AAA  `[CITED: w3.org/TR/WCAG22 §2.3.3]`

> "Motion animation triggered by interaction can be disabled, unless the animation is essential to the functionality or the information being conveyed."

**Note (proof line):** SC 2.3.3 is **Level AAA** — the book *exceeds* the AA bar by honoring it
(`prefers-reduced-motion: reduce` in `brandbook.css` disables `cwb-shimmer` / `cwb-pulse`).
The record must state it is honoring a AAA criterion, **not** that AA mandates it.

### SC 2.5.8 Target Size (Minimum) — Level AA (new in 2.2)  `[CITED: w3.org/WAI/WCAG22/Understanding/target-size-minimum]`

> "The size of the target for pointer inputs is at least 24 by 24 CSS pixels, except when:
> **Spacing:** Undersized targets (those less than 24 by 24 CSS pixels) are positioned so that if a 24 CSS pixel diameter circle is centered on the bounding box of each, the circles do not intersect another target or the circle for another undersized target;
> **Equivalent:** The function can be achieved through a different control on the same page that meets this criterion;
> **Inline:** The target is in a sentence or its size is otherwise constrained by the line-height of non-target text;
> **User agent control:** The size of the target is determined by the user agent and is not modified by the author;
> **Essential:** A particular presentation of the target is essential or is legally required for the information being conveyed."

**Backs D-06 (proof line):** the two adjudicated targets are the inline jump-nav anchors and the
theme-toggle segments. Primary `.cwb-btn` (40×40px) and theme-toggle segments (32px height)
**pass on measurement**. The narrowest jump-nav anchor (~26.9px vertical; horizontal
label-dependent) is adjudicated against the **Inline** exception ("its size is otherwise
constrained by the line-height of non-target text") with the **Spacing** exception (24px-circle
non-intersection) as the fallback test; if neither clearly holds it is recorded as a documented
finding — never fixed (out of scope, TOKEN-01 zero-drift).

### WCAG relative luminance + contrast ratio  `[CITED: w3.org/WAI/GL/wiki/Relative_luminance ; w3.org/TR/WCAG22 #dfn-contrast-ratio]`

Relative luminance:

> `L = 0.2126 * R + 0.7152 * G + 0.0722 * B`
> where for each sRGB channel `C`: `if C <= 0.03928 then C/12.92 else ((C + 0.055)/1.055) ^ 2.4` (channel value first divided by 255).

Contrast ratio:

> `(L1 + 0.05) / (L2 + 0.05)`, where L1 is the relative luminance of the lighter color and L2 of the darker.

**Errata note (record this — it pre-empts a red-team objection):** the W3C errata states "the
correct threshold for the piecewise equation is 0.04045 and not the 0.03928 that is listed" in
the published formula. The in-page code (`brandbook/index.html:826`) and `scripts/contrast-audit.sh`
use the WCAG-**published** `0.03928`. **This choice is immaterial to every verdict:** recomputing
the borderline pairs under both `0.03928` and `0.04045` yields identical ratios (primary button
4.9459 both; focus 4.7795 both; disabled 3.9203 both), because no token channel lands in the
`[0.03928, 0.04045]` window. `[VERIFIED: in-session node calc, both thresholds — 86-RESEARCH.md]`

---

## Design-System Analogues (NOTES-01 / NOTES-04 precedent) — RECORD

> **This section is a record, not a recommendation.** Three mature systems, cited for how they
> (a) document contrast/exemption reasoning and (b) verify "never-color-alone" / CVD safety
> **without** shipping simulated-screenshot binaries.

| System | Contrast / exemption documentation | CVD / never-color-alone practice | Analogue for |
|--------|-----------------------------------|----------------------------------|--------------|
| **U.S. Web Design System (USWDS)** | Token system with contrast built into the pairings; standard text 4.5:1, large text 3:1, UI/state boundaries 3:1. | Explicit rule: **"do not rely on color alone"** to convey information, indicate an action, prompt a response, or distinguish elements; cites ~4.5% of the population (8% of men) with red-green CVD. Verified by a documented design rule + manual review, **not** committed simulation images. | D-05 "never-color-alone" framing + the CVD population citation; NOTES-01 recommendation voice. `[CITED: designsystem.digital.gov/design-tokens/color/overview]` |
| **Carbon Design System (IBM)** | Documents contrast thresholds by role (4.5:1 text, 3:1 large/≥19px-semibold, 3:1 for state/boundary UI information) tied to tokens. | State/boundary information must reach 3:1 against adjacent color **and** not depend on color alone. | D-02 "required to identify" framing for status boundaries; the threshold-by-role table. `[CITED: carbondesignsystem.com/guidelines/accessibility/color]` |
| **GOV.UK Design System** | Requires components meet WCAG 2.2 SC 1.4.3 AA; documents accessibility per-component + publishes an accessibility statement rather than per-pixel exemption prose. | Verifies via automated `@axe-core/puppeteer` contrast checks + `html-validate` in CI — **re-runnable tooling, not screenshots** — the same "machine-enforced, not asserted" philosophy as D-01/D-03. | D-01/D-03 "re-runnable check over asserted prose"; NOTES-03 machine-enforcement rationale. `[CITED: design-system.service.gov.uk/accessibility]` |

**Precedent takeaways (proof lines for the notes):**
1. Mature systems verify contrast and color-independence with **re-runnable checks and documented design rules**, not committed simulated-screenshot binaries — directly validating D-05 (DevTools-emulation checklist, no binaries) and D-01/D-03 (offline calc + `--scope` guard over pasted assertions).
2. The **"never rely on color alone"** rule is a first-class, universally documented principle — the chimeway status architecture (surface + text + label + icon) is the standard-of-practice implementation, giving the A11Y-04 argument named-precedent weight.
3. Documenting a sub-threshold value **with a WCAG exemption rationale** (rather than silently passing or force-fixing) matches how these systems handle boundary/decorative color — reinforcing D-02.

---

## Cohesive Recommendations (NOTES-01 format)

> **This section carries the recommendations.** Each is a single cohesive recommendation with a
> verdict — **never a buffet of equally-weighted options** (NOTES-01 adjacency). Every entry
> carries Pros / Cons / Tradeoffs, an Analogue, an implementation Cost, a **Ship / Defer /
> Reject** Verdict, and a **Confidence** rating. Presented in a stable order **by topic**
> (contrast exemptions → button watch-item → CVD/color-independence → focus/motion/target-size →
> scope enforcement), not interleaved with the citation record above (NOTES-01 ordering).

### R-1 — Document sub-threshold pairs as WCAG exemptions, do not patch tokens

**Claim (sourced):** the sub-4.5:1 disabled text (3.92:1) and the sub-3:1 status/panel borders
(1.29–1.91:1) are covered by SC 1.4.3 **Incidental** ("inactive user interface component … no
contrast requirement") and SC 1.4.11 "**required to identify** … except for inactive components"
respectively (§ WCAG 2.2 Citation Basis). Record them as **documented exemptions** in
`notes/accessibility-checks.md`; do **not** raise the token ratios.

**Pros:** Preserves the v1.15 zero-drift / TOKEN-01 invariant (the tokens are verbatim from shipped
`chimeway_admin.css`); the exemptions are backed by verbatim normative text, so a red-team cannot
dispute applicability; identity is already carried by surface + text + label + icon, so nothing is
actually inaccessible.
**Cons / Tradeoffs:** The raw ratios still read "fail" to an automated scanner that ignores
exemption context, so the record must state the exemption rationale explicitly next to each number;
a future maintainer could mistake "exempt" for "unchecked."
**Analogue:** IBM Carbon documents state/boundary contrast **by role** and treats non-identifying
boundaries as outside the 3:1 rule; USWDS documents exemptions rather than force-fixing decorative color.
**Cost:** Low — prose + citation in `accessibility-checks.md`; zero code, zero token edits.
**Recommendation:** Record each sub-threshold pair with its verbatim-cited exemption; defer any
actual ratio change to the **ADMIN-RETHEME-01** milestone.
**Verdict:** Ship
**Confidence:** High

### R-2 — Record the 4.95:1 primary-button pair as a watch-item, do not pad it

**Claim (sourced):** white-on-teal `#0e7c86` computes to **4.95:1** — it **passes** SC 1.4.3 (≥4.5:1)
but with almost no margin, so any future token nudge would break it. Record it as a **watch-item**,
not a finding and not a fix.

**Pros:** Truthful — it passes today, so no exemption is needed; flagging the thin margin warns the
ADMIN-RETHEME-01 milestone before a nudge silently drops it below AA.
**Cons / Tradeoffs:** A watch-item has no machine gate here (the offline calc records the number but
does not fail on a thin margin); relies on the future milestone reading the note.
**Analogue:** GOV.UK's re-runnable axe-core checks would catch a regression in CI — the watch-item is
the doc-of-record stand-in until that milestone owns the live re-theme.
**Cost:** Low — one annotated row in `accessibility-checks.md`.
**Recommendation:** Record 4.95:1 as PASS + watch-item; **defer** any padding of the pair to
ADMIN-RETHEME-01 (padding it now would be a token edit, out of scope).
**Verdict:** Defer (the fix); Ship (the record)
**Confidence:** High

### R-3 — Verify never-color-alone + CVD via architecture and DevTools emulation, no binaries

**Claim (sourced):** A11Y-04 (meaning never conveyed by color alone; palette CVD-safe) is argued
primarily from the **architectural** property — every status = surface + text + **label + icon** —
backed by a documented **manual pass through Chrome DevTools "Emulate vision deficiencies"** recorded
as a checklist. **No CVD tooling or binary/screenshot artifacts are added** (D-05).

**Pros:** The label+icon architecture is the actual defense, so color-vision deficiency cannot hide
meaning regardless of hue; honors the milestone's no-binary constraint; matches documented
standard-of-practice.
**Cons / Tradeoffs:** The DevTools emulation step is inherently **manual** (operator-run) — it is a
signed checklist, not an automated gate; a screenshot would be "objective" but is explicitly forbidden.
**Analogue:** USWDS's first-class "do not rely on color alone" rule (with the ~4.5% CVD population
figure) and GOV.UK's review-plus-tooling verification — both verify via rules + review, **not**
committed simulation images.
**Cost:** Low — a manual DevTools checklist recorded in `notes/accessibility-checks.md` (and the
operator sign-off in Plan 86-03); zero binaries, zero dependencies.
**Recommendation:** Argue A11Y-04 from the never-color-alone architecture; corroborate with the
recorded DevTools-emulation checklist; ship no binaries.
**Verdict:** Ship
**Confidence:** High

### R-4 — Adjudicate the A11Y-03 borderline targets against the SC 2.5.8 Inline/Spacing exceptions

**Claim (sourced):** primary `.cwb-btn` (40×40px) and theme-toggle segments (32px height) **pass
SC 2.5.8 on measurement**. The narrowest inline jump-nav anchor (~26.9px vertical; horizontal
label-dependent) is adjudicated against the **Inline** exception ("size … constrained by the
line-height of non-target text"), with the **Spacing** exception (24px-circle non-intersection) as
the fallback test. If neither clearly holds, record it as a documented finding — never change CSS.

**Pros:** Both exceptions are quoted verbatim, so the adjudication is defensible; the pass-on-
measurement targets need no exception at all; the fallback (record-as-finding) keeps tokens/CSS
untouched.
**Cons / Tradeoffs:** The Inline/Spacing determination for the narrowest anchor is a **judgment against
rendered geometry** — it must be measured on the actual `file://` render, not asserted; a wrong measure
would mis-adjudicate.
**Analogue:** GOV.UK adjudicates target size per-component against WCAG 2.2's new AA criteria (2.5.8 is
new in 2.2) rather than blanket-failing small inline controls.
**Cost:** Low — measure rendered geometry, record the applicable exception (or the finding) in
`accessibility-checks.md`; no code change.
**Recommendation:** Record the two pass-on-measurement targets as PASS; adjudicate the jump-nav anchor
under Inline (Spacing fallback); if neither holds, record a documented finding — do **not** edit CSS.
**Verdict:** Ship
**Confidence:** Medium (the pass-on-measurement targets are High; the narrowest-anchor exception is Medium pending the rendered-geometry check)

### R-5 — Machine-enforce the scope boundary via the widened `--scope` allowlist, not a pasted diff

**Claim (sourced):** the red-team scope audit (NOTES-03 / D-03) must **widen the existing
`scripts/brandbook-guards.sh --scope` allowlist** to exactly `brandbook/**` + `README.md` + `mix.exs`
+ `notes/**` + the guard/render scripts, and capture its **output** — rather than pasting a
`git diff --stat` into `red-team.md`.

**Pros:** The porcelain-walk guard **fails** on any stray out-of-scope edit; the boundary is enforced
by the tool, not asserted in prose (the exact NOTES-03 footgun avoided); one source of truth (the
default `--scope` list), no drift risk from a separate mode.
**Cons / Tradeoffs:** Widening the allowlist is itself an edit to a guard script — but that script is
inside the allowlist, so the guard remains self-consistent; the allowlist must be kept exact (too wide
defeats the boundary).
**Analogue:** GOV.UK's re-runnable axe-core/html-validate CI checks — "machine-enforced, not asserted"
is the same philosophy; a pasted diff is the anti-pattern.
**Cost:** Low — extend the `case` block in `brandbook-guards.sh --scope` (Plan 86-04) and capture its
output plus the `logo-guards.sh` binary-budget result in `notes/red-team.md`.
**Recommendation:** Widen the default `--scope` allowlist (not a new mode); capture the guard output +
binary-budget result verbatim as the NOTES-03 close.
**Verdict:** Ship
**Confidence:** High

---

## Zero-drift proof (record)

This phase **documents and defers** — it never patches tokens or the shipped admin CSS. The hard gate:

```bash
# tokens frozen (v1.15 zero-drift / TOKEN-01)
git diff --exit-code brandbook/tokens/tokens.css
# no new binary/raster committed by this plan (research.md is the only artifact)
git diff --stat
```

All actual ratio/token changes (raising status-border ratios to 3:1, padding the 4.95:1 primary
button) belong to the **ADMIN-RETHEME-01** milestone, which consumes this research record as its
provenance. `[VERIFIED: 86-RESEARCH.md § Verified Contrast Findings; notes/accessibility-checks.md]`
