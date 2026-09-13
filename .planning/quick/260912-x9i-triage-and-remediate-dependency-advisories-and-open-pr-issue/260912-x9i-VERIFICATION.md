---
phase: 260912-x9i-dependency-and-inbox-triage
verified: 2026-09-13T15:09:17Z
status: passed
score: 7/7 must-haves verified
implementation_sha: af6847ff5d6081453ab49c8471fec19b5776e4e6
covered_files:
  - .github/workflows/ci.yml
  - .planning/quick/260912-x9i-triage-and-remediate-dependency-advisories-and-open-pr-issue/260912-x9i-PLAN.md
  - .planning/quick/260912-x9i-triage-and-remediate-dependency-advisories-and-open-pr-issue/260912-x9i-SUMMARY.md
  - SECURITY.md
  - chimeway_admin/lib/chimeway_admin/live_auth.ex
  - chimeway_admin/mix.exs
  - chimeway_admin/mix.lock
  - chimeway_admin/test/chimeway_admin/live_auth_test.exs
  - chimeway_inbox/lib/chimeway_inbox/router.ex
  - chimeway_inbox/mix.exs
  - chimeway_inbox/mix.lock
  - chimeway_inbox/test/support/endpoint.ex
  - examples/chimeway_demo_host/.formatter.exs
  - examples/chimeway_demo_host/lib/demo_host/adapters/echo_adapter.ex
  - examples/chimeway_demo_host/lib/demo_host/notifiers/invite_sent.ex
  - examples/chimeway_demo_host/lib/demo_host/notifiers/password_reset.ex
  - examples/chimeway_demo_host/lib/demo_host/notifiers/payment_reminder.ex
  - examples/chimeway_demo_host/mix.exs
  - examples/chimeway_demo_host/mix.lock
  - lib/chimeway/adapter.ex
  - lib/chimeway/adapters/mailglass.ex
  - lib/chimeway/adapters/test.ex
  - lib/chimeway/application.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/delivery_attempt.ex
  - lib/chimeway/delivery_planning.ex
  - lib/chimeway/dispatch.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/dispatch/sync.ex
  - lib/chimeway/dispatch/workflow_progression_worker.ex
  - lib/chimeway/inbox/change_publisher.ex
  - lib/chimeway/notifier.ex
  - lib/chimeway/policy.ex
  - lib/chimeway/rendering.ex
  - lib/chimeway/signal.ex
  - lib/chimeway/traces.ex
  - lib/chimeway/traces/explanation.ex
  - lib/chimeway/trigger.ex
  - lib/chimeway/webhooks.ex
  - lib/chimeway/webhooks/ingress.ex
  - lib/chimeway/webhooks/process_feedback_worker.ex
  - lib/chimeway/workflows.ex
  - lib/chimeway/workflows/progression.ex
  - lib/chimeway/workflows/progression_outcome.ex
  - lib/mix/tasks/chimeway.gen.migrations.ex
  - mix.exs
  - mix.lock
  - package-lock.json
  - package.json
  - scripts/prove-alpha-twin.exs
  - scripts/verify-apns.sh
  - test/chimeway/alpha_twin_runner_test.exs
  - test/chimeway/release_gate_contract_test.exs
covered_digest: "v1:sha256:8a55ae4f1800d41befd6ced7f3345c10c4977980412e613a6a7aa162ae8866bf"
external_state:
  hackney_tracker: https://github.com/szTheory/chimeway/issues/29
  predecessor_pr: https://github.com/szTheory/chimeway/pull/22
  dependabot_pr: https://github.com/szTheory/chimeway/pull/28
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 7/7
  gaps_closed: []
  gaps_remaining: []
  regressions: []
  evidence_refreshed:
    - "Root mix ci passed 1,603 tests with zero failures at implementation ancestor 1b81f3cb."
    - "The final af6847ff tree passes mix ci.lint plus focused Alpha twin and APNs executable proofs."
    - "Final mix ci.verify_gates passed all three serial constituents at exact implementation SHA af6847ff."
    - "Public run 34763028703 exposed only three failing leaf jobs at 8213a0cd; each has a bounded local repair and direct focused evidence."
