# Research: Phase 2 — First Outbound Delivery Slice

## Overview

Phase 2 adds the outbound delivery spine that Phase 1 deliberately deferred: per-channel delivery rows (`chimeway_deliveries`), attempt records (`chimeway_delivery_attempts`), an adapter behaviour contract that keeps provider code out of core, and two concrete adapters (Test and Logger) that prove the contract without requiring a live provider. The phase must produce an end-to-end verifiable path from `Chimeway.trigger/3` through delivery planning, sync dispatch, adapter call, attempt persistence, and final state transition — all in one traceable data chain.

The central design constraint carried forward from Phase 1 is that data must be written before external calls, state must be explicit and queryable, and adapters must be swappable by config without touching core. Three risks dominate: (1) coupling adapter call sites to core before the behaviour contract is locked, (2) recording only final delivery status without attempt rows (destroying forensic traceability), and (3) diverging delivery lifecycle states from the terminal/retryable semantics Phase 3's Oban path will assume.

---

## Existing Foundation (from Phase 1)

Phase 1 shipped a fully operational event-and-notification core. The following modules and patterns are directly reusable or extendable in Phase 2.

**Schemas and tables (additive only — no changes needed):**
- `Chimeway.Events.Event` / `chimeway_events` — UUID PK, `notification_key`, `notification_version`, `idempotency_key`, `payload`, unique index on `idempotency_key`
- `Chimeway.Notifications.Notification` / `chimeway_notifications` — UUID PK, `event_id` FK, `recipient_identity`, `recipient_type`, `seen_at`, `read_at`, `archived_at`, `metadata`, unique index on `(event_id, recipient_identity)`

**Core modules:**
- `Chimeway.Trigger` — deterministic pipeline: validate → resolve recipients → `Ecto.Multi` transaction → `{:ok, ...}` / `{:duplicate, ...}` / `{:error, ...}` outcomes. Phase 2 extends this to call dispatch after notification creation.
- `Chimeway.Notifier` — behaviour with `notification_key/0`, `version/0`, `recipients/1`, `build/2` callbacks. Phase 2 adds channel-intent logic in the trigger/planner layer, not inside adapters.
- `Chimeway.Inbox` — explicit lifecycle transitions and side-effect-free queries. Delivery planning must not mutate inbox state.
- `Chimeway.Repo` — standard Ecto Repo under application supervision; SQL sandbox in tests.

**Patterns established:**
- `Ecto.Multi` for transactional writes with explicit rollback
- Tagged returns: `{:ok, ...}` / `{:error, reason}` / `{:duplicate, struct}` everywhere
- Unique DB constraints as source-of-truth for idempotency (not application-level checks alone)
- Payload/metadata sanitization (`sanitize_payload/1`, `sanitize_metadata/1`) before any write
- `recipient_identity` as the stable string key across all per-recipient tables
- Tests tagged by behaviour slice (`@moduletag :phase1_fast`, `:phase1_db`, etc.)

**Naming and migration conventions to mirror:**
- Tables prefixed `chimeway_`
- UUID PKs using `primary_key: false` + explicit `add :id, :uuid, primary_key: true`
- Named indexes for every unique constraint (allows changeset `unique_constraint` to reference by name)
- `timestamps(type: :utc_datetime_usec)` everywhere

---

## Topic 1: Delivery Row Lifecycle States

**Confidence:** HIGH

Phase 2 must define the canonical state set used by Phase 3 policy and Phase 4 trace queries. Changing state names later requires a data migration, so lock them now.

**Recommended states:**

| State | Meaning | Terminal? |
|-------|---------|-----------|
| `pending` | Planned, not yet dispatched | No — retryable |
| `dispatched` | Enqueued or in-flight (set before adapter call) | No |
| `succeeded` | Provider confirmed acceptance | Yes |
| `failed` | Attempt made, terminal failure for this attempt | No — retryable in Phase 3 |
| `suppressed` | Policy or preference blocked delivery | Yes — not retryable |
| `cancelled` | Explicitly cancelled before dispatch | Yes |

Critical distinction: `failed` is NOT `suppressed`. `failed` means the attempt happened and the provider rejected or was unreachable. Phase 3 Oban will retry `failed` deliveries. `suppressed` and `cancelled` are truly terminal and should never be retried.

**Ecto.Enum implementation:**

