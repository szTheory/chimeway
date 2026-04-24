---
phase: 1
phase_name: Durable Core Spine
verified_at: 2026-04-24T03:05:00Z
status: passed
score: 4/4
---

# Phase 1 Verification: Durable Core Spine

## Goal

Deliver the foundational event/notification data model with stable key identity and in-app lifecycle semantics.

## Goal Achievement: ACHIEVED

## Success Criteria

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Developer can define a notifier with stable key/version and trigger it with idempotency input | PASS | `test/chimeway/notifier_contract_test.exs` and `test/chimeway/trigger_pipeline_test.exs` pass with deterministic recipient checks. |
| 2 | Triggering a notifier persists durable event and per-recipient in-app notification records | PASS | `test/chimeway/persistence_transaction_test.exs` verifies event+notification rollback integrity in one transaction. |
| 3 | Recipient inbox supports unread filtering and explicit `seen/read/archive` transitions | PASS | `test/chimeway/inbox_query_test.exs`, `test/chimeway/inbox_state_transition_test.exs`, and `test/chimeway/inbox_integration_test.exs` are green. |
| 4 | Duplicate trigger attempts with same idempotency key do not create duplicate canonical records | PASS | `test/chimeway/idempotency_constraint_test.exs` confirms serial and concurrent duplicate normalization to one canonical event row. |

## Command Evidence

### Plan 01-01 command set

```bash
mix test test/chimeway/notifier_contract_test.exs test/chimeway/trigger_pipeline_test.exs --seed 0
```

Result: PASS (`6 tests, 0 failures`)

### Plan 01-02 command set

```bash
mix test test/chimeway/persistence_transaction_test.exs test/chimeway/idempotency_constraint_test.exs test/chimeway/migration_contract_test.exs --seed 0
```

Result: PASS (`4 tests, 0 failures`)

### Plan 01-03 command set

```bash
mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/inbox_integration_test.exs --seed 0
```

Result: PASS (`6 tests, 0 failures`)

## Requirements Coverage

| Requirement | Status | Verification evidence |
|-------------|--------|-----------------------|
| CORE-01 | PASS | `mix test test/chimeway/notifier_contract_test.exs test/chimeway/trigger_pipeline_test.exs --seed 0` |
| CORE-02 | PASS | `mix test test/chimeway/notifier_contract_test.exs test/chimeway/trigger_pipeline_test.exs --seed 0` and `mix test test/chimeway/idempotency_constraint_test.exs --seed 0` |
| CORE-03 | PASS | `mix test test/chimeway/persistence_transaction_test.exs test/chimeway/idempotency_constraint_test.exs test/chimeway/migration_contract_test.exs --seed 0` |
| CORE-04 | PASS | `mix test test/chimeway/notifier_contract_test.exs test/chimeway/trigger_pipeline_test.exs --seed 0` |
| INBX-01 | PASS | `mix test test/chimeway/persistence_transaction_test.exs test/chimeway/idempotency_constraint_test.exs test/chimeway/migration_contract_test.exs --seed 0` |
| INBX-02 | PASS | `mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/inbox_integration_test.exs --seed 0` |
| INBX-03 | PASS | `mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/inbox_integration_test.exs --seed 0` |

## Security Gate (ASVS L1)

Security gate remains enabled with `block_on: high`.

| Threat ID | Severity | Mitigation check | Status |
|-----------|----------|------------------|--------|
| TM-03-RECIPIENT-IDOR | High | `rg "recipient_identity == \^recipient_identity" lib/chimeway/inbox.ex && mix test test/chimeway/inbox_state_transition_test.exs --seed 0` | PASS |
| TM-03-IMPLICIT-READ-SIDE-EFFECT | High | `mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_integration_test.exs --seed 0` | PASS |
| TM-03-VERIFICATION-DRIFT | Medium | `rg "mix test|CORE-01|INBX-03|PASS" .planning/phases/01-durable-core-spine/VERIFICATION.md` | PASS |

## Notes

- `test/chimeway/trigger_pipeline_test.exs` now runs under `Chimeway.DataCase` because the trigger path performs transactional DB writes.
- All Phase 1 requirements listed in roadmap scope (`CORE-01..04`, `INBX-01..03`) are now backed by executable evidence.
