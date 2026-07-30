---
phase: 90
slug: pipeline-tiering-pr-main-nightly
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-29
---

# Phase 90 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This phase is CI/CD orchestration (YAML), not Elixir library code. Its "test framework"
> is the existing ExUnit **ci.yml contract tests** (regex-parse `ci.yml`, assert structural
> invariants) plus GitHub-Actions-native static (`actionlint`) and dynamic (`gh workflow run`)
> checks — all executable without waiting for a real 07:00 UTC cron.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (structural/contract)** | ExUnit — `test/chimeway/release_gate_contract_test.exs`, `test/chimeway/ci_observability_contract_test.exs` |
| **Framework (workflow syntax)** | `actionlint` v1.7.12 (installed locally) |
| **Framework (live execution)** | GitHub Actions itself, driven via `gh workflow run` / `gh run watch` |
| **Config file** | none — `actionlint` needs no config; ExUnit config is existing `mix.exs`/`config/test.exs` |
| **Quick run command** | `actionlint .github/workflows/ci.yml` (sub-second) |
| **Full suite command** | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/ci_observability_contract_test.exs` |
| **Live nightly-equivalent** | `gh workflow run ci.yml --ref <branch> -f run_nightly=true` then `gh run watch <id> --exit-status` |
| **Estimated runtime** | contract tests ~seconds; live dispatch several minutes |

---

## Sampling Rate

- **After every task commit that touches `ci.yml`:** Run `actionlint .github/workflows/ci.yml` (sub-second).
- **After every plan wave:** Run the full ExUnit contract suite (`mix test .../release_gate_contract_test.exs .../ci_observability_contract_test.exs`).
- **Before `/gsd-verify-work` (phase gate):** BOTH the full contract suite must be green AND at least one `gh run watch --exit-status` on a `run_nightly=true` dispatch must be evidenced green on the final pre-merge state. This live dispatch is the phase's real proof — no static check substitutes for it.
- **Max feedback latency:** ~1s (actionlint) for per-commit; minutes for the live dispatch.

---

## Per-Task Verification Map

> Seeded post-planning. Task IDs are assigned by the planner; the requirement→check
> mapping below (from RESEARCH.md §Validation Architecture) is the source the planner
> lifts per-task `<verify>` blocks from.

| Req ID | Behavior to prove | Test Type | Automated Command | File Exists |
|--------|-------------------|-----------|-------------------|-------------|
| TIER-01 (cold build) | `nightly_cold_build` job exists, has NO `actions/cache` step, gated on nightly | static (regex/ExUnit) | new ExUnit assertion + `actionlint` | ❌ W0 |
| TIER-01 (full matrix) | `test` `otp` matrix resolves to `["26","27"]` on push/schedule | static (actionlint) + dynamic | `actionlint` + live dispatch matrix-leg count == 2 | ❌ W0 |
| TIER-01 (1.17 floor) | `test_floor_1_17` job pins `elixir: "1.17"` / `otp: "27"` | static (regex/ExUnit) | new ExUnit assertion on the job block | ❌ W0 |
| TIER-01 (all three, live) | dispatched nightly run executes + passes all three | dynamic (GH Actions) | `gh workflow run ci.yml -f run_nightly=true` → `gh run watch --exit-status` | n/a (exec-time) |
| TIER-02 (relocated) | `verify_admin` `if:` references `resolve_tiers.outputs.run_nightly`, not the bare `event_name != 'pull_request'` | static (regex/ExUnit) | update lane assertion + `actionlint` | ❌ W0 |
| TIER-02 (relocated, live) | push run shows `verify_admin` `skipped`; nightly dispatch shows `success` | dynamic (GH Actions) | `gh run view <id> --json jobs --jq …` | n/a (exec-time) |
| TIER-03 (PR single OTP) | `pull_request` `test` shows exactly 1 matrix leg (OTP 27) | dynamic (GH Actions) | `gh run view --json jobs` matrix-leg count == 1 | n/a (exec-time) |
| TIER-03 (push/nightly full) | `push`/`schedule` `test` shows 2 matrix legs (OTP 26 + 27) | dynamic (GH Actions) | same query, count == 2 | n/a (exec-time) |
| TIER-04 (nightly-gate) | `nightly-gate` exists, `needs:` scoped to relocated lanes, calls `aggregate-gate.sh` | static (regex/ExUnit) | new ExUnit assertion | ❌ W0 |
| TIER-04 (decision, live) | dispatched nightly with all lanes green shows `nightly-gate` = success | dynamic (GH Actions) | `gh run watch --exit-status` + job conclusion | n/a (exec-time) |
| Regression guard (Pitfall 1) | `ci-gate` `needs:` no longer references `verify_admin`; `@ci_gate_lanes` 14 → 13 | static (ExUnit, exists) | `mix test .../release_gate_contract_test.exs` | ✅ exists, needs update |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/release_gate_contract_test.exs` — update `@ci_gate_lanes` (14 → 13, drop `verify_admin`); rename the "aggregates 14 required lanes" test to match; add assertions for `resolve_tiers`, `nightly_cold_build`, `test_floor_1_17`, `nightly-gate` job existence/shape; add assertion that `verify_admin`'s `if:` no longer contains the bare `github.event_name != 'pull_request'` guard.
- [ ] `test/chimeway/ci_observability_contract_test.exs` — decide whether the three new jobs join `@build_lanes` (if they reuse `obs-summary.sh` for observability parity) or are explicitly exempted; encode the decision as an assertion.
- [ ] No new Elixir test framework/config needed — `mix test` already covers `.exs` contract tests; `actionlint` needs no project config for this repo.

*The three new jobs and the `ci-gate`/contract-test updates MUST land in the atomic change described in RESEARCH.md Pitfall 1 — the contract test is the Wave 0 backstop that proves the atomicity held.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The nightly tier actually runs end-to-end on GitHub-hosted runners | TIER-01/02/04 | A `schedule:`-gated path cannot be exercised on a PR, and hosted-runner Postgres/cache semantics are not reproduced by `act` locally | `gh workflow run ci.yml --ref <branch> -f run_nightly=true`, then `gh run watch <run-id> --exit-status`; confirm `nightly_cold_build`, both `test` OTP legs, `test_floor_1_17`, `verify_admin`, and `nightly-gate` all ran and passed |
| PR-path `test` shrinks to one OTP leg | TIER-03 | Requires a real `pull_request` event to observe the resolved matrix | Open/update a PR; `gh run view --json jobs` and assert exactly one `Test` matrix leg (OTP 27) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify (actionlint / ExUnit contract) or a documented Manual-Only entry
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all contract-test updates (the atomicity backstop)
- [ ] No watch-mode flags
- [ ] One green `gh run watch --exit-status` on a `run_nightly=true` dispatch evidenced before phase close
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