---

# Quick 260912-x9i: Dependency and GitHub Inbox Verification Report

**Goal:** Clear every safely remediable dependency advisory, document the bounded upstream residual, and preserve contributor provenance until exact public replacement evidence exists.
**Verified:** 2026-09-13T15:09:17Z
**Status:** passed
**Re-verification:** Yes — final integrated source candidate

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Root incorporates the exact live PR #28 lock resolution without changing root dependency constraints. | ✓ VERIFIED | Current `mix.lock` SHA-256 is `77bce3f4b98e7c79a1e48bf5dc483a49b62de95d0f29f80ca4e67a5635e3f92f`, byte-for-byte equal to `mix.lock` at live PR head `d03c7b88e51738083b3ab12575b10730f94d1592`. PR #28 is still open, non-draft, mergeable, old-base `f516b607167023edefeb767182adddbd9709aec5`, and changes only `mix.lock`. Later `mix.exs` edits only add nested-project formatter checks and replace planning-era comments; dependency declarations and support floors remain unchanged. |
| 2 | Admin and inbox resolve advisory-safe supported graphs and pass independently. | ✓ VERIFIED | Both locks resolve Phoenix 1.8.13, LiveView 1.2.11, Plug 1.20.3, Postgrex 0.22.4, Hackney 4.7.4, Ecto 3.14.2, and Ecto SQL 3.14.0. Both raw Hex audits exit 0. Admin passes 61/61 at the formerly failing seed after repair `7559b58b`; inbox passes 29/29. The later publisher syntax cleanup is behavior-equivalent and its focused proof passes 4/4. Their manifests and Elixir `~> 1.17` floors are unchanged. |
| 3 | Demo constraints, lock, workflow, and mutation contract agree on Accrue 1.5.1. | ✓ VERIFIED | Demo declares Decimal `~> 3.0` and Ecto SQL `~> 3.14.0`; root resolves Accrue 1.5.1; `verify_accrue` pins exact official commit `d30fc25dbf6ba551792c66ff451b4b93c0af4bf1`. The location-selected release contract passes 9 tests, 0 failures and includes destructive replace/remove checks scoped to the exact `szTheory/accrue` checkout. Final `mix ci.verify_gates` at `af6847ff` passed the packaged Accrue proof 3/3. |
| 4 | Residual advisory risk is exact, graph-specific, and honestly documented. | ✓ VERIFIED | Raw root audit reports exactly four Hackney 1.25.0 findings; raw demo audit reports exactly those four plus three Cowlib 2.20.0 feed mappings. `SECURITY.md` records the four Hackney IDs, fixed floor 4.0.1, the Accrue/Braintree, Threadline, and Tzdata paths, exposure boundary, removal trigger, and the bounded Cowlib feed exception. Exact one-shot ignore audits exit 0; raw audits remain visibly non-zero. |
| 5 | No unsafe override, hidden waiver, support-floor change, or JavaScript churn was introduced. | ✓ VERIFIED | Repository search finds no checked-in `HEX_IGNORE_ADVISORIES` or `ignore-advisory-ids` outside Markdown evidence. Root/admin/inbox manifests, `package.json`, and `package-lock.json` are unchanged across x9i. Demo Mint/HPAX/Req/Finch entries are absent after solving; no Hackney 4 override or Git dependency was added. |
| 6 | Live GitHub has exactly one semantically complete Hackney tracker when Hackney is present. | ✓ VERIFIED | Both root and demo dependency trees were captured successfully and contain Hackney nodes. Exactly one open issue has marker `<!-- chimeway-hackney-residual:x9i -->`: issue #29. Its body contains all four CVEs, 4.0.1, accrue/braintree/threadline/tzdata/hackney paths, attacker-controlled URL and SOCKS5 exposure text, and a closure condition explicitly requiring upstream Accrue/Braintree and Threadline compatibility plus green integration gates. |
| 7 | Contributor PRs remain open unless exact public replacement evidence authorizes closure. | ✓ VERIFIED | PR #22 is open, draft, and conflicting at head `61004f6669ebd9f5c3f7b709b8af16c2376c6807`; PR #28 is open and mergeable at the exact incorporated lock head `d03c7b88e51738083b3ab12575b10730f94d1592`. Final local candidate `af6847ff5d6081453ab49c8471fec19b5776e4e6` returns HTTP 422 from the public commit API. Therefore no public replacement/equal SHA/exact-`pr-gate` chain exists yet, and leaving both PRs open is the PLAN-required safe disposition. |

