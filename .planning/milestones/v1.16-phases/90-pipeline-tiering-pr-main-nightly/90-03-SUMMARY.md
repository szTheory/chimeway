---
phase: 90-pipeline-tiering-pr-main-nightly
plan: 03
subsystem: ci-cd
tags: [github-actions, ci, nightly, cold-build, otp-floor, aggregate-gate]
requires:
  - phase: 90-pipeline-tiering-pr-main-nightly
    provides: 90-01 resolve_tiers run_nightly/otp_matrix outputs + concurrency fix
  - phase: 90-pipeline-tiering-pr-main-nightly
    provides: 90-02 verify_admin nightly-only + ci-gate 13-lane contract
provides:
  - nightly_cold_build job (cache-free cold-build backstop, TIER-01)
  - test_floor_1_17 job (Elixir 1.17 / OTP 27 floor leg, TIER-01)
  - nightly-gate aggregate job over the four nightly-composition lanes (TIER-04)
  - live end-to-end proof of the full nightly tier + PR-path single-OTP behavior
affects:
  - phase-91 QUAL-05 CI<->release version-skew reconciliation (leans on test_floor_1_17)
tech-stack:
  added: []
  patterns:
    - Cache-free job (no actions/cache step at all) as a cold-build correctness backstop
    - Dedicated 1.17-floor job with its own test-floor- cache-key namespace
    - Aggregate gate mirroring ci-gate's aggregate-gate.sh pass/fail contract, scoped to nightly lanes
    - Contract-test block-extraction boundary widened to recognize digit-bearing job ids
key-files:
  created:
    - .planning/phases/90-pipeline-tiering-pr-main-nightly/90-03-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
    - test/chimeway/ci_observability_contract_test.exs
decisions:
  - "[90-03]: nightly_cold_build omits any actions/cache step entirely (not a restore-skip, not a key salt) so a cache-key correctness bug can never hide behind a warm cache; it is deliberately exempt from the @build_lanes cache-id invariant."
  - "[90-03]: test_floor_1_17 pins elixir 1.17 / otp 27 (the exact pair release.yml/publish-hex.yml build/publish with) and keys its own test-floor- cache namespace; exercises mix.exs's declared ~> 1.17 floor under the full test suite."
  - "[90-03]: nightly-gate needs [resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin] and aggregates NIGHTLY_COLD_BUILD TEST TEST_FLOOR_1_17 VERIFY_ADMIN via aggregate-gate.sh; kept LAST in ci.yml; ci-gate left untouched at 13 lanes (T-90-03)."
  - "[90-03]: Rule 1 fix — extract_ci_job_block boundary regex widened [a-z_]+ -> [a-z0-9_]+ in both contract-test files so digit-bearing job ids (test_floor_1_17) bound cleanly instead of over-capturing into the next job."
metrics:
  duration: 30 min
  completed: 2026-07-30
status: complete
---

# Phase 90 Plan 03: Nightly Tier Composition + Live Proof Summary

**Added the two remaining nightly-only build jobs (`nightly_cold_build` cache-free backstop, `test_floor_1_17` 1.17/OTP-27 floor leg) and the `nightly-gate` aggregate job, then proved the entire nightly tier plus the PR-path single-OTP claim live on GitHub-hosted runners.**

## Performance