```elixir
field :status, Ecto.Enum,
  values: [:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled],
  default: :pending
```

Using `Ecto.Enum` rather than a bare `:string` field provides: compile-time validation of allowed values, readable DB storage (`"pending"` not an integer), and safe pattern matching on atoms in application code. Avoid integer enums — they are unreadable in DB queries and destroy operator debuggability.

**Guarded state transitions** in the `Chimeway.Deliveries` context module:

```elixir
@allowed_transitions %{
  pending: [:dispatched, :suppressed, :cancelled],
  dispatched: [:succeeded, :failed, :suppressed],
  failed: [:dispatched]  # Phase 3 will re-enter dispatched on retry
}

def transition_status(%Delivery{} = delivery, new_status) do
  allowed = Map.get(@allowed_transitions, delivery.status, [])
  if new_status in allowed do
    delivery |> change(status: new_status) |> Repo.update()
  else
    {:error, {:invalid_transition, from: delivery.status, to: new_status}}
  end
end
```

This approach keeps transition guards in the context module, not scattered across caller sites.

**Key implementation note:** The `dispatched` state must be set before the adapter is called. If the adapter call happens without first transitioning to `dispatched`, a crash between the adapter call and the DB write leaves the delivery in `pending` with no record that an attempt occurred. The Ecto.Multi in the sync dispatcher must set `dispatched` as step one.

---

## Topic 2: Attempt Tracking Schema

**Confidence:** HIGH

Every provider call must create one `chimeway_delivery_attempts` row regardless of outcome. Attempt rows are the forensic record. A delivery with `status: failed` and no attempt rows is unexplainable.

**`chimeway_delivery_attempts` columns:**

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `delivery_id` | UUID FK → `chimeway_deliveries`, not null | Index required for FK performance |
| `outcome` | string (Ecto.Enum) | `:succeeded`, `:failed`, `:bounced`, `:rejected` |
| `provider_response` | map/jsonb | compact, redacted; no full response bodies |
| `inserted_at` | utc_datetime_usec | timestamp of this attempt; no `updated_at` (attempts are immutable) |

Attempts are append-only. No `updated_at`. No status transitions on attempt rows. The delivery row transitions; the attempt row is a permanent record of what happened at that point in time.

**Outcome classification (done in dispatcher, not adapter):**

| Adapter return | Attempt `outcome` | Delivery `status` |
|---------------|-------------------|--------------------|
| `{:ok, meta}` | `:succeeded` | `succeeded` |
| `{:error, :temporary, detail}` | `:failed` | `failed` |
| `{:error, :permanent, detail}` | `:rejected` | `failed` |
| `{:error, :bounced, detail}` | `:bounced` | `failed` |

Note: both `:temporary` and `:permanent` adapter errors lead to `delivery.status = :failed`. The distinction is captured in `attempt.outcome` (`:failed` vs `:rejected`) and becomes meaningful for Phase 3 retry policy: permanent rejections should not be retried.

**Ecto.Enum for outcome:**

```elixir
field :outcome, Ecto.Enum, values: [:succeeded, :failed, :bounced, :rejected]
```

**Migration notes:**
- Delivery attempts table has no `updated_at` — do not use `timestamps()` macro; use `add :inserted_at, :utc_datetime_usec, null: false` explicitly.
- Add `create index(:chimeway_delivery_attempts, [:delivery_id])` for FK performance and delivery-to-attempts query efficiency.
- FK: `references(:chimeway_deliveries, type: :uuid, on_delete: :delete_all)` — cascade delete is appropriate since attempts have no meaning without their delivery.

---

## Topic 3: Adapter Behaviour Contract

**Confidence:** HIGH

The adapter contract must be locked in Plan 02-02 before any concrete adapter implementation. Everything else (dispatcher wiring, test harness, contract tests) depends on this shape being stable.

**`Chimeway.Adapter` behaviour:**

