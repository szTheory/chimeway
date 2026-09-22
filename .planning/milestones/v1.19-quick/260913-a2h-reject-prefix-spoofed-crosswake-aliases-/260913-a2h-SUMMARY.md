---
phase: 260913-a2h-crosswake-exact-aliases
plan: 01
quick_id: 260913-a2h
subsystem: release-proof
tags: [elixir, ast, crosswake, release-security, tdd]
requires:
  - phase: 260912-x9g-release-hardening
    provides: ExUnit-rooted, cycle-safe CrossWake proof reachability
provides:
  - Exact full-alias identity enforcement for detached README recipe calls
  - Exact full-alias identity enforcement for rooted focused-test proof markers and the worker alternative
  - Public-verifier regression coverage for six prefix-spoofed aliases
affects: [release, crosswake-proof, documentation-contracts]
actuals:
  tokens: 1855
  tasks: 2
  commits: 2
plan_head_before: f52064b5b0e3122191e9896cf6e24a23827c68d7
task-commits:
  red: 2812d297794fd5a8b2e665ea2a4e32b71786b481
  green: 3979004e7b11f82e4ad5b6d3a3fec687cda67a00
tech-stack:
  added: []
  patterns:
    - Parsed Elixir aliases are matched as complete atom lists at proof boundaries
    - Security mutations exercise the public verifier and pair verdicts with focused-execution evidence
key-files:
  created:
    - .planning/quick/260913-a2h-reject-prefix-spoofed-crosswake-aliases-/260913-a2h-SUMMARY.md
  modified:
    - lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex
    - test/chimeway/crosswake_provider_feedback_docs_contract_test.exs
key-decisions:
  - "Trusted CrossWake proof calls are recognized only by their complete canonical alias lists; matching a final alias segment is insufficient."
  - "Each spoofing boundary has its own public-verifier test tag and proves rejection occurs before focused execution."
patterns-established:
  - "Detached AST proof boundaries compare complete aliases such as `[:Redaction]`, never `List.last/1`."
requirements-completed: []
coverage:
  - id: D1
    description: Prefix-spoofed focused Code, Redaction, Registry, and worker aliases are rejected before focused execution
    verification:
      - kind: integration
        ref: test/chimeway/crosswake_provider_feedback_docs_contract_test.exs#exact_alias_identity focused cases
        status: pass
      - kind: integration
        ref: CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/crosswake_provider_feedback_docs_contract_test.exs --warnings-as-errors
        status: pass
    human_judgment: false
  - id: D2
    description: Prefix-spoofed README Redaction and Registry aliases are rejected before focused execution
    verification:
      - kind: integration
        ref: test/chimeway/crosswake_provider_feedback_docs_contract_test.exs#exact_alias_identity README cases
        status: pass
    human_judgment: false
  - id: D3
    description: Canonical README, focused proof, worker alternative, reachability, authority, checkout, and cleanup behavior remains accepted
    verification:
      - kind: integration
        ref: test/chimeway/crosswake_provider_feedback_docs_contract_test.exs (30 tests, 0 failures)
        status: pass
      - kind: other
        ref: mix format --check-formatted
        status: pass
    human_judgment: false
duration: 15 min
completed: 2026-09-13
status: complete
---

# Quick 260913-a2h: Exact CrossWake Alias Identity Summary

**CrossWake release proof now accepts only complete trusted module aliases and rejects six attacker-prefixed lookalikes before focused execution.**

## Performance

- **Duration:** 15 min
- **Completed:** 2026-09-13
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added six independently selectable public-verifier mutations covering every trusted README and focused-test alias boundary.
- Replaced suffix-only marker classification with exact alias-list matching for `Code`, `Redaction`, `Registry`, and `MyApp.Workers.ChimewayProviderFeedbackWorker`.
- Preserved all 24 prior CrossWake contract cases while bringing the full contract to 30 passing tests.

## Task Commits

