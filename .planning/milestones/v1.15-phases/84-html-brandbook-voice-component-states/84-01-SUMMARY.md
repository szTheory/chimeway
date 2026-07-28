---
phase: 84-html-brandbook-voice-component-states
plan: 01
subsystem: ui
tags: [brandbook, css, guards, scoped-css, static-html, cascade-layers, at-scope, shell]

# Dependency graph
requires:
  - phase: 81-design-tokens
    provides: brandbook/tokens/tokens.css --cw-* SSOT consumed by name
  - phase: 82-logo-exploration-shortlist
    provides: scripts/logo-guards.sh house guard pattern (scaffolding reused)
  - phase: 83-logo-direction-selection
    provides: brandbook/assets/logo/*.svg shipped marks bound by D-05 parity
provides:
  - scripts/brandbook-guards.sh — dependency-free four-family gate + --scope + presence-gates
  - brandbook/brandbook.css — scoped @layer/@scope stylesheet (layout + nine states + skeleton + do/don't)
  - CSS contract for later waves — .cwb-* / .is-* / .cw-brandbook class vocabulary
affects: [84-02, 84-03, 84-04, 85-repo-integration, 86-a11y-audit]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cascade layers (@layer cwb.reset/book/demo) + @scope (.cw-brandbook) for BOOK-02 non-leak"
    - "Static .is-* state-forcing classes duplicating live pseudo-classes (STATE-01)"
    - "Pure-CSS shimmer/pulse behind prefers-reduced-motion guard (Phase-86 a11y)"
    - "CSS-only .cwb-do/.cwb-dont misuse wrappers around correct assets (STATE-02, D-06)"
    - "Guard families: file://-safety negatives, scope-nonleak audit, section-presence positives, D-05 logo parity"

key-files:
  created:
    - scripts/brandbook-guards.sh
    - brandbook/brandbook.css
  modified: []

key-decisions:
  - "[84-01]: D-04 corrected — only TWO currentColor marks (mark-mono, logotype-mono) are inlined/parity-checked; inverse is fixed-color <img>, not inlined"
  - "[84-01]: Presence-gate keeps the guard RED until brandbook/index.html + brandbook.css both exist; family checks still run over whichever file is present"
  - "[84-01]: Skeleton state is realized as .cwb-skeleton (never a literal is-skeleton); guard greps is-skeleton|cwb-skeleton for the skeleton row"
  - "[84-01]: scope-nonleak audit flags any column-0 element/'*' selector opening a block; every rule is nested under @layer/@scope or .cw-brandbook-prefixed"
  - "[84-01]: xmllint over index.html is advisory (HTML5 void elements tolerated) — SKIP, not FAIL, on non-fatal parse notes"

patterns-established:
  - "brandbook-guards.sh is the canonical Phase-84 gate; inline commands never substitute for it"
  - "brandbook.css consumes --cw-* by name only: zero #hex literals, zero token redefinitions"

requirements-completed: [BOOK-01, BOOK-02, STATE-01, STATE-02]

coverage:
  - id: D1
    description: "scripts/brandbook-guards.sh — dependency-free four-family guard + --scope git-boundary mode + presence-gates (BOOK-01 gate wiring)"
    requirement: "BOOK-01"
    verification:
      - kind: automated
        ref: "bash -n scripts/brandbook-guards.sh (syntax clean)"
        status: pass
      - kind: automated
        ref: "bash scripts/brandbook-guards.sh (exits non-zero: presence-gate fires for absent index.html)"
        status: pass
      - kind: automated
        ref: "bash scripts/brandbook-guards.sh --scope (working tree carries only allowed phase paths)"
        status: pass
    human_judgment: false
  - id: D2
    description: "brandbook/brandbook.css — scoped @layer/@scope stylesheet with nine .is-* states + .cwb-skeleton (STATE-01) and CSS-only .cwb-do/.cwb-dont (STATE-02); non-leak scoped (BOOK-02)"
    requirement: "BOOK-02"
    verification:
      - kind: automated
        ref: "grep @layer/@scope/cwb-skeleton/cwb-dont + eight is-* states present, zero six-digit #hex (plan Task 2 verify) => OK"
        status: pass
      - kind: automated
        ref: "bash scripts/brandbook-guards.sh family 2 scope-nonleak audit over brandbook.css => 4 PASS"
        status: pass
    human_judgment: false
  - id: D3
    description: "All nine component states expressible as static forcing classes plus .cwb-skeleton shimmer (STATE-01)"
    requirement: "STATE-01"
    verification:
      - kind: automated
        ref: "for s in hover active focus disabled loading error empty selected; do grep is-$s brandbook.css; done + grep cwb-skeleton => OK"
        status: pass
      - kind: automated
        ref: "grep prefers-reduced-motion brandbook.css (skeleton/loading animation disabled) => present"
        status: pass
    human_judgment: false
  - id: D4
    description: "CSS-only .cwb-dont misuse wrapper so do/don't pairs need no broken SVG (STATE-02, D-06)"
    requirement: "STATE-02"
    verification:
      - kind: automated
        ref: "grep cwb-do / cwb-dont in brandbook.css (cage/cramped/brass-body variants) => present"
        status: pass
    human_judgment: false

# Metrics
duration: 12min
completed: 2026-07-18
status: complete
---

# Phase 84 Plan 01: Guard + Scoped Stylesheet Foundation Summary

**Dependency-free four-family brandbook-guards.sh (file://-safety negatives, scope-nonleak audit, section-presence positives, D-05 logo parity) plus a scoped @layer/@scope brandbook.css carrying all layout, nine static .is-* states, a reduced-motion-safe skeleton shimmer, and CSS-only do/don't wrappers.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-18
- **Completed:** 2026-07-18
- **Tasks:** 2
- **Files modified:** 2 (created)

## Accomplishments

- Authored `scripts/brandbook-guards.sh` modeled on `scripts/logo-guards.sh`: strict-mode header, pass/fail/skip helpers, FAILED accumulator, verbatim `--scope` git-porcelain walk (allow-list narrowed to `brandbook/*` + the guard + `.planning/*`), and presence-gates that keep the gate RED until the book files exist.
- Implemented all four check families: (1) file://-safety negatives over index.html — bans fetch/XHR/`type="module"`/cross-file `<use href>`/remote/root-absolute refs; (2) scope-nonleak audit over brandbook.css — asserts `@layer`+`@scope`, flags bare column-0 selectors, bans non-token `#hex`; (3) section-presence positives — eight `.is-*` states + `.cwb-skeleton`, `data-cwb-theme`, `luminance`, voice anchors, error phrase, brand casing; (4) D-05 parity binding the two inlined marks' `d=` paths to the SSOT assets.
- Recorded the D-04 factual correction in the guard header: only two `currentColor` marks are inlined/parity-checked (inverse is a fixed-color `<img>`).
- Authored `brandbook/brandbook.css` with layer order `cwb.reset, cwb.book, cwb.demo`, `@scope (.cw-brandbook)` blocks, plain-descendant fallback, all layout classes, the nine static states, `.cwb-skeleton`/`cwb-pulse` shimmer under a `prefers-reduced-motion: reduce` guard, and the D-06 `.cwb-do`/`.cwb-dont` (cage/cramped/brass-body) wrappers — consuming `--cw-*` by name only with zero hex literals and zero redefinitions.

## Task Commits

Each task was committed atomically:

1. **Task 1: Author scripts/brandbook-guards.sh (D-07 four-family guard + D-05 parity)** - `525cabc` (feat)
2. **Task 2: Author brandbook/brandbook.css (scoped layers + nine states + skeleton + .cwb-dont)** - `b70df5a` (feat)

**Plan metadata:** committed separately (docs: complete plan)

## Files Created/Modified

- `scripts/brandbook-guards.sh` - Dependency-free Phase-84 acceptance gate: four check families, `--scope` git-boundary mode, presence-gates (RED until book files authored).
- `brandbook/brandbook.css` - Scoped `@layer`/`@scope` book stylesheet: layout primitives, nine static `.is-*` states + `.cwb-skeleton` shimmer (reduced-motion safe), CSS-only `.cwb-do`/`.cwb-dont` misuse wrappers, all consuming the `--cw-*` SSOT by name.

## Decisions Made

- Corrected CONTEXT D-04's three-mark inline set to two: only `chimeway-mark-mono.svg` and `chimeway-logotype-mono.svg` carry `fill="currentColor"` and recolor with the theme, so only those two are inlined and D-05-parity-checked (per the PATTERNS CRITICAL FINDING; confirmed by direct asset inspection).
- Presence-gate accumulates a FAIL for each missing book file but still runs the families over whichever file is present, so `brandbook.css` (authored this plan) is validated now while the overall guard stays RED on the absent `index.html`.
- Treated `xmllint` over `index.html` as advisory (HTML5 void elements are not XML-well-formed): parse notes SKIP rather than FAIL, matching the optional-tool posture of the house pattern.

## Deviations from Plan

None - plan executed exactly as written. The RED overall guard result is the intended presence-gate behavior (index.html is authored in a later wave), not a defect.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

None.

## Known Stubs

None. No placeholder/TODO/FIXME or empty-data stub patterns in the two authored files. The guard's RED-by-presence state is intentional wiring, not a stub.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The `.cwb-*` / `.is-*` / `.cw-brandbook` class vocabulary and the four guard families are ready for Wave 2/3, which author `brandbook/index.html`. Once that file exists, families 1/3/4 and the xmllint check activate and the presence-gate clears to GREEN.
- No blockers.

## Self-Check: PASSED

- FOUND: scripts/brandbook-guards.sh
- FOUND: brandbook/brandbook.css
- FOUND commit: 525cabc (Task 1)
- FOUND commit: b70df5a (Task 2)
- No tracked file deletions introduced by either task commit.

---
*Phase: 84-html-brandbook-voice-component-states*
*Completed: 2026-07-18*