- **Duration:** ~30 min (dominated by the ~10 min live nightly-tier run)
- **Completed:** 2026-07-30
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- **TIER-01 (cold build):** `nightly_cold_build` job — Elixir 1.19 / OTP 27, gated on `needs.resolve_tiers.outputs.run_nightly == 'true'`, with **no `actions/cache` step at all** — fetches every dep and compiles every module from nothing (`compile --warnings-as-errors` -> `ecto.create/migrate` -> `mix ci.test`), plus a trailing obs-summary step (no `CACHE_*` env, since there is no cache to report on).
- **TIER-01 (1.17 floor):** `test_floor_1_17` job — pinned `elixir-version: "1.17"` / `otp-version: "27"` (the exact pair `release.yml`/`publish-hex.yml` build/publish with), with its own `test-floor-` cache-key namespace; runs the full suite ending at `mix ci.test`.
- **TIER-04:** `nightly-gate` appended as the **last** job in ci.yml, mirroring `ci-gate`'s `aggregate-gate.sh` pass/fail contract over `NIGHTLY_COLD_BUILD TEST TEST_FLOOR_1_17 VERIFY_ADMIN`; `ci-gate` untouched at 13 lanes.
- Extended both contract-test files with structural assertions for the three new jobs (and re-confirmed `ci-gate` stays 13 lanes excluding the nightly jobs), documenting why the two nightly build jobs are exempt from `@build_lanes`.
- Proved the whole tier live: one `run_nightly=true` dispatch (all named jobs green) and one PR-path run (exactly one executed OTP leg).

## Task Commits

Each task was committed atomically:

1. **Task 1: nightly_cold_build + test_floor_1_17 + contract assertions (TIER-01)** — `d827306` (feat)
2. **Task 2: nightly-gate aggregate job + contract assertions (TIER-04)** — `211dd33` (feat)
3. **Task 3: Closing live proof (no repo files)** — verification-only; evidence recorded below.

## Live Proof (Task 3)

### Full nightly-tier dispatch (TIER-01/02/04)
- **Dispatch:** `gh workflow run ci.yml --ref main -f run_nightly=true`
- **Run:** `30512184143` (event `workflow_dispatch`, headSha `211dd33f`, conclusion **success**)
- **Named jobs, all `success`:** Resolve tier flags · Test (Elixir 1.19 / OTP 26) · Test (Elixir 1.19 / OTP 27) · Nightly cold build (cache-correctness backstop) · Test (Elixir 1.17 floor / OTP 27) · Admin integration gate · ci-gate · nightly-gate
- **0** jobs `cancelled` or `failure`.

### PR-path single-OTP proof (TIER-03) — via throwaway branch/draft PR
Because this phase uses `branching_strategy=none` (all work committed directly to `main`), a main->main PR is impossible. Per the plan's PR-PATH PROOF DEVIATION, a short-lived throwaway branch + draft PR were used purely to trigger one `pull_request`-event ci.yml run, then torn down:

- **Throwaway branch:** `ci/tier03-pr-proof` (one empty commit `4c5e0a2918ffa6a15d8868ed353483cfb0bc4479` — needed because a zero-diff branch cannot open a PR)
- **Draft PR:** `#9` ("ci: TIER-03 PR-path single-OTP proof (throwaway)")
- **PR-path run:** `30512220386` (event `pull_request`, headSha `4c5e0a29`, pr-gate **success**)
- **Result:** exactly **one executed** `Test (` leg — `Test (Elixir 1.19 / OTP 27)` = success; **no OTP 26 leg** present. `Test (Elixir 1.17 floor / OTP 27)` and other nightly-only jobs correctly `skipped`.
- **Cleanup (completed):** PR `#9` closed; branch `ci/tier03-pr-proof` deleted on origin (`git push origin --delete`) and locally; returned to `main`. The throwaway PR/branch were **not** merged and do **not** linger. Verified: 0 remote heads for `ci/tier03-pr-proof`.

Note on the `startswith("Test (")` filter: a naive count returns 2 because `test_floor_1_17`'s display name also begins with "Test (" — but it is `skipped` on the PR path. The substantive TIER-03 claim (the `test` matrix runs a single OTP leg on PRs) is proven by exactly one *executed* leg and the absence of any OTP-26 leg.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Widened `extract_ci_job_block` boundary regex to recognize digit-bearing job ids**
- **Found during:** Task 1 (contract tests failed).
- **Issue:** The shared block-extraction helper's boundary class `[a-z_]+:` does not match job names containing digits, so `test_floor_1_17:` was not recognized as a block boundary. `extract_ci_job_block("nightly_cold_build")` over-captured into `test_floor_1_17` (which has an `actions/cache` step and `id: cache_main`), breaking the "no cache" / "no cache id" assertions. The plan's claim that both new underscore-named ids "bound cleanly on both sides" overlooked the digits in `test_floor_1_17`.
- **Fix:** Changed the boundary class to `[a-z0-9_]+:` in both `release_gate_contract_test.exs` and `ci_observability_contract_test.exs`. This is minimal and safe: it newly recognizes only `test_floor_1_17` as a boundary; hyphenated gate jobs (`ci-gate`, `nightly-gate`) intentionally remain non-boundaries, preserving all existing extraction behavior.
- **Files modified:** `test/chimeway/release_gate_contract_test.exs`, `test/chimeway/ci_observability_contract_test.exs`
- **Commit:** `d827306`

