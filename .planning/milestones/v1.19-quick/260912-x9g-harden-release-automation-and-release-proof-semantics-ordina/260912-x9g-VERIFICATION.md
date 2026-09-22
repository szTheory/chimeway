---
phase: 260912-x9g-release-hardening
verified: 2026-09-13T12:11:10Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - .github/workflows/ci.yml
  - .github/workflows/release-pr-automerge.yml
  - .github/workflows/release.yml
  - .planning/quick/260912-x9g-harden-release-automation-and-release-proof-semantics-ordina/260912-x9g-PLAN.md
  - .planning/quick/260912-x9g-harden-release-automation-and-release-proof-semantics-ordina/260912-x9g-RESEARCH.md
  - .planning/quick/260912-x9g-harden-release-automation-and-release-proof-semantics-ordina/260912-x9g-SUMMARY.md
  - .planning/quick/260913-a2h-reject-prefix-spoofed-crosswake-aliases-/260913-a2h-PLAN.md
  - .planning/quick/260913-a2h-reject-prefix-spoofed-crosswake-aliases-/260913-a2h-SUMMARY.md
  - .planning/quick/260913-a2h-reject-prefix-spoofed-crosswake-aliases-/260913-a2h-VERIFICATION.md
  - .planning/quick/260913-b0l-accept-only-the-real-fully-qualified-det/260913-b0l-PLAN.md
  - .planning/quick/260913-b0l-accept-only-the-real-fully-qualified-det/260913-b0l-SUMMARY.md
  - .planning/quick/260913-b0l-accept-only-the-real-fully-qualified-det/260913-b0l-VERIFICATION.md
  - lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex
  - mix.exs
  - priv/adoption/crosswake-provider-feedback-docs-selected-sha
  - priv/mobile_proof/crosswake-selected-sha
  - scripts/ci/verify-clean.sh
  - test/chimeway/crosswake_provider_feedback_docs_contract_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - test/chimeway/verify_clean_test.exs
covered_digest: "v1:sha256:99f6387260c92e5cfd0c26236c9232ad12518dbbb1c46c96bae7d8f94be1e67d"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "Prefix-spoofed focused and README aliases are rejected by complete context-specific identities."
    - "The selected SHA's legitimate fully qualified README calls are accepted again."
    - "The real detached CrossWake constituent exits zero and emits its stable marker."
  gaps_remaining: []
  regressions: []
---

# Quick 260912-x9g: Release Automation and Proof Semantics Verification Report

**Goal:** Close the release-readiness false-positive paths while preserving release topology and public maintainer entrypoints.
**Verified:** 2026-09-13T12:11:10Z
**Status:** passed
**Re-verification:** Yes — after repairs 260913-a2h and 260913-b0l

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Ordinary, unparseable, and lookup-failed merges cannot be mistaken for an already completed Release Please release. | ✓ VERIFIED | `.github/workflows/release.yml:52-110` defaults uncertain cases to `should_run=true` and requires exact head/base/title identity before tagged-label or manifest-tag suppression. Current `:release_hardening` replay: 3 tests, 0 failures. |
| 2 | Pending Release Please PRs receive deterministic CI on PAT and fallback paths without duplicate PAT dispatch. | ✓ VERIFIED | `.github/workflows/release.yml:121-155` dispatches exact-branch `ci.yml` when a pending PR exists and PAT is absent or the update is stale, while the PAT/fresh branch avoids duplicate dispatch. Predicate mutations passed. |
| 3 | Detached proof markers are exact required calls reachable from genuine ExUnit roots through a bounded local graph, followed by the real pinned proof. | ✓ VERIFIED | Root, pruning, local reachability, cycle, missing-marker, exact-alias, and focused-execution contracts all pass. README identities are exact full paths; focused identities remain exact one-segment imports; worker identity is exact. Real selected-SHA gate exited zero with `crosswake_provider_feedback_docs_verified`. |
| 4 | `mix verify.clean` distinguishes clean, unstaged, staged, untracked, and ignored repository states. | ✓ VERIFIED | The public alias invokes the executable porcelain-v1 guard. Current replay: 7 tests, 0 failures in owned temporary Git repositories. |
| 5 | Exact permission maps and exact release/Hex secret placement are mutation-locked. | ✓ VERIFIED | Workflow permissions remain exactly `contents/pull-requests/issues/actions: write`; bootstrap is exactly `actions: write, contents: read, pull-requests: read`; publish is exactly `contents: read`. Release fallback expression count is 1, PAT-presence expression count is 1, and `HEX_API_KEY` count is 2 in only the dry-run/live step envs. Mutation group and actionlint pass. |

