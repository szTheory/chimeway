# Quick 260912-x9g: Release Automation and Proof Semantics - Research

**Researched:** 2026-09-13
**Domain:** GitHub Actions release orchestration, Elixir AST proof contracts, Git repository cleanliness
**Confidence:** HIGH for repository findings; MEDIUM for current hosted-platform behavior

## Summary

This item should remain a bounded hardening pass. The release preflight currently treats every merge commit containing a pull-request number as eligible for "already released" classification; because it then derives `v1.1.1` from the manifest and that GitHub release exists, an ordinary merged PR can skip Release Please without ever proving that the merged PR was the Release Please PR. `[VERIFIED: .github/workflows/release.yml:42-80; .release-please-manifest.json; gh release view v1.1.1 -R szTheory/chimeway]`

The Release Please CI bootstrap has a separate token-path bug. `prs_created` means a release PR was created **or updated**, but the workflow always skips explicit dispatch when it is true. That is correct only for a PAT-backed action whose PR event starts ordinary CI. The action's own documentation recommends a PAT for downstream Release Please PR workflows, while GitHub documents `workflow_dispatch` as an event that always creates a run even when invoked with `GITHUB_TOKEN`; therefore the fallback path must dispatch explicitly. `[CITED: https://github.com/googleapis/release-please-action#outputs] [CITED: https://github.com/googleapis/release-please-action#other-actions-on-release-please-prs] [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow]`

The CrossWake verifier and cleanliness alias each have one narrow semantic gap: the verifier scans the entire focused-test AST without reachability analysis, and `git diff --exit-code` observes only unstaged tracked changes. Use a bounded ExUnit-rooted local call graph for the former and a small executable repository-status guard for the latter. `[VERIFIED: lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex:202-240; mix.exs:85-95]`

**Primary recommendation:** Make release classification identity-first, make CI bootstrap token-aware, make proof calls reachable from ExUnit roots, and replace the cleanliness alias with a tested porcelain-status guard; do not redesign the release topology. `[VERIFIED: .github/workflows/release.yml:27-247; .github/workflows/release-pr-automerge.yml:25-188]`

## Project Constraints (from AGENTS.md)

- Preserve the project value that notification decisions remain explainable. `[VERIFIED: AGENTS.md:3-7]`
- Keep `mix verify.*` and `mix ci.*` entrypoints maintained and keep local/CI scripts in parity. `[VERIFIED: AGENTS.md:25-30]`
- Do not leak sensitive payload fields in telemetry or operator surfaces; by extension, new release diagnostics should print only branch/title/status metadata and never token values. `[VERIFIED: AGENTS.md:25-29]`
- Route these objectively machine-testable contracts to executable evidence, not conversational UAT or human checkpoints. `[VERIFIED: AGENTS.md:30-32]`
- Preserve the locked stack floor: verbatim, `"Elixir 1.17+ / OTP 26+"`. `[VERIFIED: AGENTS.md:9-15]`

## Scope Contract

| ID | Required outcome | Research support |
|---|---|---|
| REL-01 | Ordinary merges cannot be classified as completed releases | Qualify the fetched PR as the exact Release Please branch/base/title before evaluating release labels or manifest-derived tag existence. |
| REL-02 | `GITHUB_TOKEN` fallback still receives deterministic required CI | Explicitly dispatch `ci.yml` for an open release PR when the PAT is absent, including when `prs_created == true`. |
| PROOF-01 | Required detached CrossWake proof calls cannot live only in dead helpers | Count markers only in ExUnit roots and transitively invoked local functions. |
| CLEAN-01 | `mix verify.clean` rejects unstaged, staged, and untracked state | Run a tested `git status --porcelain=v1 --untracked-files=all` guard. |

All four outcomes are release hygiene. No product behavior, database schema, public notification API, dependency, or package version change belongs in this item. `[VERIFIED: .planning/quick-batches/260912-x9e/BATCH.json; .planning/v1.19-MILESTONE-AUDIT.md:88-101]`

