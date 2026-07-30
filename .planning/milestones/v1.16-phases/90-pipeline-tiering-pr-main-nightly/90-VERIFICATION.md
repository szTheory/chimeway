---
phase: 90-pipeline-tiering-pr-main-nightly
verified: 2026-07-30T04:15:11Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 90: Pipeline Tiering (PR / main / nightly) Verification Report

**Phase Goal:** Introduce a `schedule:`-driven nightly tier that absorbs the expensive full-matrix, cold-build, and heavy-browser work, so the PR path stays fast and single-OTP while release confidence is preserved on a slower, honest cadence.
**Verified:** 2026-07-30T04:15:11Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (Success Criterion) | Status | Evidence |
| --- | --- | --- | --- |
| 1 | TIER-01: A `schedule:`-triggered nightly run performs one full cold build (no restored cache), the full OTP {26,27} matrix, and a 1.17-floor leg honoring `~> 1.17`. | ✓ VERIFIED | `on.schedule.cron "0 7 * * *"` (ci.yml:8-9); `resolve_tiers` emits `otp_matrix=["26","27"]` for non-PR events (ci.yml:48-52); `nightly_cold_build` gated on `run_nightly` with **no** `actions/cache` step (ci.yml:1067-1114); `test_floor_1_17` pinned `elixir 1.17` / `otp 27` (ci.yml:1116-1159); mix.exs `elixir: "~> 1.17"`. Live nightly run `30512184143`: "Nightly cold build", "Test (Elixir 1.17 floor / OTP 27)", both OTP 26+27 legs all `success`. |
| 2 | TIER-02: The heavy Playwright `verify_admin` browser-smoke lane runs on the nightly tier instead of on every PR/push. | ✓ VERIFIED | `verify_admin` now `needs: [resolve_tiers]` + `if: needs.resolve_tiers.outputs.run_nightly == 'true'` (ci.yml:887-891). Live: PR run `30512220386` shows "Admin integration gate" = `skipped`; nightly run `30512184143` = `success`. |
| 3 | TIER-03: The PR path (`pr-gate`) runs a single OTP version (27); only push and nightly run the full OTP matrix. | ✓ VERIFIED | `resolve_tiers` sets `otp_matrix=["27"]` on `pull_request`, else `["26","27"]` (ci.yml:48-52); `test` matrix driven by `fromJSON(needs.resolve_tiers.outputs.otp_matrix)` (ci.yml:213). Live PR run `30512220386`: only "Test (Elixir 1.19 / OTP 27)" executed, **no** OTP 26 leg. Live nightly run: both 26 and 27. |
| 4 | TIER-04: A nightly aggregate gate mirrors `ci-gate`'s pass/fail decision semantics for every lane relocated to the nightly tier. | ✓ VERIFIED | `nightly-gate` `needs: [resolve_tiers, nightly_cold_build, test, test_floor_1_17, verify_admin]`, calls `scripts/ci/aggregate-gate.sh NIGHTLY_COLD_BUILD TEST TEST_FLOOR_1_17 VERIFY_ADMIN` — the identical script/env→arg pattern `ci-gate` uses (ci.yml:1191-1204 vs 1161-1183). Live nightly run: "nightly-gate" = `success`. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `.github/workflows/ci.yml` — `resolve_tiers` | Bare setup job, outputs run_nightly + otp_matrix, no checkout | ✓ VERIFIED | ci.yml:37-60; no `actions/checkout`; single `id: flags` bash step. |
| ci.yml — `on:`/`concurrency` | schedule cron + workflow_dispatch.run_nightly boolean; event-name-keyed group; PR-only cancel | ✓ VERIFIED | ci.yml:3-24. `cancel-in-progress: ${{ github.event_name == 'pull_request' }}`. |
| ci.yml — `test` matrix | fromJSON-driven OTP matrix, needs resolve_tiers | ✓ VERIFIED | ci.yml:208-213. |
| ci.yml — `verify_admin` | nightly-gated | ✓ VERIFIED | ci.yml:887-891. |
| ci.yml — `nightly_cold_build` | zero cache-restoring steps | ✓ VERIFIED | ci.yml:1067-1114; explicit no-cache comment (1094-1099); no `actions/cache`. |
| ci.yml — `test_floor_1_17` | elixir 1.17 / otp 27, `test-floor-` cache key | ✓ VERIFIED | ci.yml:1116-1159. |
| ci.yml — `nightly-gate` | aggregate-gate.sh over four nightly lanes, last job | ✓ VERIFIED | ci.yml:1191-1204; last block in file. |
| `scripts/ci/aggregate-gate.sh` | fail any lane != success | ✓ VERIFIED | script:15-26; shared by pr-gate, ci-gate, nightly-gate. |
| `release_gate_contract_test.exs` | tiering shape + 13-lane ci-gate contract | ✓ VERIFIED | Lines 236-244 (13 lanes), 357-499 (tiering block). |
| `ci_observability_contract_test.exs` | nightly jobs exempt from @build_lanes | ✓ VERIFIED | Lines 20-28 (exemption doc), 316-343. |

