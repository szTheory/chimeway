---
phase: 92-reliability-triage-determinism
verified: 2026-07-30T20:00:00Z
status: passed
score: 8/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 92: Reliability Triage & Determinism Verification Report

**Phase Goal:** Establish a trustworthy CI reliability signal — measure and reduce real-vs-flaky failures, close the two outstanding CI-only backlog issues, and add the last determinism/isolation guards.
**Verified:** 2026-07-30T20:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

**Note on SUMMARY drift:** 92-01/92-02 SUMMARYs are accurate. 92-03-SUMMARY.md documents a mid-session deferral of the live-CI proofs for REL-02/REL-03 (commits not yet pushed at that point). That deferral was subsequently closed by the orchestrator in commit `15dfc02` ("docs(92): close REL-02/REL-03 live-CI backstops — verified-fixed on phase HEAD"), after two lint fixes (`eff0ba4`, `2fdbea2`) were pushed and proven green. This verification judges the **current** repository state, not the superseded mid-session SUMMARY note — the deferral is closed, not open.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | REL-01: measured completed-run failure rate on `main` `ci-gate` is under 10%, corroborated by ≥5 consecutive green runs | ✓ VERIFIED | `.planning/CI-RELIABILITY-REPORT.md`: `failures=2 excluded=0 rate=6% streak=10` over last 30 push-on-main runs; population = `ci-gate` JOB conclusion, event=push/branch=main, cancelled/skipped excluded. `scripts/ci/reliability-report.sh` exits 0. |
| 2 | REL-01: `reliability-report.sh` classifier is boundary-tested (exactly-10%/streak-4 fail, just-under/streak-5 pass, cancelled-run adjacency, secret hygiene, no `eval`) | ✓ VERIFIED | `test/chimeway/ci_reliability_contract_test.exs` — ran locally: included in the 169-test batch run below, 0 failures. Script contains `set -euo pipefail`, whitelist-emit only, jq-parsed (no `eval` of gh-derived strings, confirmed via `grep -c eval` pattern in file). |
| 3 | REL-02: backlog #2 (`demo.up --check`) and #3 (Accrue path-dep) are each verified-fixed with pinned mechanisms, OR quarantined behind a linked tracking issue — no undocumented CI-only gap | ✓ VERIFIED | `.planning/CI-HARDENING-BACKLOG.md` records both **VERIFIED-FIXED** (not quarantined) with pinned root-cause mechanisms, citing push run `30573877353` @ `eff0ba43`. Live-checked via `gh run view 30573877353`: `verify_example=success`, `verify_journeys=success`, `verify_accrue=success`, `ci-gate=success`, `headSha=eff0ba43b08e53cd08a395d970f019538e7a6cbe` (confirmed ancestor of current HEAD via `git merge-base --is-ancestor`). Tracking issue `#4` confirmed `CLOSED` via `gh issue view 4`. |
| 4 | REL-02: verified-fixed/quarantine decision is driven by a log-assertable fact pinned to the phase's own HEAD (not a foreign/earlier run) | ✓ VERIFIED | The cited run's `headSha` (`eff0ba43...`) matches a commit in this phase's own history (`eff0ba4`, the credo-fix commit landed as part of closing this phase), confirmed an ancestor of current HEAD. Not a pre-phase or foreign run. |
| 5 | REL-03: a nightly-only `test_seed_zero` lane runs `mix test --seed 0` with the `ci.test` excludes and `--warnings-as-errors`, gated on `needs.resolve_tiers.outputs.run_nightly == 'true'` | ✓ VERIFIED | `.github/workflows/ci.yml` lines 1232–1275: job `test_seed_zero` (`name: "Test ordering guard (--seed 0)"`), `if: needs.resolve_tiers.outputs.run_nightly == 'true'`, final step `mix test --seed 0 --exclude mailglass --exclude accrue --exclude threadline --exclude sigra --warnings-as-errors`. |
| 6 | REL-03: `test_seed_zero` runs ONLY on nightly — never added to `ci-gate`/`pr-gate`, random seed retained on PR/push | ✓ VERIFIED | `ci-gate` needs list (line 1280) does not include `test_seed_zero`; live push run `30573877353` shows `Test ordering guard (--seed 0): skipped` (correctly skipped on push, not run). |
| 7 | REL-03: with `--seed 0` the default suite passes identically to random-seed runs (deterministic ordering, no coupling) | ✓ VERIFIED | Live nightly dispatch `30573935421` (`headSha=eff0ba43...`, `event=workflow_dispatch`): `Test ordering guard (--seed 0): success`, `nightly-gate: success`. |
| 8 | REL-03: `nightly-gate` needs + `aggregate-gate.sh` token list include `test_seed_zero`/`TEST_SEED_ZERO`; contract test asserts the 5-lane composition; `test_seed_zero` exempt from `@build_lanes` | ✓ VERIFIED | `ci.yml` lines 1308–1322: `nightly-gate` needs = `[resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin, test_seed_zero]`; `aggregate-gate.sh NIGHTLY_COLD_BUILD TEST TEST_FLOOR_1_17 VERIFY_ADMIN TEST_SEED_ZERO`. `test/chimeway/release_gate_contract_test.exs` lines 475–499 assert the exact needs list + token string. `test/chimeway/ci_observability_contract_test.exs` line 359 asserts `refute "test_seed_zero" in @build_lanes`. Both contract files ran green locally. |
| 9 | REL-04: `EnvHelper.put_env_isolated/3` sets an app-env key and restores the exact prior value on exit when present | ✓ VERIFIED | `test/support/env_helper.ex` (28 lines, full logic — not a stub); `test/chimeway/test_support/env_helper_test.exs` test "restores the exact prior value on exit when the key was present" — ran green (LIFO on_exit idiom). |
| 10 | REL-04: `put_env_isolated/3` DELETES the key on exit when it was absent (not left `nil`) | ✓ VERIFIED | `env_helper.ex` line 22: `:error -> Application.delete_env(app, key)`. Unit test "deletes the key on exit when it was absent before the call" asserts `Application.fetch_env == :error` post-exit — ran green. |
| 11 | REL-04: `policy_test.exs` (async: true) routes its `:chimeway/:adapter` mutations only through the helper — no bare app-env mutation remains | ✓ VERIFIED | `grep -n "put_env_isolated" test/chimeway/policy_test.exs` → 2 matches (lines 248, 279); `grep -n "Application.put_env" test/chimeway/policy_test.exs` → 0 matches. |
| 12 | REL-04: a contract assertion greps every `async: true` DataCase module and fails on any bare app-env put, guarding the async split as the suite grows | ✓ VERIFIED | `test/chimeway/ci_observability_contract_test.exs` describe block "REL-04 adoption guard" (line 470) with helpers `async_true_module?/1`, `bare_app_env_put?/1`, `comment_line?/1` — ran green. |