## Architectural Responsibility Map

| Capability | Primary tier | Secondary tier | Rationale |
|---|---|---|---|
| Release-merge classification | CI/CD automation | GitHub API | The workflow decides whether Release Please runs; `gh pr view` and `gh release view` supply identity/status facts. `[VERIFIED: .github/workflows/release.yml:42-89]` |
| Release-PR CI bootstrap | CI/CD automation | GitHub Actions dispatch API | The workflow must choose between native PAT-triggered CI and explicit fallback dispatch. `[VERIFIED: .github/workflows/release.yml:91-122]` |
| Detached proof anti-vacuity | Elixir Mix task | Detached CrossWake test execution | Static reachability is a precondition; the real focused test remains the behavioral proof. `[VERIFIED: lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex:119-149,242-260]` |
| Clean worktree proof | Repository script | Mix alias | Git porcelain is the source of truth; `mix verify.clean` remains the stable maintainer entrypoint. `[VERIFIED: mix.exs:85-95; MAINTAINING.md:15-27]` |

## Exact Defects and Lowest-Risk Fixes

### 1. Release preflight classifies by merge syntax before release-PR identity

**Defect.** The current preflight extracts any `"Merge pull request #([0-9]+)"`, reads only labels, then checks whether the manifest-derived tag already has a GitHub release. It never reads or verifies `headRefName`, `baseRefName`, or `title`. The load-bearing current values are verbatim `"release-please--branches--main"`, base `"main"`, title prefix `"chore(main): release "`, labels `"autorelease: pending"` / `"autorelease: tagged"`, and manifest package key `"."`. `[VERIFIED: .github/workflows/release.yml:42-80; .github/workflows/release-pr-automerge.yml:42-55,93-130; release-please-config.json; .release-please-manifest.json]`

**Observed consequence.** The checked-in manifest is `{".": "1.1.1"}` and the public repository has a published `v1.1.1` release. Thus an ordinary GitHub merge commit with a PR number and without `autorelease: tagged` reaches the existing-release branch and emits `should_run=false`. `[VERIFIED: .release-please-manifest.json; gh release view v1.1.1 -R szTheory/chimeway --json tagName,isDraft,isPrerelease,publishedAt,url; .github/workflows/release.yml:52-76]`

**Fix.** Fetch one PR JSON object containing `headRefName,baseRefName,title,labels`. Before either the tagged-label check or the manifest-tag check, require all of:

```text
headRefName == "release-please--branches--main"
baseRefName == "main"
title starts with "chore(main): release "
```

These values are copied verbatim from the workflow that already identifies and merges Release Please PRs. `[VERIFIED: .github/workflows/release-pr-automerge.yml:42-55,93-130]`

If the commit has no parseable PR number, the PR lookup fails, or any identity field differs, set `should_run=true` and exit before reading the manifest-derived tag. Uncertainty should run the idempotent Release Please action; only positively identified already-completed release work should skip it. `[VERIFIED: .github/workflows/release.yml:57-60,82-89]`

**Contract additions.** In `test/chimeway/release_gate_contract_test.exs`, extract the `release-preflight` block and assert:

- the `gh pr view` JSON fields include exact `headRefName`, `baseRefName`, `title`, and `labels`;
- exact branch/base/title checks occur before `expected_tag=` and `gh release view`;
- the non-release/unknown branch writes `should_run=true`;
- only a qualified Release Please PR can reach `autorelease: tagged` or existing-tag skip logic.

The existing root-package and secret-scope contracts should remain unchanged. `[VERIFIED: test/chimeway/release_gate_contract_test.exs:1080-1166]`

### 2. Fresh fallback PR updates skip the only unattended CI dispatch

