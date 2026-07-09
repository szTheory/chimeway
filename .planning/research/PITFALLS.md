# Domain Pitfalls

**Domain:** Brand identity + design-system package production for an OSS Elixir/Phoenix dev tool (v1.15 Brand Identity & Brand Book — `brandbook/` deliverable)
**Researched:** 2026-07-09
**Confidence:** HIGH (WCAG/W3C citations verified against primary sources; design-token and logo-craft findings cross-checked against multiple independent practitioner sources; brand-specific constraints sourced directly from `prompts/chimeway-brand-book.md` and `prompts/brand-book-pressure-test.md`)

This file supersedes the stale v1.4-era `PITFALLS.md` previously at this path (webhook/workflow pitfalls, out of scope for this milestone). Roadmap phase names below are descriptive placeholders (Logo System, Design Tokens, HTML Brandbook, Brand Voice & Microcopy, Component States & Accessibility, Red-Team/Decision Notes) — the roadmapper should map these onto actual numbered phases starting after Phase 80.

## Critical Pitfalls

### Pitfall 1: Generic / AI-templated logomark (derivative, not brand-based)

**What goes wrong:**
The logo reads as a stock AI-generator output — rounded abstract blob, generic "connection dots" glyph, or a gradient orb — indistinguishable from thousands of other devtool logos (the exact "gradient-mesh SaaS blob" the brand book explicitly bans in §19).

**Why it happens:**
Programmatic/AI-assisted SVG generation defaults to safe, trend-following shapes because it's optimizing for "looks like a logo" rather than "is *this* brand." Without an explicit conceptual constraint (path + endpoint + signal arc, per brand book §13), the generator falls back to generic geometry.

**How to avoid:**
Anchor every logo direction to one of the brand book's specific concept primitives (rounded path entering a bell-like endpoint; a c-curve becoming a route; two route nodes joined by a chime arc; a `cw` monogram where the w implies a path) before generating SVG. Reject any direction that could be relabeled for a different company without losing meaning — a classic distinctiveness gut-check used by logo-systems specialists.

**Warning signs:** The mark still "works" if you swap the wordmark for a competitor's name; the concept can't be explained in one sentence tied to Chimeway's actual metaphor (routed signal, not generic tech).

**Phase to address:** Logo System phase (concept selection gate, before SVG production).

---

### Pitfall 2: Illegible at 16px favicon size / fails the "small test"

**What goes wrong:**
A mark that looks refined at 200px turns to visual mush at 16×16 (256 total pixels) — thin strokes anti-alias into gray smudge, multiple small shapes merge, and the mark becomes unrecognizable as a favicon, docs-sidebar icon, or GitHub social avatar.

**Why it happens:**
Designers (and generators) iterate at large canvas sizes and never test the actual deployed size. Detail that reads fine at 512px collapses well before 16px.

**How to avoid:**
Apply the standard "shrink to 16px, can you still tell what it is" test to every candidate mark before it's shortlisted; if it turns to mush, simplify with fewer shapes and thicker strokes rather than trying to preserve detail. Brand book §13 already sets minimum sizes (16px min / 24px preferred digital, 8mm print) — treat 16px as the hard gate, not the preferred size. Provide a purpose-built simplified favicon variant (already scoped in `artifact_requirements`: `favicon.svg`) rather than reusing the primary mark unmodified.

**Warning signs:** The mark relies on ≥3 distinct visual ideas at once (brand book §13 caps this at two); stroke width under ~1.5px relative to the mark's bounding box; any internal negative-space detail smaller than roughly 10% of the mark's height.

**Phase to address:** Logo System phase (dedicated small-size/favicon QA step before options are presented to the user).

