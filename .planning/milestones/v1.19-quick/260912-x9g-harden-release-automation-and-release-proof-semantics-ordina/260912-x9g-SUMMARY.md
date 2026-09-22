---
phase: 260912-x9g-release-hardening
plan: 01
subsystem: release-infrastructure
tags: [github-actions, release-please, elixir-ast, git, security]
requires:
  - phase: 104-provider-feedback-recipe-truth
    provides: pinned detached CrossWake documentation proof
  - phase: 60.1-release-automation
    provides: Release Please and Hex publication topology
provides:
  - identity-first release suppression and token-aware release-PR CI bootstrap
  - ExUnit-rooted cycle-safe CrossWake proof reachability
  - complete Git index/worktree/untracked cleanliness verification
affects: [release, ci, crosswake-proof, maintainer-workflow]
actuals:
  tokens: 10649
  tasks: 3
  commits: 7
tech-stack:
  added: []
  patterns:
    - fail-open idempotent release execution under uncertain merge metadata
    - declaration-rooted bounded AST reachability with exact local call keys
    - porcelain-v1 repository cleanliness as a single source of truth
key-files:
  created:
    - scripts/ci/verify-clean.sh
    - test/chimeway/verify_clean_test.exs
  modified:
    - .github/workflows/release.yml
    - lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex
    - mix.exs
    - test/chimeway/release_gate_contract_test.exs
    - test/chimeway/crosswake_provider_feedback_docs_contract_test.exs
key-decisions:
  - "Only exact Release Please PR identity may reach already-tagged or already-published suppression; uncertain metadata runs the idempotent action."
  - "Shell release bootstrap receives only PAT-presence state, never the release token, and explicitly dispatches exact-branch CI when native PR events are not sufficient."
  - "Detached proof markers count only from genuine ExUnit declarations and exact reachable local definitions; quote, fn, captures, and dead helpers are pruned."
patterns-established:
  - "GitHub workflow authority contracts extract named jobs and steps before asserting permissions and secret placement."
  - "Temporary Git-state tests allocate one immediate child of System.tmp_dir!() and guard recursive cleanup by exact path shape and lstat type."
requirements-completed: []
coverage:
  - id: D1
    description: Exact Release Please identity, token-aware CI dispatch, least privilege, and step-scoped secrets
    verification:
      - kind: integration
        ref: test/chimeway/release_gate_contract_test.exs#release workflow decision and authority boundaries
        status: pass
      - kind: other
        ref: actionlint .github/workflows/release.yml .github/workflows/release-pr-automerge.yml .github/workflows/ci.yml
        status: pass
    human_judgment: false
  - id: D2
    description: Detached CrossWake markers are accepted only from rooted reachable executable bodies
    verification:
      - kind: unit
        ref: test/chimeway/crosswake_provider_feedback_docs_contract_test.exs
        status: pass
      - kind: integration
        ref: mix verify.crosswake_provider_feedback_docs
        status: pass
    human_judgment: false
  - id: D3
    description: verify.clean covers staged, unstaged, untracked, ignored, and clean Git states
    verification:
      - kind: integration
        ref: test/chimeway/verify_clean_test.exs
        status: pass
      - kind: other
        ref: mix verify.clean
        status: pass
    human_judgment: false
duration: 1h 30m
completed: 2026-09-13
status: complete
---

# Quick 260912-x9g: Release Automation and Proof Semantics Summary

**Release decisions now require positive identity and exact authority, detached proof markers require executable reachability, and repository cleanliness covers every Git state.**

## Performance

- **Duration:** 1h 30m
- **Completed:** 2026-09-13
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Release Please suppression now occurs only after exact head branch, base branch, title prefix, and well-formed PR metadata are established; uncertain inputs run the idempotent action.
- Release-PR CI bootstrap distinguishes PAT-backed fresh updates from fallback/stale paths without exposing token values, broadening permissions, or moving Hex credentials.
- CrossWake static proof scans real module/describe ExUnit roots and a bounded, cycle-safe exact local call graph while pruning dead, quoted, and anonymous code.
- `mix verify.clean` now delegates to an executable porcelain-v1 guard proven against clean, staged, unstaged, nested-untracked, and ignored states.