**Score:** 5/5 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `.github/workflows/release.yml` | Identity-first release preflight and token-aware bootstrap | ✓ VERIFIED | Exists, substantive, actionlint-clean, wired into release and bootstrap jobs. |
| `test/chimeway/release_gate_contract_test.exs` | Region-scoped release mutation contracts | ✓ VERIFIED | Current focused group passes 3/3 and destructively checks identity, dispatch, permissions, and secrets. |
| `lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex` | Exact, rooted, cycle-safe detached proof | ✓ VERIFIED | README validation uses exact selected-source full aliases; focused scanner uses separate exact aliases and exact worker path; real detached gate passes. |
| `test/chimeway/crosswake_provider_feedback_docs_contract_test.exs` | Production-shaped positive fixture and adversarial graph/alias coverage | ✓ VERIFIED | Selected README fixture mirrors the authority; 30 active tests cover roots, helpers, cycles, false roots, spoofing, authority, checkout, cleanup, and execution. |
| `scripts/ci/verify-clean.sh` | Porcelain-v1 cleanliness guard | ✓ VERIFIED | Executable; one `git status --porcelain=v1 --untracked-files=all` source; no cleaning side effects. |
| `test/chimeway/verify_clean_test.exs` | Real repository-state behavior proof | ✓ VERIFIED | Seven active tests use guarded, immediate-child temporary repositories. |
| `mix.exs` | Stable aliases and aggregate wiring | ✓ VERIFIED | `verify.clean` invokes the guard; `ci.verify_gates` remains exactly the three expected serial constituents. |

**Artifacts:** 7/7 verified

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Release contract test | `release.yml` | Extracted regions and destructive mutations | ✓ WIRED | Current group passes and reads production workflow text. |
| `release.yml` | `ci.yml` | Exact release-branch dispatch | ✓ WIRED | Dispatch command remains within the token-aware pending-PR predicate. |
| CrossWake contract test | CrossWake verifier | Public `verify/1`, verdict, and focused-execution signal | ✓ WIRED | Positive case requires `{:ok, true}`; every hostile case requires `{:error, false}`. |
| CrossWake verifier | Selected CrossWake SHA | Authority → checkout → source contract → focused proof | ✓ WIRED | Independent real alias run emits the stable marker and exits zero. |
| `mix.exs` | `verify-clean.sh` | Stable public alias | ✓ WIRED | Exact alias contract passes. |
| Verify-clean test | `verify-clean.sh` | `System.cmd/3` in isolated Git repositories | ✓ WIRED | All relevant Git states are exercised. |

### Data-Flow Trace

| Artifact | Input | Flow | Status |
|---|---|---|---|
| Release preflight | Merge message + one PR JSON object | Exact identity → qualified tag checks → `should_run` | ✓ FLOWING |
| CI bootstrap | Pending count + PAT-presence boolean + `prs_created` | Predicate → exact-ref dispatch/native CI | ✓ FLOWING |
| CrossWake README proof | Authority-selected recipe AST | Exact full aliases → source contract | ✓ FLOWING |
| CrossWake focused proof | Authority-selected test AST | ExUnit roots → bounded reachable graph → exact markers → real focused execution | ✓ FLOWING |
| Cleanliness guard | Git porcelain rows | Empty/non-empty decision → exit status and evidence rows | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Release identity/dispatch/authority mutations | Release contract with `--only release_hardening` | 3 tests, 0 failures | ✓ PASS |
| Full local CrossWake + cleanliness contracts | `... mix test crosswake_provider_feedback_docs_contract_test.exs verify_clean_test.exs --warnings-as-errors` | 37 tests, 0 failures | ✓ PASS |
| All planned alias spoofs | CrossWake contract `:exact_alias_identity` cases within full replay | 6 cases passed | ✓ PASS |
| Full-path README Redaction prefix | Public `verify/1` with `Evil.Crosswake.Companions.Chimeway.Redaction` | `{:error, false}` | ✓ PASS |
| Full-path README Registry prefix | Public `verify/1` with `Evil.CrosswakeExample.Chimeway.Registry` | `{:error, false}` | ✓ PASS |
| Real selected-SHA proof | `mix ci.crosswake_provider_feedback_docs` | Exit 0; `crosswake_provider_feedback_docs_verified` | ✓ PASS |
| Workflow syntax and formatting | `actionlint ...` plus `mix format --check-formatted` | Exit 0; zero diagnostics | ✓ PASS |