```elixir
defmodule Chimeway.Adapter do
  @moduledoc """
  Behaviour contract for outbound delivery adapters.

  Adapters receive a pre-planned `%Chimeway.Delivery{}` struct and deliver it
  to the provider. Adapters must not call back into notifier modules to render
  content — all rendered content must be present on the delivery struct before
  `deliver/2` is called.

  Adapter config (API keys, from addresses, etc.) is passed as a keyword list
  at call time from `Application.get_env/3`. Never hardcode config at compile time.

  Return shapes:
  - `{:ok, meta}` — provider accepted the delivery; `meta` is a compact map
    written to `chimeway_delivery_attempts.provider_response`. Redact sensitive
    fields from `meta` before returning.
  - `{:error, reason_class, detail}` — delivery failed; `reason_class` is one of
    `:temporary | :permanent | :bounced`; `detail` is a compact map (no PII,
    no full response bodies).
  """

  @callback deliver(delivery :: term(), config :: keyword()) ::
              {:ok, map()} | {:error, atom(), map()}
end
```

**Design decisions locked by this contract:**

1. Single delivery per call (no batching). Maps cleanly to one attempt row per call. Batching is a premature optimization and would complicate attempt tracking.

2. Three-tuple error return `{:error, reason_class, detail}` rather than two-tuple `{:error, reason}`. The `reason_class` is required for Phase 3 retry policy. The detail map provides context for the attempt record without leaking full provider responses.

3. Config at call time via `Application.get_env`. Never read config in module attributes or `@config`. This supports test overrides via `Application.put_env` in test setup and runtime environment switching.

4. Adapters must not render content. The `%Chimeway.Delivery{}` struct must carry all content needed by the adapter. This prevents circular coupling (adapter → notifier module) and keeps adapters thin and swappable.

**What the `%Chimeway.Delivery{}` struct needs for adapters:**

The struct must carry enough information that an adapter has everything it needs without callbacks into core:
- `id` — delivery UUID
- `channel` — which channel this delivery targets
- `notification_id` — for traceability
- `recipient_identity` — who to deliver to
- `metadata` — rendered content or content references (subject, body, template refs)
- `status` — current state

The planner's job is to populate `metadata` with everything the adapter will need before the adapter is called.

---

## Topic 4: Test/Log Adapter Implementation

**Confidence:** HIGH

Two adapters ship in Phase 2: `Chimeway.Adapters.Test` and `Chimeway.Adapters.Logger`. Together they satisfy INTG-02 ("at least one outbound adapter seam") without requiring a live provider or network dependency.

**`Chimeway.Adapters.Test` — Swoosh.Adapters.Test pattern:**

Swoosh's test adapter is the canonical Elixir reference implementation. It stores sent emails in the process dictionary (or agent) so ExUnit tests can assert on what was delivered without side effects. The pattern:

```elixir
defmodule Chimeway.Adapters.Test do
  @behaviour Chimeway.Adapter

  def deliver(delivery, _config) do
    store_delivery(delivery)
    {:ok, %{adapter: "test", delivered_at: DateTime.utc_now()}}
  end

  defp store_delivery(delivery) do
    deliveries = Process.get(:chimeway_test_deliveries, [])
    Process.put(:chimeway_test_deliveries, [delivery | deliveries])
  end

  def delivered_messages() do
    Process.get(:chimeway_test_deliveries, [])
  end

  def assert_delivered(%Chimeway.Delivery{} = expected) do
    delivered = delivered_messages()
    unless Enum.any?(delivered, &match_delivery?(&1, expected)) do
      raise ExUnit.AssertionError,
        message: "Expected delivery not found in test adapter store.\nExpected: #{inspect(expected)}\nDelivered: #{inspect(delivered)}"
    end
    :ok
  end
end
```

Key design points:
- Process dictionary storage ensures test isolation without shared state between test processes
- `assert_delivered/1` produces a readable failure message (not a generic assertion error)
- No GenServer or ETS needed for basic test isolation; process dictionary is sufficient and simpler
- If async tests need shared assertion, a test-scoped Agent can be introduced later

**`Chimeway.Adapters.Logger` — zero-dependency adapter:**

```elixir
defmodule Chimeway.Adapters.Logger do
  @behaviour Chimeway.Adapter
  require Logger

  def deliver(delivery, _config) do
    Logger.info("[chimeway_delivery]",
      channel: delivery.channel,
      recipient_identity: delivery.recipient_identity,
      notification_key: delivery.notification.notification_key  # via preload or metadata field
    )
    {:ok, %{adapter: "logger", logged: true}}
  end
end
```

Key design points:
- Log line includes only tagged metadata fields — never the full `metadata` map from the delivery (which may contain rendered content or sensitive data)
- Always returns `{:ok, ...}` — logger adapter never fails
- No state, no external dependencies, safe for any environment including production debugging