**Score:** 12/12 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/support/env_helper.ex` | `put_env_isolated/3` capture/restore helper | ✓ VERIFIED | 28 lines, full snapshot→set→on_exit(restore-or-delete) logic |
| `test/chimeway/test_support/env_helper_test.exs` | unit test for both branches | ✓ VERIFIED | 2 tests, both green |
| `scripts/ci/reliability-report.sh` | re-runnable classifier | ✓ VERIFIED | 156 lines, `set -euo pipefail`, whitelist-emit, integer-arithmetic boundaries, no `eval` |
| `test/fixtures/ci/run_list_sample.json` | mixed fixture | ✓ VERIFIED | 8 lines, present |
| `test/chimeway/ci_reliability_contract_test.exs` | boundary + hygiene tests | ✓ VERIFIED | 162 lines, part of green 169-test batch |
| `.planning/CI-RELIABILITY-REPORT.md` | durable snapshot | ✓ VERIFIED | 61 lines, real `actions/runs/<id>` permalinks, population definition, measured rate/streak |
| `.github/workflows/ci.yml` (`test_seed_zero` + nightly-gate wiring) | nightly-only seed-0 lane | ✓ VERIFIED | Job block + needs/token wiring present and live-proven |
| `test/chimeway/release_gate_contract_test.exs` (5-lane assertions) | nightly-gate composition contract | ✓ VERIFIED | Lines 475–517, green |
| `test/chimeway/ci_observability_contract_test.exs` (exemption + adoption guard) | `test_seed_zero` exemption + REL-04 guard | ✓ VERIFIED | Lines 341–360, 470–501, green |
| `.planning/CI-HARDENING-BACKLOG.md` (#2/#3 resolution) | verified-fixed or quarantine | ✓ VERIFIED | Both entries VERIFIED-FIXED with pinned mechanisms + live run citation; issue #4 closed |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `policy_test.exs` | `EnvHelper.put_env_isolated/3` | direct call, lines 248/279 | ✓ WIRED | grep confirms 2 call sites, 0 bare `Application.put_env` remaining |
| `ci_observability_contract_test.exs` REL-04 guard | async test-file sources | file-glob + regex scan | ✓ WIRED | describe block present, ran green |
| `reliability-report.sh` | `gh run list`/`gh run view` (ci-gate job) | population definition in script header | ✓ WIRED | Script + committed report both cite live run ids/permalinks |
| `test_seed_zero` | `nightly-gate` needs → `aggregate-gate.sh` | `TEST_SEED_ZERO` token | ✓ WIRED | ci.yml lines 1311/1321-1322; contract test asserts exact string |
| `release_gate_contract_test.exs` nightly-gate assertion | `ci.yml` nightly-gate needs | exact-string assertion | ✓ WIRED | Assertion matches current ci.yml verbatim |

### Behavioral Spot-Checks / Probe Execution (live-CI backstop)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Push run proves REL-02 lanes green on phase HEAD | `gh run view 30573877353 --json headSha,conclusion,jobs` | `headSha=eff0ba43...` (ancestor of HEAD), `ci-gate=success`, `verify_example/verify_journeys/verify_accrue=success`, `Lint=success` | ✓ PASS |
| Nightly dispatch proves REL-03 green on phase HEAD | `gh run view 30573935421 --json headSha,conclusion,jobs` | `headSha=eff0ba43...`, `event=workflow_dispatch`, `Test ordering guard (--seed 0)=success`, `nightly-gate=success` | ✓ PASS |
| `test_seed_zero` correctly excluded from push path | `gh run view 30573877353` job list | `Test ordering guard (--seed 0)=skipped` on push (adjacency edge holds) | ✓ PASS |
| Tracking issue #4 closed | `gh issue view 4 --json state,closedAt` | `state=CLOSED`, `closedAt=2026-07-30T19:27:32Z` | ✓ PASS |
| `eff0ba43` is ancestor of current HEAD (not a foreign/earlier run) | `git merge-base --is-ancestor eff0ba43 HEAD` | exit 0 | ✓ PASS |
| Full local test batch (env_helper + policy + observability + reliability + release_gate contracts) | `MIX_ENV=test mix test <5 files> --warnings-as-errors` | 169 tests, 0 failures | ✓ PASS |
| `lib/` untouched across the whole phase | `git diff --stat af837e3..HEAD -- lib/` | empty | ✓ PASS |
| No debt markers (TBD/FIXME/XXX/TODO/placeholder) in any phase-modified file | grep scan of all 17 non-planning modified files | 0 matches | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| REL-01 | 92-02 | Real-vs-flaky rate measured, <10% failure + ≥5 streak | ✓ SATISFIED | `.planning/CI-RELIABILITY-REPORT.md`, `reliability-report.sh`, `ci_reliability_contract_test.exs` |
| REL-02 | 92-03 | Two CI-only backlog issues verified-fixed or quarantined | ✓ SATISFIED | `CI-HARDENING-BACKLOG.md` verified-fixed with pinned mechanisms + live run `30573877353`; issue #4 closed |
| REL-03 | 92-03 | Nightly `--seed 0` ordering guard, random seed elsewhere | ✓ SATISFIED | `ci.yml` `test_seed_zero` job + nightly-gate wiring; live-proven on dispatch `30573935421` |
| REL-04 | 92-01 | Capture/restore `put_env` helper adopted, contract-guarded | ✓ SATISFIED | `env_helper.ex`, `env_helper_test.exs`, `policy_test.exs` adoption, adoption contract guard |

No orphaned requirements: `.planning/REQUIREMENTS.md` line 84 traceability table maps `REL-01..04` → Phase 92 → Complete, and all four IDs are declared across the three plans' `requirements:` frontmatter.

### Anti-Patterns Found

None. Scanned all 17 non-`.planning/` and non-SUMMARY files modified in this phase for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER|placeholder|coming soon|not yet implemented` — zero matches.

