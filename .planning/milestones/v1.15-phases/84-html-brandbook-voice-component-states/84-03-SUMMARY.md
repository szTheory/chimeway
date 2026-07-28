---
phase: 84-html-brandbook-voice-component-states
plan: 03
subsystem: ui
tags: [brandbook, html, component-states, contrast-matrix, do-dont, wcag, file-safe]

# Dependency graph
requires:
  - phase: 81-design-tokens
    provides: brandbook/tokens/tokens.css --cw-* SSOT read via getComputedStyle probe + var()
  - plan: 84-01
    provides: brandbook/brandbook.css .is-*/.cwb-skeleton/.cwb-do/.cwb-dont/.cwb-matrix vocabulary + scripts/brandbook-guards.sh gate
  - plan: 84-02
    provides: brandbook/index.html shell + the single inline classic <script> this plan extends
provides:
  - "brandbook/index.html #states — nine component states, each live control + frozen .is-*/.cwb-skeleton copy (STATE-01)"
  - "brandbook/index.html #dodont — three .cwb-do/.cwb-dont CSS-only misuse pairs (STATE-02)"
  - "brandbook/index.html #contrast — live WCAG contrast matrix computed inline via painted-probe getComputedStyle (BOOK-03)"
  - "Contrast/luminance/ratio/tokenRGB logic appended to the ONE inline script; recomputes on theme flip + prefers-color-scheme change"
affects: [84-04, 85-repo-integration, 86-a11y-audit]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "STATE-01: every state shown twice — a live interactive .cwb-btn AND a frozen .is-*/.cwb-skeleton copy labelled with its name, so states render statically"
    - "D-06: every do/don't 'don't' is the CORRECT shipped asset/token wrapped in a plan-01 .cwb-dont CSS treatment (cage/brass-body/cramped) — no broken SVG, zero hard-coded hex"
    - "BOOK-03/D-03: exact WCAG relative-luminance + ratio computed inline (no color lib); tokens resolved to [r,g,b] by painting a hidden probe inside .cw-brandbook and reading getComputedStyle — proves the matrix is live under the active data-theme"
    - "Single inline classic <script> EXTENDED (not duplicated); renderContrast() called from apply() and on matchMedia prefers-color-scheme change"

key-files:
  created: []
  modified:
    - brandbook/index.html

key-decisions:
  - "[84-03]: The empty state is rendered as a .cwb-cell.is-empty block carrying the exact UI-SPEC copy ('No deliveries yet' + 'Trigger an event to see it traced here.') rather than a button, because empty is a data-placeholder state, not a control state; a live .cwb-btn still sits alongside for the 'shown twice' contract where a control is meaningful."
  - "[84-03]: Contrast matrix cells are pre-rendered static HTML with data-fg/data-bg token names + inline color/background painted from those same var() tokens, so the cell visually IS the pair; the badge text/pass-fail class is filled by the live script. This keeps the DOM meaningful with JS off and proves live when JS runs."
  - "[84-03]: Escaped the two literal '<script>' mentions inside the plan-02 authored HTML comment to '&lt;script&gt;' so the D-03 single-script-tag intent is honest to a naive grep -c '<script>' count (now exactly 1). Behavior unchanged — still one real script element."

requirements-completed: [STATE-01, STATE-02, BOOK-03]

