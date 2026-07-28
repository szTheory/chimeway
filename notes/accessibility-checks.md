# Chimeway Brand Book — Accessibility Checks (WCAG 2.2)

**Date:** 2026-07-27
**Scope:** rendered `brandbook/index.html` + the frozen `--cw-*` token layer (`brandbook/tokens/tokens.css`).
**Requirements:** A11Y-01 (text contrast), A11Y-02 (non-text contrast), A11Y-03 (focus/motion/target-size), A11Y-04 (never color-alone / CVD), A11Y-05 (per-pairing record).
**Method (D-01):** the per-pairing ratios below are the **evidence of record**, produced by the dependency-free offline calc `scripts/contrast-audit.sh` (POSIX shell + awk, no node/npm/network). The calc reads the `--cw-*` hexes verbatim from `brandbook/tokens/tokens.css` (READ-ONLY; TOKEN-01 zero-drift) and reproduces the WCAG relative-luminance + contrast-ratio formula already inlined in `brandbook/index.html:824-835`. Re-run `scripts/contrast-audit.sh` to reproduce every number here byte-for-byte.

**Disposition rule (D-02):** sub-threshold pairings are recorded as **documented WCAG exemptions**, never patched — editing the tokens would violate the v1.15 zero-drift invariant (deferred to ADMIN-RETHEME-01). Every load-bearing pair passes.

**Rounding contract:** ratios are printed to **2 decimals, rounded half-up** — `int(ratio * 100 + 0.5) / 100`. The AA verdict uses a `>=` comparison against the threshold (text 4.5:1, non-text/UI 3:1), so a ratio exactly on the threshold scores PASS. This contract is stated in the calc header and reproduced identically on every re-run.

---

## 1. Per-pairing ratio table — evidence of record (A11Y-05)

Quoted **verbatim** from `scripts/contrast-audit.sh` stdout (light + dark, all pair classes: text fg/bg, status triads text/surface ×5, status borders ×5, panel borders, focus rings, primary button, disabled). The `AA` column is the raw WCAG AA test **only**; the exemption disposition for each FAIL is adjudicated in §3 below, not by the calc.

