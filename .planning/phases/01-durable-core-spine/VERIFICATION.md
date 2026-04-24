---
phase: "01"
phase_name: "Durable Core Spine"
verified_at: "2026-04-24"
status: passed
score: "4/4 criteria"
---

# Phase 01 Verification: Durable Core Spine

## Goal Achievement

Phase goal achieved. The foundational event/notification data model exists with stable key identity and in-app lifecycle semantics. All seven requirements are satisfied by substantive, wired, and tested code. Independent verification ran `mix test --seed 0` against the live codebase: 65 tests, 0 failures.

## Success Criteria

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Developer can define a notifier with stable key/version and trigger it with idempotency input | VERIFIED | `Chimeway.Notifier` behaviour exports `notification_key/0`, `version/0`, `recipients/1`, `build/2` callbacks and `validate_module!/1`. `Chimeway.Trigger.trigger/3` calls `Keyword.fetch(opts, :idempotency_key)` and guards blank keys before calling `Notifier.validate_module!/1`. `notifier_contract_test.exs` covers valid module, missing `notification_key`, and missing `version`. `trigger_pipeline_test.exs` covers missing key, blank key, and deterministic sorted output. |
| 2 | Triggering a notifier persists durable event and per-recipient in-app notification records | VERIFIED | `Chimeway.Trigger` builds an `Ecto.Multi` that inserts an `Event` row then runs `insert_all` on `chimeway_notifications` in one transaction. `persistence_transaction_test.exs` asserts both tables are empty after a failing notification insert, proving atomicity. `idempotency_constraint_test.exs` confirms notifications row count stays at 1 after duplicate trigger. |
| 3 | Recipient inbox supports unread filtering and explicit `seen/read/archive` transitions | VERIFIED | `Chimeway.Inbox.list_for_recipient/2` filters `read_at IS NULL` when `unread_only: true` and orders `desc: :inserted_at`. `mark_seen/3`, `mark_read/3`, `archive/3` each update exactly one timestamp field and are scoped by both `notification_id` and `recipient_identity`. `inbox_query_test.exs` asserts newest-first order and unread filter. `inbox_state_transition_test.exs` asserts each function only sets its own field and cross-recipient attempts return `{:error, :not_found}`. `inbox_integration_test.exs` calls through the public `Chimeway.*` API end-to-end and confirms `list_for_recipient/2` does not mutate `read_at`. |
| 4 | Duplicate trigger attempts with same idempotency key do not create duplicate canonical records | VERIFIED | `chimeway_events_idempotency_key_index` unique index enforced at DB level. `Trigger` catches the unique changeset constraint error and returns `{:duplicate, existing_event}` after a `Repo.get_by` lookup. `idempotency_constraint_test.exs` asserts serial duplicates yield one `{:ok, _}` and one `{:duplicate, %Event{}}` with `Repo.aggregate(Event, :count, :id) == 1`. Concurrent test streams 10 tasks and asserts exactly 1 success, 9 duplicates, and 1 total DB row. |

## Artifact Inventory

