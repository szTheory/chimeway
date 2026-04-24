# Phase 1 Pattern Mapping: Durable Core Spine

## 1) Summary and constraints

Phase 1 should be planned as a **durable data and contract phase**, not a "first pass" prototype. Because this repository has no runtime code yet, use canonical Phoenix/Ecto library conventions as the implementation analog and enforce the locked planning decisions as non-negotiable constraints.

Primary planning intent:
- Establish stable notifier identity via persisted `notification_key` + `notification_version`.
- Build a deterministic `trigger/3` flow with explicit idempotency input.
- Persist `events` and per-recipient in-app `notifications` transactionally.
- Expose explicit inbox lifecycle transitions (`seen`, `read`, `archive`) without hidden mutations.

Hard constraints from project artifacts:
- Keep v0.1 in a single `chimeway` package, but preserve extraction seams for future package split.
- Do not persist module names as durable identity.
- Use UUID primary keys and database-enforced uniqueness for idempotency correctness.
- Do not introduce `deliveries`/`attempts` tables in this phase.
- Do not auto-mark notifications as read/seen during inbox reads.

## 2) Target file map for phase 1 (files likely to be created/modified)

The map below is the practical Phoenix/Ecto-oriented baseline for plans `01-01`, `01-02`, and `01-03`.

| File | Role | Plan Link | Expected Action |
|------|------|-----------|-----------------|
| `mix.exs` | Add Ecto/Postgres/test deps and aliases | 01-01, 01-02, 01-03 | Modify |
| `config/config.exs` | Repo + app-level defaults | 01-02 | Create/Modify |
| `config/test.exs` | SQL sandbox + test DB settings | 01-03 | Create/Modify |
| `lib/chimeway/application.ex` | Supervise Repo/processes | 01-02 | Create |
| `lib/chimeway/repo.ex` | Ecto Repo boundary | 01-02 | Create |
| `lib/chimeway.ex` | Public API facade (`trigger`, inbox APIs) | 01-01, 01-03 | Create |
| `lib/chimeway/notifier.ex` | Behaviour contract for notifier modules | 01-01 | Create |
| `lib/chimeway/trigger.ex` | Deterministic trigger pipeline orchestration | 01-01 | Create |
| `lib/chimeway/events/event.ex` | Event schema + changeset + constraints | 01-02 | Create |
| `lib/chimeway/notifications/notification.ex` | Notification schema + lifecycle fields | 01-02 | Create |
| `lib/chimeway/inbox.ex` | Query + state transition APIs | 01-03 | Create |
| `priv/repo/migrations/*_create_chimeway_events.exs` | Durable event table + idempotency index | 01-02 | Create |
| `priv/repo/migrations/*_create_chimeway_notifications.exs` | Recipient rows + lifecycle columns + indexes | 01-02 | Create |
| `test/support/data_case.ex` | Shared DB test setup + sandbox ownership | 01-03 | Create |
| `test/chimeway/trigger_test.exs` | Contract/pipeline correctness tests | 01-01 | Create |
| `test/chimeway/persistence_test.exs` | Transactional event+notification persistence tests | 01-02 | Create |
| `test/chimeway/idempotency_test.exs` | Serial/concurrent duplicate protection tests | 01-02 | Create |
| `test/chimeway/inbox_test.exs` | Lifecycle APIs + query semantics tests | 01-03 | Create |
| `test/chimeway/migration_contract_test.exs` | Schema/index existence assertions | 01-02 | Create |
| `.planning/phases/01-durable-core-spine/01-VALIDATION.md` | Requirement-to-test traceability evidence | 01-03 | Modify |
| `.planning/phases/01-durable-core-spine/VERIFICATION.md` | Command evidence and acceptance logs | 01-03 | Modify |

## 3) Pattern catalog (for each target file role: purpose, concrete coding pattern, anti-patterns)

### Role: public API boundary (`lib/chimeway.ex`)
- **Purpose:** Present stable, small surface area for host apps.
- **Concrete coding pattern:** Keep this module thin; delegate to `Trigger` and `Inbox` modules with explicit return tuples.
- **Anti-patterns to block:** Business logic embedded in facade; broad `defdelegate` to unstable internals; raising exceptions for expected duplicate/idempotency outcomes.