```
== WCAG 2.x offline contrast audit (brandbook/tokens/tokens.css) ==
formula: brandbook/index.html:824-835 · rounding: 2dp half-up · text>=4.5:1 ui>=3:1 (>= = PASS)

class          theme  pairing                    fg        bg         ratio  thr   AA
-----          -----  -------                    --        --         -----  ---   --
text           light  body text (fg/surface)     #102027   #fffdf8    16.42  4.5   PASS
text           dark   body text (fg/surface)     #fffdf8   #07131a    18.49  4.5   PASS
text           light  muted caption              #5e6b72   #fffdf8     5.40  4.5   PASS
text           dark   muted caption              #b8c5c9   #07131a    10.62  4.5   PASS
text           light  link                       #0e5f67   #fffdf8     7.24  4.5   PASS
text           dark   link                       #9adbcf   #07131a    12.00  4.5   PASS
status-text    light  success text/surface       #0b6b47   #e8f6ef     5.88  4.5   PASS
status-text    dark   success text/surface       #b7f0d7   #0d2f24    11.36  4.5   PASS
status-text    light  warning text/surface       #765000   #fff2cf     6.46  4.5   PASS
status-text    dark   warning text/surface       #ffe0a0   #33260b    11.54  4.5   PASS
status-text    light  danger text/surface        #9f2424   #fdecec     6.68  4.5   PASS
status-text    dark   danger text/surface        #ffd4d4   #3a1717    11.88  4.5   PASS
status-text    light  info text/surface          #0e5f67   #e8f6f5     6.64  4.5   PASS
status-text    dark   info text/surface          #b8eee8   #0d3035    11.02  4.5   PASS
status-text    light  neutral text/surface       #425158   #f1eee4     7.10  4.5   PASS
status-text    dark   neutral text/surface       #d5dee1   #142832    11.14  4.5   PASS
status-border  light  success border/surface     #9fd8bf   #e8f6ef     1.45  3.0   FAIL
status-border  dark   success border/surface     #2d7a5d   #0d2f24     2.80  3.0   FAIL
status-border  light  warning border/surface     #e5c36d   #fff2cf     1.53  3.0   FAIL
status-border  dark   warning border/surface     #8a6824   #33260b     2.87  3.0   FAIL
status-border  light  danger border/surface      #eda3a3   #fdecec     1.77  3.0   FAIL
status-border  dark   danger border/surface      #984747   #3a1717     2.53  3.0   FAIL
status-border  light  info border/surface        #94d4d7   #e8f6f5     1.50  3.0   FAIL
status-border  dark   info border/surface        #397b83   #0d3035     2.91  3.0   FAIL
status-border  light  neutral border/surface     #d8d3c7   #f1eee4     1.29  3.0   FAIL
status-border  dark   neutral border/surface     #4b6972   #142832     2.58  3.0   FAIL
panel-border   light  panel border (line/paper)  #d8d3c7   #fffdf8     1.47  3.0   FAIL
panel-border   dark   panel border (line/paper)  #29414a   #07131a     1.74  3.0   FAIL
panel-border   light  border-strong/surface      #a9bebf   #fffdf8     1.91  3.0   FAIL
panel-border   dark   border-strong/surface      #4b6972   #07131a     3.19  3.0   PASS
focus-ring     light  focus ring / surface       #2d6cdf   #fffdf8     4.78  3.0   PASS
focus-ring     dark   focus ring / surface       #d6a84f   #07131a     8.57  3.0   PASS
focus-ring     light  focus ring / panel         #2d6cdf   #ffffff     4.86  3.0   PASS
focus-ring     dark   focus ring / panel         #d6a84f   #10232c     7.37  3.0   PASS
button         light  primary button fg/bg       #ffffff   #0e7c86     4.95  4.5   PASS
button         dark   primary button fg/bg       #07131a   #9adbcf    12.00  4.5   PASS
disabled       light  disabled text fg/bg        #68757b   #eee9dc     3.92  4.5   FAIL
disabled       dark   disabled text fg/bg        #7f9298   #13242b     4.92  4.5   PASS
```

**Corroborating rendered-output proof (not evidence of record):** `brandbook/index.html` ships an **8-cell live contrast matrix** (`#contrast-matrix`, `renderContrast()` at index.html:850) that resolves tokens by painting a hidden probe inside `.cw-brandbook` under the active `data-theme` and recomputes on theme flip. It proves the tokens *paint correctly* under both themes — but it scores only **8 text cells** and never covers the status triads, borders, focus rings, or disabled states where the exemptions live. Per D-01 it is cited here as a corroborating witness only; the offline calc above is the A11Y-05 evidence of record (this avoids the vacuous-pass footgun of an ~8-row table).

---

## 2. A11Y-01 — text contrast (SC 1.4.3 Contrast (Minimum), Level AA)

**All load-bearing text passes 4.5:1.** Body text 16.42/18.49, muted caption 5.40/10.62, link 7.24/12.00, and all five status text/surface triads 5.88+ (light) / 11.02+ (dark). The primary button is the only load-bearing pair near the line — recorded as a watch-item below.

The single sub-4.5 text pair is **disabled text (3.92:1 light)**, recorded as a **DOCUMENTED WCAG EXEMPTION** under the SC 1.4.3 *Incidental* exception. Verbatim [CITED: w3.org/TR/WCAG22 §1.4.3]:

> "Incidental: Text or images of text that are part of an inactive user interface component, that are pure decoration, that are not visible to anyone, or that are part of a picture that contains significant other visual content, have **no contrast requirement**."

- **disabled text `#68757b` / disabled bg `#eee9dc` = 3.92 (light)** — EXEMPT: a disabled control is an "inactive user interface component," which under 1.4.3 Incidental has **no contrast requirement**. Disposition: DOCUMENTED, no token change. (Dark disabled `#7f9298`/`#13242b` = 4.92 passes 4.5:1 anyway.)
- **`chimeway` header wordmark** — covered by the SC 1.4.3 *Logotypes* exception ("Text that is part of a logo or brand name has no contrast requirement"); the mono logotype on paper contrasts strongly regardless.

