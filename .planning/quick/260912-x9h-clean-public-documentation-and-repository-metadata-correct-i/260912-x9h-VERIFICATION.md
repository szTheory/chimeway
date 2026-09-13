---
phase: 260912-x9h
verified: 2026-09-13T13:06:42Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - .github/workflows/release.yml
  - .planning/quick/260912-x9h-clean-public-documentation-and-repository-metadata-correct-i/260912-x9h-PLAN.md
  - .planning/quick/260912-x9h-clean-public-documentation-and-repository-metadata-correct-i/260912-x9h-RESEARCH.md
  - .planning/quick/260912-x9h-clean-public-documentation-and-repository-metadata-correct-i/260912-x9h-SUMMARY.md
  - AGENTS.md
  - MAINTAINING.md
  - README.md
  - SECURITY.md
  - chimeway_inbox/lib/chimeway_inbox/auth.ex
  - examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs
  - guides/flows/multi-step-journeys.md
  - guides/introduction/inbox-integration.md
  - guides/recipes/feedback-escalation-workflow.md
  - guides/recipes/password-reset-support-trace.md
  - lib/chimeway/delivery_target.ex
  - lib/chimeway/delivery_target_attempt.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/target_resolver.ex
  - lib/mix/tasks/demo.up.ex
  - mix.exs
  - scripts/ci/verify-clean.sh
  - test/chimeway/doc_contract_test.exs
  - test/chimeway/integration/readme_snippet_test.exs
covered_digest: "v1:sha256:46bf67823e9762047ed60200c938c8d8972255d3236da304f14fe1ef7f686eeb"
deleted_files:
  - GSD-CONTEXT.md
  - guides/flows/trigger-to-delivery.md
  - guides/flows/async-dispatch.md
  - guides/flows/policy-and-preferences.md
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "Demo.Up focused tests now call the public helper directly and pass 2/2 without relying on incidental module loading."
    - "The exact retained JOUR-05 demo.up --check smoke passes 1/1 through the isolated database wrapper."
    - "Public delivery-target types are documented and mix ci.docs exits zero without warnings."
  gaps_remaining: []
  regressions: []
residuals:
  - finding: "The broader mix verify.journeys alias remains red in 7 of 11 older tests."
    scope: "outside x9h's changed Demo.Up checkout-boundary behavior"
    evidence: "Current supplied replay reports pre-existing tenant-scoping, seed-isolation, and background ownership failures; the x9h-owned JOUR-05 consumer passes independently."
---

# Quick 260912-x9h: Public Documentation and Repository Truth Verification Report

**Goal:** Finish the highest-value release-facing documentation and repository-tooling truth within a strict 15-path cap.
**Verified:** 2026-09-13T13:06:42Z
**Status:** passed
**Re-verification:** Yes — after bounded gap correction

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | README shows the runnable WelcomeUser callbacks exercised by `Chimeway.ReadmeSnippetTest`, including `rendering/2`. | ✓ VERIFIED | README and its executable fixture are unchanged since the prior pass. README defines all five callbacks and matching stable values. The current Task 1 evidence remains 501 tests, 0 failures. |
| 2 | The inbox guide matches the current dependency and map-shaped auth callbacks while retaining authorization and opaque-reload boundaries. | ✓ VERIFIED | Guide and source are unchanged since the prior pass. Version-derived dependency, map arguments, independent tenant/recipient authorization, opaque identity, secret custody, and reload reauthorization remain present and contract-locked. |
| 3 | Current public Markdown uses the canonical owner, retired placeholder guides are absent, and nothing public links to them. | ✓ VERIFIED | All four deletions remain absent, and the previously verified canonical-owner, retired-basename, placeholder, and tracked-relative-link checks have no regression. Only the already authorized Demo test changed after the original x9h boundary. |
| 4 | `demo.up` validates its source-checkout path before side effects and retains the real journey smoke. | ✓ VERIFIED | Production ordering remains unchanged: root validation occurs first and the single validated child is reused. Commit `419297e6` removes test preload dependence; independent focused replay passes 2/2. The exact x9h-owned `JOUR-05 mix demo.up --check` smoke passes 1/1 with 33 exclusions through the isolated database wrapper. |
| 5 | MAINTAINING matches hardened release/token/clean-tree behavior, AGENTS delegates to STATE/ROADMAP, and obsolete bootstrap context is absent. | ✓ VERIFIED | These files are unchanged since the prior pass. The supplied exact planned release-facing group remains 676 tests, 0 failures, 4 excluded; AGENTS retains durable pointers and `GSD-CONTEXT.md` remains absent. |

**Score:** 5/5 truths verified (0 present but behavior-unverified)

## Re-verification of Prior Gaps

| Prior gap | Current evidence | Status |
|---|---|---|
| Demo focused tests depended on prior module loading | Tests now directly invoke `Mix.Tasks.Demo.Up.demo_host_path!/1`; independent current run is 2 tests, 0 failures, 1 journey excluded | ✓ CLOSED |
| Retained Demo.Up journey was red | Exact `JOUR-05` isolated run is 1 test, 0 failures, 33 excluded | ✓ CLOSED |
| HexDocs failed on public/private type references | `DeliveryTarget.t/0` and `DeliveryTargetAttempt.t/0` exist; `BindingRevision` is documented; independent `mix ci.docs` exits 0 with no warnings | ✓ CLOSED |

No previously passing truth regressed.

## Scope Verification

| Expected | Actual | Status |
|---|---|---|
| 15 unique x9h implementation paths | 15 unique paths across the original three task commits | ✓ VERIFIED |
| 11 modified | 11 modified | ✓ VERIFIED |
| 4 deleted | 4 deleted | ✓ VERIFIED |

