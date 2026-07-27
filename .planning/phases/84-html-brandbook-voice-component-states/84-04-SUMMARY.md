---
phase: 84-html-brandbook-voice-component-states
plan: 04
subsystem: ui
tags: [brandbook, html, voice, microcopy, naming, checkpoint, theme-resolution, adaptive-logo, file-safe]

# Dependency graph
requires:
  - phase: 81-design-tokens
    provides: brandbook/tokens/tokens.css --cw-* SSOT + light/dark/system theming
  - plan: 84-01
    provides: brandbook/brandbook.css .cwb-* vocabulary + scripts/brandbook-guards.sh gate
  - plan: 84-02
    provides: brandbook/index.html shell, theme toggle, logo family, token/type/spacing sections
  - plan: 84-03
    provides: brandbook/index.html #states / #dodont / #contrast + the single inline script
provides:
  - "brandbook/index.html #voice — voice/tone by context (docs/errors/marketing/cli) with verbatim good/bad pairs + banned/preferred vocabulary (VOICE-01)"
  - "brandbook/index.html #errors — named 'what happened → why it matters → how to fix' error-message template with canonical worked example (VOICE-02)"
  - "brandbook/index.html #naming — CTA + naming rules: lowercase chimeway graphic vs title-case Chimeway prose, 'install chimeway' CTA (VOICE-03)"
  - "Phase-complete, guard-green (7 families), file://-safe brand book — human-verified on light + dark"
affects: [85-repo-integration, 86-a11y-audit]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "VOICE copy lifted VERBATIM from prompts/chimeway-brand-book.md (no invented examples); the 'install chimeway' CTA sourced from the binding UI-SPEC line 106 + CONTEXT, not the prompt file"
    - "D-11 inverse treatment: inverse SVG assets derived by ink #102027 → paper #fffdf8 (teal kept), not filter:invert()"
    - "Theme-adaptive fixed-color lockups: light/inverse <img> swap via .cwb-logo--light/.cwb-logo--dark gated on explicit data-theme AND system prefers-color-scheme — no pinned color tiles"
    - "Theme resolution: explicit data-theme selectors outrank prefers-color-scheme (dark @media gated on :root:not([data-theme]))"

key-files:
  created:
    - brandbook/assets/logo/chimeway-logotype-stacked-inverse.svg
    - brandbook/assets/logo/chimeway-mark-inverse.svg
  modified:
    - brandbook/index.html
    - brandbook/brandbook.css
    - brandbook/tokens/tokens.css
    - scripts/brandbook-guards.sh

key-decisions:
  - "[84-04]: Voice/error/naming copy is lifted verbatim from prompts/chimeway-brand-book.md; the primary CTA label 'install chimeway' is the one exception — it is authoritative in UI-SPEC line 106 + 84-CONTEXT, not in the prompt file, so no grep hit there is expected (per plan Task 2)."
  - "[84-04]: Checkpoint gap-closure fixed theme resolution in tokens.css so an explicit data-theme now outranks the OS prefers-color-scheme (the 'light does nothing under a dark OS' bug), rather than reworking the toggle script."
  - "[84-04]: Fixed-color lockups render theme-adaptively via a light/inverse <img> swap (.cwb-logo--light/.cwb-logo--dark) instead of pinned color tiles; the redundant standalone inverse card was dropped and the OG social preview was framed as its own bordered .cwb-preview thumbnail (light-only by design, ships a baked light bg)."
  - "[84-04]: Two inverse lockup assets (chimeway-logotype-stacked-inverse.svg, chimeway-mark-inverse.svg) were derived via the D-11 inverse treatment to complete the theme-swap set."
  - "[84-04]: brandbook-guards.sh gained family 5 (selector-coverage), family 6 (theme-resolution), and family 7 (adaptive-logo coverage) to lock the gap-closure fixes against regression."

requirements-completed: [VOICE-01, VOICE-02, VOICE-03]

