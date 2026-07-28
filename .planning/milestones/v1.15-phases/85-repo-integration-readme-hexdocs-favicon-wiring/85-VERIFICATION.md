---
phase: 85-repo-integration-readme-hexdocs-favicon-wiring
verified: 2026-07-27T00:00:00Z
status: passed
score: 6/6 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 85: Repo Integration (README + HexDocs + Favicon Wiring) Verification Report

**Phase Goal:** Make the real brand mark visible on the surfaces adopters actually see — the GitHub README and HexDocs — through minimal, tightly-scoped edits that leave every v1.14 contract green.
**Verified:** 2026-07-27
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ------- | ---------- | -------------- |
| 1 | README header renders theme-swapping `<picture>` lockup (dark `<source>` → logotype-inverse.svg + default `<img src=logotype.svg alt="Chimeway">`); plain `# Chimeway` H1 gone; relative paths only (INTEG-01) | ✓ VERIFIED | README.md lines 2-7: `<picture>` with `<source media="(prefers-color-scheme: dark)" srcset="brandbook/assets/logo/chimeway-logotype-inverse.svg">` and `<img src="brandbook/assets/logo/chimeway-logotype.svg" alt="Chimeway" width="380">`. `grep '^# Chimeway$'` → no match. `grep 'src(set)?="https?://'` → no match. |
| 2 | mix.exs docs() sets logo: chimeway-mark.svg and favicon: favicon.svg; no :assets map; ex_doc ~> 0.31 unchanged (INTEG-02) | ✓ VERIFIED | mix.exs:228-229 exact entries present. No `assets:` key in mix.exs. mix.exs:41 `{:ex_doc, "~> 0.31", ...}` unchanged. |
| 3 | `mix docs` copies mark + favicon into doc/assets/ byte-identical; referenced in generated HTML (INTEG-02) | ✓ VERIFIED | `mix docs` exit 0. `cmp doc/assets/logo.svg brandbook/assets/logo/chimeway-mark.svg` → IDENTICAL; `cmp doc/assets/favicon.svg brandbook/assets/favicon/favicon.svg` → IDENTICAL. Generated HTML references assets/logo.svg + assets/favicon.svg. Human render already approved (sidebar mark + browser-tab favicon). |
| 4 | package() files: list unchanged — no brandbook/assets added (INTEG-04) | ✓ VERIFIED | mix.exs:219 `files: ~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs)` verbatim. |
| 5 | README numbered snippet blocks + badges/tagline untouched; chimeway_admin untouched (INTEG-04) | ✓ VERIFIED | Full phase diff (8a8374c~1..6997ffe) touches only README.md (+8/-1, header region only), mix.exs (+2), doc_contract_test.exs (+4/-1). No `## When to use`/snippet edits, no chimeway_admin. readme_snippet_test green. |
| 6 | Three v1.14 contract tests exit 0 (INTEG-04) | ✓ VERIFIED | `mix test doc_contract_test.exs release_gate_contract_test.exs readme_snippet_test.exs` → 530 tests, 0 failures. |

**Score:** 6/6 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | ----------- | ------ | ------- |
| `README.md` | header lockup markup net-added | ✓ VERIFIED | `<a><picture>` lockup at lines 1-7; badges/tagline/snippet blocks intact |
| `mix.exs` | docs() logo:/favicon: keys added | ✓ VERIFIED | lines 228-229; package() and ex_doc untouched |
| `brandbook/assets/logo/*.svg`, `favicon.svg` | pre-existing (Phase 83) | ✓ VERIFIED | all four referenced SVGs present on disk |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| README `<picture>`/`<img>` src/srcset | brandbook/assets/logo/*.svg | relative in-repo paths (no remote URLs) | ✓ WIRED | grep confirms relative paths; no `https?://` in src/srcset |
| mix.exs docs() :logo/:favicon | brandbook/assets/*.svg → doc/assets/ | ExDoc copies at build (no :assets map) | ✓ WIRED | `mix docs` copied both byte-identical; HTML references them |

### Authorized Deviation (validated, not flagged)

The `# Chimeway` H1 anchor was dropped from `@readme_section_order` in `test/chimeway/doc_contract_test.exs` (commit 6997ffe). Verified the edit is limited to that one anchor plus an explanatory comment: `git show 6997ffe` = 4 insertions / 1 deletion, only the `"# Chimeway",` list entry removed; list now starts at `"## When to use"`. This is the coordinator-approved contract evolution (lockup replaces the plain title, pre-declared for Phase 86 scope audit) — authorized scope, not drift. The three contract tests are green as a result.

### Anti-Patterns Found

None. No debt markers (TBD/FIXME/XXX/TODO) in the modified header region, mix.exs docs(), or the test edit. No stubs, no hardcoded empty data, no remote-URL leakage.

### Human Verification Required

None outstanding. Task 3's human visual-render gate (sidebar mark + browser-tab favicon) has already been confirmed ("approved").

### Gaps Summary

No gaps. All six must-have truths verified against the codebase: README lockup markup present with relative paths and no residual H1; mix.exs docs() wires the square mark + favicon with no :assets map and no ex_doc bump; `mix docs` copies both assets byte-identical into doc/assets/ and references them in generated HTML; scope stayed confined to the README header, docs(), and a single authorized narrative-gate anchor; package() files: and chimeway_admin untouched; all three v1.14 contract tests pass (530/0). Phase goal achieved.

---

_Verified: 2026-07-27_
_Verifier: Claude (gsd-verifier)_
