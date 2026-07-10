---
phase: 81-design-tokens-reconciliation-documentation
plan: 01
subsystem: brandbook
tags: [design-tokens, css, custom-properties, theming, reconciliation]
requires: []
provides:
  - brandbook/tokens/tokens.css SSOT — all --cw-* tokens on global :root
  - Cross-phase token-name contract (81-03 tokens.json mirror, Phase 84 HTML brandbook consumer)
  - Light/dark/system theming resolved on :root / [data-theme] / @media
affects:
  - 81-03 (tokens.json hand-sync mirror)
  - Phase 84 (HTML brandbook token consumption)
  - Phase 85 (docs)
tech-stack:
  added: []
  patterns:
    - "--cw-* custom properties published on bare :root (de-scoped from @layer cw.tokens + :where(.chimeway-admin))"
    - "Four theme surfaces (:root light base, [data-theme=light], [data-theme=dark], @media prefers-color-scheme:dark :root) writing one stable token-name set"
    - "Dark values are verbatim hand-authored hex copies — no CSS filter inversion"
key-files:
  created:
    - brandbook/tokens/tokens.css
  modified: []
key-decisions:
  - "[81-01]: tokens.css :root is the cross-phase SSOT; --cw-* names are a locked contract that 81-03 mirrors and Phase 84 consumes"
  - "[81-01]: Generalized the shipped --cw-admin-* alias layer to the 7 D-04 names (--cw-surface-bg/-panel/-fg/-fg-muted/-border/-accent/-focus); --cw-admin-* names never appear in the brandbook"
  - "[81-01]: Net-new --cw-info aliases var(--cw-blue) (D-06/DIV-2 DOCUMENTED); net-new --cw-border-width: 1px (DIV-7 DOCUMENTED); no new hex introduced"
  - "[81-01]: Dark elevation preserved by overriding --cw-shadow-panel to the shipped dark value (formerly reached via --cw-admin-shadow) in both dark blocks"
  - "[81-01]: Sub-primitive divergences deferred verbatim — --cw-radius-sm stays 5px (DIV-1), info triad stays teal-hued #0e5f67 (DIV-3)"
requirements-completed: [TOKEN-01, TOKEN-03, TOKEN-05]
duration: 2 min
completed: 2026-07-10
status: complete
---

# Phase 81 Plan 01: Design Tokens tokens.css SSOT Summary

**Authored `brandbook/tokens/tokens.css` — the canonical `--cw-*` design-token layer published on global `:root`, reconciled verbatim (lowercase) with the shipped `chimeway_admin.css` token layer and de-scoped from `@layer cw.tokens` / `:where(.chimeway-admin)` to bare `:root` + `[data-theme]` + `@media`.**

## Performance

- **Duration:** ~2 min
- **Tasks:** 2
- **Files created:** 1

## Accomplishments

- Created the greenfield `brandbook/tokens/` tree and authored `tokens.css`.
- Published all 15 color primitives byte-equal (lowercase) to shipped `chimeway_admin.css:5-19` on bare `:root` (D-01/D-03/TOKEN-01).
- Emitted all non-color scalars verbatim (spacing, type, radius, shadow, focus-ring/offset, z-index, motion shorthands) plus the net-new `--cw-border-width: 1px` (D-08/DIV-7/TOKEN-03 css side).
- Emitted the five status triads verbatim, the 7 generalized semantic aliases (de-scoping `--cw-admin-*`), the `--cw-info: var(--cw-blue)` alias, and the verbatim control/surface layer (D-04/D-05/D-06).
- Authored the three theme override blocks — `[data-theme="light"]`, `[data-theme="dark"]`, and `@media (prefers-color-scheme: dark) :root` — all writing the same `--cw-*` names; dark values are verbatim hand-authored hex copies with no CSS filter inversion (D-02/TOKEN-05).
- Preserved dark elevation by overriding `--cw-shadow-panel` to the shipped dark value in both dark blocks (previously reached via the dropped `--cw-admin-shadow` alias).

## Task Commits

Each task was committed atomically:

1. **Task 1: Author the base `:root` block** — `f6da724` (feat)
2. **Task 2: Author the three theme override blocks (light / dark / system)** — `e44ea80` (feat)

## Files Created/Modified

- `brandbook/tokens/tokens.css` — the canonical `--cw-*` token SSOT: `:root` light base + `[data-theme="light"]` + `[data-theme="dark"]` + `@media (prefers-color-scheme: dark) :root`.

## Decisions Made

- The `--cw-*` names locked here are a cross-phase contract; renaming any after downstream consumption (81-03 JSON, Phase 84 HTML book) is a break.
- Generalized the shipped `--cw-admin-*` alias layer to exactly the 7 D-04 names; the 5 non-color `--cw-admin-*` pass-throughs (shadow/radius/radius-sm/transition/panel-soft) are reachable under their primitive/scalar names and were NOT re-aliased (RESEARCH Open Q1).
- Deferred sub-primitive divergences verbatim rather than patching: `--cw-radius-sm` stays `5px` (DIV-1 DEFERRED), info triad stays teal-hued `#0e5f67` (DIV-3 DEFERRED).
- Documented net-new tokens as aliases/least-surprise defaults: `--cw-info` = `var(--cw-blue)` (DIV-2), `--cw-border-width: 1px` (DIV-7) — distinct from the D-04 `--cw-border` color alias.

## Verification

- PASS: 15-primitive case-insensitive hex-equality vs shipped `chimeway_admin.css` (no DRIFT lines).
- PASS: `--cw-info: var(--cw-blue)` present with no hex literal on the line.
- PASS: `--cw-border-width: 1px` present; `--cw-radius-sm: 5px` verbatim; `--cw-status-info-text: #0e5f67` teal-hued verbatim.
- PASS: no `--cw-admin-` name leaked into the brandbook.
- PASS: four theme surfaces present (`:root`, `[data-theme="light"]`, `[data-theme="dark"]`, `@media (prefers-color-scheme: dark)`); no `filter: invert()` anywhere.
- PASS: dark generalized values (`--cw-surface-panel: #10232c`, `--cw-fg-muted: #b8c5c9`, `--cw-border: #29414a`, `--cw-accent: var(--cw-mint)`, `--cw-focus: var(--cw-brass)`) and dark status/elevation spot-checks equal to shipped dark block.
- PASS: cross-check script confirms every hex/shorthand value in tokens.css equals its shipped counterpart (generalized names mapped to their `--cw-admin-*` originals).
- PASS (HARD GATE): `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css chimeway_admin/assets/css/chimeway_admin.css` → exit 0 (both shipped admin CSS files unmodified, TOKEN-04 support).

## Deviations from Plan

None — plan executed exactly as written. (One in-progress fix: an explanatory comment initially contained the literal `--cw-admin-` string, which tripped the no-leak acceptance grep; the comment was reworded before the Task 1 commit. No token declaration changed.)

**Total deviations:** 0.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or empty-value content in `tokens.css` — the file is a complete, populated token layer.

## User Setup Required

None — inert static CSS asset, no runtime, no configuration.

## Next Phase Readiness

Ready for 81-02 and 81-03. The `--cw-*` names and values in `tokens.css` are the frozen SSOT that 81-03's `tokens.json` mirrors and Phase 84's HTML brandbook consumes.

## Self-Check: PASSED

- Found created file: `brandbook/tokens/tokens.css`.
- Found task commits: `f6da724`, `e44ea80`.
- Hard gate verified: shipped admin CSS files show zero drift.
- No tracked file deletions introduced by either task commit.

---
*Phase: 81-design-tokens-reconciliation-documentation*
*Completed: 2026-07-10*