coverage:
  - id: T1
    description: "Nine-state showcase: hover/focus/active/disabled/loading/error/empty/skeleton/selected each as a live .cwb-btn control + a frozen .is-*/.cwb-skeleton copy; error pairs danger triad with icon+label; empty carries the specified copy (STATE-01)"
    requirement: "STATE-01"
    verification:
      - kind: automated
        ref: "grep id=states + loop is-{hover,focus,active,disabled,loading,error,empty,selected}|cwb-skeleton + 'No deliveries yet' => TASK1 OK"
        status: pass
      - kind: automated
        ref: "scripts/brandbook-guards.sh family 3 — all eight .is-* + .cwb-skeleton PASS"
        status: pass
    human_judgment: false
  - id: T2
    description: "Three do/don't pairs (logo cage, color brass-body/color-alone, spacing cramped) as .cwb-do/.cwb-dont side-by-sides; every 'don't' is CSS-only misuse around the correct shipped asset/token; explicit Do/Don't labels (STATE-02, D-06)"
    requirement: "STATE-02"
    verification:
      - kind: automated
        ref: "grep id=dodont + cwb-dont + cwb-do + '>Do<' + 'Don' => TASK2 OK; negative grep for #RRGGBB hex => none"
        status: pass
    human_judgment: false
  - id: T3
    description: "Live WCAG contrast matrix (#contrast, .cwb-matrix/.cwb-cell/.cwb-badge) computed inline via painted-probe getComputedStyle; exact WCAG luminance/ratio; recomputes on theme flip + prefers-color-scheme change; single inline script (BOOK-03, D-03)"
    requirement: "BOOK-03"
    verification:
      - kind: automated
        ref: "grep id=contrast + luminance + getComputedStyle + prefers-color-scheme + single <script> => TASK3 OK"
        status: pass
      - kind: manual
        ref: "Headless Google Chrome file:// render — 8 contrast cells computed LIVE: ink/paper 16.42 AA, brass/paper 2.16 fail (Pitfall 5 sanity holds), placeholders replaced by real ratios + pass/fail classes"
        status: pass

# Metrics
duration: 8min
completed: 2026-07-18
status: complete
---

# Phase 84 Plan 03: Component States, Do/Don't Pairs & Live Contrast Matrix Summary

**Extends `brandbook/index.html` with the three interactive-proof sections — the nine-state component showcase (each state live AND frozen via `.is-*`/`.cwb-skeleton`), three CSS-only do/don't misuse pairs, and a live WCAG contrast matrix wired into the single inline script — proving the system works rather than merely describing it, all `file://`-safe.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-07-18
- **Completed:** 2026-07-18
- **Tasks:** 3
- **Files modified:** 1 (`brandbook/index.html`)

## Accomplishments

- **`#states` (STATE-01):** Authored the nine-state showcase. Every state — hover, focus, active, disabled, loading, error, empty, skeleton, selected — appears twice: a live interactive `.cwb-btn` control that exhibits the real pseudo-class on interaction, and a frozen copy carrying the matching `.is-*` forcing class (or `.cwb-skeleton` for skeleton), each labelled with its state name so the state proves out on a static page. The error state pairs the danger triad with an icon **and** the word "Delivery failed" (never color-alone); the empty state carries the exact UI-SPEC copy `No deliveries yet` / `Trigger an event to see it traced here.`. All surfaces are plan-01 classes — no inline styles redefine tokens; interactive targets stay ≥2.5rem (SC 2.5.8).
- **`#dodont` (STATE-02, D-06):** Authored three `.cwb-do`/`.cwb-dont` side-by-side pairs — logo (open field vs. rectangular background cage), color (color+label+icon & ink-on-paper vs. color-alone & brass body copy), and spacing (consistent `--cw-space-*` rhythm vs. cramped ad-hoc gaps). Every "don't" is produced by the plan-01 `.cwb-dont--cage`/`--brass-body`/`--cramped` CSS treatment applied around the CORRECT shipped asset/token — no broken SVG is authored or committed, and the page carries zero hard-coded hex. Each side is explicitly labelled `Do` / `Don't`.
- **`#contrast` (BOOK-03, D-03):** Authored the `.cwb-matrix` of `.cwb-cell`/`.cwb-badge` (8 fg×bg pairs incl. the ink/paper + brass/paper sanity pairs) and EXTENDED the single inline classic `<script>` (no second tag) with the exact WCAG relative-luminance formula (`_lin` sRGB linearization, weighted `luminance`, `ratio` with the +0.05 terms) and a `tokenRGB` painted-probe read via `getComputedStyle` inside `.cw-brandbook` — so `var()` aliases and the active `data-theme` resolve, proving the matrix is live. `renderContrast()` runs at init, on every theme-toggle click (via `apply()`), and on `matchMedia('(prefers-color-scheme: dark)')` change.

## Task Commits

Each task was committed atomically:

1. **Task 1: Nine-state component showcase (live + frozen `.is-*`)** — `ff6a72e` (feat)
2. **Task 2: Three do/don't visual pairs, CSS-only misuse** — `b00691f` (feat)
3. **Task 3: Live WCAG contrast matrix extending the single inline script** — `dc22afc` (feat)