**2. [Rule 1 - Bug] Reworded a ci.yml comment that tripped its own contract assertion**
- **Found during:** Task 1.
- **Issue:** The `nightly_cold_build` explanatory comment literally contained the string `actions/cache` ("deliberately NO actions/cache step here"), which the new `refute String.contains?(job_block, "actions/cache")` assertion matched.
- **Fix:** Reworded to "deliberately NO dependency/build cache step here" (same intent, no `actions/cache` substring).
- **Files modified:** `.github/workflows/ci.yml`
- **Commit:** `d827306`

### Documented plan-text deviation (pre-authorized)

**PR-path proof via throwaway branch/PR instead of the phase's own PR.** The plan text (Task 3, TIER-03) said to "open or update the pull request that ships this phase's branch." With `branching_strategy=none` there is no phase branch and a main->main PR is impossible. The orchestrator's PR-PATH PROOF DEVIATION instructions were followed exactly (throwaway branch + draft PR to trigger one `pull_request` run, then full teardown). Recorded above with ids and cleanup confirmation. No merge into main occurred.

**Total deviations:** 2 auto-fixed (Rule 1), 1 pre-authorized plan-text deviation.

## Verification

- PASS: `actionlint .github/workflows/ci.yml` (exit 0) after both Task 1 and Task 2.
- PASS: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/ci_observability_contract_test.exs` — 142 tests, 0 failures.
- PASS (live): `run_nightly=true` dispatch run `30512184143` — all named nightly jobs `success`, 0 cancelled/failure.
- PASS (live): PR-path run `30512220386` — exactly one executed `Test (` leg (OTP 27), no OTP 26 leg.

## Threat Model Verification

- **T-90-03 (ci-gate needs scope creep, mitigate):** `ci-gate` needs list re-asserted at exactly 13 entries excluding `nightly-gate`/`nightly_cold_build`/`test_floor_1_17` via `extract_ci_gate_needs/1`; contract suite now fails immediately if a future edit widens `ci-gate`.
- **T-90-04 (concurrency under full nightly graph, mitigate):** the live `run_nightly=true` dispatch ran the full nightly job graph to completion with 0 cancelled jobs — Plan 90-01's `event_name`-keyed concurrency fix holds under the complete tier.
- **T-90-01 / T-90-02 (accept):** unchanged; the boolean `run_nightly` input is only string-compared, and the repo remains on `pull_request` (not `pull_request_target`).

## Known Stubs

None. No placeholder/TODO/FIXME or unwired data introduced; all three new jobs run real build/test commands and were exercised live.

## Next Phase Readiness

Phase 90 (all of TIER-01..04) is complete and proven live. `test_floor_1_17` sets up — but does not complete — the CI<->release version-skew reconciliation that Phase 91 (QUAL-05) owns. Ready for phase verification and Phase 91.

## Self-Check: PASSED

- Found `.github/workflows/ci.yml` with `nightly_cold_build`, `test_floor_1_17`, and `nightly-gate` jobs.
- Found commits `d827306` and `211dd33` in git history.
- Found SUMMARY file at `.planning/phases/90-pipeline-tiering-pr-main-nightly/90-03-SUMMARY.md`.
- Live runs `30512184143` (nightly) and `30512220386` (PR-path) confirmed via `gh run view`.
- Throwaway branch `ci/tier03-pr-proof` confirmed deleted on origin (0 remote heads) and locally; PR `#9` closed.