**Score:** 7/7 must-have truths verified.

## Resolved Package Graphs

| Graph | Verified versions |
|---|---|
| Root | Accrue 1.5.1; Decimal 3.1.1; Ecto 3.14.2; Ecto SQL 3.14.0; ExDoc 0.40.4; ExMoney 6.2.1; Mint 1.10.0; Oban 2.24.1; Tzdata 1.1.5; Hackney 1.25.0 residual |
| Admin | Decimal 3.1.1; Ecto 3.14.2; Ecto SQL 3.14.0; Phoenix 1.8.13; LiveView 1.2.11; Plug 1.20.3; Postgrex 0.22.4; Hackney 4.7.4; Oban 2.24.1; Tzdata 1.1.5 |
| Inbox | Same safe core as admin, including Hackney 4.7.4; Phoenix PubSub 2.3.0 |
| Demo | Decimal 3.1.1; Ecto 3.14.2; Ecto SQL 3.14.0; Cowboy 2.19.0; Cowlib 2.20.0; Phoenix 1.8.13; LiveView 1.2.11; Plug 1.20.3; Postgrex 0.22.4; Swoosh 1.28.0; Hackney 1.25.0 residual |

`mix deps.get --check-locked` exited 0 independently in all four projects and reported every resolution unchanged. This verifies that the checked-in lock state agrees with the current manifests and solver.

## Advisory Evidence

| Graph / command | Raw result | Explicit-policy result | Status |
|---|---|---|---|
| Root `mix hex.audit` | Exit 1; exactly CVE-2026-47069, -47071, -47075, -47076 on Hackney 1.25.0 | Same four IDs supplied only through `HEX_IGNORE_ADVISORIES`; exit 0 | ✓ EXPECTED RESIDUAL |
| Root `mix deps.audit` | Not represented as globally clean | Exact four corresponding GHSA IDs supplied on the command line; `No vulnerabilities found`, exit 0 | ✓ EXPECTED RESIDUAL |
| Admin `mix hex.audit` | `No retired or security advisory packages found`, exit 0 | No ignore needed | ✓ CLEAN |
| Inbox `mix hex.audit` | `No retired or security advisory packages found`, exit 0 | No ignore needed | ✓ CLEAN |
| Demo `mix hex.audit` | Exit 1; four Hackney findings plus CVE-2026-43971, -43966, -43969 mapped to Cowlib 2.20.0 | Exact seven IDs supplied only for the one-shot command; exit 0 | ✓ DOCUMENTED RESIDUAL |

The live dependency-tree captures confirm the root constraint paths `accrue -> braintree -> hackney`, `threadline -> hackney`, and `tzdata -> hackney`; the demo retains Threadline/Tzdata/Swoosh paths to Hackney. This is consistent with `SECURITY.md` and issue #29.

## Behavioral Evidence