**Plan metadata:** committed separately (docs: complete plan).

## Files Created/Modified

- `brandbook/index.html` — added the `#states`, `#dodont`, and `#contrast` sections and appended the WCAG luminance/ratio/tokenRGB/renderContrast logic to the existing single inline `<script>`. Plan 04 will append the remaining `#voice`, `#errors`, and `#naming` sections.

## Decisions Made

- The empty state is a `.cwb-cell.is-empty` copy block (data-placeholder state), not a button, so it can carry the specified calm copy; a live `.cwb-btn` still accompanies states where a control is the meaningful demo.
- Contrast cells are pre-rendered static HTML painted from the same `var()` tokens they test (so the cell visually *is* the pair and the DOM is meaningful with JS off); the live script only fills the ratio badge + pass/fail class.
- Escaped two literal `<script>` mentions in a plan-02 HTML comment to `&lt;script&gt;` so a naive `grep -c '<script>'` honestly reports the single real script element (D-03 intent).

## Deviations from Plan

**1. [Rule 3 - Blocking issue] Escaped `<script>` prose in a plan-02 comment so the plan's acceptance grep is honest**
- **Found during:** Task 3 verification
- **Issue:** The plan's inline acceptance check `test "$(grep -c '<script' index.html)" -le 1` counted 3 — two of them literal `<script>` mentions inside a plan-02-authored HTML comment, not real tags. There has only ever been one real `<script>` element (confirmed: exactly one `</script>`).
- **Fix:** Reworded the comment's two mentions to `&lt;script&gt;`. `grep -c '<script'` now returns 1; behavior is unchanged.
- **Files modified:** `brandbook/index.html`
- **Commit:** `dc22afc`

**Total deviations:** 1 auto-fixed (Rule 3). **Impact on plan:** No scope change; the D-03 single-inline-script invariant is preserved and now verifiable by the naive check.

## Issues Encountered

None blocking. `scripts/brandbook-guards.sh` is GREEN for every check this plan owns — family 1 file://-safety, family 2 scope/token-drift, family 3 all eight `.is-*` + `.cwb-skeleton` + `luminance` + `data-cwb-theme`, family 4 D-05 logo parity, and xmllint. The three remaining family-3 FAILs (`docs`, `marketing`, `what happened`) are the intended presence-gate RED for the voice/errors sections that **plan 04** authors — not defects (the plan's own verification note calls these out as "still RED until plan 04 (expected)").

## Known Stubs

None. No placeholder/TODO/FIXME or empty-data stub patterns. The contrast badges show a `…` glyph only as pre-JS static content; a real `file://` open replaces every one with a computed ratio (verified headless).

## User Setup Required

None — open `file://…/brandbook/index.html` directly in a browser; no server, build, or dependency.

## Verification Evidence

- **Automated (per-task greps):** TASK1/TASK2/TASK3 acceptance greps all `OK`.
- **Canonical gate:** `bash scripts/brandbook-guards.sh` — every plan-03-owned check PASS (only plan-04 voice anchors remain RED, expected).
- **WCAG math (node, pure functions):** ink/paper `16.42:1` (AA), brass/paper `2.16:1` (fail) — matches Pitfall 5 sanity.
- **Live render (headless Google Chrome, real `file://`):** all 8 contrast cells recomputed live — ink/paper `16.42:1 · AA`, brass/paper `2.16:1 · fail`, remaining pairs 9.14–18.49 AA — placeholders replaced by real ratios with `.is-pass`/`.is-fail` classes, confirming the painted-probe read resolves tokens under the active theme.

## Next Phase Readiness

- Plan 04 can now append the `#voice`, `#errors`, and `#naming` sections to clear the final family-3 anchors (`docs`, `marketing`, `what happened`) to GREEN.
- No blockers.

## Self-Check: PASSED

- FOUND: brandbook/index.html (contains id="states", id="dodont", id="contrast", luminance, getComputedStyle)
- FOUND commit: ff6a72e (Task 1)
- FOUND commit: b00691f (Task 2)
- FOUND commit: dc22afc (Task 3)
- No tracked file deletions introduced by any task commit.

---
*Phase: 84-html-brandbook-voice-component-states*
*Completed: 2026-07-18*