The original x9h boundary is unchanged. Repair commit `419297e6` touches only the already authorized Demo.Up test path. Commit `2f3bd762` is a separate low-hanging public-type documentation cleanup that closes the repository docs gate; it is not counted as an x9h implementation-path expansion.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `README.md` | Complete notifier snippet | ✓ VERIFIED | Substantive and contract-bound to the passing runtime fixture. |
| `guides/introduction/inbox-integration.md` | Current dependency, callback type, privacy, and reload guidance | ✓ VERIFIED | Matches root version and `ChimewayInbox.Auth`; security boundaries remain. |
| `test/chimeway/doc_contract_test.exs` | Executable public-doc drift contracts | ✓ VERIFIED | Current Task 1 and Task 3 evidence is green. |
| `lib/mix/tasks/demo.up.ex` | Fail-fast source-checkout boundary | ✓ VERIFIED | Guard executes before Ecto/application/subprocess work; exact consumer smoke passes. |
| `MAINTAINING.md` | Hardened release/operator truth | ✓ VERIFIED | Exact identity, fallback dispatch, PAT behavior, and complete dirty-state semantics remain contract-locked. |
| `AGENTS.md` | Durable planning pointers | ✓ VERIFIED | References STATE and ROADMAP without copied changing phase state. |

The current artifact query reports 6/6 passed.

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| README | Executable WelcomeUser fixture | Callback/value contract plus integration execution | ✓ WIRED | Unchanged and covered by current 501-test evidence. |
| Inbox guide | `ChimewayInbox.Auth` | Version-derived dependency and map-shaped callback prose | ✓ WIRED | Guide and callback signatures agree. |
| Demo.Up | Demo host child | Active project root, validated once, reused by nested commands | ✓ WIRED | Focused boundary tests and exact JOUR-05 both pass. |
| MAINTAINING | Release workflow and clean-tree script | Contracted behavior wording | ✓ WIRED | Current 676-test evidence remains green. |

The current key-link query reports 4/4 verified.

## Behavioral and Gate Evidence

| Behavior / Gate | Evidence | Result | Status |
|---|---|---|---|
| README/public docs focused suite | Supplied current Task 1 run | 501 tests, 0 failures | ✓ PASS |
| Demo focused unit contract | Independent current nested test run with `--exclude journey --warnings-as-errors` | 2 tests, 0 failures; 1 excluded | ✓ PASS |
| Exact retained Demo.Up smoke | Supplied isolated `JOUR-05` run through `scripts/test-db` | 1 test, 0 failures; 33 excluded | ✓ PASS |
| Maintainer/agent/release-facing group | Supplied exact planned Task 3 run | 676 tests, 0 failures; 4 excluded | ✓ PASS |
| HexDocs build | Independent current `mix ci.docs` | Exit 0; HTML, Markdown, and EPUB generated without warnings | ✓ PASS |
| Focused formatting and correction diffs | Current formatter plus `git diff --check` for `419297e6` and `2f3bd762` | Exit 0 | ✓ PASS |
| Full `mix verify.journeys` | Supplied current broader replay | 11 tests, 7 failures | OUT-OF-SCOPE RESIDUAL — not claimed green |
| `mix ci.verify_gates` | Not rerun per orchestrator instruction | Existing exact constituent evidence retained; no new aggregate claim | N/A |

## Out-of-Scope Residual

The full `mix verify.journeys` alias remains red in seven older tests involving tenant-scoping, seed isolation, and background database ownership. This report does **not** call that suite green. It does not reverse x9h's actual must-have because the only journey behavior x9h changed and promised to retain—`JOUR-05 mix demo.up --check`—passes independently through the canonical isolated database wrapper. The remaining failures touch no x9h implementation path and are carried as separate repository-quality debt.

## Test Quality Audit

| Test File | Linked Truth | Active | Skipped | Circular | Assertion Level | Verdict |
|---|---|---:|---:|---|---|---|
| `test/chimeway/doc_contract_test.exs` | Truths 1, 2, 3, 5 | Active | 0 relevant | No | Exact value / destructive negative | ✓ PASS |
| `test/chimeway/integration/readme_snippet_test.exs` | Truth 1 | Active | 0 | No | End-to-end DB behavior | ✓ PASS via current Task 1 evidence |
| `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs` | Truth 4 | 3 | 0 | No | Direct public helper + subprocess journey | ✓ PASS — direct calls deterministically load the task; exact journey consumer passes |

No disabled tests or circular expected-value generation were found.

## Requirements Coverage

No formal requirement IDs are assigned to this quick item. All five PLAN truths are verified.

## Anti-Patterns Found

No blocker anti-pattern remains in the changed x9h files. The prior incidental module-load reliance is removed. The three corrected public types now satisfy ExDoc without suppressing warnings.

## Advisory (New Scope, Unevidenced)

None. The broader journey residual is evidenced and explicitly separated above; it is not a newly inferred x9h defect.

## Probe Execution

No standalone probes are declared. Direct ExUnit, Mix task, docs, formatter, and contract evidence is recorded above.

## Decision Coverage

N/A — no item-specific CONTEXT.md decision block exists.

## Human Verification

N/A — documentation/tooling infrastructure with fully machine-testable acceptance. No conversational UAT applies.

## Gaps Summary

No x9h gaps remain. All five must-haves are verified, including deterministic Demo.Up unit coverage, the exact retained JOUR-05 smoke, and warning-clean HexDocs generation. The broader journey suite remains explicitly red and separately scoped.

---

_Verified: 2026-09-13T13:06:42Z_
_Verifier: gsd-verifier_