### Expensive Constituent Evidence and Aggregate Timeout

The earlier monolithic `mix ci.verify_gates` invocation timed out at 900 seconds and is **not** reported as green.

Independent evidence remains complete for the aggregate's exact three constituents:

- `ci.verify_contracts`: 661 tests, 0 failures in 520.4 seconds from the x9g verification.
- `ci.verify_accrue_package`: 3 tests, 0 failures in 554.5 seconds from the x9g verification.
- `ci.crosswake_provider_feedback_docs`: rerun after both repairs; exit zero with `crosswake_provider_feedback_docs_verified`.

An ancestry/diff check proves x9g commit `f52064b5` is an ancestor of the current head and only the CrossWake verifier plus its dedicated contract test changed among x9g's relevant files. Release workflow/contracts, cleanliness files, `mix.exs`, and aggregate composition are unchanged. The changed constituent was rerun; the unchanged expensive constituent evidence is retained. The first two independent runs alone totaled 1,074.9 seconds, explaining the previous 900-second serial-wrapper timeout without converting that invocation into a pass.

### Probe Execution

No standalone probe scripts are declared. The real detached Mix task is the authoritative executable proof and passed.

### Requirements Coverage

This quick item maps no formal IDs in `.planning/REQUIREMENTS.md`.

| Contract | Status | Evidence |
|---|---|---|
| D1: exact release identity, dispatch, permissions, and secrets | ✓ SATISFIED | Current mutation replay, exact counts, and actionlint pass. |
| D2: rooted, exact, real detached CrossWake proof | ✓ SATISFIED | Local contract and selected-SHA detached proof both pass; stronger full-prefix probes fail closed. |
| D3: complete Git-state cleanliness | ✓ SATISFIED | Current seven-test behavior replay passes. |

### Test Quality Audit

| Test File | Linked Contract | Active | Skipped | Circular | Assertion Level | Verdict |
|---|---|---:|---:|---:|---|---|
| `test/chimeway/release_gate_contract_test.exs` (`:release_hardening`) | D1 | 3 | 0 | 0 | Destructive mutation / exact value | PASS |
| `test/chimeway/crosswake_provider_feedback_docs_contract_test.exs` | D2 | 30 | 0 | 0 | Behavioral public-verifier and real detached backstop | PASS |
| `test/chimeway/verify_clean_test.exs` | D3 | 7 | 0 | 0 | Behavioral real-Git state transitions | PASS |

**Disabled tests on contracts:** 0  
**Circular patterns detected:** 0  
**Insufficient assertions:** 0

### Anti-Patterns Found

No unreferenced TBD/FIXME/XXX markers, disabled contract tests, suffix-based alias matching, stubs, or hollow wiring were found in the changed x9g surfaces.

### Decision Coverage

No CONTEXT.md exists for x9g; there are no separate context decisions to check.

### Human Verification Required

N/A — release/CI infrastructure with entirely machine-testable acceptance criteria. No human UAT applies.

## Gaps Summary

No gaps. Release decisions are identity-first and token-aware, authority and secret scopes are exact, the CrossWake proof is rooted and spoof-resistant while accepting its real selected source, and repository cleanliness covers all required Git states. The earlier timed-out aggregate remains transparently non-green, with complete independent constituent evidence recorded instead.

---

_Verified: 2026-09-13T12:11:10Z_  
_Verifier: the agent (gsd-verifier)_