**Why not Swoosh in Phase 2?**

The Test/Logger adapters satisfy INTG-02 and prove the behaviour contract without adding a dependency. Swoosh requires: (1) an email renderer callback added to the notifier contract, (2) a concrete `%Swoosh.Email{}` struct construction in the adapter, and (3) Swoosh itself as an optional dependency. These are valid Phase 2 additions but are not required to prove the adapter seam. The contract established in Phase 2 is designed to be Swoosh-compatible (single-delivery call, keyword config, redacted metadata return) so adding a Swoosh adapter later requires zero changes to core.

---

## Topic 5: Delivery Planning Integration

**Confidence:** HIGH

Delivery planning is the bridge between Phase 1 (notification rows created per recipient) and Phase 2 (delivery rows created per recipient × channel). The planner must run after notification creation in the same trigger pipeline.

**Integration point in `Chimeway.Trigger`:**

The existing `Ecto.Multi` in `Chimeway.Trigger.trigger/3` ends after inserting notifications. Phase 2 adds a dispatch call after that transaction completes:

```elixir
# Existing Phase 1 Multi:
Ecto.Multi.new()
|> Ecto.Multi.insert(:event, event_changeset)
|> Ecto.Multi.run(:notifications, &insert_notifications/3)
|> Repo.transaction()
|> normalize_trigger_result(...)

# Phase 2 extension: after the transaction, call dispatch
# Option A: extend the Multi (single transaction, maximum atomicity)
|> Ecto.Multi.run(:deliveries, fn _repo, %{notifications: notifications} ->
  plan_deliveries(notifications, channels)
end)

# Option B: call dispatcher after transaction returns (two-phase)
# with {:ok, result} <- Repo.transaction(multi) do
#   dispatcher.dispatch(result.notifications, opts)
# end
```

**Recommendation: Option A (extend the Multi)** for planning delivery rows in the same transaction as notification creation. This ensures events, notifications, and delivery rows are atomic. The adapter call itself (Option B territory) must happen outside the planning transaction because: (a) adapter calls can be slow/fail, and (b) holding a DB transaction open during an HTTP call blocks connection pool resources.

**Channel resolution: where does the channel list come from?**

The `Chimeway.Notifier` behaviour currently has `recipients/1` returning a list of recipient maps. Phase 2 needs channels per recipient. Decision from 02-CONTEXT.md (D-02): hybrid intent model — notifier declares recipient-level intent including channel preferences, but the planner expands and classifies channels, not the adapter.

Practical implementation: extend the recipient map returned by `recipients/1` to include a `channels` key, or add a separate `channels/2` callback to the notifier behaviour. The `channels/2` approach keeps the contract explicit:

```elixir
# Option: add channels/2 to Chimeway.Notifier behaviour
@callback channels(params :: map(), recipient :: map()) :: [atom()]
# returns e.g. [:in_app, :email]

# Planner then iterates:
# for recipient <- recipients, channel <- notifier.channels(params, recipient) do
#   plan_delivery(notification_id, channel)
# end
```

If adding `channels/2` to the notifier behaviour, it must be validated in `Chimeway.Notifier.validate_module!/1` alongside existing callbacks.

**Idempotent planning:**

The delivery planner must be idempotent: calling plan with the same `(notification_id, channel)` twice must create exactly one delivery row. Enforce via:
- Unique index on `(notification_id, channel)` in the migration
- `on_conflict: :nothing` in `Repo.insert` (or `insert_all`)
- Return `:ok` (not an error) when the row already exists

This directly mirrors Phase 1's idempotency strategy: DB constraint enforces correctness, application returns a normalized "already exists" outcome.

---

## Topic 6: State Transition Patterns

**Confidence:** HIGH

Phase 1 used independent nullable timestamps (`seen_at`, `read_at`, `archived_at`) for inbox lifecycle — a deliberate choice for fields that have independent semantics. Phase 2 delivery status is different: it is a mutually exclusive state machine with ordered transitions. The right pattern here is a single `status` field with guarded transitions.

**Pattern: guard table in context module**

