---
phase: 92
slug: reliability-triage-determinism
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-30
---

# Phase 92 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `92-RESEARCH.md` § Validation Architecture. Task IDs are reconciled against PLAN.md during planning/execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19 CI matrix; 1.17 floor on push/nightly) |
| **Config file** | `config/test.exs` (pool sizing), `test/test_helper.exs` (`ExUnit.start()`) |
| **Quick run command** | `mix test test/chimeway/<file>.exs` |
| **Full suite command** | `mix ci.test` (excludes mailglass/accrue/threadline/sigra; `--warnings-as-errors`) |
| **Bash-script tests** | `System.cmd("bash", [script], env: [...])` against committed fixtures (obs-summary precedent) |
| **Estimated runtime** | ~130 s (full default suite) |

---

## Sampling Rate

- **After every task commit:** Run the specific new/changed test file — `mix test <file>` (fast)
- **After every plan wave:** Run `mix ci.test` (full default suite, `--warnings-as-errors`)
- **Phase gate (before `/gsd-verify-work`):** full `ci-gate` green on push + one nightly dispatch green (for REL-03) + `scripts/ci/reliability-report.sh` exits 0
- **Max feedback latency:** ~130 s (full suite); per-task file runs are seconds

---

## Per-Task Verification Map

> Requirement-level rows from research. `Task ID` / `Plan` / `Wave` are filled once PLAN.md task IDs exist.

| Task ID | Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|---------|-------------|----------|-----------|-------------------|-------------|--------|
| TBD | REL-01 | `reliability-report.sh` classifies success/failure/cancelled + computes rate + streak | unit (bash-vs-fixture) | `mix test test/chimeway/ci_reliability_contract_test.exs` | ❌ W0 | ⬜ pending |
| TBD | REL-01 | Live bar met: <10% failure, ≥5 consecutive green on `main` `ci-gate` | integration (log-assert) | `scripts/ci/reliability-report.sh` exits 0 on live `main` history | ❌ W0 | ⬜ pending |
| TBD | REL-02 | #2 (`demo.up --check`) lanes green on push | integration (log-assert) | `gh run view <push-run> --json jobs -q '…Example…/.conclusion=="success"'` | ✅ live CI | ⬜ pending |
| TBD | REL-02 | #3 (Accrue path-dep) lane green on push | integration (log-assert) | `gh run view <push-run> --json jobs -q '…Accrue…/.conclusion=="success"'` | ✅ live CI | ⬜ pending |
| TBD | REL-02 | If quarantined: tracking issue linked in backlog | doc-contract | grep backlog for `#<issue>` | N/A unless quarantine | ⬜ pending |
| TBD | REL-03 | `test_seed_zero` exists, nightly-gated, runs `--seed 0`, wired into `nightly-gate` needs+tokens | contract (ci.yml parse) | `mix test test/chimeway/release_gate_contract_test.exs` (extended) | ⚠️ existing, new assertions | ⬜ pending |
| TBD | REL-03 | Lane green on a real nightly dispatch | integration (log-assert) | `gh workflow run ci.yml -f run_nightly=true` then assert `test_seed_zero` success | ❌ W0 (live proof) | ⬜ pending |
| TBD | REL-04 | `put_env` helper restores prior value + deletes when absent | unit | `mix test test/chimeway/test_support/env_helper_test.exs` | ❌ W0 | ⬜ pending |
| TBD | REL-04 | async DataCase modules adopt helper (no raw `put_env` in async modules) | contract (grep) | adoption assertion in a contract test | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/ci/reliability-report.sh` — REL-01 measurement (new)
- [ ] `test/fixtures/ci/run_list_sample.json` — fixture for the parser test (new)
- [ ] `test/chimeway/ci_reliability_contract_test.exs` — REL-01 parser unit test (new; mirror `ci_observability_contract_test.exs` bash-against-fixture harness)
- [ ] `test/support/env_helper.ex` + `test/chimeway/test_support/env_helper_test.exs` — REL-04 helper + test (new)
- [ ] Extend `test/chimeway/release_gate_contract_test.exs` — nightly-gate needs/tokens for `test_seed_zero`
- [ ] Extend `ci_observability_contract_test.exs` — `test_seed_zero` exemption note + async-DataCase-no-raw-`put_env` adoption assertion
- [ ] `.planning/CI-RELIABILITY-REPORT.md` — committed measured snapshot + run permalinks (durability)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Decision: verified-fixed vs. quarantine for backlog #2/#3 | REL-02 | Judgment call once lanes confirmed green on the phase's own push | Confirm both lanes green on the phase HEAD push run; research recommends verified-fixed for both |

*All other phase behaviors have automated / log-assertable verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 130s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