**Informational (non-blocking) note:** The plan's Task 3 acceptance criteria for 92-03 included tightening `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs`'s `@tag timeout` from `300_000` to `120_000` (re-asserted green after the tighten). This tighten was **not applied** — `grep -n timeout examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs` still shows `300_000`. This is explicitly and transparently documented in the current `CI-HARDENING-BACKLOG.md`: *"The interim `@tag timeout: 300_000` is retained — tightening to `120_000` is an optional future cleanup, not part of REL-02 (which is the verified-fixed decision itself)."* This item does not appear in the phase's `must_haves.truths` (only in a task-level acceptance criterion), and REL-02's actual must-have — verified-fixed-or-quarantined with no undocumented gap — is independently satisfied. Not a phase-goal blocker; flagged for visibility only.

### Human Verification Required

None. All must-haves are verified against artifacts or against live, log-assertable CI evidence (`gh run view`/`gh issue view` output captured in this report), consistent with this project's "shift-left, 0 human UAT" convention for live-CI backstops.

### Gaps Summary

No gaps. All 12 derived truths (roadmap Success Criteria 1–4, expanded against the three plans' must_haves) are VERIFIED against current repository state and live CI evidence — not against the now-superseded 92-03-SUMMARY.md deferral notes, which were subsequently closed by commit `15dfc02` and proven via push run `30573877353` and nightly dispatch `30573935421`, both pinned to `headSha eff0ba43...`, confirmed an ancestor of current HEAD (`15dfc02`).

---

_Verified: 2026-07-30T20:00:00Z_
_Verifier: Claude (gsd-verifier)_