**Defect.** The current branch is verbatim: `if [ "${PRS_CREATED:-false}" = "true" ]; then ... skipping workflow_dispatch`. The action documents `prs_created` as true when any pull request is **created or updated**, not as proof that a PAT was used or CI started. `[VERIFIED: .github/workflows/release.yml:101-122] [CITED: https://github.com/googleapis/release-please-action#outputs]`

**Fix.** Expose a non-secret boolean in the bootstrap step, for example `RELEASE_PLEASE_TOKEN_CONFIGURED: ${{ secrets.RELEASE_PLEASE_TOKEN != '' }}`. Dispatch `ci.yml` on the exact release branch whenever an open pending release PR exists and either:

```text
RELEASE_PLEASE_TOKEN_CONFIGURED != "true"
or PRS_CREATED != "true"
```

The first clause closes the fallback hole after a fresh create/update. The second preserves the current stale/open-PR recovery dispatch. When both a PAT is configured and the PR was freshly created/updated, native PR CI remains the non-duplicated fast path. `[VERIFIED: .github/workflows/release.yml:91-122] [CITED: https://github.com/googleapis/release-please-action#other-actions-on-release-please-prs]`

GitHub's current documentation says `workflow_dispatch` always creates a workflow run even when initiated with `GITHUB_TOKEN`; it also describes GITHUB_TOKEN-created PR opened/synchronize/reopened runs as approval-required. Explicit dispatch is therefore the deterministic unattended fallback even under the newer platform behavior. `[CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow]`

**Contract additions.** Require the boolean env, the fallback-aware dispatch predicate, the exact branch `"release-please--branches--main"`, and the existing open/pending PR guard. Assert the old unconditional `PRS_CREATED == true -> skipping workflow_dispatch` shape is absent. `[VERIFIED: .github/workflows/release.yml:91-122]`

### 3. CrossWake AST markers are occurrence-based, not reachability-based

**Defect.** `executable_focused_test?/1` calls `remote_call?/3` over the entire source, and both `remote_call?/3` and `worker_perform_call?/1` use `Macro.prewalk` with no execution roots. A private function never called by a test therefore satisfies the static gate. `[VERIFIED: lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex:202-240]`

The pinned real CrossWake proof already has reachable evidence: verbatim `setup_all do ... Code.compile_string(recipe, @readme)`, tests call local `perform/1`, `perform/1` contains `apply(MyApp.Workers.ChimewayProviderFeedbackWorker, :perform, ...)`, and a test directly calls `Redaction.feedback_from_provider_attrs(attrs)`. `[VERIFIED: ../crosswake@36841e065ad4a71b58b80bd599d111c8ee178390:examples/phoenix_host/test/crosswake_example/chimeway/provider_feedback_recipe_test.exs:47-50,58-82,141-172,259-260]`

**Fix.** Parse the focused test once. Build a bounded local call graph:

1. Collect `do` bodies from the ExUnit entry macros `setup`, `setup_all`, and `test` anywhere in the module AST.
2. Index `def` / `defp` bodies by local `{name, arity}`.
3. Start a worklist with only the ExUnit entry bodies.
4. While walking a reachable body, record the exact remote/dynamic proof markers and enqueue local calls whose `{name, arity}` exists in the definition index.
5. Use a `MapSet` of visited `{name, arity}` keys so recursive/cyclic helpers terminate.
6. Pass only when reachable bodies contain `Code.compile_string`, `Redaction.feedback_from_provider_attrs`, and either `Registry.apply_provider_feedback` or `apply(MyApp.Workers.ChimewayProviderFeedbackWorker, :perform, ...)`.

The marker spellings above are the current contract verbatim. `[VERIFIED: lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex:202-240]`

Do not attempt a general Elixir evaluator, expand arbitrary macros, or infer dynamic function names. This verifier owns one pinned focused-test shape, and the subsequent real `mix test` invocation remains required. `[VERIFIED: lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex:119-149,242-260]`