coverage:
  - id: T1
    description: "Voice-by-context section (#voice): docs/errors/marketing/cli each with a verbatim good/bad pair; banned + preferred vocabulary lists (VOICE-01)"
    requirement: "VOICE-01"
    verification:
      - kind: automated
        ref: "grep id=voice + docs/errors/marketing/cli anchors + 'idempotency key' + 'omnichannel' => TASK1 OK"
        status: pass
      - kind: automated
        ref: "scripts/brandbook-guards.sh family 3 — voice-context anchors docs/errors/marketing/cli PASS"
        status: pass
    human_judgment: false
  - id: T2
    description: "Named error template (#errors, 'what happened → why it matters → how to fix' with canonical example) + naming/CTA rules (#naming, lowercase chimeway vs title-case Chimeway, 'install chimeway' CTA) (VOICE-02, VOICE-03)"
    requirement: "VOICE-02, VOICE-03"
    verification:
      - kind: automated
        ref: "grep id=errors + id=naming + 'what happened' + 'install chimeway' + chimeway + Chimeway => TASK2 OK"
        status: pass
      - kind: automated
        ref: "scripts/brandbook-guards.sh family 3 — 'what happened', lowercase 'chimeway', title-case 'Chimeway' PASS"
        status: pass
    human_judgment: false
  - id: T3
    description: "Human-verify: full guard suite green + file:// render in Chromium (logos, states, do/don't, theme toggle, contrast matrix, voice sections), no console errors, responsive"
    requirement: "BOOK-01/02/03, VOICE-01/02/03"
    verification:
      - kind: automated
        ref: "bash scripts/brandbook-guards.sh — all 7 families PASS (exit 0); --scope clean"
        status: pass
      - kind: manual
        ref: "Headless-Chrome Playwright probe — logo-swap + theme assertions pass under light AND dark OS; user visual sign-off on light + dark"
        status: pass
    human_judgment: true

# Metrics
duration: 53min
completed: 2026-07-18
status: complete
---

# Phase 84 Plan 04: Brand Voice, Error Template, Naming/CTA & Final Verification Summary

**Completes `brandbook/index.html` with the brand-voice content — voice/tone by context (docs/errors/marketing/CLI) with verbatim good/bad pairs, the named "what happened → why it matters → how to fix" error-message template, and the lowercase-`chimeway`-graphic vs title-case-`Chimeway`-prose naming/CTA rules — then closes the phase: the full seven-family guard suite is green, the book is `file://`-safe, and the render is human-verified on both light and dark after a checkpoint gap-closure that fixed theme resolution, nav/visual polish, and theme-adaptive logo rendering.**

## Performance

- **Duration:** ~53 min (includes the checkpoint gap-closure)
- **Started:** 2026-07-18
- **Completed:** 2026-07-18
- **Tasks:** 3 (2 authoring + 1 human-verify checkpoint)
- **Files modified:** 4 + 2 new assets (`brandbook/index.html`, `brandbook/brandbook.css`, `brandbook/tokens/tokens.css`, `scripts/brandbook-guards.sh`; new `chimeway-logotype-stacked-inverse.svg`, `chimeway-mark-inverse.svg`)

## Accomplishments

- **`#voice` (VOICE-01):** Authored the voice-by-context section documenting tone across four contexts — `docs`, `errors`, `marketing`, `cli` — each with a good/bad pair lifted VERBATIM from `prompts/chimeway-brand-book.md` (no invented copy): the idempotency-key docs line vs. the "magically knows" anti-example; the `invoice.paid` delivery-suppressed error vs. "This chime did not ring."; the app-owned-database marketing line vs. the "Supercharge… omnichannel journeys" anti-example; the provider-accepted CLI line vs. "Push delivered." Bad examples are marked as don'ts. The banned-vocabulary list (blast/campaign/journey/omnichannel/AI-powered/magical/zero-config/…) and preferred-vocabulary list (notification/event/recipient/delivery/attempt/trace/policy/…) are both present.
- **`#errors` (VOICE-02):** Authored the named reusable error-message template — "Chimeway error message pattern: what happened → why it matters → how to fix" — with the literal `what happened` phrase the guard requires, the canonical worked example `Delivery suppressed: recipient disabled email for `invoice.paid`.` broken into its three template slots, and the "This chime did not ring." anti-example.
- **`#naming` (VOICE-03):** Authored the CTA + naming rules — lowercase `chimeway` graphic wordmark vs. title-case `Chimeway` prose (both literals present), lowercase package names (`chimeway`, `chimeway_ecto`) and `Chimeway.*` modules, and the developer-to-developer primary CTA label `install chimeway` (never a sales CTA), sourced from the binding UI-SPEC line 106 + 84-CONTEXT rather than the prompt file.
- **Phase close (Task 3 checkpoint):** The full seven-family guard suite passes (`bash scripts/brandbook-guards.sh` exit 0), `--scope` is clean, a headless-Chrome Playwright probe passes all logo-swap + theme assertions under both light and dark OS, and the user gave visual sign-off on light + dark. All eight Phase-84 requirements (BOOK-01/02/03, STATE-01/02, VOICE-01/02/03) are now satisfied across the four plans.

