---
phase: 75
slug: runtime-prefix-propagation
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-01
---

# Phase 75 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Ecto SQL Sandbox and PostgreSQL |
| **Config file** | `config/test.exs`, `test/support/conn_case.ex`, `test/support/data_case.ex` |
| **Quick run command** | `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.test && mix verify.install_golden && mix verify.runtime_prefix` |
| **Estimated runtime** | ~180 seconds |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs --warnings-as-errors` once Wave 0 creates the file; before that, run the smallest touched test file with `--warnings-as-errors`.
- **After every plan wave:** Run `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors`.
- **Before `/gsd:verify-work`:** `mix ci.test`, `mix verify.install_golden`, and `mix verify.runtime_prefix` must be green.
- **Max feedback latency:** 180 seconds for focused prefix checks; broader CI can run as the final phase gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 75-01-01 | 01 | 0 | RUN-01, RUN-02, RUN-03, RUN-04 | T-75-01 | Prefix test harness creates and tears down isolated `chimeway` schema without leaking app env into public-mode tests | integration harness | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` | no - W0 | pending |
| 75-01-02 | 01 | 0 | RUN-01, RUN-02, RUN-03 | T-75-02 | `Repo.default_options/1` delegates to `Chimeway.Storage.repo_opts/1`, preserves explicit `prefix:` probes, and routes string-source `insert_all` | unit | `MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs --warnings-as-errors` | no - W0 | pending |
| 75-02-01 | 02 | 1 | RUN-01, RUN-02 | T-75-01 | Trigger, duplicate idempotency, lifecycle, traces, and explainability read/write configured schema and not accidental `public` | integration | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` | no - W0 | pending |
| 75-03-01 | 03 | 1 | RUN-04 | T-75-03 | Inbox, admin, trace, and recovery preserve tenant filters and redaction while using configured prefix | integration + focused public tests | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs test/chimeway/inbox_integration_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` | no - W0 | pending |
| 75-04-01 | 04 | 2 | RUN-03 | T-75-02 | Workflow progression, signal routing, digest, webhook ingress, dispatch workers, and direct `Oban.Job` paths use the correct storage/job prefixes | integration | `MIX_ENV=test mix test test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` | no - W0 | pending |
| 75-05-01 | 05 | 2 | RUN-01, RUN-02, RUN-03, RUN-04 | T-75-01 / T-75-02 / T-75-03 | Focused alias and final gates prove prefixed mode and legacy public mode both remain green | CI alias | `mix verify.runtime_prefix && mix ci.test && mix verify.install_golden` | no - W0 | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] `test/support/prefixed_runtime_case.ex` - serialized prefix env and DB/schema/migration setup for prefixed runtime integration tests.
- [ ] `test/chimeway/repo_prefix_test.exs` - unit guardrails for `Repo.default_options/1`, `Storage.repo_opts/1`, explicit prefix override preservation, and string-source `insert_all` routing proof.
- [ ] `test/chimeway/runtime_prefix_integration_test.exs` - prefixed runtime integration proof for RUN-01 through RUN-04.
- [ ] `mix verify.runtime_prefix` - focused local gate for the Wave 0 guardrails and prefixed runtime integration suite.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| PostgreSQL 15 compatibility | RUN-01, RUN-02, RUN-03, RUN-04 | Local development may run PostgreSQL 14 while the project target is PostgreSQL 15+ | Treat green CI or a local PostgreSQL 15 service run of `mix verify.runtime_prefix` as final proof |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency target documented.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