## Task Commits

1. **Release workflow RED contract** — `9ebff01e`
2. **Identity-first release workflow and token-aware CI bootstrap** — `379c1090`
3. **CrossWake reachability RED contract** — `839afc7b`
4. **ExUnit-rooted CrossWake reachability implementation** — `7857bea6`
5. **Repository cleanliness RED behavior contract** — `dfc5d12a`
6. **Porcelain-v1 cleanliness guard and Mix alias** — `320526ab`
7. **Expanded destructive mutation matrix** — `2939d231`

## Verification

- Release hardening focus: 3 tests, 0 failures; destructive identity, fail-open, dispatch, permission transplant, release-token relocation, and Hex-token placement mutations all rejected.
- CrossWake contract: 24 tests, 0 failures, including passing and failing cyclic graphs, multi-hop helpers, false roots, and real focused-execution gating.
- Cleanliness contract: 7 tests, 0 failures in isolated real Git repositories.
- Combined focused contract replay: 194 tests, 0 failures before the final mutation-matrix expansion; all added assertions subsequently passed in their focused suites.
- `actionlint` reported zero diagnostics for all three release/CI workflows.
- `mix verify.crosswake_provider_feedback_docs` returned `crosswake_provider_feedback_docs_verified` against the selected detached SHA.
- `mix format --check-formatted` passed.
- `mix verify.clean` returned `verify.clean: clean` after all implementation commits.
- Aggregate constituents passed: `ci.verify_contracts` completed 661 tests with 0 failures; `ci.verify_accrue_package` completed 3 tests with 0 failures; `ci.crosswake_provider_feedback_docs` passed independently.

## Decisions Made

- Preserve the existing release topology and public Mix entrypoints; harden only the decision and evidence seams.
- Combine roots and local definitions only within the same `defmodule`, preventing proof markers from being assembled across unrelated modules.
- Prune function captures in addition to explicit `fn` and `quote` forms because an uninvoked capture is not executable proof.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Isolated dependency and build paths for nested package fixtures**

- **Found during:** Task 1 full replay
- **Issue:** Exporting a shared absolute `MIX_DEPS_PATH` let nested consumer fixtures overwrite the root dependency checkout with their own lock graph.
- **Fix:** Used an isolated executor worktree with its own lock-pinned dependency/build state and no inherited Mix path during nested fixture runs.
- **Files modified:** None
- **Verification:** Two full release-contract replays passed with 165 tests and 0 failures.

**2. [Rule 2 - Security completeness] Pruned uninvoked function captures**

- **Found during:** Task 2 reachable-expression implementation
- **Issue:** The plan named `fn` and `quote`; function captures are the same non-executed proof surface unless invoked.
- **Fix:** Pruned `&` capture AST alongside `fn` and `quote`.
- **Files modified:** `lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex`
- **Verification:** CrossWake contract passed 24 tests with 0 failures.

**Total deviations:** 2 auto-fixed (1 blocking isolation issue, 1 security-completeness fix). No topology or public API scope expansion.

## Issues Encountered

- The monolithic `mix ci.verify_gates` command crossed the repository's configured 900-second test-gate timeout while serially running its packaged-consumer lane, after `ci.verify_contracts` had passed 661 tests. It was stopped at the timeout boundary. The unfinished constituent was then run directly (`mix ci.verify_accrue_package`: 3 tests, 0 failures), and the final CrossWake constituent had already passed directly. This provides complete constituent evidence without treating an over-time aggregate process as green.

## Known Stubs

None.

## Threat Review

- T-x9g-01 through T-x9g-06 are mitigated by passing mutation or behavior evidence.
- No new endpoint, schema, authentication surface, or broader credential authority was introduced.

## User Setup Required

None.

## Self-Check: PASSED

- All seven declared implementation/test files exist.
- All seven task commits exist on `agent-qb-x9g` in the order listed above.
- The implementation worktree is clean and the summary is intentionally uncommitted in the shared quick-batch planning directory.

---
*Quick: 260912-x9g*
*Completed: 2026-09-13*
