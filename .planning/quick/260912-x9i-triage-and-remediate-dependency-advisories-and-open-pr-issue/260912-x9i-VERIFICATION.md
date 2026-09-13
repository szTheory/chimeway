---
phase: 260912-x9i-dependency-and-inbox-triage
verified: 2026-09-13T14:01:25Z
status: passed
score: 7/7 must-haves verified
implementation_sha: 7559b58b2f71462981236ddcadd4a03c60628325
covered_files:
  - .github/workflows/ci.yml
  - SECURITY.md
  - chimeway_admin/lib/chimeway_admin/live_auth.ex
  - chimeway_admin/mix.lock
  - chimeway_admin/test/chimeway_admin/live_auth_test.exs
  - chimeway_inbox/mix.lock
  - examples/chimeway_demo_host/mix.exs
  - examples/chimeway_demo_host/mix.lock
  - mix.lock
  - test/chimeway/release_gate_contract_test.exs
external_state:
  hackney_tracker: https://github.com/szTheory/chimeway/issues/29
  predecessor_pr: https://github.com/szTheory/chimeway/pull/22
  dependabot_pr: https://github.com/szTheory/chimeway/pull/28
behavior_unverified: 0
overrides_applied: 0
release_gate_handoff:
  - "The expensive root, ecosystem, and aggregate release suites were intentionally not rerun by this independent verifier; the orchestrator reserved one final integrated run before ship. This report does not call those suites green."
---

# Quick 260912-x9i: Dependency and GitHub Inbox Verification Report

**Goal:** Clear every safely remediable dependency advisory, document the bounded upstream residual, and preserve contributor provenance until exact public replacement evidence exists.
**Verified:** 2026-09-13T14:01:25Z
**Status:** passed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Root incorporates the exact live PR #28 lock resolution without changing root constraints. | ✓ VERIFIED | Current `mix.lock` SHA-256 is `77bce3f4b98e7c79a1e48bf5dc483a49b62de95d0f29f80ca4e67a5635e3f92f`, byte-for-byte equal to `mix.lock` at live PR head `d03c7b88e51738083b3ab12575b10730f94d1592`. PR #28 is still open, non-draft, mergeable, old-base `f516b607167023edefeb767182adddbd9709aec5`, and changes only `mix.lock`. Root `mix.exs` is unchanged in the x9i range. |
| 2 | Admin and inbox resolve advisory-safe supported graphs and pass independently. | ✓ VERIFIED | Both locks resolve Phoenix 1.8.13, LiveView 1.2.11, Plug 1.20.3, Postgrex 0.22.4, Hackney 4.7.4, Ecto 3.14.2, and Ecto SQL 3.14.0. Both raw Hex audits exit 0. Current tests pass: admin 61/61 at the formerly failing seed after repair `7559b58b`; inbox 29/29. Their manifests and Elixir `~> 1.17` floors are unchanged. |
| 3 | Demo constraints, lock, workflow, and mutation contract agree on Accrue 1.5.1. | ✓ VERIFIED | Demo declares Decimal `~> 3.0` and Ecto SQL `~> 3.14.0`; root resolves Accrue 1.5.1; `verify_accrue` pins exact official commit `d30fc25dbf6ba551792c66ff451b4b93c0af4bf1`. The location-selected release contract passes 9 tests, 0 failures and includes destructive replace/remove checks scoped to the exact `szTheory/accrue` checkout. `actionlint` and focused formatting exit 0. |
| 4 | Residual advisory risk is exact, graph-specific, and honestly documented. | ✓ VERIFIED | Raw root audit reports exactly four Hackney 1.25.0 findings; raw demo audit reports exactly those four plus three Cowlib 2.20.0 feed mappings. `SECURITY.md` records the four Hackney IDs, fixed floor 4.0.1, the Accrue/Braintree, Threadline, and Tzdata paths, exposure boundary, removal trigger, and the bounded Cowlib feed exception. Exact one-shot ignore audits exit 0; raw audits remain visibly non-zero. |
| 5 | No unsafe override, hidden waiver, support-floor change, or JavaScript churn was introduced. | ✓ VERIFIED | Repository search finds no checked-in `HEX_IGNORE_ADVISORIES` or `ignore-advisory-ids` outside Markdown evidence. Root/admin/inbox manifests, `package.json`, and `package-lock.json` are unchanged across x9i. Demo Mint/HPAX/Req/Finch entries are absent after solving; no Hackney 4 override or Git dependency was added. |
| 6 | Live GitHub has exactly one semantically complete Hackney tracker when Hackney is present. | ✓ VERIFIED | Both root and demo dependency trees were captured successfully and contain Hackney nodes. Exactly one open issue has marker `<!-- chimeway-hackney-residual:x9i -->`: issue #29. Its body contains all four CVEs, 4.0.1, accrue/braintree/threadline/tzdata/hackney paths, attacker-controlled URL and SOCKS5 exposure text, and a closure condition explicitly requiring upstream Accrue/Braintree and Threadline compatibility plus green integration gates. |
| 7 | Contributor PRs remain open unless exact public replacement evidence authorizes closure. | ✓ VERIFIED | PR #22 is open, draft, and conflicting at head `61004f6669ebd9f5c3f7b709b8af16c2376c6807`; PR #28 is open and mergeable at the exact incorporated lock head. Current local implementation SHA `7559b58b2f71462981236ddcadd4a03c60628325` returns HTTP 422 from the public commit API. Therefore no public replacement/equal SHA/exact-`pr-gate` chain exists yet, and leaving both PRs open is the PLAN-required safe disposition. |

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
| Workflow syntax and focused formatting | `actionlint` and `mix format --check-formatted` exit 0 | ✓ PASS |
| Lock consistency | Four independent `mix deps.get --check-locked` invocations exit 0 | ✓ PASS |
| npm security | `npm audit --audit-level=low`: 0 vulnerabilities | ✓ PASS |