| Check | Current result | Status |
|---|---|---|
| Admin warning-strict tests at previously failing seed `964474` | 61 tests, 0 failures | ✓ PASS |
| Admin raw Hex audit after compatibility repair | 0 findings | ✓ PASS |
| Inbox warning-strict tests after current root cleanup | 29 tests, 0 failures | ✓ PASS |
| Inbox raw Hex audit | 0 findings | ✓ PASS |
| Accrue immutable-checkout contract location group | 9 tests, 0 failures; 160 excluded | ✓ PASS |
| Inbox publisher boundary after implicit-`try` normalization | Focused proof: 4 tests, 0 failures | ✓ PASS |
| Root `mix ci` at implementation ancestor `1b81f3cb` | 1,603 tests, 0 failures, 41 excluded; formatting, warning-strict compile, and strict Credo green | ✓ PASS |
| Final `mix ci.verify_gates` at exact candidate `af6847ff` | Root doc/release contracts 669/669 with 4 excluded; packaged Accrue 3/3 with 166 excluded; terminal `crosswake_provider_feedback_docs_verified` marker | ✓ PASS |
| Final lint tree at `af6847ff` | Root `mix ci.lint` exits 0 after `79517be0` made the demo formatter fetch its locked dependencies first | ✓ PASS |
| Final Alpha twin tree at `af6847ff` | Focused runner suite 9/9; `scripts/test-db mix verify.alpha_twin` exits 0 and emits `fixture=passed delivery=provider_accepted activation=authorized` | ✓ PASS |
| Final APNs tree at `af6847ff` | `mix verify.apns` exits 0: root 35/35 plus disabled and enabled clean-consumer proof JSON; five focused static contracts, Bash 3.2 syntax, strict compile probe, and warning mutation all pass | ✓ PASS |
| Documentation | `mix ci.docs` green after public-comment cleanup | ✓ PASS |
| Workflow syntax and focused formatting | `actionlint` and focused `mix format --check-formatted` exit 0 | ✓ PASS |
| Lock consistency | Four independent `mix deps.get --check-locked` invocations exit 0 | ✓ PASS |
| npm security | `npm audit --audit-level=low`: 0 vulnerabilities | ✓ PASS |

### Verification-Driven Repair

The first independent admin replay exposed a real order-dependent failure under LiveView 1.2.11: a test cleanup path could leave `:unauthorized_redirect` explicitly set to `nil`, and `redirect(to: nil)` now raises. Commit `7559b58b` makes the production fallback nil-safe and restores exact prior test environment state. Replaying the original failing seed now passes 61/61. This closes the only blocker found by this verification.

## Final-Candidate Delta Audit

The source changes after the initial x9i verification are bounded and evidenced:

- `a6c85f04` converts an explicit `try` to Elixir's implicit function-level `catch` form without changing publisher return or exception semantics; focused tests pass 4/4.
- `65bf20f6` applies formatter-normalized syntax in the inbox/demo trees and adds the demo's standard `.formatter.exs`; no runtime contract changes.
- `2afb22ac` replaces planning-era production comments with evergreen descriptions and extends `mix ci.lint` to run all three nested project formatters. Final lint, docs, root CI, and release-gate runs are green after this commit.
- `1b81f3cb` changes planning records only and is the exact implementation ancestor used for the 1,603-test root CI run and the initial green `mix ci.verify_gates` run.
- `79517be0` makes the nested demo formatter fetch its locked dependencies before formatter evaluation; final `mix ci.lint` exits 0.
- `239b60e9` derives Alpha twin's unique fixture database from the supplied `DATABASE_URL` while retaining the local 55432 fallback and failing closed on malformed URLs; its focused suite passes 9/9 and the real proof gate passes.
- `af6847ff` removes APNs clean-consumer compile-order ambiguity without weakening the strict warning probe; the full APNs gate and focused mutation/static contracts pass.

The final implementation candidate is `af6847ff5d6081453ab49c8471fec19b5776e4e6`. The three commits after `1b81f3cb` are bounded CI-harness repairs prompted by the public run; they do not alter the x9i lock graphs, residual-advisory policy, admin/inbox behavior, Accrue checkout, or GitHub disposition contract.

