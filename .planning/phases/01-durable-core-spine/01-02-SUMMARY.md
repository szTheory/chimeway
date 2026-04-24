---
phase: 01-durable-core-spine
plan: "02"
subsystem: database
tags: [ecto, postgres, idempotency, notifications, persistence]
requires:
  - phase: 01-01
    provides: notifier contract validation and deterministic recipient normalization
provides:
  - Durable event persistence with database-enforced idempotency.
  - Per-recipient notification persistence with uniqueness guarantees.
  - Transactional trigger behavior with duplicate normalization and rollback coverage.
affects: [01-03, phase-2-delivery-planning, operator-explainability]
tech-stack:
  added: [jason]
  patterns: [Ecto.Multi transactional writes, idempotency conflict normalization, SQL sandbox integration tests]
key-files:
  created:
    - lib/chimeway/repo.ex
    - lib/chimeway/events/event.ex
    - lib/chimeway/notifications/notification.ex
    - priv/repo/migrations/20260424023200_create_chimeway_events.exs
    - priv/repo/migrations/20260424023201_create_chimeway_notifications.exs
    - test/support/data_case.ex
    - test/chimeway/persistence_transaction_test.exs
    - test/chimeway/idempotency_constraint_test.exs
    - test/chimeway/migration_contract_test.exs
  modified:
    - lib/chimeway/application.ex
    - config/dev.exs
    - config/test.exs
    - lib/chimeway/trigger.ex
    - mix.exs
    - mix.lock
    - test/test_helper.exs
key-decisions:
  - "Persist event and notification fanout in one Ecto.Multi transaction rooted at event insert."
  - "Normalize unique idempotency conflicts into deterministic {:duplicate, existing_event} responses."
  - "Sanitize payload and metadata maps by dropping password/token/secret keys before persistence."
patterns-established:
  - "Pattern 1: Canonical event row is inserted before notification fanout, with notifications written in the same transaction."
  - "Pattern 2: Duplicate idempotency keys are treated as expected control flow, not exceptional failures."
requirements-completed: [CORE-03, INBX-01, CORE-02]
duration: 13 min
completed: 2026-04-24
---

# Phase 01 Plan 02: Durable Persistence and Idempotency Summary

**Transactional event and notification persistence now enforces durable idempotency and rollback-safe fanout with database-backed guarantees.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-04-24T02:31:10Z
- **Completed:** 2026-04-24T02:44:45Z
- **Tasks:** 3
- **Files modified:** 16

## Accomplishments
- Added `Chimeway.Repo` supervision and concrete event/notification schemas aligned with durable identity constraints.
- Landed migrations with named unique indexes for idempotency and per-recipient uniqueness, plus inbox query index.
- Reworked trigger execution to use `Ecto.Multi` transaction boundaries, deterministic duplicate normalization, and payload/metadata sanitization.
- Added SQL sandbox support and integration tests for rollback integrity, serial/concurrent duplicate behavior, and migration contracts.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Repo, Event schema, and Notification schema with required fields** - `0cb5c6f` (feat)
2. **Task 2: Add migrations with explicit index names for idempotency and inbox access** - `74af6c8` (feat)
3. **Task 3: Wire Ecto.Multi transactional persistence and idempotency tests** - `98f85b7` (feat)

Additional verification compliance fix:

- **Post-task verification fix:** `0f81eaa` (fix) - aligned migration index declaration formatting with mandatory verification regex checks.

**Plan metadata:** Pending (included in this completion commit)

## Files Created/Modified
- `lib/chimeway/repo.ex` - Defines Ecto repository for `:chimeway`.
- `lib/chimeway/events/event.ex` - Canonical event schema with idempotency unique constraint mapping.
- `lib/chimeway/notifications/notification.ex` - Per-recipient notification schema with lifecycle fields.
- `priv/repo/migrations/20260424023200_create_chimeway_events.exs` - Creates durable events table and named idempotency index.
- `priv/repo/migrations/20260424023201_create_chimeway_notifications.exs` - Creates notifications table with named uniqueness/inbox indexes.
- `lib/chimeway/trigger.ex` - Adds transactional persistence flow, duplicate normalization, and sanitization.
- `test/support/data_case.ex` - SQL sandbox ownership helper for DB tests.
- `test/chimeway/persistence_transaction_test.exs` - Verifies event/notification rollback integrity.
- `test/chimeway/idempotency_constraint_test.exs` - Verifies serial and concurrent duplicate handling with one canonical event.
- `test/chimeway/migration_contract_test.exs` - Verifies required tables and named indexes exist.
- `mix.exs` / `mix.lock` - Adds `jason` dependency required for map-field encoding in Postgres operations.