**Watch-item (record, do NOT fix):** primary button white `#ffffff` on teal `#0e7c86` = **4.95:1** — a PASS, but any token nudge would break it. Per D-02 + TOKEN-01 this is recorded, never patched; a tightening belongs to ADMIN-RETHEME-01.

---

## 3. A11Y-02 — non-text / UI contrast (SC 1.4.11 Non-text Contrast, Level AA)

**Load-bearing UI information passes 3:1.** Focus rings — which *are* required to identify the focus state — pass in every theme: blue `#2d6cdf` = 4.78 (surface) / 4.86 (panel) light; brass `#d6a84f` = 8.57 (surface) / 7.37 (panel) dark.

The status borders (1.29–1.77 light) and panel borders (line/paper 1.47, border-strong 1.91 light) fall below 3:1. They are recorded as **DOCUMENTED WCAG EXEMPTIONS** under SC 1.4.11's *User Interface Components* scoping. Verbatim [CITED: w3.org/TR/WCAG22 §1.4.11]:

> "User Interface Components: Visual information **required to identify** user interface components and states, except for inactive components or where the appearance of the component is determined by the user agent and not modified by the author"

The operative test is *required to identify*. Every Chimeway status is identified by **surface fill + text color + a text label + an icon glyph** (the "never color-alone" architecture — see §5). The border color is therefore **not the information required to identify** the component or its state; it is a decorative boundary, outside the 3:1 requirement.

| Pairing (light) | Ratio | SC | Disposition |
|-----------------|-------|-----|-------------|
| status success border `#9fd8bf` / surface | 1.45 | 1.4.11 | EXEMPT — identity carried by surface + text + label + icon |
| status warning border `#e5c36d` / surface | 1.53 | 1.4.11 | EXEMPT — "required to identify" carried by label+icon |
| status danger border `#eda3a3` / surface | 1.77 | 1.4.11 | EXEMPT |
| status info border `#94d4d7` / surface | 1.50 | 1.4.11 | EXEMPT |
| status neutral border `#d8d3c7` / surface | 1.29 | 1.4.11 | EXEMPT |
| panel border line `#d8d3c7` / paper | 1.47 | 1.4.11 | EXEMPT — decorative boundary, not "required to identify" |
| border-strong `#a9bebf` / paper | 1.91 | 1.4.11 | EXEMPT — decorative boundary |

All EXEMPT rows are DOCUMENTED (no token change). The dark borders trend higher (2.53–3.19) but the same exemption applies where they remain sub-3:1.

---

## 4. A11Y-03 — focus, motion, target size (verified against rendered CSS)

Evidence located in `brandbook/brandbook.css` (rendered output), recorded per D-06.