The canonical verification fingerprint covers 55 sorted inputs and is `v1:sha256:8a55ae4f1800d41befd6ced7f3345c10c4977980412e613a6a7aa162ae8866bf`.

## GitHub Inbox Disposition

| Item | Live state | Correct current action |
|---|---|---|
| Issue #29 | Open; exactly one x9i marker issue; semantically complete body | Keep open until upstream compatibility and integration-gate closure condition is met. |
| PR #28 | Open, non-draft, mergeable; exact one-file lock delta incorporated | Keep open until the final implementation SHA is public and has a completed successful check named exactly `pr-gate`, then close with the required marked replacement/SHA/check comment. |
| PR #22 | Open, draft, conflicting predecessor | Keep open for the same evidence precondition; do not rebase or erase its provenance. |

There are no closure comments yet, which is correct. The final implementation SHA `af6847ff5d6081453ab49c8471fec19b5776e4e6` is not public, so any closure now would violate the PLAN rather than advance it.

## Scope and Prohibited-Change Audit

- Root lock change is exactly PR #28; admin and inbox changes are lock-only solver refreshes.
- Demo changes are limited to the coupled manifest/lock, Accrue workflow ref, region-scoped release contract, and dependency advisory documentation.
- The bounded admin repair touches only `LiveAuth` and its direct test.
- No root/admin/inbox dependency declaration or Elixir/OTP floor changed.
- No JavaScript file changed, and npm reports zero vulnerabilities. `npm outdated` currently shows dev-only `@playwright/test` current/wanted 1.60.0 versus latest 1.63.0; x9i explicitly excludes JavaScript churn, so this is informational release backlog rather than an x9i defect.
- The implementation worktree was clean at `af6847ff` immediately before this report-only refresh; `git diff --check` exits 0.

## Final Evidence Boundaries and Release Handoff

The public run at implementation ancestor `8213a0cd` completed with only three failing leaf jobs: Lint, Alpha twin hermetic gate, and Optional APNs adapter gate. Its `pr-gate` fan-in therefore also failed. Commits `79517be0`, `239b60e9`, and `af6847ff` directly repair those three leaves and have the focused evidence recorded above. The final SHA has not yet been published, so no public exact-SHA CI claim is made here.

The 1,603-test `mix ci` result remains explicitly attributed to implementation ancestor `1b81f3cb`. In contrast, `mix ci.verify_gates` was freshly rerun at exact final SHA `af6847ff` and exited 0: root doc/release contracts 669/669 with 4 excluded, packaged Accrue 3/3 with 166 excluded, and the terminal CrossWake documentation marker emitted.

No green claim is made for a raw final-tree `mix verify.example`: its local replay used a reused demo database and failed six older seed/tenant-isolation examples. No green claim is made for a raw final-tree `mix verify.journeys` either; the corresponding public leaf passed at `8213a0cd`, but that is ancestor evidence rather than an exact-final-SHA rerun. These boundaries do not convert either alias into a release blocker or a false pass.

This does not leave an x9i must-have unverified: the changed lock graphs, exact residual policy, package-local compatibility behavior, immutable Accrue checkout contract, and conditional GitHub disposition all have direct current evidence. Shipping remains blocked until the orchestrator publishes the final integrated SHA and obtains exact-SHA `pr-gate` success; only then may PR #22/#28 be closed.

## Human Verification

N/A. All x9i acceptance behavior is machine-readable; no conversational UAT applies.

## Gaps Summary

No x9i implementation gap remains. The admin regression found during verification is repaired and replayed at its original failing seed. The remaining Hackney and Cowlib outputs are explicit, bounded, and tracked rather than hidden. PR closure is correctly pending public exact-SHA evidence and is not a completion gap under the PLAN's conditional disposition rule.

---

_Verified: 2026-09-13T15:09:17Z_
_Verifier: gsd-verifier_
