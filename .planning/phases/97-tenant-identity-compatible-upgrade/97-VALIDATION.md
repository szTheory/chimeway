---
phase: 97
slug: tenant-identity-compatible-upgrade
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-11
---

# Phase 97 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Ecto/PostgreSQL integration tests |
| **Config file** | `test/test_helper.exs` and `config/test.exs` |
| **Quick run command** | `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/inbox_query_test.exs test/chimeway/traces_test.exs test/chimeway/admin_test.exs test/chimeway/orchestration/recovery_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.test` |
| **Estimated runtime** | ~120 seconds for focused tests; full-suite runtime varies by PostgreSQL setup |

---

## Sampling Rate

- **After every task commit:** Run the focused test command for the changed context plus `mix format --check-formatted`.
- **After every plan wave:** Run `mix ci.test` plus the applicable `mix verify.install_golden`, `mix verify.runtime_prefix`, `mix verify.inbox`, and `mix verify.admin` entrypoints.
- **Before phase completion:** Run the full suite and all affected named `verify.*` entrypoints; machine-testable tenant isolation must use executable evidence rather than conversational UAT.
- **Max feedback latency:** 120 seconds for focused task-level verification.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 97-W0-01 | TBD | 0 | TENANT-01 | T-97-01 | Tenant identity is immutable and idempotency is isolated by `{tenant_id, idempotency_key}` | DB integration + unit | `mix test test/chimeway/tenant_identity_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 97-W0-02 | TBD | 0 | TENANT-02 | Missing or wrong tenant scope fails closed without cross-tenant existence disclosure | Unit + integration + package contract | `mix test test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors && mix verify.inbox && mix verify.admin` | ❌ W0 | ⬜ pending |
| 97-W0-03 | TBD | 0 | TENANT-03 | Legacy ownership remains unassigned until explicit host reconciliation; both static prefix modes remain valid | Migration contract + installer golden + DB integration | `mix verify.install_golden && mix verify.runtime_prefix` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/tenant_identity_test.exs` — event/notification tenant persistence, immutability, and tenant-scoped idempotency for TENANT-01.
- [ ] `test/chimeway/tenant_scope_contract_test.exs` — core surface matrix plus compatibility failure/success cases for TENANT-02.
- [ ] Installer/migration contract additions — public and prefixed golden outputs, legacy `NULL` rows, machine-readable reporting, explicit assignment, and static-prefix invariants for TENANT-03.
- [ ] `chimeway_inbox` and `chimeway_admin` tenant-context tests — explicit tenant propagation and absent-scope fail-closed behavior for TENANT-02.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Human review may assess API ergonomics, but it does not replace executable acceptance evidence.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing test references.
- [ ] No watch-mode flags.
- [ ] Focused feedback latency is under 120 seconds.
- [ ] `nyquist_compliant: true` is set in frontmatter after validation.

**Approval:** pending
