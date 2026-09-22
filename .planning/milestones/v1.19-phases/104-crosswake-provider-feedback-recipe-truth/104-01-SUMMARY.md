---
phase: 104-crosswake-provider-feedback-recipe-truth
plan: "01"
subsystem: adoption-contract
tags: [elixir, crosswake, provider-feedback, oban, security, documentation]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: proof-backed authenticated provider-feedback registry scope
provides:
  - Source-valid durable CrossWake provider-feedback worker recipe
  - Executable advisory, invalidation, denial, and recursive-redaction proof
  - Separately published and selected CrossWake documentation revision
affects: [104-02, provider-feedback-docs, release-gates]
actuals:
  tokens: 3500
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [compile-exact-readme-snippet, corroborating-provider-evidence, separate-cross-repo-authority]
key-files:
  created:
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/provider_feedback_recipe_test.exs
    - priv/adoption/crosswake-provider-feedback-docs-selected-sha
  modified:
    - ../crosswake/examples/phoenix_host/README.md
key-decisions:
  - "Provider attributes normalize only through Redaction.feedback_from_provider_attrs/1; provider tokens corroborate but never authorize invalidation."
  - "The docs revision is published on a new non-force branch and selected independently from the frozen physical-proof authority."
patterns-established:
  - "Executable docs: extract, compile, and invoke the exact README worker block against real package boundaries."
  - "Cross-repo authority: publish one tested commit, prove it from a fresh detached checkout, then record its full SHA."
requirements-completed: [DOCS-02]
coverage:
  - id: D1
    description: "Copyable provider-feedback worker uses the real conversion boundary, full host-authenticated scope, and preserves errors."
    requirement: DOCS-02
    verification:
      - kind: integration
        ref: "examples/phoenix_host/test/crosswake_example/chimeway/provider_feedback_recipe_test.exs#README recipe compiles and executes advisory feedback through both public boundaries"
        status: pass
    human_judgment: false
  - id: D2
    description: "Exact invalidation, stale/mismatched denial, installation scope, and recursive sanitization execute against the real registry."
    requirement: DOCS-02
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/crosswake_example/chimeway/registry_test.exs test/crosswake_example/chimeway/provider_feedback_recipe_test.exs --warnings-as-errors"
        status: pass
    human_judgment: false
  - id: D3
    description: "The exact tested documentation commit is remotely reproducible while the v1.18 physical branch remains frozen."
    requirement: DOCS-02
    verification:
      - kind: e2e
        ref: "fresh canonical clone + detached selected SHA + focused example-host test"
        status: pass
    human_judgment: false
duration: 6min
completed: 2026-09-12
status: complete
---

# Phase 104 Plan 01: Executable Provider-Feedback Recipe Summary

**A source-valid CrossWake worker now executes the real redaction and exact-authority registry paths at a separately pinned, remotely reproducible revision.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-12T15:19:00Z
- **Completed:** 2026-09-12T15:25:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Replaced the nonexistent provider-feedback constructor with the real redaction boundary and explicit error-preserving registry flow.
- Added four executable tests covering advisory evidence, exact session invalidation, mismatch denial, installation authority, and recursive sanitization.
- Published only `phase-104-provider-feedback-recipe-truth`, replayed the proof from a fresh detached checkout, and recorded its exact SHA separately from physical proof.

## Task Commits

1. **RED: expose the broken recipe** — `af366ca5` (CrossWake test)
2. **GREEN: make the recipe executable** — `36841e06` (CrossWake fix)
3. **Select the proven documentation revision** — `7751a2eb` (Chimeway chore)

## Files Created/Modified

- `../crosswake/examples/phoenix_host/README.md` — real durable worker recipe and exact authority guidance.
- `../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/provider_feedback_recipe_test.exs` — exact-snippet compilation and behavior proof.
- `priv/adoption/crosswake-provider-feedback-docs-selected-sha` — independently selected remote docs SHA.

## Decisions Made

- Installation-scoped authority intentionally omits session keys; session-scoped authority requires current session reference and version.
- Registry/conversion errors are returned to Oban so host retry/discard policy remains authoritative.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the installed OTP patch release for the archived CrossWake tool pin**
- **Found during:** Task 1 verification
- **Issue:** The archived checkout requested an unavailable abbreviated Erlang version while the compatible installed patch release was present.
- **Fix:** Ran proof commands with explicit `ASDF_ERLANG_VERSION=27.3.4.15` and matching Elixir OTP build; no tracked tool-version file changed.
- **Files modified:** None
- **Verification:** Focused and registry suites passed under the compatible runtime.
- **Committed in:** Not applicable (environment-only)

---

**Total deviations:** 1 auto-fixed blocking environment issue. **Impact on plan:** No product or authority contract changed.

## Issues Encountered

- The repository root cannot directly compile the nested companion test file in isolation because that package is a separate Mix project; the supported package/example-host invocations passed and the unrelated harness was left unchanged.
- Dependency resolution reported advisories in pre-existing locked web dependencies. This phase adds no dependency and does not expand the example host's network exposure.

## User Setup Required

None - the branch was published and the selected SHA recorded without additional credentials or manual configuration.

## Next Phase Readiness

- The selected documentation SHA is ready for Chimeway's mutation-negative fresh-remote verifier and CI parity wiring in Plan 104-02.
- The physical proof authority still resolves to its frozen v1.18 SHA.

## Self-Check: PASSED

- Key files exist in both repositories.
- CrossWake task commits and the Chimeway authority commit are present.
- 14 registry/recipe tests passed locally; 4 focused recipe tests passed again from a fresh canonical checkout.
- Both documentation and physical remote heads equal their intended exact SHAs.

---
*Phase: 104-crosswake-provider-feedback-recipe-truth*
*Completed: 2026-09-12*