- **Focus visible (SC 2.4.7, AA).** `.cwb-btn:focus-visible` sets `outline: var(--cw-focus-offset) solid var(--cw-focus); outline-offset: var(--cw-focus-offset)` (brandbook.css:350-353); `:scope a:focus-visible` and `.cwb-brandmark:focus-visible` also carry visible rings. Focus-ring contrast passes SC 1.4.11 (4.78+ light, 7.37+ dark, §3). **Satisfied.** [CITED: w3.org/TR/WCAG22 §2.4.7 "Any keyboard operable user interface has a mode of operation where the keyboard focus indicator is visible."]
- **Focus not obscured (SC 2.4.11, AA — new in 2.2).** The sticky `.cwb-nav` bar is the only fixed/sticky author content. The criterion is "not **entirely** hidden." **Checklist item for Plan 03 operator sign-off:** keyboard-tab the rendered `file://` page and confirm no focused control is entirely hidden behind the sticky nav. [CITED: w3.org/TR/WCAG22 §2.4.11 "When a user interface component receives keyboard focus, the component is not entirely hidden due to author-created content."]
- **Reduced motion (SC 2.3.3, Level AAA).** `@media (prefers-reduced-motion: reduce)` (brandbook.css:465) sets `animation: none` for `.cwb-skeleton` and `.cwb-btn.is-loading` — the only two animations in the book. **Note:** SC 2.3.3 is **Level AAA**; honoring it means the book *exceeds* the AA bar, not that AA mandates it. [CITED: w3.org/TR/WCAG22 §2.3.3]
- **Target size (SC 2.5.8, AA — new in 2.2).** Verbatim exceptions [CITED: w3.org/WAI/WCAG22/Understanding/target-size-minimum]: Spacing, Equivalent, **Inline** ("The target is in a sentence or its size is otherwise constrained by the line-height of non-target text"), User agent control, Essential.
  - Primary `.cwb-btn`: `min-block-size: 2.5rem; min-inline-size: 2.5rem` = **40×40px** — **PASS outright** (brandbook.css:319-320).
  - Theme-toggle segments: `min-block-size: 2rem` (32px) + `padding: 4px 16px` — height 32px ≥24px, width = text + 32px padding — **PASS on measurement**, no exception needed (brandbook.css:405-408).
  - Inline jump-nav anchors (`.cwb-anchors a`): `padding: 4px 8px`, `font-size: 14px`, `line-height: 1.35` (brandbook.css:113-120) → rendered height ≈ (14×1.35) + 8 = **~26.9px vertical** (already ≥24px); horizontal depends on label length. **Adjudication:** these are inline navigation in a horizontal wrapped list, so the **Inline** exception ("its size is otherwise constrained by the line-height of non-target text") plausibly applies; the `gap: 4px 8px` between them should additionally be checked against the **Spacing** exception. **Recorded as a documented finding — NO CSS/token change** (out of scope; the vertical dimension already meets 24px). [planner_assumption A2, low risk]

---

## 5. A11Y-04 — meaning never conveyed by color alone / colorblind-safe (CVD)

**Architectural argument (the primary defense).** Every Chimeway status renders as **surface fill + text color + a text label + an icon glyph** — never color alone. Grep-backed in `brandbook/index.html` (status badge markup, lines 176-183): each `.cwb-badge` carries a `color`/`background`/`border` token *and* an `aria-hidden` icon glyph *and* a text label. Sample (index.html:176):

```html
<span class="cwb-badge" style="color: var(--cw-status-success-text); background: var(--cw-status-success-surface); border: ... var(--cw-status-success-border);"><span aria-hidden="true">&#10003;</span> Succeeded</span>
```

Every status pill in the set is structured identically — Succeeded (check), Suppressed/Expired (warning), Failed (cross), Enqueued (recycle), Planned/Cancelled (dot), Sending (arrow) — so removing color entirely still leaves label + icon to distinguish state. This matches the USWDS/Carbon "**do not rely on color alone**" standard-of-practice ([CITED: designsystem.digital.gov/design-tokens/color/overview]; [CITED: carbondesignsystem.com/guidelines/accessibility/color]).

**CVD emulation checklist (operator sign-off in Plan 03 — no CVD tooling, no screenshots, per D-05).** Open `brandbook/index.html` via `file://` and run Chrome DevTools → Rendering → "Emulate vision deficiencies" for each mode; confirm every status remains distinguishable by label + icon (not color):

- [ ] **Protanopia** (no red) — status pills distinguishable by label + icon.
- [ ] **Deuteranopia** (no green) — success vs danger distinguishable by icon + label.
- [ ] **Tritanopia** (no blue) — info/focus states still identifiable.
- [ ] **Achromatopsia** (no color) — the strongest test: all statuses distinguishable with color fully removed.

---

## Self-check

- `scripts/contrast-audit.sh` exits 0 and its stdout is quoted verbatim in §1; re-running it reproduces every ratio here (2dp half-up).
- `brandbook/tokens/tokens.css` is untouched (`git diff --quiet -- brandbook/tokens/tokens.css`).
- All SC clauses are quoted verbatim, not paraphrased ("no contrast requirement" for 1.4.3; "required to identify" for 1.4.11).
