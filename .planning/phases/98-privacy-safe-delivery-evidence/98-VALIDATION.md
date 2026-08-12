---
phase: 98
slug: privacy-safe-delivery-evidence
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-12
---

# Phase 98 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Ecto SQL/PostgreSQL integration |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `env MIX_ENV=test mix test test/chimeway/privacy_test.exs test/chimeway/privacy_boundary_test.exs test/chimeway/trigger_sanitization_test.exs test/chimeway/telemetry_integration_test.exs test/chimeway/traces_test.exs test/chimeway/admin_test.exs --warnings-as-errors && (cd chimeway_admin && env MIX_ENV=test mix test test/chimeway_admin/live/privacy_leak_live_test.exs --warnings-as-errors)` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | Measured during Wave 0 |

---

## Sampling Rate

- **After every task commit:** Run the focused ExUnit files touched by the task with `--warnings-as-errors`.
- **After every plan wave:** Run `mix ci`; additionally run `mix verify.install_golden && mix verify.runtime_prefix` after migration or installer work.
- **Before phase verification:** Full suite and all phase-specific `verify.*` commands must be green.
- **Max feedback latency:** Keep the per-task focused run below 60 seconds; split commands if measured latency exceeds this bound.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 98-01-01 | 01 | 1 | PRIV-03, PRIV-04 | T-98-01/T-98-02 | A hostile adapter result becomes bounded durable attempt evidence and a tenant-scoped safe trace. | auto/integration | `env MIX_ENV=test mix test test/chimeway/privacy_boundary_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 98-01-02 | 01 | 1 | PRIV-03 | T-98-03/T-98-04 | Recursive casing, adjacency, empty/singleton, ordering, and atom-safety contracts are explicit. | unit | `env MIX_ENV=test mix test test/chimeway/privacy_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 98-02-01 | 02 | 2 | PRIV-03, PRIV-04 | T-98-02-01/T-98-02-02 | Trigger and delivery-planning writes retain only tenant/domain opaque identity and named safe facts. | integration | `env MIX_ENV=test mix test test/chimeway/trigger_sanitization_test.exs test/chimeway/orchestration/delivery_planning_test.exs --warnings-as-errors` | Existing suites; phase cases pending | ⬜ pending |
| 98-02-02 | 02 | 2 | PRIV-04 | T-98-02-03 | Inbox raw host inputs become tenant-bound opaque query/mutation predicates without behavioral drift. | integration | `env MIX_ENV=test mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors` | Existing suites; phase cases pending | ⬜ pending |
| 98-03-01 | 03 | 3 | PRIV-04 | T-98-03-01 | Adapter success, classified failures, and unknown returns cannot persist or return arbitrary detail. | integration | `env MIX_ENV=test mix test test/chimeway/dispatch/executor_test.exs --warnings-as-errors` | Existing suite; phase cases pending | ⬜ pending |
| 98-03-02 | 03 | 3 | PRIV-03, PRIV-04 | T-98-03-01 | Telemetry merges and Logger failure paths expose typed facts only. | integration | `env MIX_ENV=test mix test test/chimeway/telemetry_integration_test.exs --warnings-as-errors` | Existing suite; phase cases pending | ⬜ pending |
| 98-04-01 | 04 | 4 | PRIV-03, PRIV-04 | T-98-04-01 | Tenant-scoped Explanation/timeline projections retain positive safe facts and zero hostile values. | integration | `env MIX_ENV=test mix test test/chimeway/traces_test.exs --warnings-as-errors` | Existing suite; phase cases pending | ⬜ pending |
| 98-04-02 | 04 | 4 | PRIV-03, PRIV-04 | T-98-04-02/T-98-04-03 | Core Admin DTOs are safe before optional recursive view defense, and rendered Admin surfaces reject nested mixed-case sentinels. | integration | `env MIX_ENV=test mix test test/chimeway/admin_test.exs --warnings-as-errors && (cd chimeway_admin && env MIX_ENV=test mix test test/chimeway_admin/live/privacy_leak_live_test.exs --warnings-as-errors) && mix verify.admin` | Existing suites; phase cases pending | ⬜ pending |
| 98-05-01 | 05 | 4 | PRIV-04 | T-98-05-01/T-98-05-02/T-98-05-03 | Proof output accepts exactly safe facts, rejects forgeries, and claims provider handoff only. | contract | `env MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | Existing suite; phase cases pending | ⬜ pending |
| 98-06-01 | 06 | 5 | PRIV-04 | T-98-04-01/T-98-04-02/T-98-04-04 | Copied migration 034 purges legacy generic evidence in repository/public/prefixed copies and refuses unsafe rollback. | migration/integration | `env MIX_ENV=test mix test test/chimeway/migration_contract_test.exs test/chimeway/install/migrations_test.exs --warnings-as-errors && mix verify.install_golden` | Existing infrastructure; phase cases ❌ W0 | ⬜ pending |
| 98-06-02 | 06 | 5 | PRIV-03, PRIV-04 | T-98-04-03 | Public and prefixed runtimes prove non-vacuous sentinel absence across storage and diagnostics. | integration/full | `mix verify.runtime_prefix && mix ci` | Existing infrastructure; phase cases pending | ⬜ pending |

*Task IDs match finalized PLAN.md decomposition. Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/privacy_test.exs` — recursive case normalization, map/list/keyword handling, mixed shapes, and atom-safety regression coverage for PRIV-03.
- [ ] `test/chimeway/privacy_boundary_test.exs` — adversarial sentinel matrix proving no Chimeway-owned storage or diagnostic surface leaks values for PRIV-03/PRIV-04.
- [ ] Extend Trigger, Deliveries, Telemetry, Traces, core Admin, `chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs`, release-gate, installer-golden, and runtime-prefix suites with phase-specific assertions.

---

## Manual-Only Verifications

All phase behaviors have automated verification. PRIV-03 and PRIV-04 are objectively machine-testable; do not create conversational UAT or human-check checkpoints for them.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Feedback latency stays below 60 seconds for focused checks.
- [ ] `nyquist_compliant: true` set in frontmatter after evidence is green.

**Approval:** pending