## Decisions Made
- Chose `repo.insert_all("chimeway_notifications", rows)` in transaction step to keep fanout persistence explicit and batch-oriented.
- Preserved deterministic recipient normalization from Plan 01-01 while shifting trigger output toward persistence-first responses.
- Kept security data minimization in trigger persistence path via top-level sensitive-key removal.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing Repo DB configuration prevented migration execution**
- **Found during:** Task 2 (migration verification)
- **Issue:** `mix ecto.migrate` failed with missing `:database` / invalid role defaults.
- **Fix:** Added environment-aware `Chimeway.Repo` configuration in `config/dev.exs` and `config/test.exs`.
- **Files modified:** `config/dev.exs`, `config/test.exs`
- **Verification:** `mix ecto.create && mix ecto.migrate` succeeded.
- **Committed in:** `74af6c8`

**2. [Rule 1 - Bug] Schema type spec used undefined `t/0`**
- **Found during:** Task 2 verification compile step
- **Issue:** `@spec changeset(t(), ...)` caused compile failure.
- **Fix:** Removed invalid `t/0` specs from schema modules.
- **Files modified:** `lib/chimeway/events/event.ex`, `lib/chimeway/notifications/notification.ex`
- **Verification:** Compilation succeeded and migrations executed.
- **Committed in:** `74af6c8`

**3. [Rule 3 - Blocking] Map encoding failed without `jason` dependency**
- **Found during:** Task 3 test execution
- **Issue:** Postgres encoding for `:map` fields raised `Jason.encode_to_iodata!/1` undefined.
- **Fix:** Added `{:jason, "~> 1.4"}` dependency.
- **Files modified:** `mix.exs`, `mix.lock`
- **Verification:** Persistence and idempotency tests passed with map payload/metadata values.
- **Committed in:** `98f85b7`

**4. [Rule 1 - Bug] `insert_all` UUID values required binary format**
- **Found during:** Task 3 idempotency test execution
- **Issue:** `insert_all("chimeway_notifications", rows)` failed with UUID encode errors.
- **Fix:** Dumped generated UUIDs to binary with `Ecto.UUID.dump!/1` for `id` and `event_id`.
- **Files modified:** `lib/chimeway/trigger.ex`
- **Verification:** Serial and concurrent duplicate tests passed.
- **Committed in:** `98f85b7`

**5. [Rule 3 - Blocking] Verification regex required single-line index declarations**
- **Found during:** Plan-level verification checklist
- **Issue:** Required `rg` patterns failed because index declarations were multi-line.
- **Fix:** Reformatted named unique index declarations to single-line statements.
- **Files modified:** `priv/repo/migrations/20260424023200_create_chimeway_events.exs`, `priv/repo/migrations/20260424023201_create_chimeway_notifications.exs`
- **Verification:** Both `rg` verification commands passed exactly as defined in plan.
- **Committed in:** `0f81eaa`

---

**Total deviations:** 5 auto-fixed (2 bug fixes, 3 blocking fixes)  
**Impact on plan:** All deviations were execution blockers or correctness fixes required to satisfy acceptance and security verification gates; no scope creep.

## Issues Encountered
- Hex token refresh prompted interactively during dependency install; resolved by running dependency/test commands with isolated `HEX_HOME` for non-interactive execution.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Durable event and notification persistence baseline is complete and verified under serial/concurrent idempotency load.
- Plan 01-03 can now build inbox query/state APIs on top of persisted notification lifecycle fields.
- No outstanding blockers for the next plan.

---
*Phase: 01-durable-core-spine*  
*Completed: 2026-04-24*