### Role: notifier contract (`lib/chimeway/notifier.ex`)
- **Purpose:** Define explicit, durable contract for notification type identity and recipient resolution.
- **Concrete coding pattern:** Behaviour callbacks include identity (`notification_key`, `version`) and recipient resolver callback with deterministic output requirements.
- **Anti-patterns to block:** Macro-only DSL with hidden runtime semantics; persisting notifier module atoms as durable identity; optional idempotency semantics.

### Role: trigger orchestration (`lib/chimeway/trigger.ex`)
- **Purpose:** Execute a deterministic pipeline from input validation to transactional persistence.
- **Concrete coding pattern:** Validate inputs first, normalize recipients (dedupe/sort), build one `Ecto.Multi` transaction for event + notifications, return explicit outcome (`:ok`, `:duplicate`, `{:error, reason}`).
- **Anti-patterns to block:** Side effects before event persistence; idempotency checks in application memory only; non-deterministic recipient ordering.

### Role: durable schemas (`lib/chimeway/events/event.ex`, `lib/chimeway/notifications/notification.ex`)
- **Purpose:** Encode durable shape, constraints, and lifecycle columns in one canonical place.
- **Concrete coding pattern:** UUID PKs, strict required fields, `unique_constraint` mirrored to DB indexes, explicit `seen_at/read_at/archived_at` nullable timestamps.
- **Anti-patterns to block:** Generic JSON blob as only durable state; storing oversized/sensitive payload by default; flattening lifecycle into one ambiguous status field.

### Role: migrations (`priv/repo/migrations/*.exs`)
- **Purpose:** Make correctness enforceable at DB layer under concurrency.
- **Concrete coding pattern:** Create `chimeway_events` and `chimeway_notifications` only; add unique idempotency index and unique `(event_id, recipient_identity)` index; add inbox query index compatible with unread/newest-first.
- **Anti-patterns to block:** Deferring unique constraints "until later"; adding phase-2 tables early; missing foreign keys or nullability discipline.

### Role: inbox behavior (`lib/chimeway/inbox.ex`)
- **Purpose:** Provide explicit state transitions and query semantics required by INBX requirements.
- **Concrete coding pattern:** Dedicated APIs `mark_seen/2`, `mark_read/2`, `archive/2`; query function supports unread filter and `inserted_at DESC` order; read/query paths are side-effect free.
- **Anti-patterns to block:** "Fetch implies read" behavior; coupled transitions (e.g., `mark_seen` silently setting `read_at`); hidden bulk updates in query paths.

### Role: runtime wiring (`lib/chimeway/application.ex`, `lib/chimeway/repo.ex`, config files)
- **Purpose:** Keep startup and data access idiomatic for Phoenix/Ecto environments.
- **Concrete coding pattern:** Repo supervised under application tree, environment-driven config, sandbox in tests.
- **Anti-patterns to block:** Ad-hoc Repo startup inside business modules; test setup bypassing sandbox ownership; mixed environment config in source modules.

### Role: verification tests (`test/chimeway/*.exs`, `test/support/data_case.ex`)
- **Purpose:** Lock behavior with requirement-oriented slices, not incidental implementation assertions.
- **Concrete coding pattern:** Separate fast contract tests, DB transaction tests, migration/index tests, idempotency race tests, and inbox lifecycle tests; tag tests by slice for targeted reruns.
- **Anti-patterns to block:** Snapshot-style assertions that ignore invariants; only unit tests with no DB constraint coverage; no concurrent idempotency checks.

### Role: planning evidence artifacts (`01-VALIDATION.md`, `VERIFICATION.md`)
- **Purpose:** Prevent shallow "code exists" completion claims by requiring requirement and command evidence.
- **Concrete coding pattern:** Record each CORE/INBX requirement with corresponding tests and explicit verification command outputs.
- **Anti-patterns to block:** Marking plan complete without command evidence; prose-only validation without executable anchors.