```elixir
@allowed_transitions %{
  pending:    [:dispatched, :suppressed, :cancelled],
  dispatched: [:succeeded, :failed, :suppressed],
  failed:     [:dispatched]  # retry re-enters dispatched
}

def transition_status(%Delivery{} = delivery, new_status) do
  allowed = Map.get(@allowed_transitions, delivery.status, [])
  if new_status in allowed do
    delivery
    |> Delivery.changeset(%{status: new_status})
    |> Repo.update()
  else
    {:error, {:invalid_transition, from: delivery.status, to: new_status}}
  end
end
```

**Why not a changeset-only guard:**

Changeset `validate_change` can check current state against allowed transitions, but it requires passing the current state explicitly or loading the struct. Context-module guards on the loaded `%Delivery{}` struct are more readable and testable than embedded changeset logic for state machines.

**Terminal state protection:**

Wrap the dispatcher to check terminal states before dispatching:

```elixir
@terminal_states [:succeeded, :suppressed, :cancelled]

def dispatch(%Delivery{status: status} = delivery, _opts)
    when status in @terminal_states do
  {:ok, delivery}  # idempotent no-op
end
```

This prevents double-dispatch without a database round-trip for the terminal check.

**Ecto.Enum with Postgres:**

`Ecto.Enum` maps atoms to strings in the DB. Do not use `Ecto.Enum` with a custom Postgres `ENUM` type — use a plain `varchar` column (`add :status, :string, null: false, default: "pending"`) and let `Ecto.Enum` handle the atom-to-string casting. Custom Postgres enums require `ALTER TYPE` for new values, which is a painful OSS library migration. String columns are trivially additive.

---

## Topic 7: Idempotency in Delivery Planning

**Confidence:** HIGH

Phase 1 established idempotency at two layers: (1) event idempotency via unique index on `idempotency_key`, and (2) per-recipient notification uniqueness via unique index on `(event_id, recipient_identity)`. Phase 2 must extend this pattern to the delivery layer.

**Delivery planning idempotency contract:**

Given the same event and the same recipients:
- Each `(notification_id, channel)` pair produces exactly one delivery row
- Repeated calls to the planner produce no duplicates and no errors
- The unique index is the source of truth, not application-level checks

**Implementation:**

```elixir
# Migration:
create unique_index(:chimeway_deliveries, [:notification_id, :channel],
  name: :chimeway_deliveries_notification_channel_index)

# Schema:
unique_constraint(:channel,
  name: :chimeway_deliveries_notification_channel_index)

# Planner:
def plan_delivery(notification_id, channel) do
  changeset = Delivery.changeset(%Delivery{}, %{
    notification_id: notification_id,
    channel: Atom.to_string(channel),
    status: :pending
  })
  Repo.insert(changeset, on_conflict: :nothing, conflict_target: [:notification_id, :channel])
end
```

`on_conflict: :nothing` with `conflict_target` is the correct Ecto pattern for idempotent planning. This returns `{:ok, %Delivery{}}` on both first insert and subsequent no-op inserts (the struct fields may be empty on no-op inserts — handle this by loading the existing row if needed).

**Attempt idempotency:**

Attempt rows are NOT idempotent by design. Each call to the adapter produces a new attempt row. This is correct: retries should create new attempt rows, not overwrite the old one. The attempt table is an append-only log. Do not add a unique constraint to `chimeway_delivery_attempts`.

**Trigger-level idempotency chain:**

```
trigger with idempotency_key
  → unique event row (phase 1 constraint)
    → unique notification rows per (event_id, recipient_identity)  (phase 1 constraint)
      → unique delivery rows per (notification_id, channel)        (phase 2 constraint)
        → attempt rows (append-only, intentionally non-unique)
```

Each layer inherits idempotency from the layer above it. A duplicate trigger that returns `{:duplicate, event}` never reaches the delivery planner.

---

## Key Decisions Needed

The following questions require planner decision — research cannot answer them definitively because they depend on project priorities or have valid tradeoffs either way.

1. **Channel resolution callback shape:** Add `channels/2` to `Chimeway.Notifier` behaviour (explicit, enforced) vs. include channel list in recipient maps returned by `recipients/1` (flexible, implicit). The `channels/2` callback approach is cleaner but requires a migration of existing notifier modules.

2. **Rendered content in `%Chimeway.Delivery{}`:** How does adapter-ready rendered content (email subject, body, template refs) flow into the delivery struct? Options: (a) delivery `metadata` map carries rendered content set by the planner; (b) a separate `render/2` callback on the notifier is called by the dispatcher before the adapter call. Option (a) is simpler and keeps adapters truly stateless; option (b) is more flexible but creates a render→dispatch coupling the planner must manage.