### Verification-Driven Repair

The first independent admin replay exposed a real order-dependent failure under LiveView 1.2.11: a test cleanup path could leave `:unauthorized_redirect` explicitly set to `nil`, and `redirect(to: nil)` now raises. Commit `7559b58b` makes the production fallback nil-safe and restores exact prior test environment state. Replaying the original failing seed now passes 61/61. This closes the only blocker found by this verification.

## GitHub Inbox Disposition

| Item | Live state | Correct current action |
|---|---|---|
| Issue #29 | Open; exactly one x9i marker issue; semantically complete body | Keep open until upstream compatibility and integration-gate closure condition is met. |
| PR #28 | Open, non-draft, mergeable; exact one-file lock delta incorporated | Keep open until the final implementation SHA is public and has a completed successful check named exactly `pr-gate`, then close with the required marked replacement/SHA/check comment. |
| PR #22 | Open, draft, conflicting predecessor | Keep open for the same evidence precondition; do not rebase or erase its provenance. |

There are no closure comments yet, which is correct. The current SHA is not public, so any closure now would violate the PLAN rather than advance it.

## Scope and Prohibited-Change Audit

- Root lock change is exactly PR #28; admin and inbox changes are lock-only solver refreshes.
- Demo changes are limited to the coupled manifest/lock, Accrue workflow ref, region-scoped release contract, and dependency advisory documentation.
- The bounded admin repair touches only `LiveAuth` and its direct test.
- No root/admin/inbox dependency declaration or Elixir/OTP floor changed.
- No JavaScript file changed, and npm reports zero vulnerabilities. `npm outdated` currently shows dev-only `@playwright/test` current/wanted 1.60.0 versus latest 1.63.0; x9i explicitly excludes JavaScript churn, so this is informational release backlog rather than an x9i defect.
- `git diff --check` exits 0.

## Final Release-Gate Handoff

Per verifier assignment, this pass deliberately did not rerun `mix ci`, `mix verify.example`, `mix verify.accrue`, `mix verify.inbox`, or `mix ci.verify_gates`. They are expensive final integration/release checks reserved for one post-cleanup run by the orchestrator. This report makes no green claim for those aggregate commands.

That handoff does not leave an x9i must-have unverified: the changed lock graphs, exact residual policy, package-local compatibility behavior, immutable Accrue checkout contract, and conditional GitHub disposition all have direct current evidence. Shipping remains blocked until the orchestrator publishes the final integrated SHA and obtains exact-SHA `pr-gate` success; only then may PR #22/#28 be closed.

## Human Verification

N/A. All x9i acceptance behavior is machine-readable; no conversational UAT applies.

## Gaps Summary

No x9i implementation gap remains. The admin regression found during verification is repaired and replayed at its original failing seed. The remaining Hackney and Cowlib outputs are explicit, bounded, and tracked rather than hidden. PR closure is correctly pending public exact-SHA evidence and is not a completion gap under the PLAN's conditional disposition rule.

---

_Verified: 2026-09-13T14:01:25Z_
_Verifier: gsd-verifier_
