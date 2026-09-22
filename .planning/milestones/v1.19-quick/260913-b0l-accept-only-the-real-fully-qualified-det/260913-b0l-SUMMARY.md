---
phase: 260913-b0l-detached-readme-exact-identities
plan: 01
quick_id: 260913-b0l
subsystem: release-proof
tags: [elixir, ast, crosswake, detached-verification, tdd]
requires:
  - phase: 260913-a2h-crosswake-exact-aliases
    provides: Exact full-alias matching and prefix-spoof mutation coverage
provides:
  - Context-specific exact identities for the selected CrossWake README and focused proof
  - Selected-source-shaped positive fixture with non-vacuous README spoof mutations
  - Passing real detached proof at selected SHA 36841e065ad4a71b58b80bd599d111c8ee178390
affects: [release, crosswake-proof, documentation-contracts]
actuals:
  tokens: 1293
  tasks: 2
  commits: 2
plan_head_before: ce9b3c54ae2b75cb798f894dcc62ca712695cb72
task-commits:
  red: 9c9e868ade3ff042158f91dd8f31cdd995bc24b4
  green: d98416546da8779d15c7220eec370d7c7b70dd44
tech-stack:
  added: []
  patterns:
    - Detached proof allowlists are exact and specific to each parsed source context
    - Positive fixtures mirror the authority-selected source rather than abbreviating public aliases
key-files:
  created:
    - .planning/quick/260913-b0l-accept-only-the-real-fully-qualified-det/260913-b0l-SUMMARY.md
  modified:
    - lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex
    - test/chimeway/crosswake_provider_feedback_docs_contract_test.exs
key-decisions:
  - "README validation accepts only the selected source's fully qualified Redaction and Registry paths, while focused proof validation retains its exact imported one-segment aliases."
  - "The real authority-selected detached constituent is a required GREEN gate; a synthetic-only pass is insufficient."
patterns-established:
  - "Exact alias identity is defined per source context, with no suffix matching or arbitrary alias resolution."
requirements-completed: []
coverage:
  - id: D1
    description: The synthetic positive README mirrors and accepts the selected authority's fully qualified public calls
    verification:
      - kind: integration
        ref: test/chimeway/crosswake_provider_feedback_docs_contract_test.exs#selected_readme_identity
        status: pass
    human_judgment: false
  - id: D2
    description: All six prefix-spoofed aliases remain rejected before focused execution
    verification:
      - kind: integration
        ref: test/chimeway/crosswake_provider_feedback_docs_contract_test.exs#exact_alias_identity
        status: pass
      - kind: integration
        ref: test/chimeway/crosswake_provider_feedback_docs_contract_test.exs (30 tests, 0 failures)
        status: pass
    human_judgment: false
  - id: D3
    description: The real selected CrossWake checkout passes source validation and focused execution
    verification:
      - kind: integration
        ref: mix ci.crosswake_provider_feedback_docs#crosswake_provider_feedback_docs_verified
        status: pass
      - kind: other
        ref: mix format --check-formatted
        status: pass
    human_judgment: false
duration: 10 min
completed: 2026-09-13
status: complete
---

# Quick 260913-b0l: Detached README Exact Identities Summary

**The CrossWake proof now accepts the selected README's exact fully qualified public modules while retaining strict, spoof-resistant identities in both source contexts.**

## Performance

- **Duration:** 10 min
- **Completed:** 2026-09-13
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Updated the shared positive README fixture to reproduce the fully qualified calls at selected SHA `36841e065ad4a71b58b80bd599d111c8ee178390`.
- Bound README conversion and persistence validation to those exact full paths without changing the focused proof or worker allowlists.
- Restored the real detached CrossWake constituent while preserving all six prefix-spoof rejections and all 24 earlier contract cases.

## Task Commits

1. **Task 1: Make the synthetic positive README reproduce the selected authority** — `9c9e868a` (`test`)
2. **Task 2: Bind README validation to its real full paths and replay detached proof** — `d9841654` (`fix`)

## RED Evidence

- Command selected only `:selected_readme_identity` against unchanged production.
- The public verifier produced the intended pre-fix tuple `{:error, false}` rather than invoking focused execution.
- Output emitted `RED_SELECTED_README_CANONICAL_REJECTED` immediately before the assertion.
- Result: 1 test, 1 failure; 29 excluded. The assertion expected `{:ok, true}` and observed `{:error, false}`.
- The retained exact-alias security group independently remained green: 6 tests, 0 failures; 24 excluded.

## GREEN Evidence

- Selected README identity: 1 test, 0 failures; 29 excluded.
- Full local CrossWake contract: 30 tests, 0 failures with warnings treated as errors.
- Exact-alias security group: 6 tests, 0 failures; 24 excluded.
- Real detached constituent: exit zero and exact `crosswake_provider_feedback_docs_verified` marker.
- Repository `mix format --check-formatted`: passed.
- Focused formatter check for both owned files: passed.
- `git diff --check` for both owned files: passed.

## Files Created/Modified

- `lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex` — supplies the selected README's exact full aliases to the existing complete-list equality matcher.
- `test/chimeway/crosswake_provider_feedback_docs_contract_test.exs` — mirrors selected README identities, proves the prior false negative, and makes README hostile mutations non-vacuous.

## Decisions Made

- Kept exact identities context-specific: fully qualified aliases for the README and imported one-segment aliases for the focused test.
- Left `remote_call?/3`, focused marker clauses, worker identity, graph traversal, selector authorities, checkout, cleanup, and public Mix entrypoints unchanged.

## TDD Gate Compliance

- **RED:** Commit `9c9e868a` contains test-only changes and proves the selected-source-shaped positive case failed for its intended behavior assertion.
- **GREEN:** Commit `d9841654` contains the context-specific exact README identities and passes the real detached proof.
- **REFACTOR:** Not needed; GREEN changes only the two exact README alias expectations.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The executor could not commit Task 2 because the mandatory linked-worktree guard rejects commits from `resume/v1.18`; the orchestrator recorded the atomic production-only commit as `d9841654`.

## Known Stubs

None.

## Threat Review

- T-b0l-01 is mitigated by context-specific complete alias allowlists and six retained public-verifier spoof mutations.
- T-b0l-02 is mitigated by the passing real detached constituent at the selected authority.
- T-b0l-03 remains unchanged accepted risk; output stays limited to the stable marker or exit status.
- No new network, authentication, schema, secret-bearing, or file-access surface was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The CrossWake x9g gap is ready for independent re-verification after the orchestrator records the GREEN commit.

## Self-Check: PASSED

- Both owned implementation files exist.
- RED commit `9c9e868a` exists and contains only the contract test.
- The requested b0l SUMMARY exists at the quick-task path.
- The selected positive, six spoof cases, full local contract, detached proof, formatter, and diff checks all pass.
- No tracked files were deleted and no out-of-scope file was modified by this executor.

---
*Quick task: 260913-b0l*
*Completed: 2026-09-13*
