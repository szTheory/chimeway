---
phase: 01
slug: durable-core-spine
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-23
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Ecto SQL Sandbox |
| **Config file** | `mix.exs`, `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test --only phase1_fast --only phase1_db --only phase1_inbox` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test --only phase1_fast --only phase1_db --only phase1_inbox`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | CORE-01 | — | Stable `notification_key` + version contract is enforced | unit | `mix test test/chimeway/notifier_contract_test.exs --seed 0` | ✅ `test/chimeway/notifier_contract_test.exs` | ✅ green |
| 01-01-02 | 01 | 1 | CORE-02, CORE-04 | — | `trigger/3` rejects missing idempotency key and resolves recipients deterministically | unit | `mix test test/chimeway/trigger_pipeline_test.exs --seed 0` | ✅ `test/chimeway/trigger_pipeline_test.exs` | ✅ green |
| 01-02-01 | 02 | 1 | CORE-03 | — | Event + notification rows persist atomically in a transaction | integration | `mix test test/chimeway/persistence_transaction_test.exs --seed 0` | ✅ `test/chimeway/persistence_transaction_test.exs` | ✅ green |
| 01-02-02 | 02 | 1 | CORE-02, INBX-01 | — | DB constraints prevent duplicate canonical records | integration | `mix test test/chimeway/idempotency_constraint_test.exs --seed 0` | ✅ `test/chimeway/idempotency_constraint_test.exs` | ✅ green |
| 01-03-01 | 03 | 2 | INBX-02 | — | `seen/read/archive` transitions are explicit and non-implicit | integration | `mix test test/chimeway/inbox_state_transition_test.exs --seed 0` | ✅ `test/chimeway/inbox_state_transition_test.exs` | ✅ green |
| 01-03-02 | 03 | 2 | INBX-03 | — | Inbox unread filter and newest-first ordering work without side effects | integration | `mix test test/chimeway/inbox_query_test.exs --seed 0` | ✅ `test/chimeway/inbox_query_test.exs` | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/support/data_case.ex` — SQL sandbox + shared DB helpers
- [x] `test/chimeway/notifier_contract_test.exs` — CORE-01 contract coverage stubs
- [x] `test/chimeway/trigger_pipeline_test.exs` — CORE-02/CORE-04 pipeline stubs
- [x] `test/chimeway/persistence_transaction_test.exs` — CORE-03 atomic persistence stubs
- [x] `test/chimeway/inbox_state_transition_test.exs` — INBX-02 transition semantics stubs
- [x] `test/chimeway/inbox_query_test.exs` — INBX-03 unread/newest-first stubs

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved (2026-04-24)