3. **Dispatcher wiring scope in 02-01:** The plan calls for wiring the trigger pipeline to call `Chimeway.Dispatch.Sync.dispatch/2` after notification creation. Should delivery planning happen inside the notification `Ecto.Multi` (fully atomic) or in a separate step after the transaction? Atomic planning is safer for consistency; separate step allows the notification write to succeed even if channel config is missing.

4. **`suppression_reason` and `delay_fallback` column activation:** These columns are added in 02-01 but Phase 3 activates their semantics. The planner must decide whether any Phase 2 code paths write these fields (e.g., setting `suppression_reason` when a channel has no adapter configured) or whether they are schema-present but always nil/false in Phase 2.

5. **Test adapter storage mechanism:** Process dictionary (simple, isolated per-test) vs. ETS table scoped to test process (supports async test helper modules). Process dictionary is sufficient for synchronous tests; if async adapter tests are needed, ETS is the upgrade path.

---

## Recommended Approach

### 02-01: Delivery and Attempt Persistence Model

- Create both migrations in one plan. Mirror the Phase 1 migration pattern exactly: `primary_key: false`, explicit UUID, `timestamps(type: :utc_datetime_usec)`, named unique indexes.
- Include `suppression_reason` (nullable string) and `delay_fallback` (boolean, default false) in the `chimeway_deliveries` migration now. They are schema-present, behavior-inactive until Phase 3. This avoids an alter migration later.
- Attempt migration uses explicit `add :inserted_at` without `updated_at` (attempts are immutable).
- Use `Ecto.Enum` for both `status` (delivery) and `outcome` (attempt) — do not use custom Postgres enum types.
- Implement `Chimeway.Deliveries` as the single context module for both planning and recording. Keep `Chimeway.Delivery` and `Chimeway.DeliveryAttempt` as pure schema modules.
- `plan_delivery/2` uses `on_conflict: :nothing` for idempotent planning.
- `record_attempt/2` must atomically insert the attempt row AND update delivery status in one `Ecto.Multi`.
- Define `Chimeway.Dispatch` behaviour with `dispatch/2` callback and `Chimeway.Dispatch.Sync` stub. Wire trigger pipeline to call dispatch via `Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)` — this is the seam that Phase 3 replaces with Oban.
- Tests: planning is idempotent (duplicate plan creates one row), attempt recording is atomic (rollback test), transition guards reject invalid state changes.

### 02-02: Outbound Adapter Seam and Outcome Classification

- Define `Chimeway.Adapter` behaviour first (Task 1), then implement adapters, then wire the dispatcher (Task 3). This ordering prevents circular design: the dispatcher and adapters cannot be designed in parallel without a locked contract.
- `Chimeway.Adapters.Test`: process dictionary storage for test isolation, `assert_delivered/1` helper with readable failure messages.
- `Chimeway.Adapters.Logger`: structured `Logger.info` with tagged fields only (no metadata blob), always returns `{:ok, ...}`.
- `Chimeway.Dispatch.Sync.dispatch/2` full implementation: load delivery → transition to `dispatched` → call adapter → classify outcome → `record_attempt/2`. All steps 2–5 inside one `Ecto.Multi`.
- Outcome classification lives in the dispatcher, not the adapter. The adapter returns raw result; the dispatcher maps it to attempt outcome and delivery status.
- Terminal state guard: return `{:ok, delivery}` early if delivery is already in `:succeeded`, `:suppressed`, or `:cancelled`.
- Adapter config read via `Application.get_env(:chimeway, [:adapters, channel], [])` at dispatch time.

### 02-03: Adapter Contract Tests and Fake Provider Harness

- `Chimeway.Adapter.ContractTest` uses `defmacro __using__` to inject shared test assertions. The macro pattern is the standard ExUnit shared test approach — see how `DataCase` and `ConnCase` work in Phoenix.
- Shared contract assertions: behaviour satisfaction check (`:erlang.function_exported/3`), success return shape (`{:ok, map}`), redaction assertion (no `token`, `secret`, `api_key` in meta), error return shape for adapters that support failure simulation.
- Apply `use Chimeway.Adapter.ContractTest` in both `test_adapter_test.exs` and `logger_adapter_test.exs`.
- End-to-end integration test (`test/chimeway/integration/delivery_lifecycle_test.exs`) covers Scenario A (in-app), Scenario B (outbound via Test adapter), Scenario C (duplicate trigger idempotency). Tag with `@tag :integration`.
- No Bypass needed for Phase 2 since Test and Logger adapters control their own responses. Document Bypass as the pattern for future HTTP-based adapters.
- Verification anchor: `mix test --only integration` must run the lifecycle test in isolation; `mix test` must pass the full suite.