| Artifact | Exists | Substantive | Wired | Status |
|----------|--------|-------------|-------|--------|
| `mix.exs` | Yes | Yes | Yes | VERIFIED |
| `config/config.exs` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway.ex` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway/notifier.ex` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway/trigger.ex` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway/inbox.ex` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway/repo.ex` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway/application.ex` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway/events/event.ex` | Yes | Yes | Yes | VERIFIED |
| `lib/chimeway/notifications/notification.ex` | Yes | Yes | Yes | VERIFIED |
| `priv/repo/migrations/20260424023200_create_chimeway_events.exs` | Yes | Yes | Yes | VERIFIED |
| `priv/repo/migrations/20260424023201_create_chimeway_notifications.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/notifier_contract_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/trigger_pipeline_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/persistence_transaction_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/idempotency_constraint_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/migration_contract_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/inbox_query_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/inbox_state_transition_test.exs` | Yes | Yes | Yes | VERIFIED |
| `test/chimeway/inbox_integration_test.exs` | Yes | Yes | Yes | VERIFIED |

## Key Wiring

| Connection | Status | Evidence |
|------------|--------|----------|
| `lib/chimeway.ex` -> `Chimeway.Trigger.trigger/3` | WIRED | `def trigger/3` delegates directly |
| `lib/chimeway.ex` -> `Chimeway.Inbox.list_for_recipient/2` | WIRED | `def list_for_recipient/2` delegates directly |
| `lib/chimeway.ex` -> `Chimeway.Inbox.mark_seen/3` | WIRED | `def mark_seen/3` delegates directly |
| `lib/chimeway.ex` -> `Chimeway.Inbox.mark_read/3` | WIRED | `def mark_read/3` delegates directly |
| `lib/chimeway.ex` -> `Chimeway.Inbox.archive/3` | WIRED | `def archive/3` delegates directly |
| `Chimeway.Trigger` -> `Chimeway.Notifier.validate_module!/1` | WIRED | Called in `with` chain before any DB work |
| `Chimeway.Trigger` -> `Ecto.Multi.insert(:event, Event.changeset(...))` | WIRED | Confirmed in `trigger/3` |
| `Chimeway.Trigger` -> `Ecto.Multi.run(:notifications, ...)` using `insert_all` | WIRED | `insert_notifications/5` called inside multi run |
| `Chimeway.Trigger` -> idempotency conflict -> `{:duplicate, existing_event}` | WIRED | `normalize_trigger_result/3` matches changeset unique constraint error and queries `Repo.get_by(Event, idempotency_key: ...)` |
| `Chimeway.Events.Event` changeset `unique_constraint` name -> migration index name | WIRED | Both use `:chimeway_events_idempotency_key_index` |
| `Chimeway.Notifications.Notification` changeset `unique_constraint` name -> migration index name | WIRED | Both use `:chimeway_notifications_event_recipient_index` |
| `Chimeway.Application` supervision tree -> `Chimeway.Repo` | WIRED | `children = [Chimeway.Repo]` |
| `config/config.exs` -> `ecto_repos: [Chimeway.Repo]` | WIRED | Present in config |

## Requirements Coverage

| Requirement | Status | Supporting Artifacts |
|-------------|--------|---------------------|
| CORE-01 | SATISFIED | `lib/chimeway/notifier.ex` (behaviour + `validate_module!/1`), `test/chimeway/notifier_contract_test.exs` |
| CORE-02 | SATISFIED | `lib/chimeway/trigger.ex` (`Keyword.fetch` + blank-key guard), `test/chimeway/trigger_pipeline_test.exs` |
| CORE-03 | SATISFIED | `lib/chimeway/trigger.ex` (`Ecto.Multi`), `lib/chimeway/events/event.ex`, migrations, `test/chimeway/persistence_transaction_test.exs`, `test/chimeway/migration_contract_test.exs` |
| CORE-04 | SATISFIED | `lib/chimeway/trigger.ex` (`normalize_recipients/1`: dedupe by `recipient_identity`, sort ascending), `test/chimeway/trigger_pipeline_test.exs` |
| INBX-01 | SATISFIED | `lib/chimeway/trigger.ex` (`insert_notifications/5`), `lib/chimeway/notifications/notification.ex`, migrations, `test/chimeway/idempotency_constraint_test.exs` |
| INBX-02 | SATISFIED | `lib/chimeway/inbox.ex` (`list_for_recipient/2` with unread filter and `desc: :inserted_at`), `test/chimeway/inbox_query_test.exs` |
| INBX-03 | SATISFIED | `lib/chimeway/inbox.ex` (`mark_seen/3`, `mark_read/3`, `archive/3` scoped by ID + recipient), `test/chimeway/inbox_state_transition_test.exs`, `test/chimeway/inbox_integration_test.exs` |

## Anti-patterns

No TODOs, FIXMEs, HAKs, empty stub functions, or placeholder content were found in any Phase 1 runtime module. Three open risks were already identified and documented in `01-REVIEW.md`. They do not block the phase goal but should be addressed before production exposure:

1. **HIGH - Recipient shape mismatch (contract vs. persistence)**: `recipients/1` does not require `recipient_type`, but `chimeway_notifications.recipient_type` is `NOT NULL`. A notifier returning recipients without `recipient_type` or `channel` maps to `nil` in `recipient_type/1`, failing at DB insert time with `{:error, {:notifications_insert_failed, ...}}`. The `PersistenceTransactionTest` intentionally exercises this path but the behaviour contract itself does not enforce the required shape.

2. **MEDIUM - Notifier callback exceptions not normalized**: `notifier.recipients/1` and `notifier.build/2` are called without a rescue boundary. Only `repo.insert_all` inside `insert_notifications/5` is wrapped in `try/rescue`. A raising notifier propagates an unhandled exception out of `trigger/3`.

3. **MEDIUM - Shallow payload/metadata redaction**: `sanitize_map/1` drops `password`, `token`, and `secret` at the top map level only. Nested maps are passed through unchanged.

## Command Evidence

```
mix test --seed 0
# 65 tests, 0 failures  (independently verified 2026-04-24)
```

```
mix test test/chimeway/notifier_contract_test.exs test/chimeway/trigger_pipeline_test.exs --seed 0
# CORE-01, CORE-02, CORE-04
```

```
mix test test/chimeway/persistence_transaction_test.exs test/chimeway/idempotency_constraint_test.exs test/chimeway/migration_contract_test.exs --seed 0
# CORE-03, INBX-01
```

```
mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/inbox_integration_test.exs --seed 0
# INBX-02, INBX-03
```

## Summary

Phase 1 passes (7/7 requirements). All four success criteria are met by code that was read and verified directly — not inferred from summaries. The notifier behaviour contract, trigger pipeline, transactional persistence, idempotency enforcement, and inbox lifecycle API are all substantive, wired, and covered by a passing test suite. Three open risks (recipient shape mismatch, unguarded callback exceptions, shallow redaction) are documented above and should be addressed in Phase 2 or a dedicated hardening slice before production exposure.