**Contract additions.** Update the in-memory valid fixture to an ExUnit-shaped module with calls in `setup_all` / `test` plus a reachable `perform/1` helper. Add negative fixtures proving:

- all three calls only inside an uncalled `defp dead_helper` fail before `focused_test` executes;
- a reachable helper chain passes;
- removal of any one reachable boundary fails;
- a cyclic local-helper graph terminates and cannot manufacture a pass.

Keep the existing string-only, missing-file, wrong-SHA, dirty-checkout, cleanup, authority-scope, and independent physical-selector tests. `[VERIFIED: test/chimeway/crosswake_provider_feedback_docs_contract_test.exs:48-213]`

### 4. `verify.clean` ignores index and untracked state

**Defect.** The alias is exactly `"verify.clean": ["cmd git diff --exit-code"]`. `git diff` with no `--cached` compares the worktree to the index, so it does not report staged-only changes; it also does not report untracked files. `[VERIFIED: mix.exs:85-95] [CITED: https://git-scm.com/docs/git-diff]`

**Fix.** Add a repository-owned `scripts/ci/verify-clean.sh` and point the existing alias at it. The script should use `set -euo pipefail`, capture `git status --porcelain=v1 --untracked-files=all`, return zero only for empty output, and otherwise emit a concise message plus the porcelain rows. This single source covers unstaged, staged, and untracked states without three partially overlapping commands. `[CITED: https://git-scm.com/docs/git-status#Documentation/git-status.txt---porcelainltversiongt]`

Keep the public entrypoint named verbatim `"verify.clean"`; the maintainer runbook already requires `mix verify.clean` and describes it as confirming that no uncommitted files remain. `[VERIFIED: mix.exs:88-95; MAINTAINING.md:15-27]`

**Contract additions.** Add `test/chimeway/verify_clean_test.exs`. Each case creates its own owned temporary Git repository, commits one baseline file, then invokes the production script with `System.cmd/3` from that repository. Prove:

- clean repository exits 0;
- unstaged tracked edit exits nonzero;
- staged edit exits nonzero;
- untracked nested file exits nonzero;
- ignored files do not fail (`--untracked-files=all` still honors standard ignore rules).

The test must clean only its uniquely allocated temp root in `on_exit`; it must not mutate the real worktree. `[VERIFIED: test/chimeway/crosswake_provider_feedback_docs_contract_test.exs:9-24,270-278 — existing owned-temp test pattern]`

## Recommended File Scope

| File | Change |
|---|---|
| `.github/workflows/release.yml` | Identity-first release preflight and token-aware release-PR CI dispatch. |
| `test/chimeway/release_gate_contract_test.exs` | Structural ordering/identity/fallback contracts for release workflow. |
| `lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex` | Replace whole-AST occurrence checks with ExUnit-rooted reachability. |
| `test/chimeway/crosswake_provider_feedback_docs_contract_test.exs` | ExUnit-shaped valid fixture plus dead/reachable/cyclic helper tests. |
| `scripts/ci/verify-clean.sh` | New executable porcelain-status guard. |
| `mix.exs` | Route `verify.clean` to the guard, preserving alias name. |
| `test/chimeway/verify_clean_test.exs` | Behavior tests for all repository-state classes. |

`MAINTAINING.md` copy updates belong to sibling quick item `260912-x9h`; this item should only preserve its existing `mix verify.clean` interface. `[VERIFIED: .planning/quick-batches/260912-x9e/BATCH.json; MAINTAINING.md:15-27]`

## Implementation Order

1. Add failing release workflow contracts, then patch `release.yml` and run `actionlint`.
2. Add dead-helper/reachable-helper tests, then implement AST reachability and run the focused CrossWake contract.
3. Add clean-state behavior tests, then add the script and redirect the alias.
4. Run the combined focused suite, formatting/lint checks, then the canonical `mix ci.verify_gates` aggregate.