---

## Pitfalls to Avoid

1. **No attempt rows — only final delivery status.** Every adapter call must create a `chimeway_delivery_attempts` row. Missing attempt rows make "why did this fail?" unanswerable. The attempt schema must exist (from 02-01) before any adapter call (from 02-02).

2. **Adapter call before persistence.** Never call the adapter before transitioning delivery to `dispatched` in the DB. A crash between adapter call and DB write produces an untracked send. Always: persist `dispatched` state → call adapter → persist attempt row → persist final state.

3. **Adapter rendering content.** The adapter must not call back into the notifier or core to render content. The `%Chimeway.Delivery{}` struct must arrive at the adapter already carrying everything needed for the provider call. Violating this creates circular coupling and makes adapters non-replaceable.

4. **Custom Postgres ENUM type for status/outcome.** Use `Ecto.Enum` with a plain `varchar` column, not a custom Postgres `ENUM` type. Postgres ENUM types require `ALTER TYPE` DDL for adding new values, which is painful for OSS library consumers and can't be done inside a transaction on older Postgres versions.

5. **Missing unique constraint on `(notification_id, channel)`.** Without this, repeated calls to the planner create duplicate delivery rows. The Phase 1 event and notification idempotency guarantees become meaningless if delivery rows can be duplicated.

6. **Adapter config at compile time.** Never use module attributes or `@config` for adapter API keys or endpoint URLs. Read via `Application.get_env/3` at call time. Compile-time config prevents test overrides and breaks multi-environment deployment.

7. **Dispatch in the notification transaction.** Keep the adapter call outside the notification `Ecto.Multi`. Holding a DB transaction open during an HTTP call blocks connection pool resources. Plan delivery rows inside the transaction; call the adapter after the transaction commits.

8. **Test adapter with shared global state.** If the Test adapter uses a global Agent or ETS table (not process-scoped), deliveries from one test bleed into another. Use process dictionary for basic isolation, or scope an Agent to the test PID if you need async test support.

---

## References

**Phase 1 patterns directly reusable:**
- `lib/chimeway/trigger.ex` — Ecto.Multi structure, sanitize_payload/sanitize_metadata helpers, normalize_trigger_result pattern
- `lib/chimeway/notifications/notification.ex` — UUID schema, FK, lifecycle fields, unique_constraint naming
- `priv/repo/migrations/20260424023200_create_chimeway_events.exs` — migration template (primary_key: false, named unique index)
- `priv/repo/migrations/20260424023201_create_chimeway_notifications.exs` — FK pattern (`references(:chimeway_events, type: :uuid, on_delete: :delete_all)`)
- `test/chimeway/data_case.ex` — SQL sandbox setup to reuse in new test files

**Elixir ecosystem patterns:**
- `Swoosh.Adapters.Test` source — canonical reference for process-dictionary-based test adapter
- `Ecto.Multi` docs — transactional multi-step writes with conditional steps
- `Ecto.Enum` docs — atom-to-string mapping for readable DB state storage
- `defmacro __using__` with `quote do ... end` — standard ExUnit shared test pattern (used by Phoenix ConnCase/DataCase)
- `Application.get_env/3` with default — runtime config seam for adapter dispatch

**Phase 2 planning artifacts:**
- `.planning/phases/02-first-outbound-delivery-slice/02-CONTEXT.md` — locked decisions (D-01 through D-13) governing this phase
- `.planning/phases/02-first-outbound-delivery-slice/PHASE.md` — module list, DB changes, design decision application
- `.planning/REQUIREMENTS.md` — DLVR-01, DLVR-02, DLVR-03, INTG-01, INTG-02 requirement text

---

*Research date: 2026-04-24*
*Status: RESEARCH COMPLETE*
*Confidence: HIGH overall — standard Elixir/Ecto patterns with well-established Phase 1 foundation*