## 4) Verification anchors (grep- or command-checkable markers planners can use in acceptance criteria)

Use these as acceptance anchors in plans and validation docs.

| Requirement Area | Anchor Command | Expected Signal |
|------------------|----------------|-----------------|
| Notifier behaviour exists | `rg "defmodule Chimeway\\.Notifier" lib` | Module present |
| Stable key/version callbacks | `rg "@callback (notification_key|version)\\(" lib/chimeway/notifier.ex` | Durable identity callbacks present |
| Trigger API and deterministic pipeline | `rg "def trigger\\(" lib/chimeway` and `rg "Ecto\\.Multi" lib/chimeway/trigger.ex` | Trigger path + transactional orchestration present |
| No phase-2 persistence leakage | `rg "create table\\(:chimeway_(deliveries|attempts)\\)" priv/repo/migrations` | No matches |
| Event idempotency uniqueness | `rg "unique_index\\(:chimeway_events, \\[:idempotency_key\\]" priv/repo/migrations` | Unique idempotency index present |
| Per-recipient uniqueness | `rg "unique_index\\(:chimeway_notifications, \\[:event_id, :recipient_identity\\]" priv/repo/migrations` | Recipient dedupe constraint present |
| Lifecycle fields modeled explicitly | `rg "(seen_at|read_at|archived_at)" lib/chimeway/notifications/notification.ex` | Three lifecycle columns present |
| Explicit lifecycle APIs | `rg "def (mark_seen|mark_read|archive)\\(" lib/chimeway/inbox.ex` | Explicit state transitions present |
| Inbox unread/newest query semantics | `rg "read_at.*is nil|order_by\\(.*desc:.*inserted_at" lib/chimeway/inbox.ex` | Unread filter + descending order present |
| Requirement-tagged tests exist | `rg "(CORE|INBX)-0[1-4]" test/chimeway` | Tests linked to requirements |
| Core tests pass | `mix test test/chimeway/trigger_test.exs test/chimeway/persistence_test.exs test/chimeway/idempotency_test.exs test/chimeway/inbox_test.exs` | Green test run |
| Migration contract passes | `mix test test/chimeway/migration_contract_test.exs` | Schema/index checks green |

Note: if exact file/module names differ, keep the same anchors at equivalent boundaries and update the commands in `VERIFICATION.md` to match final naming.

## 5) Dependency and wave hints

Use waves to avoid shallow parallelism and preserve determinism:

### Wave 0 - scaffolding (blocking)
- Initialize Mix/Ecto structure (`mix.exs`, Repo, application supervision, config).
- Define naming conventions for stable keys and recipient identity field.
- Exit criteria: app boots with Repo in test/dev.

### Wave 1 - contracts and trigger spine (01-01)
- Implement `Notifier` behaviour and `trigger/3` orchestration contract.
- Normalize recipient resolution deterministically before persistence.
- Exit criteria: fast contract tests pass; trigger returns explicit outcomes.

### Wave 2 - durable persistence (01-02)
- Add `events` and `notifications` migrations/schemas with DB uniqueness constraints.
- Wire trigger pipeline into one atomic `Ecto.Multi`.
- Exit criteria: event + fanout rows persist atomically; duplicate idempotency keys are rejected/normalized.

### Wave 3 - inbox lifecycle APIs (01-03)
- Implement query and explicit transition APIs (`seen/read/archive`) in dedicated inbox boundary.
- Ensure query is side-effect free and newest-first with unread filtering.
- Exit criteria: lifecycle and query semantics validated against INBX requirements.

### Wave 4 - verification hardening (cross-plan closeout)
- Add migration-contract and concurrent idempotency tests.
- Update `01-VALIDATION.md` and `VERIFICATION.md` with command evidence.
- Exit criteria: each Phase 1 success criterion has a command-checkable proof anchor.

Dependency notes:
- `01-02` depends on Wave 1 contracts enough to persist stable key/version consistently.
- `01-03` depends on `notifications` schema and indexes from `01-02`.
- Verification wave should not be deferred; treat it as required completion work for each plan, not cleanup.
