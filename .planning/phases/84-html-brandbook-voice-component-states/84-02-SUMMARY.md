---
phase: 84-html-brandbook-voice-component-states
plan: 02
subsystem: ui
tags: [brandbook, html, logos, tokens, theme-toggle, static-html, file-safe]

# Dependency graph
requires:
  - phase: 81-design-tokens
    provides: brandbook/tokens/tokens.css --cw-* SSOT consumed by name via relative <link>
  - phase: 83-logo-direction-selection
    provides: brandbook/assets/logo/*.svg shipped marks (two inlined, rest <img>)
  - plan: 84-01
    provides: brandbook/brandbook.css scoped stylesheet + .cwb-*/.is-*/.cw-brandbook vocabulary; scripts/brandbook-guards.sh gate
provides:
  - brandbook/index.html — file://-safe document shell, tri-state theme toggle, logo/color/type/spacing sections
  - Section anchors logo/color/type/spacing + nav references for contrast/states/dodont/voice/errors/naming
  - The single inline classic <script> (theme toggle) that plan 03 extends with the contrast matrix
affects: [84-03, 84-04, 85-repo-integration, 86-a11y-audit]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-file file://-safe HTML: relative <link>/<img> only, no fetch/XHR/module/use-sprite/remote/root-absolute (BOOK-01)"
    - "Tri-state theme toggle in ONE inline classic <script>: data-theme set for light/dark, removed for system (D-03)"
    - "D-04 corrected split: only the two currentColor marks inlined as <svg> (theme recolor); fixed-color/inverse/raster via <img>"
    - "Token-driven swatches painted from var(--cw-*) so chips render the live resolved value per theme; zero hard-coded hex"

key-files:
  created:
    - brandbook/index.html
  modified: []

key-decisions:
  - "[84-02]: Swatch 'resolved value' is expressed visually — each chip is painted with var(--cw-*) so it repaints on theme flip; the mono label carries the token name. No hex text is printed (would be drift + would fail the zero-hex acceptance)."
  - "[84-02]: Extended the two themeable-mark demo with an accent-tinted copy (style=\"color: var(--cw-accent)\") to show the on-theme accent stroke reservation without redefining tokens."
  - "[84-02]: Inverse lockup rendered via <img> on a var(--cw-night) field (its correct usage), not inlined — confirming the plan-01 D-04 correction."

requirements-completed: [BOOK-01, BOOK-02, BOOK-03]

coverage:
  - id: T1
    description: "Document shell: relative head <link>s to tokens.css + brandbook.css + favicon, .cw-brandbook scope root, .cwb-nav ten-anchor chrome, tri-state theme toggle in one inline classic <script> (D-01/D-02/D-03, BOOK-01/BOOK-02)"
    requirement: "BOOK-01, BOOK-02"
    verification:
      - kind: automated
        ref: "grep class=cw-brandbook + href=tokens/tokens.css + href=brandbook.css + data-cwb-theme + data-theme, and NEGATIVE grep for https://, root-absolute, type=module, fetch(, XMLHttpRequest => OK"
        status: pass
      - kind: automated
        ref: "scripts/brandbook-guards.sh family 1 file://-safety over index.html => PASS"
        status: pass
    human_judgment: false
  - id: T2
    description: "Logo-family section: two currentColor marks inlined verbatim as <svg> (theme recolor), fixed-color/inverse/raster via <img>, clear-space + min-size notes, no background cage (BOOK-03, D-04 corrected, D-05 parity)"
    requirement: "BOOK-03"
    verification:
      - kind: automated
        ref: "grep mark-mono d= 'M6 5h12l-2.5 14h-7Z' + logotype-mono d= subset + assets/logo/chimeway-logotype-inverse.svg + <img + id=logo => OK"
        status: pass
      - kind: automated
        ref: "scripts/brandbook-guards.sh D-05 parity (both inlined marks match SSOT assets) => 4 PASS"
        status: pass
    human_judgment: false
  - id: T3
    description: "Color/token swatches (primitive + semantic + status-triad, each var(--cw-*)-driven, status never color-alone), 4-size/2-weight typography, 7-step 4px spacing scale — zero hard-coded hex (BOOK-03)"
    requirement: "BOOK-03"
    verification:
      - kind: automated
        ref: "grep id=color + id=type + id=spacing + cw-space- + cw-font-size- + cw-status- => OK; negative grep for #RRGGBB hex => none"
        status: pass
      - kind: automated
        ref: "scripts/brandbook-guards.sh xmllint over index.html => parses"
        status: pass
    human_judgment: false

# Metrics
duration: 5min
completed: 2026-07-18
status: complete
---

# Phase 84 Plan 02: Brand-Book Document Shell + Logo/Color/Type/Spacing Summary

**A single file://-safe `brandbook/index.html` — relative-linked to the tokens SSOT and the scoped stylesheet — that stands up the `.cw-brandbook` scaffold, a tri-state theme toggle in one inline classic script, and the token-driven logo, color, typography, and spacing sections with zero hard-coded hex.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-07-18
- **Completed:** 2026-07-18
- **Tasks:** 3
- **Files modified:** 1 (created)