### Key Link Verification

| From | To | Via | Status |
| --- | --- | --- | --- |
| `test` job | `resolve_tiers.outputs.otp_matrix` | `fromJSON(...)` in strategy.matrix.otp | ✓ WIRED (ci.yml:213) |
| `nightly-gate` | `aggregate-gate.sh` | needs → env → 4 uppercase args | ✓ WIRED (ci.yml:1194,1200-1204) |
| concurrency group | push vs schedule isolation | interpolates `github.event_name` | ✓ WIRED (ci.yml:23-24) |

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
| --- | --- | --- | --- |
| TIER-01 | 90-03 | ✓ SATISFIED | nightly_cold_build + test_floor_1_17; live run `30512184143`. |
| TIER-02 | 90-02 | ✓ SATISFIED | verify_admin nightly-gated; live skipped(PR)/success(nightly). |
| TIER-03 | 90-01 | ✓ SATISFIED | fromJSON single-OTP PR path; live run `30512220386`. |
| TIER-04 | 90-03 | ✓ SATISFIED | nightly-gate aggregate; live success. |

All four requirement IDs are declared in plan frontmatter (90-01→TIER-03, 90-02→TIER-02, 90-03→TIER-01+TIER-04) and marked `[x]` complete in REQUIREMENTS.md. No orphaned IDs.

### Prohibitions (must-NOT checks — test-tier, enforced via contract tests)

| Prohibition | Status | Evidence |
| --- | --- | --- |
| concurrency MUST NOT let a push cancel an in-flight nightly run | ✓ HELD | cancel-in-progress scoped to `pull_request` only (ci.yml:24); asserted by contract test (lines 377-396); live nightly ran to completion with 0 cancelled jobs. |
| ci-gate MUST NOT keep verify_admin / nightly jobs in its needs list | ✓ HELD | ci-gate needs = 13 lanes, no verify_admin/nightly jobs (ci.yml:1164); asserted lines 483-498. |

### Anti-Patterns Found

None. All new jobs run real build/test commands (`mix compile --warnings-as-errors`, `mix ci.test`); no TODO/FIXME/placeholder markers in modified files.

### Behavioral / Live Evidence

The runtime truths (event-conditional matrix, nightly-only gating, aggregate gate) are behavior-dependent workflow state transitions. Per the phase's accepted proof mechanism, they were validated on GitHub-hosted runners and independently re-confirmed here via `gh run view`:

- **Nightly run `30512184143`** (`run_nightly=true`): Resolve tier flags, both Test legs (OTP 26 + 27), Nightly cold build, Test 1.17-floor, Admin integration gate, ci-gate, nightly-gate — all `success`; 0 cancelled/failure.
- **PR run `30512220386`** (`pull_request`): exactly one executed Test leg (OTP 27), no OTP 26 leg; verify_admin / nightly_cold_build / test_floor_1_17 / nightly-gate all `skipped`; pr-gate `success`.

Static contract suite re-run locally: `mix test release_gate_contract_test.exs ci_observability_contract_test.exs` → **142 tests, 0 failures**.

### Gaps Summary

None. All four success criteria are structurally present in ci.yml, wired correctly, locked by passing contract tests, and confirmed by two independently re-verified live GitHub Actions runs. Phase goal achieved.

---

_Verified: 2026-07-30T04:15:11Z_
_Verifier: Claude (gsd-verifier)_
