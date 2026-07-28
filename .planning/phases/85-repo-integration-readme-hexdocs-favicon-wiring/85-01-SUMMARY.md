---
phase: 85-repo-integration-readme-hexdocs-favicon-wiring
plan: 01
subsystem: docs
tags: [readme, exdoc, hexdocs, branding, svg, favicon, picture-element]

# Dependency graph
requires:
  - phase: 83-brand-assets
    provides: shipped SVG brand assets (chimeway-logotype.svg, chimeway-logotype-inverse.svg, chimeway-mark.svg, favicon.svg)
  - phase: 84-html-brandbook-voice-component-states
    provides: finalized brand-asset filenames consumed here
provides:
  - README header renders the primary brand lockup via a GitHub-native theme-swapping <picture> element (relative brandbook/assets paths)
  - mix.exs docs() wires :logo (square mark) and :favicon so HexDocs renders the brand mark in sidebar + browser tab
  - v1.14 doc-contract narrative-order gate evolved to reflect the lockup replacing the plain # Chimeway H1
affects: [86-red-team-scope-audit, hexdocs-publish, brand-book-milestone]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GitHub-native theme swap: <picture> with a dark-scheme <source srcset> + default <img> for light mode, relative in-repo asset paths (no remote URLs)"
    - "ExDoc :logo/:favicon copy referenced SVGs into doc/assets/ (renamed to logo.svg/favicon.svg) with no :assets map"

key-files:
  created: []
  modified:
    - "README.md — header region: plain # Chimeway H1 replaced with <a><picture> brand lockup"
    - "mix.exs — docs() gains logo: and favicon: keyword entries"
    - "test/chimeway/doc_contract_test.exs — @readme_section_order narrative-order gate no longer anchors on # Chimeway"

key-decisions:
  - "Evolved the v1.14 doc-contract narrative-order gate (removed the # Chimeway H1 anchor) rather than retaining a redundant visible heading — authorized contract evolution, since the lockup IS the intended replacement for the title (INTEG-01)"
  - "Used the square chimeway-mark.svg for ExDoc :logo (not the wide logotype, not the mono variant) per D-02"
  - "No :assets map and no ex_doc version bump — ExDoc 0.40.1 copies :logo/:favicon itself (D-03)"

patterns-established:
  - "Brand lockup in README via <picture> theme-swap using relative brandbook/assets paths"

requirements-completed: [INTEG-01, INTEG-02, INTEG-04]

coverage:
  - id: D1
    description: "README header renders the primary lockup via a GitHub-native theme-swapping <picture> (dark <source srcset=logotype-inverse.svg> + default <img src=logotype.svg alt=Chimeway>), replacing the plain # Chimeway H1; relative paths only"
    requirement: "INTEG-01"
    verification:
      - kind: automated_ui
        ref: "grep gate: prefers-color-scheme + logotype-inverse.svg + logotype.svg + alt=Chimeway present, no https?:// in src/srcset (README.md)"
        status: pass
    human_judgment: false
  - id: D2
    description: "mix.exs docs() wires logo: brandbook/assets/logo/chimeway-mark.svg and favicon: brandbook/assets/favicon/favicon.svg; package() files unchanged; no :assets map; ex_doc ~> 0.31 unchanged"
    requirement: "INTEG-02"
    verification:
      - kind: integration
        ref: "grep gate on mix.exs docs()/package() + mix compile exit 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "All three v1.14 contract tests (doc_contract, release_gate_contract, readme_snippet) stay green; edits stay in scope (README header + docs() + narrative-order gate anchor)"
    requirement: "INTEG-04"
    verification:
      - kind: integration
        ref: "mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs test/chimeway/integration/readme_snippet_test.exs — 530 tests, 0 failures, exit 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "mix docs builds cleanly and copies the mark + favicon into doc/assets/ so the mark renders in the ExDoc sidebar and the favicon in the browser tab"
    requirement: "INTEG-02"
    verification:
      - kind: integration
        ref: "mix docs exit 0; cmp doc/assets/logo.svg == chimeway-mark.svg and doc/assets/favicon.svg == favicon.svg (byte-identical); doc/Chimeway.html references assets/logo.svg + assets/favicon.svg"
        status: pass
    human_judgment: true
    rationale: "Automated checks prove the assets are copied, byte-identical, and referenced in the generated HTML, but the actual VISUAL render (teal+ink mark in the sidebar slot, favicon in the browser tab) requires a human to open doc/index.html and confirm. PENDING human sign-off — user is currently away."