## Accomplishments

- Authored the file://-safe document shell: `<head>` links `tokens/tokens.css` (Phase-81 `--cw-*` SSOT, read never redefined) then `brandbook.css` by relative path plus a relative favicon `<link>`; `<body class="cw-brandbook">` scope root; a `.cwb-nav` chrome linking all ten section anchors. No remote/root-absolute refs, no `type="module"`, no `fetch`/`XHR`/cross-file use-sprite (BOOK-01).
- Wired the tri-state theme control: three `data-cwb-theme` buttons (light/dark/system) driven by ONE inline classic `<script>` that sets `data-theme` on `document.documentElement` for light/dark and REMOVES it for system (deferring to `@media (prefers-color-scheme)` in tokens.css), initializing in system mode (D-03). No second script tag — plan 03 extends this same script with the contrast matrix.
- Rendered the logo family per the corrected D-04 policy: only the two `fill="currentColor"` marks (`mark-mono`, `logotype-mono`) are inlined as `<svg>` with verbatim `d=` paths from the SSOT assets (guard D-05 parity passes), so they recolor with the theme; the fixed-color logotype/stacked/mark, the paper-white inverse lockup (on a `var(--cw-night)` field), the favicon, and the OG preview all render via `<img src>`. Marks sit on an open field with clear-space/min-size notes and no background cage.
- Authored the color, typography, and spacing sections token-driven: primitive + semantic-alias + status-triad swatches painted from `var(--cw-*)` (chips render the live resolved value and repaint on theme flip); status pills pair an icon + word so status is never color-alone; the accent-reservation list is documented; typography shows exactly four sizes at two weights via `var(--cw-font-size-*)`/`var(--cw-font-weight-*)` with sans + mono stacks; spacing shows the seven-step 4px scale as `var(--cw-space-*)`-driven bars. Zero hard-coded hex on the page.

## Task Commits

Each task was committed atomically:

1. **Task 1: Document shell, head links, anchor nav, tri-state theme toggle + inline JS** - `9a33582` (feat)
2. **Task 2: Logo-family section (inline two currentColor marks; <img> the rest)** - `d66f0f4` (feat)
3. **Task 3: Color/token swatches + typography + spacing sections** - `87db5c2` (feat)

**Plan metadata:** committed separately (docs: complete plan)

## Files Created/Modified

- `brandbook/index.html` - The standalone, file://-safe brand-book page: document shell (relative token + CSS links, scope root, ten-anchor nav), tri-state theme toggle (single inline classic script), and the logo / color-token / typography / spacing sections. Extended by plans 03 (states, contrast, do/don't) and 04 (voice, errors, naming).

## Decisions Made

- Swatch "resolved value" is shown visually: each chip is painted with `var(--cw-*)` so it renders the live resolved color under the active theme and repaints on toggle; the mono `.cwb-label` carries the token name. Printing a literal hex would be token drift and would fail the plan's zero-hex acceptance, so no hex text is emitted.
- Added an accent-tinted copy of the mono mark (`style="color: var(--cw-accent)"`) to demonstrate the reserved on-theme accent stroke without redefining any token.
- Rendered the inverse lockup via `<img>` on a `var(--cw-night)` field (its intended dark-field usage) rather than inlining it — confirming the plan-01 D-04 correction that only two marks carry `currentColor`.

## Deviations from Plan

None - plan executed exactly as written. **Total deviations:** 0 auto-fixed. **Impact on plan:** No scope change.

## Issues Encountered

None. `scripts/brandbook-guards.sh` reports GREEN for every check this plan owns — family 1 file://-safety, scope-nonleak, token-drift, D-05 logo parity (all four), and xmllint well-formedness over `index.html`. The remaining guard FAILs (`.is-hover`…`.is-empty`, `.cwb-skeleton`, `luminance`, voice anchors `docs`/`marketing`, error phrase "what happened") are the intended presence-gate RED for content authored in plans 03-04, not defects.

## Known Stubs

None. No placeholder/TODO/FIXME or empty-data stub patterns. The ten-anchor nav intentionally references section ids (`contrast`, `states`, `dodont`, `voice`, `errors`, `naming`) that plans 03-04 add — this is planned cross-wave wiring, not a stub.

## User Setup Required

None - open `file://…/brandbook/index.html` directly in a browser; no server, build, or dependency.

## Next Phase Readiness

- The shell, scope root, single inline script, and the logo/color/type/spacing sections are ready for plan 03 to append the component-state matrix, live contrast matrix (extending this script), and do/don't pairs, and for plan 04 to append the voice/errors/naming sections. Once those land, the guard's section-presence family clears to GREEN.
- No blockers.

## Self-Check: PASSED

- FOUND: brandbook/index.html
- FOUND commit: 9a33582 (Task 1)
- FOUND commit: d66f0f4 (Task 2)
- FOUND commit: 87db5c2 (Task 3)
- No tracked file deletions introduced by any task commit.

---
*Phase: 84-html-brandbook-voice-component-states*
*Completed: 2026-07-18*