1. **Task 1: Add red public-verifier fixtures for prefix-spoofed aliases** — `2812d297` (`test`)
2. **Task 2: Preserve complete aliases through both CrossWake scanners** — `3979004e` (`fix`)

## RED Evidence

Each unique tag was run independently against the suffix-only implementation:

| Case | Observed tuple | Sentinel | Result |
|---|---|---|---|
| `focused_code` | `{:ok, true}` | `RED_ALIAS_SPOOF_ACCEPTED:focused_code` | 1 test, 1 failure |
| `focused_redaction` | `{:ok, true}` | `RED_ALIAS_SPOOF_ACCEPTED:focused_redaction` | 1 test, 1 failure |
| `focused_registry` | `{:ok, true}` | `RED_ALIAS_SPOOF_ACCEPTED:focused_registry` | 1 test, 1 failure |
| `focused_worker` | `{:ok, true}` | `RED_ALIAS_SPOOF_ACCEPTED:focused_worker` | 1 test, 1 failure |
| `readme_redaction` | `{:ok, true}` | `RED_ALIAS_SPOOF_ACCEPTED:readme_redaction` | 1 test, 1 failure |
| `readme_registry` | `{:ok, true}` | `RED_ALIAS_SPOOF_ACCEPTED:readme_registry` | 1 test, 1 failure |

Every run excluded the other 29 cases and failed on the intended `observed == {:error, false}` assertion. No setup, compilation, selection, or unrelated test failure authorized GREEN.

## GREEN Evidence

- Full CrossWake contract: 30 tests, 0 failures with warnings treated as errors.
- Exact-alias security group: 6 tests, 0 failures; 24 unrelated tests excluded.
- `mix format --check-formatted`: passed for the repository.
- Focused formatter check for both owned files: passed.
- `git diff --check` for both owned files: passed.
- No `List.last(aliases)` matcher remains in the production verifier.

## Files Created/Modified

- `lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex` — preserves complete alias lists through marker classification and validates exact README and worker aliases.
- `test/chimeway/crosswake_provider_feedback_docs_contract_test.exs` — exercises six qualifier substitutions through the public `verify/1` boundary.

## Decisions Made

- Kept the verifier's root discovery, graph traversal, pruning, command execution, authority selection, cleanup, and public interface unchanged.
- Used complete parsed alias lists directly rather than introducing arbitrary alias resolution or accepted spelling variants.

## TDD Gate Compliance

- **RED:** Commit `2812d297` contains test-only changes. All six target cases independently failed on their behavior assertion with the case-specific vulnerability sentinel.
- **GREEN:** Commit `3979004e` contains the exact-alias implementation and passes the complete CrossWake contract.
- **REFACTOR:** Not needed; the minimal implementation directly replaces four suffix comparisons with complete-alias equality.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first GREEN command proved the full contract (30 tests, 0 failures) but the chained formatter check found one indentation mismatch introduced by the patch. The indentation was corrected, and the complete command then passed. This was normal formatter feedback and did not change behavior or scope.
- The executor could not commit Task 2 because the mandatory linked-worktree guard rejects commits from `resume/v1.18`; the orchestrator recorded the atomic production-only commit as `3979004e`.

## Known Stubs

None.

## Threat Review

- T-a2h-01 is mitigated by exact full-alias matching and six public-boundary mutation tests.
- T-a2h-02 and T-a2h-03 remain unchanged accepted risks; traversal and output paths were not modified.
- No new network, authentication, file-access, schema, or secret-bearing surface was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The CrossWake proof spoofing gap is closed and ready for independent x9g re-verification after the orchestrator records the GREEN commit.

## Self-Check: PASSED

- Both owned implementation files exist.
- RED commit `2812d297` exists and contains only the contract test.
- The requested SUMMARY exists at the quick-task path.
- All automated GREEN evidence passes.
- No tracked files were deleted and no out-of-scope file was modified by this executor.

---
*Quick task: 260913-a2h*
*Completed: 2026-09-13*