**Sources:** [How to Design a Favicon: Size Requirements and Best Practices](https://www.osilly.cz/how-to-design-a-favicon-size-requirements-and-best-practices-for-2026/); logo-mistake synthesis via [Designhill](https://www.designhill.com/design-blog/mistakes-to-avoid-when-using-ai-for-logo-design/) and [Global Gurus](https://globalgurus.org/how-to-fix-common-mistakes-in-ai-generated-logos-alignment-contrast-etc/).

---

### Pitfall 3: Over-literal music metaphor (clappers, notes, staff lines, bell drawings)

**What goes wrong:**
The mark or illustration set drifts into literal audio/music iconography — a detailed bell with a clapper, a musical note, staff lines, a megaphone, sound-wave art — turning Chimeway into what reads as an audio/notification-sound app rather than an infrastructure library.

**Why it happens:**
"Chime" is in the name, and both music and bell imagery are the path of least resistance for a generator or designer without a hard constraint. This is the single most explicitly-forbidden failure mode in the source spec.

**How to avoid:**
Brand book §12 states this directly: "Avoid making the brand literally about music. Chimeway is not an audio product." §13 explicitly bans "tiny clappers, musical notes, staff lines, or detailed bell drawings." §18 bans "noisy sound-wave art" and "3D rendered bells." Route the concept through the secondary metaphor set instead — paths, routes, traces, waypoints, signal arcs, timelines, delivery rails — treating "chime" as *etymology*, not *iconography*. Any bell-adjacent shape must abstract to a simple geometric endpoint (an arc or curve terminus), never a representational bell illustration.

**Warning signs:** Any SVG path resembling a bell silhouette with a visible clapper/rim detail; any note glyph (♪/♫); parallel horizontal lines suggesting a staff; sound-wave concentric arcs radiating from a point (vs. a single directional signal arc, which is acceptable).

**Phase to address:** Logo System phase + Red-Team/Decision Notes phase (explicit checklist item against brand book §12/§13/§18 literal-music banlist).

---

### Pitfall 4: Rectangular background cage forced onto the logomark

**What goes wrong:**
The generated mark gets boxed into a rounded-rect or circle "badge" container (the default output style of most AI logo generators and icon libraries), which the user has explicitly and repeatedly flagged as an unwanted pattern ("AI seems to always force a rectangular BG shape onto these logomarks and I do NOT like that").

**Why it happens:**
Container badges are the safest, most template-friendly output for AI generators because they guarantee consistent bounding boxes and simplify favicon/app-icon export pipelines — but they're generic and fight the "breaking boundaries" quality the user wants.

**How to avoid:**
Default every logo asset to a transparent background with no enclosing shape; the mark's own silhouette (not a container) defines its edge. Reserve any background treatment for clearly-labeled contextual preview swatches (e.g., "on dark," "on light") that are not part of the exportable asset set. This is a non-negotiable constraint stated three times across the source material (PROJECT.md hard taste constraints, brand-book-pressure-test.md non_negotiables, and brand book §13 misuse rules: "don't box in").

**Warning signs:** Any SVG whose outermost element is a `<rect>`/`<circle>` with a fill color sized to the full mark bounding box; export previews that only look "finished" against a colored badge.

**Phase to address:** Logo System phase (hard reject criterion at the SVG-review gate).

---

### Pitfall 5: Mark doesn't survive mono / inverse / single-color reproduction

**What goes wrong:**
The primary full-color mark uses gradients, multiple hues at similar lightness, or relies on background color-mixing to read — so the mono (single-color) or inverse (dark-mode) version loses legibility or the "signal" concept disappears entirely.

**Why it happens:**
Color is treated as the primary differentiator instead of shape. Brand book §13 requires the mark to "work in one color" and "work in dark mode," and §14 explicitly forbids gradients inside the mark — but this is easy to violate when a direction is designed color-first.

**How to avoid:**
Design the mark's silhouette to be legible in pure black-on-transparent before adding any color; treat color as a refinement layer, not the mechanism of legibility (mirrors the favicon guidance: "if your favicon is unrecognizable in black and white, color is doing too much work — a strong icon reads through shape alone"). Ship `logo-mark-mono.svg` and an inverse/dark variant as first-class deliverables (already scoped in `artifact_requirements`) and gate every direction on passing both before it's shortlisted.

**Warning signs:** A direction's rationale leans on "the teal-to-brass gradient creates depth" or similar color-dependent language; the mark uses more than 2 colors to convey its single concept.

**Phase to address:** Logo System phase.

**Sources:** [How to Design a Favicon](https://www.osilly.cz/how-to-design-a-favicon-size-requirements-and-best-practices-for-2026/); brand book §13/§14.

---

### Pitfall 6: Typemark that's just a font choice, not an integrated treatment

**What goes wrong:**
The "integrated typemark" deliverable (required: "≥1 fully-integrated typemark direction") turns out to be plain Inter/system-font lettering with the icon glued to the left — satisfying the letter of the requirement (there's an SVG called `logo-typemark.svg`) but not the intent (a custom-drawn or modified letterform where a motif/flourish is worked into the type itself).

**Why it happens:**
Typesetting a wordmark in a nice font is dramatically cheaper than custom letterform work, and it's easy to convince yourself a well-kerned Inter wordmark "counts." The user called this failure mode out directly: "not just a shitty icon to the left of basic text... a fully worked in custom type treatment."

**How to avoid:**
Require the integrated typemark direction to modify at least one letterform (e.g., the terminal of the "y" extends into a route line and terminates in the signal-arc endpoint; the "w" itself implies a path, per brand book §13's monogram idea) or to merge the icon into the negative space of a letter, not merely place it adjacent. Treat "logotype = font + kerning" as an automatic fail for the *integrated* direction specifically (a plain wordmark lockup is fine as a *separate*, non-integrated direction — the requirement is for at least one direction to go further).

**Warning signs:** The typemark SVG is structurally identical to the horizontal lockup SVG (icon + `<text>`-equivalent path with a gap), just resized; no letterform in the wordmark differs from the base typeface outline.

**Phase to address:** Logo System phase (explicit acceptance criterion distinguishing "integrated typemark" from "horizontal lockup").

---

### Pitfall 7: Mark and wordmark visually disconnected ("icon-left, text-right" default lockup)

**What goes wrong:**
The primary horizontal lockup places the logomark and wordmark too far apart, at mismatched optical weights, or on unrelated baselines/heights — reading as two unrelated logos side by side rather than one unified brand mark. This is the generic pattern the user rejected outright ("just a shitty icon to the left of basic text").

**Why it happens:**
Auto-layout tools and most "logo builder" workflows default to icon + gap + wordmark with the gap sized by convenience (e.g., a fixed padding token) rather than by the visual relationship between the two elements' specific shapes.

**How to avoid:**
Size the mark-to-wordmark gap relative to the clearspace unit already defined in brand book §13 (1x = height of the lowercase "c"), and tune it down from generic UI-icon spacing until the two elements read as one composition — echoing the user's explicit note that "the logotype should be appropriately close to the logomark, not too separated." Align optical (not just mathematical) baselines and x-heights between mark and type.

**Warning signs:** The gap between mark and wordmark is a round UI spacing token (e.g., `--cw-space-lg`) copy-pasted without visual tuning; removing either element leaves the other looking complete and unrelated to what was removed.

**Phase to address:** Logo System phase.

---

### Pitfall 8: Forking a second, parallel token system instead of reconciling with existing `--cw-*`

**What goes wrong:**
The brandbook ships its own `tokens.css`/`tokens.json` with different names, different scale steps, or different hex values than the tokens already shipped and battle-tested in `chimeway_admin/priv/static/chimeway_admin.css` (`--cw-ink`, `--cw-teal`, `--cw-space-md`, `--cw-radius-md`, the full light/dark/system theme block, focus-ring tokens, status-color triads, etc.). Now the codebase has two sources of truth for "what teal is," and any future admin re-theme has to reconcile them under time pressure.

**Why it happens:**
It's structurally easier to author a brand book's tokens fresh, matching the *written* brand book's palette (§14/§28 in `chimeway-brand-book.md`) than to first diff that written spec against the *shipped* CSS and merge. The written brand book and the shipped admin CSS already disagree in small ways (e.g., the admin CSS's dark-theme status colors, focus-halo, and several component-level tokens like `--cw-button-primary-bg` don't appear in the brand book's §14/§28 token list at all — they were added during v1.11 implementation).

**How to avoid:**
Treat `chimeway_admin.css`'s `@layer cw.tokens` block as the reconciliation source of truth for anything it already defines (colors, spacing, radius, motion, focus tokens); the brandbook's `tokens.css`/`tokens.json` should be a documented *superset* — same values and names for overlapping concepts, plus brand-level additions (typography scale beyond admin's 4-step scale, shadow/elevation beyond `--cw-shadow-panel`, motion durations) that the admin CSS doesn't yet need. Any deviation (renamed variable, changed hex, different scale) must be logged in `decision-log.md` with an explicit "propagate to chimeway_admin in a follow-on milestone" note, per PROJECT.md's stated deferral of the full `cw.tokens` re-theme. This is exactly the milestone's own explicit requirement: "reconciled with the existing `--cw-*` tokens rather than forked."

**Warning signs:** `grep -c '\-\-cw-' brandbook/tokens/tokens.css` finds variable names not present in `chimeway_admin.css`, or present with different values for the same name; a value like `--cw-teal: #0e7c86` in one file and a different hex under the same name in the other.

**Phase to address:** Design Tokens phase (dedicated reconciliation step: diff brandbook tokens against `chimeway_admin.css` before merge, not after).

**Sources:** [W3C Design Tokens Community Group format spec](https://www.designtokens.org/tr/2025.10/format/) (interoperable JSON token interchange, the standard this reconciliation should target); PROJECT.md milestone-start scope decision ("full `chimeway_admin` `cw.tokens` re-theme deferred").

---

### Pitfall 9: Token sprawl / naming chaos (no primitive-vs-semantic discipline)

**What goes wrong:**
The token set grows without a naming taxonomy — some tokens name a raw value (`--cw-teal`), some name intent (`--cw-admin-accent`), some name a component directly (`--cw-button-primary-bg`), and there's no documented rule for when to add a new token vs. reuse an existing semantic one. Six months from now nobody can tell whether `--cw-brass` or `--cw-status-warning-text` is the "correct" token for a new warning icon.

**Why it happens:**
Tokens accumulate additively as each new component needs "just one more" value, and without an explicit two-tier (primitive → semantic) or three-tier (primitive → semantic → component) model, there's no forcing function to reuse instead of add.

**How to avoid:**
Keep the two-tier structure the shipped `chimeway_admin.css` already implicitly follows: primitives (`--cw-ink`, `--cw-teal`, `--cw-space-md`) that are raw values, and semantic tokens (`--cw-admin-fg`, `--cw-admin-accent`, `--cw-status-warning-text`) that alias primitives by *purpose* and are what components actually consume. Document this explicitly in the brandbook (it's currently implicit, not written down anywhere) so the pattern survives contributor turnover. Every new token needs a one-line justification; "every token has a reason" per the milestone's own `artifact_requirements`.

**Warning signs:** A component in `examples/components.html` references a primitive color directly (`color: var(--cw-teal)`) instead of a semantic token; two semantic tokens resolve to the same primitive with no documented distinction in purpose.

**Phase to address:** Design Tokens phase.

**Sources:** [Naming Tokens in Design Systems — Nathan Curtis / EightShapes](https://medium.com/eightshapes-llc/naming-tokens-in-design-systems-9e86c7444676); [Smart Interface Design Patterns — How To Name Design Tokens](https://smart-interface-design-patterns.com/articles/naming-design-tokens/) ("component tokens should always reference semantic tokens, never primitives directly — that indirection is what keeps the system flexible").

---

### Pitfall 10: Hardcoded values leaking past tokens into the HTML brandbook or examples

**What goes wrong:**
`index.html` or `examples/*.html` end up with inline hex colors, ad-hoc `px` spacing, or one-off shadow values that never round-trip through `tokens.css` — so the "living" brandbook silently drifts from the token source of truth the moment someone tweaks a demo component by eye.

**Why it happens:**
It's fast to eyeball-adjust a color or spacing value directly in a component example rather than adding/adjusting a token and re-deriving. This is especially tempting in a standalone HTML file with scoped CSS, where there's no build-time lint to catch it.

**How to avoid:**
Author every color, spacing, radius, shadow, and motion value in the brandbook's demo CSS as a `var(--cw-*)` reference, never a literal. Add a QA step (grep for raw hex codes and bare `px` values outside the `:root`/token block) to the pre-ship checklist, mirroring the "run relevant safe format/test commands" instruction in the source spec.

**Warning signs:** `grep -E '#[0-9a-fA-F]{3,6}' brandbook/index.html` (outside the token `<style>` block) returns hits; spacing values like `padding: 17px` that don't map to any token step.

**Phase to address:** HTML Brandbook phase (QA gate before final commit).

---

### Pitfall 11: Dark-mode contrast regressions in new brandbook tokens

**What goes wrong:**
New tokens introduced by the brandbook (e.g., an extended typography or shadow scale) get a dark-mode mapping that wasn't checked against contrast, breaking the pattern the shipped admin CSS already got right — e.g., admin's dark theme swaps `--cw-admin-focus` to `--cw-brass` and status-danger text to a lighter `#ffd4d4` specifically because the light-mode danger red (`#b83232`) fails contrast on `--cw-night` (`#07131a`). A brandbook token added without doing the equivalent dark-mode remap will look fine in isolation and fail once rendered on the dark surface.

**Why it happens:**
Dark mode is treated as "invert-ish" rather than as its own contrast-checked palette. The existing admin CSS already proves this requires deliberate per-token remapping (compare the `:root` block's light values to the `[data-cw-theme="dark"]` block's — colors change, not just background).

**How to avoid:**
For every new semantic token added by the brandbook, produce and contrast-check both a light and a dark value using the same pattern as `chimeway_admin.css`'s existing `[data-cw-theme="dark"]` block, not a CSS `filter: invert()` shortcut. Run each light/dark pair through a contrast checker against its expected background before shipping.

**Warning signs:** A new token has only one value defined (no dark-mode override block entry); a status color's dark-mode text/surface pairing wasn't independently contrast-checked (just copied from light mode).

**Phase to address:** Design Tokens phase + Component States & Accessibility phase (dark-mode contrast is re-verified at the accessibility gate, not just assumed correct from token authoring).

---

### Pitfall 12: Insufficient text contrast (WCAG 2.2 SC 1.4.3)

**What goes wrong:**
Body text, muted/secondary text, or status-pill text falls below the 4.5:1 (normal text) / 3:1 (large text, ≥18pt or ≥14pt bold) contrast ratio required by WCAG 2.2 SC 1.4.3 Contrast (Minimum) — most likely candidates in this palette: `--cw-muted` (#5E6B72) on `--cw-paper`, `--cw-brass` (#D6A84F) text on light backgrounds (already flagged as forbidden in brand book §14: "Never use brass text on paper for body copy"), or any new brandbook-only text color that wasn't checked.

**Why it happens:**
A palette that looks harmonious/on-brand in a swatch doesn't guarantee every foreground/background pairing actually used in real copy clears AA. The brand book itself already names this risk and bans one specific combination — but new combinations introduced by brandbook-only components (callouts, do/don't captions, decision-log tables) aren't automatically covered by that existing rule.

**How to avoid:** Run every actually-used text/background pairing (not just the "primary combinations" table in brand book §14) through a WCAG contrast checker; record ratios in `notes/accessibility-checks.md` per the milestone's own artifact requirements. Enforce the brand book's own rules: never brass-on-paper body text, never muted text below 14px, avoid ultra-light font weights (100/200) since thin strokes anti-alias to lower effective contrast even at nominally-passing ratios.

**Warning signs:** Any caption, footnote, or muted label under 14px; any accent color (brass, mint, violet) used for body-length text rather than short labels/highlights.

**Phase to address:** Component States & Accessibility phase; verification step listed explicitly against `notes/accessibility-checks.md`.

**Sources:** [W3C — Understanding SC 1.4.3 Contrast (Minimum)](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html) (via brand book's own citation); WCAG 2.2 is a superset of 2.1 for this criterion (no numeric change).

---

### Pitfall 13: Insufficient non-text / UI-component contrast (WCAG 2.2 SC 1.4.11)

**What goes wrong:**
Interactive and meaningful graphical elements — button borders, input borders, focus rings, status-pill borders, icon glyphs that convey meaning, logomark strokes shown against a UI surface — fall below the 3:1 contrast ratio SC 1.4.11 requires against their adjacent color, even though the *text* inside those components passes 1.4.3. This is a distinct, commonly-missed criterion from text contrast.

**Why it happens:**
Design QA habitually checks text contrast (well-known) and skips non-text contrast (newer, WCAG 2.1+, less habitual). Subtle borders (e.g., `--cw-line: #D8D3C7` on `--cw-paper: #FFFDF8`) and low-contrast disabled-looking-but-actually-active controls are the most common misses.

**How to avoid:** Explicitly contrast-check: button/input border vs. its background; focus-ring color vs. both the focused element and the page background; status-pill border vs. pill surface; any icon that conveys state (not purely decorative) vs. its background. Non-text contrast applies to active/interactive components and meaningful graphics — decorative icons that only repeat adjacent text are exempt, so scope the check to state-bearing UI, not every glyph in the illustration set.

**Warning signs:** A component's only visual affordance is a border or icon at a similar lightness to its background (e.g., `--cw-line` borders on `--cw-paper` measure well under 3:1 and are meant for decorative dividers, not interactive-element outlines).

**Phase to address:** Component States & Accessibility phase.

**Sources:** [W3C — Understanding SC 1.4.11 Non-text Contrast](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html); [Deque University — 1.4.11 Non-Text Contrast](https://dequeuniversity.com/resources/wcag2.1/1.4.11-non-text-contrast).

---

### Pitfall 14: Focus visibility loss (WCAG 2.2 SC 2.4.7, 2.4.11, 2.4.13)

**What goes wrong:**
New brandbook-authored interactive demos (logo-selector toggles, dark/light/system switcher, do/don't accordion) either omit a visible focus indicator entirely, or the indicator gets obscured by a sticky header/overlay when the element scrolls into view, or the indicator's own contrast against adjacent colors is too low to register as "visible."

**Why it happens:**
The existing `chimeway_admin.css` already solved this well (`:focus-visible { outline: 3px solid var(--cw-focus-ring); outline-offset: 3px; box-shadow: 0 0 0 6px var(--cw-focus-halo); z-index: var(--cw-z-focus); }`) — but a fresh HTML brandbook built as a new standalone document can easily forget to reproduce this pattern, especially for one-off interactive widgets that weren't in the original admin component library (e.g., a logo-direction picker, a color-swatch copy button).

**How to avoid:** Reuse the exact focus-visible pattern already proven in `chimeway_admin.css` (3px outline + offset + halo box-shadow, with a raised z-index so it can't be visually clipped by neighboring elements) for every new interactive element the brandbook introduces. For any sticky/overlay elements in the brandbook's own layout (e.g., a sticky section nav), verify tabbing through the page never leaves a focused element fully hidden behind it (SC 2.4.11 Focus Not Obscured (Minimum) — new in WCAG 2.2).

**Warning signs:** Any `<button>`/`<a>`/toggle in the brandbook HTML has `outline: none` without a replacement focus style; a sticky nav/header sits above content with no scroll-margin accounting for keyboard focus.

**Phase to address:** HTML Brandbook phase (implementation) + Component States & Accessibility phase (verification via keyboard-only tab-through).

**Sources:** [W3C — Understanding SC 2.4.7 Focus Visible](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html); [W3C — Understanding SC 2.4.11 Focus Not Obscured (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html).

---

### Pitfall 15: Reduced-motion not honored in new brandbook interactions/animations

**What goes wrong:**
The brandbook adds its own motion (a route-line-drawing hero animation, a logo-reveal transition, an accordion expand) that ignores `prefers-reduced-motion`, even though `chimeway_admin.css` already ships a correct global reduced-motion utility block. A standalone HTML file authored fresh can easily omit the equivalent rule.

**Why it happens:**
Motion is usually the last thing added, often copy-pasted from an example/tutorial without the accessibility wrapper, and a single-file HTML brandbook has no shared stylesheet forcing the pattern to be inherited automatically the way `chimeway_admin.css`'s `@layer cw.utilities` does app-wide.

**How to avoid:** Port the exact `@media (prefers-reduced-motion: reduce)` block already in `chimeway_admin.css` (`animation-duration: 0.001ms !important; animation-iteration-count: 1 !important; transition-duration: 0.001ms !important; scroll-behavior: auto !important;`) into `brandbook/tokens/tokens.css` or the brandbook's own stylesheet, and apply it universally, not just to whichever specific animation was top-of-mind when authored. This is SC 2.3.3 Animation from Interactions territory (AAA, but directly named in the brand book's own §20 motion section) — treat it as a hard requirement for this project regardless of its AAA/AA classification, since the written brand book already commits to it.

**Warning signs:** Any `@keyframes`/CSS `transition` in the brandbook HTML with no corresponding reduced-motion override; motion used for anything beyond micro-feedback (hover/press), e.g., auto-playing hero animation, per brand book §20's own "avoid ... looping animations that distract" rule.

**Phase to address:** HTML Brandbook phase.

**Sources:** [W3C — Understanding SC 2.3.3 Animation from Interactions](https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions); brand book §20 (verbatim reduced-motion CSS block already specified).

---

### Pitfall 16: Colorblind-unsafe success/error palette (red-green without redundant coding)

**What goes wrong:**
Status pills (`--cw-success` green vs. `--cw-danger` red) are distinguished by hue alone. For protanopia/deuteranopia (red-green color blindness, the most common form), a success pill and an error pill can become difficult to tell apart at a glance if the only differentiator is red vs. green — especially in the compact `cw-status` pill component, which is small and uses subtle surface-tint differences.

**Why it happens:**
Red = bad, green = good is the most deeply ingrained UI convention, so it's rarely questioned even though it's the single most common colorblind-accessibility failure in status systems.

**How to avoid:**
The shipped `chimeway_admin.css` already does the right thing structurally — every `.cw-status--*` variant pairs a color with a `.cw-status__dot` and (in the component markup) a text label, never color alone. Preserve and *document* this pattern explicitly in the brandbook's accessibility notes so it isn't accidentally dropped when new brand-only status examples are authored (e.g., a marketing-page "delivered/suppressed/failed" showcase graphic). Where a purely visual status swatch is shown (e.g., in the color-palette page of the brandbook itself), consider adding a shape or icon differentiator, not just a color chip, per the “pair color with icons/text, never color alone” principle.

**Warning signs:** A new component or marketing graphic shows status via a colored dot/bar with no accompanying icon or text label; a status legend relies on a color key without also labeling each swatch.

**Phase to address:** Component States & Accessibility phase.

**Sources:** Color-blind-safe status-indicator synthesis (pair color with icon+text; avoid red+green-only, prefer blue+orange/blue+red for status pairs) — [PaletteRx — Designing Error, Warning, and Success Colors](https://paletterx.com/blog/color-for-error-and-success-states); [Coblind — Color Blind Friendly Palette](https://coblind.com/blog/color-blind-friendly-palette).

---

### Pitfall 17: Touch-target sizing below WCAG 2.2 SC 2.5.8 (24×24 CSS px minimum)

**What goes wrong:**
Small brandbook-specific interactive elements — a color-swatch "copy hex" button, a logo-direction thumbnail selector, an inline do/don't toggle — ship smaller than the 24×24 CSS pixel minimum target size (or without adequate spacing from neighboring targets), making them hard to activate precisely, especially on touch devices.

**Why it happens:**
The existing admin CSS already enforces 40–44px minimum interactive heights for its own controls (`.cw-button` `min-height: 40px`, nav items `min-height: 44px` at mobile breakpoints) — but brand-new brandbook-only widgets (which don't reuse `.cw-button`/`.cw-nav__item`) can easily be authored smaller since they're "just for the brandbook page," not the product UI.

**How to avoid:** Apply the same 40–44px interactive-height discipline already proven in `chimeway_admin.css` to every clickable element the brandbook itself introduces, even purely-decorative-context ones like copy-to-clipboard hex swatches. WCAG 2.2 SC 2.5.8 sets a hard floor of 24×24 CSS px for the hit area (not necessarily the visible glyph) with narrow exceptions (inline text links, spacing-equivalent, essential); the admin CSS's existing 40px+ convention already clears this comfortably — just don't regress below it for brandbook-only chrome.

**Warning signs:** Any custom brandbook button/icon-trigger under 24px in either dimension with no spacing exception rationale; icon-only controls without a padded hit area larger than the visible icon.

**Phase to address:** Component States & Accessibility phase.

**Sources:** [W3C — Understanding SC 2.5.8 Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html).

---

### Pitfall 18: Inconsistent voice/tone or copy that violates the LLM banlist

**What goes wrong:**
Different brandbook sections (marketing-facing hero copy vs. component-state labels vs. decision-log prose) drift into inconsistent registers — or worse, hype/SaaS language explicitly banned by the brand book leaks in ("supercharge," "omnichannel," "AI-powered," "book a demo") because the brandbook itself is a large, multi-section document authored across several passes.

**Why it happens:**
The brand book's own §9 draws a real distinction ("brand metaphors are allowed in headlines and marketing, but operational docs and admin UI must be literal") which is easy to blur inside a single brandbook document that necessarily contains both marketing-style hero examples *and* literal component-state examples side by side.

**How to avoid:** Tag every copy example in the brandbook with its intended *context* (marketing headline vs. operational/UI copy vs. docs) so voice register is explicit, not implicit — mirroring brand book §25's own "Homepage / Docs / Admin UI / Release notes / Social post" per-context good/bad structure. Run every piece of brandbook prose against the §33 LLM copy banlist as a literal grep-style check before shipping (`customer engagement platform`, `omnichannel`, `growth engine`, `book a demo`, `AI-powered`, etc.).

**Warning signs:** A single page mixes a punchy marketing headline immediately followed by literal operational copy with no visual/structural cue distinguishing the two registers; any banlist phrase appears anywhere in `brandbook/`.

**Phase to address:** Brand Voice & Microcopy phase.

---

### Pitfall 19: Error copy that violates the what/why/how-to-fix pattern

**What goes wrong:**
Example error/empty/suppressed-state copy in the component-states deliverable reverts to vague, unhelpful phrasing ("Oops," "Something went wrong," "Delivery failed") — exactly the anti-pattern the brand book already calls out in §21, and exactly what Nielsen Norman Group's error-message guidelines identify as the most common and most damaging error-copy failure.

**Why it happens:**
Placeholder/lorem-ipsum-style copy is fast to write for a *demonstration* component and easy to forget to replace with a real, brand-accurate example before the brandbook ships — especially for states that aren't the primary focus (e.g., a "loading" or "empty" state gets real attention, but the adjacent "error" state next to it gets a throwaway label).

**How to avoid:** Every error/failure/suppressed-state example in `examples/components.html` must follow the three-part pattern the brand book already specifies and demonstrates (§21): *what happened* (Delivery suppressed), *why it matters/why it happened* (recipient disabled email for `invoice.paid`), *how to fix or what happens next* (Chimeway will retry with backoff). Treat brand book §21's own "Good" examples as the literal copy bank to reuse/adapt, not just inspiration — don't invent new placeholder error strings from scratch.

**Warning signs:** Any example error/empty state in the component library reads as a single unqualified sentence with no cause and no next step; the word "Oops," bare "Error," or "Something went wrong" appears anywhere in the brandbook's example copy.

**Phase to address:** Brand Voice & Microcopy phase + Component States & Accessibility phase (states deliverable specifically).

**Sources:** [NN/g — Error-Message Guidelines](https://www.nngroup.com/articles/error-message-guidelines/) ("explicit, human-readable, polite, precise, gives constructive advice"; positive, non-blaming tone).

---

### Pitfall 20: CTA inconsistency (SaaS-style CTAs leaking into examples)

**What goes wrong:**
Landing-page or README-header example copy in the brandbook includes CTA language the brand book explicitly bans ("Book a demo," "Start free trial," "Contact sales," "See pricing") because these are the *default* CTA patterns most marketing-template references and AI copy generators reach for, and the brandbook's own `examples/landing-page-section.html` is exactly the kind of artifact where that default is most likely to surface.

**Why it happens:**
Landing-page section examples are frequently drafted by adapting a generic SaaS landing-page template/structure, which drags its CTA conventions along even when the visual design is customized.

**How to avoid:** Use only the CTA set the brand book already prescribes in §23 ("Get started," "Read the docs," "View on GitHub") for every example CTA in the brandbook, with no exceptions in demonstration content. Treat this as a literal find-and-replace check, same as the banlist check in Pitfall 18.

**Warning signs:** Any button/link copy in `examples/landing-page-section.html` or `examples/readme-header-example.md` doesn't match the brand book's approved CTA list.

**Phase to address:** Brand Voice & Microcopy phase.

---

### Pitfall 21: Polluting the repo outside `brandbook/`

**What goes wrong:**
The milestone's implementation touches files outside the self-contained folder — editing `chimeway_admin.css` directly to "test" reconciled tokens, modifying unrelated README sections beyond the agreed header, or adding new top-level directories (`assets/`, `design/`) that fragment where brand material lives — violating the explicit repo-hygiene non-negotiable ("do not shit up the codebase... avoid unrelated edits").

**Why it happens:**
It's tempting to "just quickly verify" a reconciled token value by pasting it into the real `chimeway_admin.css` rather than only reading/diffing it, or to add a README badge/logo reference that requires touching more of the README than the agreed-upon header-only scope.

**How to avoid:** Enforce the milestone's own stated rollout boundary from PROJECT.md verbatim: "`brandbook/` package + README header + favicon this milestone; full `chimeway_admin` `cw.tokens` re-theme deferred to a follow-on milestone." Any edit outside `brandbook/`, the README header, and a single new favicon reference should be treated as scope creep requiring explicit sign-off. Run `git diff --stat` against the milestone branch before each commit and flag any path outside the allowed set.

**Warning signs:** `git status`/`git diff --stat` shows modified files under `chimeway_admin/priv/static/` or `lib/`; new top-level directories appear that aren't `brandbook/`.

**Phase to address:** Red-Team/Decision Notes phase (final repo-diff audit) — but should be a running check across every phase, not just the last one.

---

### Pitfall 22: Adding a build system / node_modules bloat for a static artifact

**What goes wrong:**
The team reaches for a bundler, a static-site generator, a CSS preprocessor toolchain, or an npm-based SVG-optimization pipeline with `node_modules` checked in (or even just introduced as a new required dev dependency) to produce what the source spec explicitly wants to be plain, dependency-free SVG/HTML/CSS/JSON/Markdown.

**Why it happens:**
Build tooling feels like "doing it properly" to engineers used to modern frontend stacks, and it's genuinely convenient for things like SVG optimization or a component-preview dev server — but it directly contradicts the explicit non-negotiable ("no large binaries or new build system unless clearly justified") and the "open locally via `file://`" requirement, which a bundled/hashed-asset output usually breaks.

**How to avoid:** Default to zero build step: hand-authored/optimized SVG (or a one-time, not-checked-in `svgo` CLI pass during authoring — the tool doesn't need to be a repo dependency), plain CSS with `@layer`/custom properties (the existing `chimeway_admin.css` already proves this scales fine without a preprocessor), and a single self-contained `index.html`. If a static server is genuinely needed for local preview (e.g., to work around `file://` CORS restrictions on relative asset fetches), keep the brandbook fully inlined/self-referencing so it works via direct file open — the spec explicitly asks for "works from local file open when practical."

**Warning signs:** A `package.json` appears inside `brandbook/`; any `node_modules/` directory gets created and is at risk of accidental commit; the HTML brandbook requires `npm run dev` to view rather than opening directly in a browser.

**Phase to address:** HTML Brandbook phase (architecture decision made up front) + Red-Team/Decision Notes phase (final check that no build artifacts snuck in).

---

### Pitfall 23: Committing large binaries or unlicensed/undocumented font files

**What goes wrong:**
Either (a) large raster screenshots/exports get committed uncompressed, inflating repo size permanently (git never shrinks history without a rewrite), or (b) an actual font binary (e.g., a `.woff2` for Inter/IBM Plex Mono/Source Serif 4) gets bundled into `brandbook/assets/` without checking its license terms, creating a licensing-compliance gap even though the fonts themselves are open (SIL Open Font License) — the brand book already correctly notes their OFL status but that doesn't mean redistributing the binary inside this repo is automatically the right call for this milestone.

**Why it happens:**
Committing a "final" rendered PNG of the color palette or logo grid feels safer/more portable than trusting SVG/HTML to render consistently everywhere; bundling a webfont file feels like the "complete" solution for guaranteed typography rendering in the standalone HTML brandbook.

**How to avoid:** The milestone's own font strategy is already decided and stated in PROJECT.md: "system font stack + documented OSS webfont recommendation; wordmark/typemark rendered as SVG outlines (no bundled font binary)." Hold that line — no font binaries in this milestone, full stop. For raster assets, only include them if they "earn their keep" (per the non-negotiables) and keep them optimized/compressed; prefer SVG for anything that can be vector (which is nearly everything in this deliverable set — logo, diagrams, icons, even the color palette can be rendered as SVG swatches). Git itself stores a full copy of every version of a binary in history, so once a bloated PNG is committed and later replaced, the repo stays bloated unless history is rewritten — avoid the mistake rather than plan to clean it up later.

**Warning signs:** Any file over a few hundred KB in `brandbook/`; any `.ttf`/`.otf`/`.woff`/`.woff2` file anywhere in the commit; a PNG export of something that could have been shipped as SVG.

**Phase to address:** Logo System phase + HTML Brandbook phase (font-loading decision) + Red-Team/Decision Notes phase (file-size budget check before ship).

**Sources:** [Atlassian — How to handle big repositories with Git](https://www.atlassian.com/git/tutorials/big-repositories) (git stores a full compressed copy of every version of every binary; deltas are ineffective on most binary formats); [SVG optimization synthesis](https://www.callstack.com/blog/image-optimization-on-ci-and-local) (properly optimized SVG can be up to 80% smaller).

---

### Pitfall 24: Unscoped brandbook CSS leaking into the host page/repo

**What goes wrong:**
The brandbook's CSS uses bare element selectors (`h1`, `button`, `a`) or unscoped custom properties on `:root` without a namespacing wrapper, so if the brandbook is ever embedded, iframed, or its CSS accidentally referenced from another page, it silently overrides styling elsewhere — the same class of bug the milestone explicitly wants to avoid ("scoped CSS that cannot leak into the repo").

**Why it happens:**
A standalone `index.html` feels "isolated by definition" since it's its own document, so scoping discipline feels unnecessary — but the non-negotiable is really about defensive authoring (in case the brandbook's CSS file is ever `<link>`-included elsewhere, or its patterns get copy-pasted into product code without the scoping wrapper).

**How to avoid:** Reuse the exact scoping pattern `chimeway_admin.css` already validates in production: a single root class (e.g., `.chimeway-brandbook`) wrapping all rules via `:where(.chimeway-brandbook ...)` (using `:where()` keeps specificity at zero so it composes safely if ever nested), with `@layer` boundaries (`cw.tokens`, `cw.base`, `cw.layout`, `cw.components`, `cw.utilities`) mirroring the admin CSS's own layer structure for consistency and easy future consolidation.

**Warning signs:** Any bare-tag selector (`h1 { ... }` without a scoping ancestor) in the brandbook's `<style>` block; `:root` used for brand-book-specific tokens instead of a scoped class (which would leak custom properties globally if ever included alongside other pages).

**Phase to address:** HTML Brandbook phase (CSS architecture decision made at the start, not retrofitted).

---

### Pitfall 25: Scope creep into a full `chimeway_admin` re-theme

**What goes wrong:**
Momentum from "we're already reconciling tokens" or "the new logo looks so much better than the current admin header" pulls the milestone into actually re-theming `chimeway_admin`'s shipped UI (swapping in new tokens app-wide, replacing the current `.cw-brand__mark` circle-badge placeholder with the new logo, restyling components) — which is explicitly deferred to a follow-on milestone per PROJECT.md's own scope decision.

**Why it happens:**
The reconciliation work in Pitfall 8 naturally surfaces every place the current admin CSS *could* be improved with the new brand direction, and it's hard to resist "just fixing it while we're in there," especially since the current `.cw-brand__mark` (a plain circular badge with a letter, per `chimeway_admin.css` lines 417-426) is visibly a placeholder that the new logo system is a strict improvement over.

**How to avoid:** Treat the reconciled tokens as *documentation and future-readiness*, not an app-wide swap, this milestone. Explicitly log the `.cw-brand__mark` placeholder-vs-real-logo gap as a follow-on milestone action item in `decision-log.md` rather than closing it now. Re-affirm PROJECT.md's own boundary at each phase transition: "brandbook/ package + README header + favicon this milestone; full chimeway_admin cw.tokens re-theme deferred to a follow-on milestone."

**Warning signs:** A plan or commit touches `chimeway_admin`'s LiveView templates or component CSS beyond what's needed to *read* existing tokens for reconciliation; `.cw-brand__mark`'s markup/CSS changes.

**Phase to address:** Red-Team/Decision Notes phase (explicit scope-boundary check as a standing agenda item, cross-referenced against PROJECT.md at milestone close).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Ship only 3 logo directions instead of the target 3–5 | Faster to review/decide | User has less real choice; risk the "distinct" direction never gets explored | Only if 3 directions are each meaningfully distinct (not 3 minor variants of one idea) — never acceptable as a way to avoid doing the harder integrated-typemark direction |
| Reuse `chimeway_admin.css`'s 4-step type scale instead of authoring a full marketing type scale | Zero new tokens to reconcile | Brandbook can't demonstrate hero/display typography credibly for landing pages | Acceptable for UI-context tokens; not acceptable for the brandbook's own marketing-typography demonstration, which needs the fuller scale from brand book §15 |
| Skip a real dark/light/system toggle in the HTML brandbook, just show static side-by-side screenshots | Simpler HTML, no JS needed | Fails to actually prove the tokens work live; less "implementation-ready" for engineers copying patterns | Never acceptable — a live toggle is core to proving the token system works, and it's cheap (a few lines of vanilla JS + `data-cw-theme` attribute swap, already proven by the admin CSS pattern) |
| Use `filter: invert()` for a fast dark-mode mock instead of per-token dark values | Fast to prototype | Produces contrast-broken, muddy dark-mode colors (inverted teal ≠ a good dark accent) | Never acceptable for shipped artifacts; fine only as a 30-second internal sanity check, discarded immediately |
| Defer accessibility-checks.md until after all artifacts are "done" | Faster initial production | Contrast/focus failures discovered late require rework across every already-finished component example | Never acceptable — accessibility checks should run per-artifact as it's produced, not as a final pass (a final pass should verify, not discover) |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|-----------------|-------------------|
| Existing `chimeway_admin` `--cw-*` tokens | Treating the brand book's *written* §14/§28 token list as authoritative over the *shipped* `chimeway_admin.css`, when they've already diverged (shipped CSS has status-color triads, focus-halo, and component tokens the written brand book never defined) | Diff shipped CSS against written brand book first; shipped CSS wins for anything it already defines in production, since it's load-bearing and already contrast-tuned |
| README (existing, v1.14-hardened) | Rewriting more of the README than the agreed "header" scope while adding the logo, since the README is already a carefully contract-tested "additive-superset decision page" (per v1.14 Phase 79) | Touch only the header region (logo/wordmark placement); leave the byte-identical source/packaged-README doc-contract tests (from Phase 79) untouched and passing |
| Favicon delivery | Adding a new asset pipeline/route to serve the favicon dynamically | Ship a static `favicon.svg` (already scoped in artifact_requirements) referenced with a plain `<link rel="icon">`, no new backend code |
| HexDocs / GitHub social preview | Assuming the brandbook's `social-card.svg` will "just work" as an OG image without checking GitHub/HexDocs' actual required raster formats (OG images generally need PNG/JPEG, not SVG, per common platform constraints) | Author the social card as SVG source but note in `decision-log.md` that a rasterized export (PNG at 1200×630 / 1200×675 / 1280×640 per brand book §30) is a near-term follow-up if/when OG images are actually wired into the README or a landing page — don't silently assume SVG-only is sufficient if OG usage is claimed as "done" |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Unoptimized SVGs (editor cruft: unused defs, full-precision floating-point paths, embedded editor metadata) | `brandbook/assets/*.svg` files are 5–10x larger than needed; git diffs on SVG edits are noisy and hard to review | Run an SVG optimizer (e.g., `svgo`) once during authoring (not as a checked-in dependency) before committing final assets; hand-verify the optimized output still renders identically | Becomes a real repo-size problem once there are a dozen-plus logo/diagram SVGs, especially if iterated on repeatedly (each revision adds to git history even after later cleanup) |
| Raster screenshots of the color palette / logo grid instead of native SVG/HTML rendering | Palette/logo pages look fine once, but any future palette tweak requires re-generating and re-committing a new screenshot, and old screenshots linger in history | Render palette swatches and logo previews as live SVG/HTML in the brandbook itself — no raster generation step needed at all | Breaks the "always up to date" promise of a living brandbook the first time a token changes and the screenshot isn't regenerated |
| Large embedded base64 images inside SVG or HTML (e.g., a raster texture background) | Single-file HTML brandbook balloons in size; slow to open, slow to diff in code review | Prefer pure CSS/SVG for all textures and backgrounds (brand book §18 already suggests "subtle paper texture if desired" — implement via CSS gradient/noise SVG filter, not an embedded bitmap) | Breaks the "doesn't explode repo size" requirement immediately, since base64-encoded images are ~33% larger than the binary and can't be delta-compressed effectively by git |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Bundling a font binary without verifying its license terms line by line | OFL fonts are permissively licensed, but redistributing binaries still carries reserved-name and modification-notice obligations under the SIL OFL that are easy to get subtly wrong if copied casually | Don't bundle font binaries at all this milestone (per the already-decided font strategy); if a future milestone does bundle one, keep the OFL license file and any reserved-name notices alongside it verbatim |
| Inline `<script>` in the standalone HTML brandbook with unsanitized dynamic content (e.g., a "copy hex code" clipboard feature built carelessly) | Low risk for a static local file, but sets a bad precedent/pattern if code is later copy-pasted into a real Phoenix/LiveView template without the same static-content guarantee | Keep any JS in the brandbook trivial, static, and free of any dynamic HTML injection (`innerHTML` with unescaped input); if copy-to-clipboard is included, use `navigator.clipboard.writeText` with a static, known string, never user-influenced content |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Brandbook shows logo options with no rationale or ship/reject/defer recommendation, just a gallery | User (a non-designer stakeholder) has to do the design-critique work themselves, defeating the point of "be very thorough... show me logo options so I can choose" | Every logo direction ships with the decision-matrix fields already scoped (`logo-options.md`): rationale, pros/cons, ship/reject/defer, confidence — the user picks between pre-vetted options, not raw sketches |
| Do/don't logo usage examples are abstract prose only, no visual side-by-side | Easy to misapply logo rules in practice (e.g., still boxing it in) because the rule was read, not seen | Render every do/don't rule as a visual pair (correct usage next to the explicit misuse: boxed, stretched, low-contrast background, subtitle added) directly in the brandbook, not just a bullet list |
| Dark/light/system token demonstration only shows isolated color swatches, not real components in context | Engineers implementing UI can't tell if a token pairing actually looks right together until they build it themselves | Show real assembled components (buttons, status pills, cards, forms) in both light and dark, not just a token swatch grid — this is what makes tokens "implementation-ready" rather than merely documented |

## "Looks Done But Isn't" Checklist

- [ ] **Logo system:** Often missing a *simplified* small-size/favicon variant distinct from the primary mark — verify `favicon.svg` isn't just the primary mark resized, but a deliberately reduced-detail version that passes the 16px test.
- [ ] **Design tokens:** Often missing dark-mode values for every new semantic token — verify every token added by the brandbook (not just carried over from `chimeway_admin.css`) has both a light and dark value, contrast-checked independently.
- [ ] **Accessibility checks:** Often missing non-text/UI-component contrast checks (SC 1.4.11) even when text contrast (SC 1.4.3) was checked — verify `notes/accessibility-checks.md` explicitly lists both criteria with pass/fail per component, not just body-text pairs.
- [ ] **Component states:** Often missing the `disabled` and `focus` states for interactive brandbook-native widgets (color-swatch copy button, theme toggle) even when hover/active are covered — verify all states listed in the milestone scope (hover/focus/active/disabled/loading/error/empty/skeleton/selected) exist for every genuinely interactive element the brandbook itself introduces, not just for the documented product components.
- [ ] **Reduced motion:** Often missing on brand-new brandbook-specific animation (hero reveal, logo-direction carousel) even when the ported admin utility class exists elsewhere in the file — verify the `prefers-reduced-motion` block is applied globally in the brandbook's own stylesheet, not assumed inherited.
- [ ] **Repo hygiene:** Often missing a final `git diff --stat` review against the milestone's stated file-scope boundary — verify no files changed outside `brandbook/`, the README header region, and the favicon reference.
- [ ] **Token reconciliation:** Often missing an explicit diff artifact — verify `decision-log.md` documents every case where a brandbook token value/name differs from `chimeway_admin.css`, with a stated reason, not silent drift.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|------------------|
| Discovered rectangular-cage or over-literal-music-metaphor logo direction after user review | LOW | Logo directions are cheap SVG iterations at this stage — regenerate the offending direction(s) against the corrected constraint; no downstream code depends on logo files yet since rollout is scoped to README header + favicon only |
| Discovered token-fork drift (brandbook tokens don't match `chimeway_admin.css`) after both files exist | MEDIUM | Diff the two token sets, decide per-value which is authoritative (shipped CSS wins for anything already in production), regenerate `brandbook/tokens/tokens.css`/`tokens.json` from the reconciled source, and log every resolved conflict in `decision-log.md` |
| Discovered contrast failures across multiple components after accessibility-checks.md was written late (Pitfall in Technical Debt table) | MEDIUM-HIGH | Re-run contrast checks per component, not just per token in isolation (a token can pass a swatch check but fail in a specific combination used in a real component); expect to touch multiple example files, not just the token source |
| Discovered scope creep into `chimeway_admin` re-theme mid-milestone | MEDIUM | Revert the out-of-scope admin CSS/template changes (they're likely still uncommitted or in a small number of recent commits given the milestone is fresh); move the underlying idea into a follow-on-milestone note in `decision-log.md` rather than discarding the insight |
| Discovered committed font binary or oversized raster asset after several commits | MEDIUM-HIGH | Removing the file from the working tree isn't enough — git retains it in history; requires either doing this cleanup *before* first push (amend/rebase while still local-only) or accepting the size cost and fixing forward (never force-rewrite already-pushed shared history without explicit user approval) |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| Generic/AI-templated logomark | Logo System | Concept traceable to a named brand-book metaphor primitive (§13); fails the "could be relabeled for any company" test |
| Illegible at 16px favicon | Logo System | Visual 16px-shrink test on every candidate; simplified favicon variant ships separately from primary mark |
| Over-literal music metaphor | Logo System + Red-Team/Decision Notes | Explicit checklist grep/visual-scan against brand book §12/§13/§18 banned-imagery list |
| Rectangular background cage | Logo System | Hard reject rule: no enclosing `<rect>`/`<circle>` in exportable mark SVGs |
| Mark fails mono/inverse | Logo System | `logo-mark-mono.svg` and inverse variant both pass legibility review independently of color version |
| Typemark is just a font choice | Logo System | Integrated typemark direction modifies ≥1 letterform or merges icon into letter negative space — structurally distinct from the plain horizontal lockup SVG |
| Mark/wordmark visually disconnected | Logo System | Gap tuned to brand book §13 clearspace unit, not a generic UI spacing token; passes "remove one element, does the other still feel complete" test |
| Second parallel token system (fork) | Design Tokens | `decision-log.md` contains explicit diff of brandbook tokens vs. `chimeway_admin.css`; no unexplained name/value divergence |
| Token sprawl / naming chaos | Design Tokens | Documented primitive-vs-semantic taxonomy; every token has a one-line justification |
| Hardcoded values leaking into HTML | HTML Brandbook | `grep` for raw hex/px values outside token block returns zero hits in shipped files |
| Dark-mode contrast regressions | Design Tokens + Component States & Accessibility | Every new semantic token has an independently contrast-checked dark value, not an inverted/derived guess |
| Text contrast failures (SC 1.4.3) | Component States & Accessibility | `notes/accessibility-checks.md` lists every real text/background pairing used, with ratios |
| Non-text/UI contrast failures (SC 1.4.11) | Component States & Accessibility | `notes/accessibility-checks.md` separately covers interactive-element borders, focus rings, meaningful icons |
| Focus visibility loss (SC 2.4.7/2.4.11) | HTML Brandbook + Component States & Accessibility | Keyboard-only tab-through of the full brandbook HTML confirms every focusable element shows a visible, unobscured indicator |
| Reduced motion not honored (SC 2.3.3) | HTML Brandbook | `prefers-reduced-motion` block ported into brandbook stylesheet and applied globally, verified with OS-level reduced-motion toggle |
| Colorblind-unsafe status palette | Component States & Accessibility | Every status example pairs color with icon/text/shape, never color alone; spot-checked with a color-blindness simulation |
| Touch-target sizing below 24×24px | Component States & Accessibility | Every brandbook-native interactive element measured ≥24×24 CSS px hit area (target: match existing 40–44px admin convention) |
| Inconsistent voice/tone, banlist leakage | Brand Voice & Microcopy | Full-text grep of `brandbook/` against brand book §33 LLM copy banlist; every copy example tagged by context (marketing/UI/docs) |
| Error copy missing what/why/how-to-fix | Brand Voice & Microcopy + Component States & Accessibility | Every error/suppressed/failed example follows the 3-part pattern from brand book §21, reusing its literal example copy where applicable |
| CTA inconsistency | Brand Voice & Microcopy | Every example CTA matches the brand book §23 approved list exactly |
| Repo pollution outside `brandbook/` | Red-Team/Decision Notes (running check every phase) | `git diff --stat` shows changes confined to `brandbook/`, README header region, and favicon reference only |
| Unwanted build system / node_modules | HTML Brandbook + Red-Team/Decision Notes | No `package.json`/`node_modules` inside `brandbook/`; HTML opens directly via `file://` with no dev-server dependency |
| Large binaries / unlicensed fonts | Logo System + HTML Brandbook + Red-Team/Decision Notes | No font binaries committed (system stack + SVG outlines only, per PROJECT.md decision); file-size budget check before ship |
| Unscoped CSS leakage | HTML Brandbook | All brandbook CSS wrapped in a single scoping class using `:where()`, mirroring `chimeway_admin.css`'s proven pattern |
| Scope creep into full admin re-theme | Red-Team/Decision Notes | No changes to `chimeway_admin` templates/component CSS beyond read-only reconciliation; deferred re-theme item logged in `decision-log.md` |

## Sources

**Accessibility (WCAG 2.2), verified against W3C primary sources:**
- [W3C — Understanding SC 1.4.3 Contrast (Minimum)](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)
- [W3C — Understanding SC 1.4.11 Non-text Contrast](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html) and [Deque University summary](https://dequeuniversity.com/resources/wcag2.1/1.4.11-non-text-contrast)
- [W3C — Understanding SC 2.4.7 Focus Visible](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html)
- [W3C — Understanding SC 2.4.11 Focus Not Obscured (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html)
- [W3C — Understanding SC 2.3.3 Animation from Interactions](https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions)
- [W3C — Understanding SC 2.5.8 Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)

**Design tokens:**
- [Design Tokens Community Group — Format specification 2025.10](https://www.designtokens.org/tr/2025.10/format/)
- [Nathan Curtis (EightShapes) — Naming Tokens in Design Systems](https://medium.com/eightshapes-llc/naming-tokens-in-design-systems-9e86c7444676)
- [Smart Interface Design Patterns — How To Name Design Tokens](https://smart-interface-design-patterns.com/articles/naming-design-tokens/)

**Logo/graphic craft:**
- [OSILLY — How to Design a Favicon: Size Requirements and Best Practices](https://www.osilly.cz/how-to-design-a-favicon-size-requirements-and-best-practices-for-2026/)
- [Designhill — Common Mistakes to Avoid When Using AI for Logo Design](https://www.designhill.com/design-blog/mistakes-to-avoid-when-using-ai-for-logo-design/)
- [Global Gurus — How to Fix Common Mistakes in AI-Generated Logos](https://globalgurus.org/how-to-fix-common-mistakes-in-ai-generated-logos-alignment-contrast-etc/)

**Colorblind-safe status color:**
- [PaletteRx — Designing Error, Warning, and Success Colors for Your System](https://paletterx.com/blog/color-for-error-and-success-states)
- [Coblind — Color Blind Friendly Palette: How to Design Accessible Colors](https://coblind.com/blog/color-blind-friendly-palette)

**Brand voice / error copy:**
- [Nielsen Norman Group — Error-Message Guidelines](https://www.nngroup.com/articles/error-message-guidelines/)

**Repo hygiene:**
- [Atlassian — How to handle big repositories with Git](https://www.atlassian.com/git/tutorials/big-repositories)
- [Callstack — Image Optimization on CI and Local (SVG optimization)](https://www.callstack.com/blog/image-optimization-on-ci-and-local)

**Project-internal (authoritative for constraints):**
- `.planning/PROJECT.md` — v1.15 milestone scope, hard taste constraints, rollout boundary, font strategy
- `prompts/chimeway-brand-book.md` — brand voice, logo direction, color/token specs (§9, §12, §13, §14, §15, §18, §19, §20, §21, §23, §25, §28, §33)
- `prompts/brand-book-pressure-test.md` — non-negotiables, quality bar, artifact requirements
- `chimeway_admin/priv/static/chimeway_admin.css` — shipped, production `--cw-*` token system, scoping pattern, and accessibility patterns (focus-visible, reduced-motion) that the brandbook must reconcile with, not fork

---
*Pitfalls research for: Chimeway v1.15 Brand Identity & Brand Book*
*Researched: 2026-07-09*