## Task Commits

Each authoring task was committed atomically:

1. **Task 1: Voice-by-context section with verbatim good/bad + vocabulary lists (VOICE-01)** — `b45a320` (feat)
2. **Task 2: Named error template (VOICE-02) + naming/CTA rules (VOICE-03)** — `d608411` (feat)
3. **Task 3: Human-verify checkpoint** — no code of its own; drove the gap-closure commits below.

**Checkpoint gap-closure commits** (see Deviations):

- `20020d6` (fix) — resolve theme toggle so explicit light/dark outranks OS preference (tokens.css)
- `40ee112` (fix) — style nav, links, headings and panel rhythm (brandbook.css)
- `89e9c57` (test) — harden brandbook-guards with selector-coverage (family 5) + theme-resolution (family 6)
- `9bbdcb5` (fix) + `e6c336e` (test) — interim: pin fixed-color lockups + add logo-field-coverage guard (family 7)
- `ff338a4` (feat) — derive inverse stacked + mark lockup assets (D-11 inverse treatment)
- `740a88f` (fix) — render fixed-color lockups theme-adaptively (light/inverse `<img>` swap), not on tiles
- `d79b5f1` (test) — rework guard family 7 → adaptive-logo coverage
- `24ec9c3` (fix) — frame the OG social preview as a bordered `.cwb-preview` thumbnail

**Plan metadata:** committed separately (docs: complete plan).

## Files Created/Modified