# Metrics
duration: 8min
completed: 2026-07-28
status: awaiting-human-verify
---

# Phase 85 Plan 01: Repo Integration (README lockup + HexDocs logo/favicon) Summary

**Wired the shipped Chimeway brand assets into the two adopter-facing surfaces — a GitHub-native theme-swapping `<picture>` lockup in the README header and `:logo`/`:favicon` in ExDoc `docs()` — keeping all v1.14 contracts green via a deliberate narrative-order-gate evolution.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-28T00:48:30Z
- **Completed (automated work):** 2026-07-28T00:56:36Z
- **Tasks:** 3 (2 auto committed; Task 3 automated gate complete, human visual verify PENDING)
- **Files modified:** 3

## Accomplishments
- README header now renders the primary brand lockup via a GitHub-native `<picture>` element that theme-swaps: dark `<source srcset="brandbook/assets/logo/chimeway-logotype-inverse.svg">` + default `<img src="brandbook/assets/logo/chimeway-logotype.svg" alt="Chimeway" width="380">`, wrapped in a repo `<a href>`. All paths relative; badges, tagline, and numbered snippet blocks untouched.
- `mix.exs docs()` wires `logo: "brandbook/assets/logo/chimeway-mark.svg"` (square mark) and `favicon: "brandbook/assets/favicon/favicon.svg"`. No `:assets` map, no `ex_doc` bump, `package() files:` unchanged.
- `mix docs` builds cleanly and copies both assets into `doc/assets/` (byte-identical to sources); the generated pages reference `assets/logo.svg` in the sidebar and `assets/favicon.svg` in the tab.
- All three v1.14 contract tests pass (530 tests, 0 failures) after evolving the doc-contract narrative-order gate to drop the now-removed `# Chimeway` H1 anchor.

## Task Commits

1. **Task 1: Replace README text heading with theme-swapping brand lockup** - `8a8374c` (feat)
2. **Task 2: Wire ExDoc :logo and :favicon into mix.exs docs()** - `6c16077` (feat)
3. **Task 3 (contract evolution): drop # Chimeway H1 anchor from readme narrative-order gate** - `6997ffe` (test)

_Note: Task 3 is a checkpoint:human-verify task. Its automated portion (contract tests + mix docs + asset byte-verification) is complete; the human visual render confirmation remains pending (see Next Phase Readiness). The `test(...)` commit above is the fix that resolved the plan-internal contract conflict discovered while executing Task 3._

## Files Created/Modified
- `README.md` - Header region: plain `# Chimeway` H1 replaced with `<a><picture>` brand lockup (relative brandbook/assets paths, `alt="Chimeway"`).
- `mix.exs` - `docs()` gains `logo:` (square mark) and `favicon:` entries; `package()` and `ex_doc` requirement untouched.
- `test/chimeway/doc_contract_test.exs` - `@readme_section_order` narrative-order gate now starts at `## When to use`; the `# Chimeway` H1 anchor removed (comment updated to note the lockup replaces the title).