This order isolates failures by seam and leaves the expensive detached/package aggregate until local contracts are green. `[VERIFIED: mix.exs:127-139; lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex:242-260]`

## Validation Architecture

| Concern | Automated command | Expected evidence |
|---|---|---|
| Release workflow structure | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --exclude adoption_paths_e2e --exclude accrue_packaged_cli --warnings-as-errors` | New preflight identity and fallback dispatch contracts pass. |
| Workflow syntax/security lint | `actionlint .github/workflows/release.yml .github/workflows/release-pr-automerge.yml .github/workflows/ci.yml` | Zero diagnostics. |
| Reachability unit contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/crosswake_provider_feedback_docs_contract_test.exs --warnings-as-errors` | Dead helper rejected; reachable helper accepted. |
| Real detached CrossWake proof | `mix verify.crosswake_provider_feedback_docs` | Exact selected SHA is checked out cleanly and the focused proof passes. |
| Cleanliness behavior | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/verify_clean_test.exs --warnings-as-errors` | Clean/unstaged/staged/untracked/ignored cases behave exactly. |
| Formatting | `mix format --check-formatted` | Zero formatting drift. |
| Canonical release gate | `mix ci.verify_gates` | Contract subset, packaged Accrue proof, and detached CrossWake proof all pass. |

Do not run `mix verify.clean` as the final command until the quick-batch artifacts themselves are committed, because its purpose is to reject exactly that uncommitted state. `[VERIFIED: MAINTAINING.md:15-27]`

## Common Pitfalls

### Checking tag existence before PR identity

**Failure:** A published current manifest tag is mistaken for proof that the just-merged PR was a completed release PR. **Prevention:** qualify head/base/title first; on uncertainty run Release Please. `[VERIFIED: .github/workflows/release.yml:42-80]`

### Treating `prs_created` as token provenance

**Failure:** A fallback-token PR update skips dispatch even though `prs_created` says nothing about which token created it. **Prevention:** branch explicitly on whether `RELEASE_PLEASE_TOKEN` is configured. `[VERIFIED: .github/workflows/release.yml:101-122] [CITED: https://github.com/googleapis/release-please-action#outputs]`

### Counting definitions as executions

**Failure:** `Macro.prewalk` finds load-bearing calls in unreachable functions. **Prevention:** roots plus transitive local calls, followed by actual focused-test execution. `[VERIFIED: lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex:119-149,202-260]`

### Replacing AST proof with test success alone

**Failure:** A passing focused file can stop exercising the documented recipe while retaining unrelated green tests. **Prevention:** keep both static reachable-marker proof and runtime focused execution. `[VERIFIED: lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex:119-149]`

### Using only `git diff` variants

**Failure:** staged-only or untracked artifacts survive a supposedly clean release checkout. **Prevention:** use porcelain status including all untracked paths and behavior-test it in owned temp repos. `[VERIFIED: mix.exs:88-95] [CITED: https://git-scm.com/docs/git-status#Documentation/git-status.txt---porcelainltversiongt]`

## Security Domain

| Threat | Category | Control |
|---|---|---|
| Crafted ordinary PR suppresses release processing | Tampering | Exact head/base/title identity must precede release-complete checks; lookup failure runs rather than skips. |
| Fallback-token automation bypasses required checks | Tampering / Repudiation | Explicit `workflow_dispatch` on the exact release branch and existing `ci-gate` SHA enforcement. `[VERIFIED: .github/workflows/release-pr-automerge.yml:66-93,129-146]` |
| Dead code fabricates detached proof | Tampering | Reachability from ExUnit roots plus actual pinned focused execution. |
| Generated or staged artifact escapes clean-release proof | Tampering | Porcelain guard covers index, worktree, and untracked files. |
| Secret disclosure in diagnostics | Information disclosure | Compute only a boolean for PAT presence; never print `RELEASE_PLEASE_TOKEN`, `GITHUB_TOKEN`, or `HEX_API_KEY`. Preserve existing publish-step-only HEX scoping. `[VERIFIED: .github/workflows/release.yml:6-8,17-21,82-89,243-247; test/chimeway/release_gate_contract_test.exs:1120-1135]` |

ASVS authentication/session/cryptography categories are not applicable to this code/config-only CI hardening. Access control is applicable only through GitHub token permissions; preserve the current explicit workflow/job permissions and do not add scopes. `[VERIFIED: .github/workflows/release.yml:17-21,96-100,248-249; .github/workflows/ci.yml:36-43]`

## Environment Availability

| Dependency | Available | Version observed | Use |
|---|---:|---|---|
| Elixir / Mix | yes | 1.19.5 / OTP 27 | Compile and execute contract tests. |
| Git | yes | 2.50.1 | Cleanliness behavior fixtures and detached proof. |
| Bash | yes | GNU bash 3.2.57 | Repository cleanliness guard; avoid Bash 4-only features. |
| `actionlint` | yes | 1.7.12 | Static GitHub Actions validation. |
| GitHub CLI | yes | 2.95.0 | Workflow runtime and read-only live release verification. |

All versions above were probed in this worktree on 2026-09-13. `[VERIFIED: local command probes]`

## Assumptions Log

| # | Claim | Risk if wrong |
|---|---|---|
| A1 | A boolean PAT-presence env expression is accepted by the repository's GitHub Actions runner exactly as written. `[ASSUMED]` | `actionlint` may pass while runtime expression typing differs; represent it as a string env and compare to `"true"`. |
| A2 | The bounded call-graph walker need only support ordinary local calls by exact name/arity, not arbitrary macro expansion or dynamic local apply. `[ASSUMED]` | A future pinned CrossWake test could change shape; the real aggregate will fail closed and require an intentional verifier update. |

## Sources

### Primary repository evidence (HIGH confidence)

- `.github/workflows/release.yml` — release preflight, token fallback, CI bootstrap, release SHA gate, Hex publish.
- `.github/workflows/release-pr-automerge.yml` — canonical release branch/title/label identity and exact-SHA `ci-gate` enforcement.
- `lib/mix/tasks/verify.crosswake_provider_feedback_docs.ex` — whole-AST marker scan and real focused-test execution.
- `test/chimeway/crosswake_provider_feedback_docs_contract_test.exs` — current mutation contracts and fixture pattern.
- `mix.exs` and `MAINTAINING.md` — stable `verify.clean` interface and present implementation.
- `.planning/v1.19-MILESTONE-AUDIT.md` — accepted milestone status and bounded stabilization debt.
- Adjacent CrossWake checkout at selected revision `36841e065ad4a71b58b80bd599d111c8ee178390` — actual focused-test reachability shape.

### Official external documentation (MEDIUM confidence)

- https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow — `GITHUB_TOKEN` recursion rules and dispatch exceptions.
- https://github.com/googleapis/release-please-action#other-actions-on-release-please-prs — PAT recommendation for downstream workflows.
- https://github.com/googleapis/release-please-action#outputs — `prs_created` semantics.
- https://git-scm.com/docs/git-status — stable porcelain status contract.
- https://git-scm.com/docs/git-diff — worktree/index comparison semantics.

## Metadata

**Confidence breakdown:**

- Exact defects: HIGH — source paths were opened and the ordinary-merge consequence was confirmed against the live current release.
- Lowest-risk implementation: HIGH — it preserves existing topology and changes only decision predicates, proof reachability, and repository-state detection.
- Hosted GitHub token behavior: MEDIUM — current official GitHub and Release Please documentation differs in wording around GITHUB_TOKEN-created PR events, but both support explicit `workflow_dispatch` as the deterministic fallback.

**Valid until:** 2026-10-13 for repository details; re-check GitHub token/event documentation if implementation occurs after that date.