- `brandbook/index.html` — added the `#voice`, `#errors`, and `#naming` sections; during gap-closure, reworked fixed-color lockup rendering to a theme-adaptive `<img>` swap and framed the OG preview as a bordered thumbnail. This completes the book (all planned sections now present).
- `brandbook/brandbook.css` — gap-closure: styled nav, links, headings, panel rhythm, and the adaptive-logo/preview treatments. *(Beyond the plan's declared `files_modified` — see Deviations.)*
- `brandbook/tokens/tokens.css` — gap-closure: dark `@media` gated on `:root:not([data-theme])` so an explicit `data-theme` outranks OS `prefers-color-scheme`. *(Beyond declared scope — see Deviations.)*
- `scripts/brandbook-guards.sh` — gap-closure: added family 5 (selector-coverage), family 6 (theme-resolution), family 7 (adaptive-logo coverage). *(Beyond declared scope — see Deviations.)*
- `brandbook/assets/logo/chimeway-logotype-stacked-inverse.svg`, `brandbook/assets/logo/chimeway-mark-inverse.svg` — new inverse assets derived via the D-11 inverse treatment to complete the theme-swap set. *(Beyond declared scope — see Deviations.)*

## Decisions Made

- All voice/error/naming copy is verbatim from `prompts/chimeway-brand-book.md`; the sole exception is the `install chimeway` CTA label, which is authoritative in UI-SPEC line 106 + 84-CONTEXT (not the prompt file), so no grep hit there is expected.
- The theme-resolution bug ("light does nothing under a dark OS") was fixed at the token layer (gating the dark `@media` on `:root:not([data-theme])`) rather than in the toggle script, keeping the single inline script untouched.
- Fixed-color lockups now swap light/inverse `<img>` by theme (`.cwb-logo--light`/`.cwb-logo--dark`) instead of sitting on pinned color tiles; the redundant standalone inverse card was dropped and the OG social preview was reframed as a self-contained bordered `.cwb-preview` thumbnail (light-only by design — it ships its own baked light background).
- Guard families 5/6/7 were added so the gap-closure fixes (selector coverage, theme resolution, adaptive-logo swap) are locked against regression.

## Deviations from Plan

**1. [Rule 1 - Bug / Rule 2 - Missing critical functionality] Checkpoint gap-closure touched files beyond the plan's declared `files_modified: [brandbook/index.html]`**

- **Found during:** Task 3 (human-verify checkpoint) — the live `file://` render in Chromium exhibited visual defects the human caught: an explicit light theme did nothing under a dark OS (theme-resolution bug), nav/links/headings/panel rhythm were unstyled, and fixed-color logo lockups did not adapt to theme.
- **Issue:** Closing these defects required edits outside `brandbook/index.html` — the theme-resolution fix belongs in `brandbook/tokens/tokens.css`; the nav/visual polish and adaptive-logo/preview treatments belong in `brandbook/brandbook.css`; two inverse lockup SVGs had to be derived to complete the theme-swap set; and `scripts/brandbook-guards.sh` needed three new families (5/6/7) to lock the fixes against regression.
- **Fix:** Gap-closed with the user in the loop across commits `20020d6`, `40ee112`, `89e9c57`, `9bbdcb5`, `e6c336e`, `ff338a4`, `740a88f`, `d79b5f1`, `24ec9c3` (all on `main`). No runtime code, no CI changes, `chimeway_admin` untouched — all edits stayed inside the `brandbook/` + guard-script scope the milestone allows (`--scope` confirms).
- **Files modified beyond declared scope:** `brandbook/brandbook.css`, `brandbook/tokens/tokens.css`, `scripts/brandbook-guards.sh`, plus new `brandbook/assets/logo/chimeway-logotype-stacked-inverse.svg` and `chimeway-mark-inverse.svg`.
- **Commits:** as listed above.

**Total deviations:** 1 (in-scope checkpoint gap-closure). **Impact on plan:** No milestone-scope change — every edit stayed within the `brandbook/`-only + guard-script boundary and the phase gate is green. The plan's declared `files_modified` under-scoped the checkpoint fixes; recorded honestly here.

## Issues Encountered

None blocking. The checkpoint visual defects were expected surface for a first live `file://` render and were resolved in-loop. `scripts/brandbook-guards.sh` is GREEN for all seven families (exit 0) and `--scope` is clean.

## Known Stubs

None. No placeholder/TODO/FIXME or empty-data stub patterns in the authored voice/error/naming content or the gap-closure edits.

## User Setup Required

None — open `file://…/brandbook/index.html` directly in a browser; no server, build, or dependency.

## Verification Evidence

- **Automated (per-task greps):** TASK1/TASK2 acceptance greps `OK`.
- **Canonical gate:** `bash scripts/brandbook-guards.sh` — all seven families PASS (exit 0), including family 3 voice anchors (`docs`/`errors`/`marketing`/`cli`), `what happened`, lowercase `chimeway`, title-case `Chimeway`; family 6 theme-resolution; family 7 adaptive-logo coverage.
- **Scope:** `bash scripts/brandbook-guards.sh --scope` — working tree carries only allowed phase paths.
- **Live render:** headless-Chrome Playwright probe passes all logo-swap + theme assertions under light AND dark OS; user gave visual sign-off on light + dark.

## Next Phase Readiness

- Phase 84 is complete (4/4 plans). All eight phase requirements (BOOK-01/02/03, STATE-01/02, VOICE-01/02/03) satisfied.
- Phase 85 (Repo Integration) can proceed against the finalized asset filenames, including the two new inverse lockups.
- No blockers.

## Self-Check: PASSED

- FOUND: brandbook/index.html (contains id="voice", id="errors", id="naming", 'what happened', 'install chimeway')
- FOUND: brandbook/assets/logo/chimeway-logotype-stacked-inverse.svg
- FOUND: brandbook/assets/logo/chimeway-mark-inverse.svg
- FOUND commit: b45a320 (Task 1)
- FOUND commit: d608411 (Task 2)
- FOUND commits: 20020d6, 40ee112, 89e9c57, ff338a4, 740a88f, d79b5f1, 24ec9c3 (checkpoint gap-closure)
- Guard suite green (7 families, exit 0); --scope clean.
- No unexpected tracked file deletions introduced by any task commit.

---
*Phase: 84-html-brandbook-voice-component-states*
*Completed: 2026-07-18*