## Decisions Made
- **Evolved the doc-contract narrative-order gate instead of retaining a redundant heading.** The coordinator authorized removing the `# Chimeway` entry from `@readme_section_order` because the brand lockup IS the intended replacement for the plain-text title (INTEG-01) — keeping a visible `# Chimeway` heading alongside the lockup would have undercut the phase's visual goal. This is a deliberate, pre-declared contract evolution (documented here for Phase 86's scope audit), not a band-aid to force a green test.
- Square `chimeway-mark.svg` for ExDoc `:logo` (icon-scale sidebar slot); fixed-color, not the mono variant (D-02).
- No `:assets` map, no `ex_doc` bump (D-03); `package() files:` left unchanged (D-04).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 4 - Architectural/Scope, coordinator-approved] Evolved doc_contract_test narrative-order gate to drop the `# Chimeway` H1 anchor**
- **Found during:** Task 3 (running the v1.14 contract suite)
- **Issue:** The plan contained two contradictory must-haves. Task 1 / must_have truth #1 require the plain `# Chimeway` Markdown H1 to be **removed** (replaced by the lockup). But must_have truth #6 / Task 3 require `doc_contract_test.exs` to **exit 0**, and that test's `@readme_section_order` gate (`test/chimeway/doc_contract_test.exs:1428`) hard-requires a line-anchored `^# Chimeway$` heading as the first narrative section. Removing the H1 (as Task 1 specifies) necessarily failed the contract — `README missing narrative section heading: # Chimeway`. The plan author analyzed `release_gate_contract_test` (presence-only, undisturbed) but overlooked this narrative-order gate. No README arrangement can both omit a literal `# Chimeway` line and satisfy the regex.
- **Resolution path:** Surfaced as a blocking decision (Rule 4) rather than silently resolved. Coordinator directed evolving the contract: the `# Chimeway` anchor was a proxy for the README title, which is now the brand lockup, so the anchor is retired.
- **Fix:** Removed the `"# Chimeway",` entry from `@readme_section_order` (list now starts at `"## When to use"`) and added a comment noting the title is now the GitHub-native brand lockup carrying `alt="Chimeway"`. No other test or contract touched.
- **Files modified:** `test/chimeway/doc_contract_test.exs`
- **Verification:** `mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs test/chimeway/integration/readme_snippet_test.exs` → 530 tests, 0 failures, exit 0.
- **Committed in:** `6997ffe`

---

**Total deviations:** 1 (Rule 4 architectural/scope, coordinator-approved contract evolution)
**Impact on plan:** The edit is deliberate and pre-declared for Phase 86's scope audit. It resolves an internal plan contradiction while preserving the phase intent (lockup replaces the plain title) and keeping all three v1.14 contracts green. Scope remained confined to the README header, `mix.exs docs()`, and the single narrative-order-gate anchor. No runtime code, no `chimeway_admin`, no `package() files:` change, no `ex_doc` bump, no `:assets` map.

## Issues Encountered
- The plan-internal contract contradiction described above (resolved via coordinator-approved contract evolution). A second, unrelated log line during the test run — a `Threadline.Export.CleanupTask` Ecto-sandbox `handle_info` crash — is a background GenServer message from a dependency, not a test failure; the suite reports 0 failures.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

**Automated work complete; ONE human visual verification PENDING.**

- ✅ Task 1 & Task 2 committed; all acceptance criteria passed.
- ✅ v1.14 contract suite green (530 tests, 0 failures).
- ✅ `mix docs` builds cleanly; `doc/assets/logo.svg` and `doc/assets/favicon.svg` are byte-identical to the brandbook sources; generated HTML references both.
- ⏳ **PENDING human sign-off (Task 3 human-verify gate):** a human must run `open doc/index.html` and visually confirm (1) the teal+ink square mark renders in the ExDoc left sidebar logo slot, and (2) the favicon shows in the browser tab. Optionally glance at the GitHub README preview to confirm the lockup renders in both light and dark mode. The user is currently away — this is the single outstanding item. Resume signal: type "approved" once the render is confirmed, or describe what looks wrong.

## Self-Check: PASSED

- `85-01-SUMMARY.md` present on disk.
- Commits `8a8374c`, `6c16077`, `6997ffe` present in git history.
- README no longer contains a standalone `# Chimeway` H1 (count 0); `<picture>` lockup present (count 1).

---
*Phase: 85-repo-integration-readme-hexdocs-favicon-wiring*
*Completed (automated): 2026-07-28 — human visual verify pending*
