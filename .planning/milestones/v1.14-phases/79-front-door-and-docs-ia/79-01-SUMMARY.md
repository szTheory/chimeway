---
phase: 79-front-door-and-docs-ia
plan: 01
subsystem: docs
tags: [readme, hexdocs, doc-contract, exunit, information-architecture, elixir]

# Dependency graph
requires:
  - phase: 78-release-and-package-truth
    provides: canonical szTheory owner URL, unpacked-Hex artifact truth contract, sibling preview/path status phrases
provides:
  - README rewritten as an additive-superset decision page (value prop, When to use, Non-goals, Host-owned boundaries, Optional surfaces)
  - DOCS-16 public-API snippet chain in README (notification_key/0, Chimeway.trigger, prefix config, Chimeway.Traces.explain_delivery)
  - Three Flows stubs delinked from README nav + mix.exs docs.extras (files kept on disk)
  - Canonical szTheory owner URLs in golden-path.md (legacy jonlunsford removed)
  - Executable doc-contract markers pinning the README rewrite, plus golden-path legacy-URL guard and README sibling-install forbid
  - Packaged (unpacked-Hex) README public-story invariants asserted in the release gate
affects: [docs, adopter-onboarding, hexdocs-ia, release-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Docs truth = executable ExUnit string contract (extend existing describe blocks, never add a new test file)"
    - "Marker-string lockstep: the same phrase asserted in both the source-tree README (doc_contract) and the packaged README (release_gate)"

key-files:
  created: []
  modified:
    - README.md
    - mix.exs
    - guides/introduction/golden-path.md
    - test/chimeway/doc_contract_test.exs
    - test/chimeway/release_gate_contract_test.exs

key-decisions:
  - "Reused Phase 78's enforced sibling-status phrases (in-repo preview/path package / not published on Hex yet) verbatim so README, packaged guides, and packaged README stay in lockstep"
  - "Kept idempotency_key:/tenant_id: colon-suffixed tokens exclusively inside Chimeway.trigger examples (prose uses bare forms) to satisfy the per-trigger count invariant"
  - "README shows no recipients/1 callback — recipient wiring stays in golden-path to avoid the plain-substring identity: forbid"

patterns-established:
  - "New multi-word/heading doc markers go in an explicit string-list attribute (@readme_decision_markers), never ~w() which splits on whitespace"
  - "First-hop guides outside release_gate's package-facing file list get their own legacy-URL forbid guard in doc_contract"

requirements-completed: [DOCS-14, DOCS-15, DOCS-16, DOCS-17, ADPT-01]

coverage:
  - id: D1
    description: "README leads with a local-first value prop + preserved explainability promise (DOCS-14)"
    requirement: "DOCS-14"
    verification:
      - kind: unit
        ref: "test/chimeway/doc_contract_test.exs#requires decision-page marker local-first in README"
        status: pass
    human_judgment: false
  - id: D2
    description: "README states use cases, non-goals, host-owned boundaries, and optional/preview-surface status (DOCS-15)"
    requirement: "DOCS-15"
    verification:
      - kind: unit
        ref: "test/chimeway/doc_contract_test.exs#requires decision-page marker ## Non-goals / ## When to use / ## Host-owned boundaries / ## Optional surfaces in README"
        status: pass
    human_judgment: false
  - id: D3
    description: "README public snippets show the notification_key/0 stable key, tenant_id, idempotency_key, storage prefix, and Chimeway.Traces.explain_delivery on the real public API, per-trigger invariant enforced (DOCS-16)"
    requirement: "DOCS-16"
    verification:
      - kind: unit
        ref: "test/chimeway/doc_contract_test.exs#every Chimeway.trigger example includes idempotency_key and tenant_id + requires Chimeway.Traces.explain_delivery in README"
        status: pass
    human_judgment: false
  - id: D4
    description: "Three Flows stubs delinked from README nav + mix.exs docs.extras (files kept on disk, multi-step-journeys.md preserved); golden-path legacy URLs canonicalized and guarded (DOCS-17)"
    requirement: "DOCS-17"
    verification:
      - kind: unit
        ref: "test/chimeway/doc_contract_test.exs#forbids the legacy jonlunsford owner URL in golden path guide"
        status: pass
      - kind: manual_procedural
        ref: "grep -c 'guides/flows/trigger-to-delivery.md' README.md == 0; ls guides/flows/{trigger-to-delivery,policy-and-preferences,async-dispatch}.md succeeds; grep -c multi-step-journeys.md mix.exs >= 1"
        status: pass
    human_judgment: false
  - id: D5
    description: "Packaged (unpacked-Hex) README carries the new DOCS-14/15/16 public-story invariants (ADPT-01)"
    requirement: "ADPT-01"
    verification:
      - kind: integration
        ref: "test/chimeway/release_gate_contract_test.exs#unpacked Hex package carries package truth docs and source links"
        status: pass
    human_judgment: false

# Metrics
duration: ~12min
completed: 2026-07-03
status: complete
---

# Phase 79 Plan 01: Front Door and Docs IA Summary

**README rewritten as an additive-superset decision page (local-first value prop, four decision sections, and the DOCS-16 public-API trigger-to-explain snippet chain), with the story locked by byte-identical ExUnit markers in both the source-tree and packaged (unpacked-Hex) README contracts.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-07-03
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Rewrote README.md as an additive superset: local-first value prop + preserved explainability promise, plus `## When to use`, `## Non-goals`, `## Host-owned boundaries`, and `## Optional surfaces` decision sections. Optional surfaces frame chimeway_admin/chimeway_inbox as in-repo preview/path packages, not published on Hex yet.
- Added the DOCS-16 canonical snippet chain on the real public API: notifier `notification_key/0` + `version/0`, `Chimeway.trigger/3` with both `tenant_id` and `idempotency_key`, `config :chimeway, prefix: "chimeway"`, and `Chimeway.Traces.explain_delivery/1` with `delivery_id` sourced from `result.trace`.
- Delinked the three Flows stubs (trigger-to-delivery, policy-and-preferences, async-dispatch) from README nav + mix.exs docs.extras while keeping the files on disk and preserving multi-step-journeys.md.
- Canonicalized the four legacy jonlunsford owner URLs in golden-path.md to szTheory and added a doc-contract guard so the fix cannot silently regress.
- Locked the rewrite with executable assertions: README `@required` marker + `@readme_decision_markers` list + per-trigger invariant + sibling-install forbid (doc_contract), and packaged-README public-story invariants (release_gate). `mix ci.verify_gates` green (505 tests, 0 failures).

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite README + delink Flows stubs + fix golden-path URLs** - `4445d2d` (feat)
2. **Task 2: Lock README rewrite + golden-path URL guard + sibling-install forbid in doc_contract** - `362e707` (test)
3. **Task 3: Lock packaged-README public-story invariants in release gate** - `db241a5` (test)

## Files Created/Modified
- `README.md` - Rewritten as an additive-superset decision page with four decision sections and the DOCS-16 public-API snippet chain; trigger-to-delivery Flow nav link removed
- `mix.exs` - Removed the three Flows stub entries from docs.extras (multi-step-journeys.md kept)
- `guides/introduction/golden-path.md` - Four legacy jonlunsford owner URLs canonicalized to szTheory
- `test/chimeway/doc_contract_test.exs` - README describe extended (explain_delivery marker, decision-marker list, per-trigger invariant, sibling-install forbid); golden path describe extended with legacy-URL guard
- `test/chimeway/release_gate_contract_test.exs` - Unpacked-artifact test asserts the packaged README carries local-first, `## Non-goals`, `## Host-owned boundaries`, in-repo preview/path package, and Chimeway.Traces.explain_delivery

## Decisions Made
- Reused Phase 78's already-enforced sibling-status phrases (`in-repo preview/path package`, `not published on Hex yet`) verbatim, keeping README, packaged guides, and packaged README in string lockstep.
- Confined the colon-suffixed `idempotency_key:` / `tenant_id:` tokens to `Chimeway.trigger(...)` examples (two triggers, each carrying both opts) and used bare `tenant_id` / `idempotency_key` in prose, so the per-trigger count invariant holds (2/2/2).
- Kept recipient wiring out of README entirely (no `recipients/1` callback) to avoid tripping the README plain-substring `identity:` forbid (RESEARCH Pitfall 1).
- For the host-boundary packaged-README marker, asserted the `## Host-owned boundaries` heading (byte-identical across both contracts).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. Baseline contract suites were green before edits (493 tests) and stayed green after each task; the full lane finished at 505 tests, 0 failures.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The first-hop docs story (README front door + golden-path URL hygiene + Flows-stub delinking) is complete and contract-locked, including proof it survives Hex packaging.
- No blockers. The three delinked Flows stubs remain backlog candidates for later completion (files intact, still cross-linked from getting-started.md and password-reset-support-trace.md).

---
*Phase: 79-front-door-and-docs-ia*
*Completed: 2026-07-03*

## Self-Check: PASSED
- All 5 modified files present on disk; SUMMARY.md created.
- All three task commits (4445d2d, 362e707, db241a5) present in git history.
