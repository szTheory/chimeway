# Phase 2 Research: First Outbound Delivery Slice

**Phase**: 2 — First Outbound Delivery Slice
**Requirements**: DLVR-01, DLVR-02, DLVR-03, INTG-01, INTG-02
**Researched**: 2026-04-23
**Status**: RESEARCH COMPLETE

---

## Executive Summary

Phase 2 adds the outbound delivery spine: per-channel delivery rows, attempt tracking, adapter behaviour contracts, and one working adapter seam. It is the "prove end-to-end" milestone — not adapter breadth. The key architectural insight from Phase 1 is that `chimeway_deliveries` and `chimeway_delivery_attempts` were deferred here intentionally (D-06), meaning Phase 2 must wire the persistence model that Phase 3's Oban path will rely on. Three risks dominate: (1) coupling the adapter call site to core before the behaviour contract is locked, (2) skipping attempt rows and only storing final status, (3) diverging the delivery lifecycle states from what Phase 3 policy and Phase 4 trace queries assume. All three are avoidable with plan sequencing: data model + states first, adapter behaviour second, contract tests third.

The standard stack for this phase is Ecto + PostgreSQL for persistence, explicit `@behaviour` callbacks for the adapter contract, Swoosh as the first concrete adapter seam (or a test/log adapter if Swoosh feels premature), and Mox for contract testing. No new optional dependencies need to be introduced unless the email adapter lands this phase.

---

## 1. Technical Domain: Delivery and Attempt Persistence Model

### Schema design (confidence: HIGH)

Phase 1 established the `chimeway_events` and `chimeway_notifications` tables. Phase 2 adds two tables that complete the lifecycle spine.

**`chimeway_deliveries`** — one row per recipient × channel per event:

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `notification_id` | UUID FK → `chimeway_notifications` | Required for the Phase 3 delay_fallback read-state check (D-08 in Phase 3 context) |
| `channel` | string/atom | `:in_app`, `:email`, `:sms`, `:webhook`, etc. |
| `status` | string | Explicit lifecycle state (see state machine below) |
| `suppression_reason` | string | nullable; plain atom name as string e.g. `"channel_disabled"` (Phase 3 D-06) |
| `delay_fallback` | boolean | default false; used in Phase 3 for read-state recheck |
| `metadata` | map/jsonb | provider-specific metadata, kept compact |
| `inserted_at` | utc_datetime_usec | |
| `updated_at` | utc_datetime_usec | |

**`chimeway_delivery_attempts`** — one row per provider call attempt:

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `delivery_id` | UUID FK → `chimeway_deliveries` | |
| `outcome` | string | `:succeeded`, `:failed`, `:bounced`, `:rejected` |
| `provider_response` | map/jsonb | response code, message ID, HTTP status — compact, no PII |
| `inserted_at` | utc_datetime_usec | timestamp of this attempt |

Both tables must be created in this phase. The Phase 3 `suppression_reason` and `delay_fallback` columns are noted in Phase 3 PHASE.md as `alter` migrations — the planner may choose to include them here in anticipation (cheaper now than a migration later) or defer strictly to Phase 3. Either is valid; document the decision.

### Delivery state machine (confidence: HIGH)

The explicit states align with DLVR-03 and are referenced by Phase 3 policy (terminal state definition) and Phase 4 trace queries:

| State | Meaning |
|-------|---------|
| `pending` | planned, not yet dispatched |
| `dispatched` | enqueued or in-flight |
| `succeeded` | provider confirmed acceptance |
| `failed` | attempt made, terminal failure (retryable in Phase 3 Oban path) |
| `suppressed` | policy or preference blocked delivery (final, not retryable) |
| `cancelled` | explicitly cancelled before dispatch |

**Critical**: `failed` must not be a terminal suppression — it is still retryable (Phase 3 D-05). `suppressed` and `cancelled` are truly terminal. The planner must ensure the state machine transitions are enforced at the Ecto changeset level, not just by convention.

### Idempotency in delivery planning (confidence: HIGH)

DLVR-01 requires planning per-channel delivery rows from the event + recipient set. The planner must be deterministic: same event + same recipients + same channels → same delivery rows (no duplicates). Enforce via a unique index on `(notification_id, channel)` in `chimeway_deliveries`. Duplicate planning attempts should upsert-or-ignore, not create new rows.

This connects to Phase 1's idempotency foundation: if the event is already idempotent, delivery planning over it must also be idempotent.

---

## 2. Technical Domain: Adapter Behaviour Contract

### Behaviour definition pattern (confidence: HIGH)

Following Phase 1 D-03 (explicit behaviour callbacks as primary contract), the adapter seam should be a `Chimeway.Adapter` behaviour:

```elixir
defmodule Chimeway.Adapter do
  @doc """
  Deliver a notification to a single recipient via this channel.
  Returns {:ok, metadata} on acceptance or {:error, reason} on failure.
  """
  @callback deliver(delivery :: Chimeway.Delivery.t(), config :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
```

Key decisions to make during planning:
- **Single-delivery or batch?** Single-delivery per call is simpler and maps cleanly to attempt tracking. Batch is a premature optimization.
- **Config injection:** adapter config (`api_key`, `from_email`, etc.) should be passed as a keyword list at call time from application config, not stored as state. This makes testing and multi-tenancy simpler.
- **Return shape:** `{:ok, metadata}` where `metadata` is a compact map written to `chimeway_delivery_attempts.provider_response`. Never return full response bodies — redact at the adapter level.

### Adapter classification of outcomes (confidence: HIGH)

DLVR-03 requires explicit state classification. The adapter `deliver/2` return is NOT the delivery state — the caller (dispatcher) must classify:

| Adapter return | Delivery outcome | Attempt `outcome` |
|---------------|-----------------|-------------------|
| `{:ok, meta}` | `succeeded` | `:succeeded` |
| `{:error, :temporary}` | `failed` | `:failed` |
| `{:error, :permanent}` | `failed` (terminal class) | `:rejected` |
| `{:error, :bounced}` | `failed` | `:bounced` |

The distinction between temporary and permanent errors is critical for retry semantics (Phase 3 Oban). Phase 2 only uses sync dispatch, but the classification must be in place so Phase 3 doesn't require refactoring the attempt schema.

Recommended: define an `{:error, reason_class, detail}` 3-tuple for adapter errors where `reason_class` is one of `:temporary | :permanent | :bounced` and `detail` is a compact map.

### First outbound adapter seam (confidence: HIGH)

INTG-02 requires at least one adapter seam beyond in-app. Two options:

**Option A: Test/Log adapter (lower risk)**
- `Chimeway.Adapters.Test` — stores deliveries in process memory (similar to Swoosh.Adapters.Test)
- `Chimeway.Adapters.Logger` — logs a structured message, always returns `{:ok, %{logged: true}}`
- Pro: no new dependencies; proves the behaviour contract with zero provider coupling
- Con: doesn't validate email-specific ergonomics (headers, unsubscribe, rendering)

**Option B: Swoosh email adapter (more realistic)**
- Wraps `%Swoosh.Email{}` construction and `Swoosh.Mailer.deliver/2`
- Uses `Swoosh.Adapters.Test` in tests (already the pattern from Swoosh docs)
- Pro: validates real email rendering + adapter ergonomics early
- Con: adds Swoosh as an optional dependency; requires notifier renderer callback for email

**Recommendation (confidence: MEDIUM)**: Plan for the Test/Logger adapter in 02-02 and mention Swoosh as the natural next adapter (either also in 02-02 or as a follow-up). The Test adapter is sufficient to satisfy INTG-02. If the team has email rendering already designed (the notifier `render/2` callback), Swoosh costs little to add alongside.

---

## 3. Technical Domain: Dispatcher (Sync Path)

### Sync dispatcher pattern (confidence: HIGH)

Phase 2 uses sync dispatch (DLVR-04: "System supports sync dispatch for v1"). The dispatcher:

1. Loads the delivery row
2. Calls `policy_check/1` (pre-dispatch; Phase 2 can be a stub that always returns `:proceed` — Phase 3 wires real policy)
3. Calls `adapter.deliver(delivery, config)`
4. Records attempt row with outcome
5. Transitions delivery status

The `Ecto.Multi` pattern is required to keep persistence transactional:

```elixir
Multi.new()
|> Multi.insert(:delivery, delivery_changeset)
|> Multi.run(:dispatch, fn _repo, %{delivery: delivery} ->
  result = adapter.deliver(delivery, config)
  {:ok, result}
end)
|> Multi.insert(:attempt, fn %{delivery: delivery, dispatch: result} ->
  attempt_changeset(delivery, result)
end)
|> Multi.update(:final_delivery, fn %{delivery: delivery, dispatch: result} ->
  status_changeset(delivery, result)
end)
|> Repo.transaction()
```

**Critical**: the attempt row and the delivery status update must happen in the same transaction as the adapter call where possible. For async paths (Phase 3 Oban), the worker handles this within `perform/1`.

### Dispatcher seam for Phase 3 (confidence: HIGH)

Phase 3 will add an Oban dispatcher alongside the sync one. Phase 2 must lay the seam: a `Chimeway.Dispatch` behaviour with a `dispatch/2` callback, and a `Chimeway.Dispatch.Sync` implementation. This mirrors Phase 3's D-01 (resolve dispatcher at call time via `Application.get_env`).

Phase 2 doesn't need to implement the Oban dispatcher — just establish the `Chimeway.Dispatch` behaviour so Phase 3 can add `Chimeway.Dispatch.Oban` without touching existing call sites.

---

## 4. Technical Domain: Adapter Contract Tests

### Contract test pattern (confidence: HIGH)

INTG-01 requires adapters to be replaceable and not core-coupled. The enforcement mechanism is a shared contract test module:

```elixir
defmodule Chimeway.Adapter.ContractTest do
  @moduledoc """
  Include this module in any adapter test to verify it satisfies
  the Chimeway.Adapter behaviour contract.
  """
  defmacro __using__(_) do
    quote do
      test "deliver/2 returns {:ok, map} on success" do
        # test body using adapter-specific setup
      end
      test "deliver/2 returns {:error, reason_class, detail} on failure" do
        # ...
      end
    end
  end
end
```

Usage in adapter test:
```elixir
defmodule Chimeway.Adapters.TestAdapterTest do
  use Chimeway.Adapter.ContractTest
  # adapter-specific setup...
end
```

This ensures every adapter — current and future — passes the same contract assertions. Phase 2 must define and use this contract; Phase 3+ adapters inherit it.

### Fake provider harness (confidence: HIGH)

For HTTP-based adapters (Swoosh with real providers, webhooks, SMS), use `Bypass` to simulate provider responses:
- Success path (200 + message ID)
- Temporary failure (429 rate limit, 503 service unavailable)
- Permanent rejection (400 invalid recipient)
- Bounce callback (if applicable)

For the Test/Logger adapter in Phase 2, Bypass is not needed — the adapter controls its own responses.

---

## 5. Key Pitfalls for This Phase

### Pitfall 1: No attempt rows, only final delivery status (confidence: HIGH)

From PITFALLS.md: "No attempt table, only final status" is never acceptable for production. Every adapter call must create a `chimeway_delivery_attempts` row before transitioning delivery status. This is the forensic record. Missing attempt rows means "why did this fail?" questions are unanswerable.

**Prevention**: Plan 02-01 must add the attempt schema before 02-02 adds the adapter — the attempt row must be in place before any provider call is made.

### Pitfall 2: Adapter call before persistence (confidence: HIGH)

From ARCHITECTURE.md Anti-Pattern 1: sending via provider first, then persisting. If the adapter call succeeds but the DB write fails, the send is untracked. Always: persist delivery row → call adapter → persist attempt row.

### Pitfall 3: Coupling adapter rendering to core (confidence: HIGH)

The adapter receives a `%Chimeway.Delivery{}` struct. It must NOT reach back into the notifier module to call render callbacks — that's core's responsibility. Core renders content before handing to the adapter. The adapter only knows how to deliver pre-rendered content to a provider. Violating this creates circular coupling and makes adapters non-replaceable.

**Prevention**: The `%Chimeway.Delivery{}` struct should carry rendered content (or a content ref) so the adapter call site has everything it needs without callbacks into core.

### Pitfall 4: Delivery state as string vs atom (confidence: MEDIUM)

Storing states as atoms (`succeeded`) or as strings (`"succeeded"`) in the DB has tradeoffs. Ecto Enum type maps atoms to strings cleanly. Avoid bare integer enums — they are unreadable in DB queries and break operator debuggability. Use string-mapped atoms via `Ecto.Enum` or a custom type.

### Pitfall 5: Missing unique constraint on (notification_id, channel) (confidence: HIGH)

Without this index, repeated calls to the delivery planner create duplicate delivery rows. Given Phase 1's idempotency guarantees on events, this constraint is the natural extension to the delivery layer. Add it in the migration.

### Pitfall 6: Adapter config at compile time (confidence: MEDIUM)

Hardcoding adapter config in module attributes or `@config` at compile time prevents runtime environment switching and test overrides. Always read adapter config via `Application.get_env/3` at call time.

---

## 6. Plan Scope Recommendations

### 02-01: Delivery and Attempt Persistence Model

**Scope**:
- `chimeway_deliveries` migration with all required columns (include `suppression_reason` and `delay_fallback` as nullable to avoid a Phase 3 alter migration — decision for the planner)
- `chimeway_delivery_attempts` migration
- `Chimeway.Delivery` Ecto schema with state machine via changeset validations or `Ecto.Enum`
- `Chimeway.DeliveryAttempt` Ecto schema
- Delivery planner logic: event → recipient set → delivery rows (idempotent, unique constraint respected)
- Sync dispatcher skeleton (`Chimeway.Dispatch` behaviour + `Chimeway.Dispatch.Sync` stub)
- Tests: planning creates correct delivery rows; duplicate planning is idempotent; state transitions are enforced

**Not in scope for 02-01**:
- Real adapter calls
- Adapter behaviour definition
- Contract tests

### 02-02: First Outbound Adapter Seam and Outcome Classification

**Scope**:
- `Chimeway.Adapter` behaviour definition with `deliver/2` callback
- `Chimeway.Adapters.Test` (in-memory; mirrors Swoosh.Adapters.Test pattern)
- `Chimeway.Adapters.Logger` (structured log, always succeeds)
- Sync dispatcher wired to adapter call + attempt persistence
- Outcome classification: `{:ok, meta}` → `succeeded`, `{:error, class, detail}` → `failed` with `attempt.outcome` set appropriately
- Integration tests: trigger → deliver → verify delivery status + attempt row for success and failure paths

**Optional in 02-02** (or first follow-up): Swoosh email adapter wrapper if the notifier email renderer is ready.

**Not in scope for 02-02**:
- Oban or async dispatch
- Policy/preference checks (stubbed to always-proceed)
- Contract test module definition (that's 02-03)

### 02-03: Adapter Contract Tests and Fake Provider Harness

**Scope**:
- `Chimeway.Adapter.ContractTest` shared test module
- Apply contract tests to `Chimeway.Adapters.Test` and `Chimeway.Adapters.Logger`
- If Swoosh adapter landed in 02-02: apply contract tests there too, with Bypass for provider simulation
- Fake provider harness (Bypass-based) for HTTP adapters if any HTTP adapter exists this phase
- Verify the full end-to-end path: trigger → event → notification → delivery → attempt for in-app + outbound channel

**Not in scope for 02-03**:
- Policy hardening (Phase 3)
- Oban worker tests (Phase 3)

---

## 7. Dependency and Migration Analysis

### New modules (confidence: HIGH)

- `lib/chimeway/delivery.ex` — Ecto schema for `chimeway_deliveries`
- `lib/chimeway/delivery_attempt.ex` — Ecto schema for `chimeway_delivery_attempts`
- `lib/chimeway/planner.ex` — delivery planning logic (may already have a stub from Phase 1)
- `lib/chimeway/dispatch.ex` — dispatcher behaviour
- `lib/chimeway/dispatch/sync.ex` — sync dispatcher implementation
- `lib/chimeway/adapter.ex` — adapter behaviour
- `lib/chimeway/adapters/test.ex` — test adapter
- `lib/chimeway/adapters/logger.ex` — logger adapter
- `test/support/chimeway/adapter/contract_test.ex` — shared contract assertions

### New migrations (confidence: HIGH)

- `create_chimeway_deliveries` — includes all columns, unique index on `(notification_id, channel)`
- `create_chimeway_delivery_attempts` — includes index on `delivery_id`

### Optional new dependencies (confidence: MEDIUM)

- `swoosh ~> 1.x` — only if email adapter ships this phase; optional, keep in `[optional: true]` dep or separate package seam
- `bypass ~> 2.x` — only in `:test` env, only if HTTP-based adapter lands this phase

### No breaking changes to Phase 1 schemas (confidence: HIGH)

Phase 2 adds new tables. Phase 1 `chimeway_events` and `chimeway_notifications` tables are unchanged. The only linkage is the `notification_id` FK on `chimeway_deliveries` pointing to `chimeway_notifications.id`.

---

## 8. Elixir Ecosystem Patterns to Follow

| Pattern | Confidence | Source |
|---------|------------|--------|
| `@behaviour` callbacks for adapter contract | HIGH | Phase 1 D-03, ARCHITECTURE.md |
| `Ecto.Multi` for transactional dispatch | HIGH | ARCHITECTURE.md plan-then-dispatch |
| `Ecto.Enum` for delivery state | HIGH | Readable DB, operator-queryable |
| Unique index on `(notification_id, channel)` | HIGH | Idempotency extension from Phase 1 |
| `Application.get_env` for adapter config at call time | HIGH | Phase 3 D-01 pattern precedent |
| `defmacro __using__` for shared contract tests | HIGH | Standard ExUnit shared test pattern |
| Attempt row before status transition | HIGH | PITFALLS.md + ARCHITECTURE.md |
| Outcome classification in dispatcher, not adapter | HIGH | Keeps adapters thin and swappable |
| Bypass for HTTP provider simulation | MEDIUM | STACK.md recommendation |
| Swoosh.Adapters.Test as model for Test adapter | HIGH | Mature pattern, well-documented |

---

## 9. Open Questions for Planner

1. **`suppression_reason` and `delay_fallback` columns**: Add in Phase 2 migration (avoiding Phase 3 alter migration cost) or defer strictly? Phase 3 D-06 and D-08 are well-specified — including them in Phase 2 is low risk and saves a migration.

2. **Email adapter scope**: Does the Swoosh email adapter land in Plan 02-02, or is the Test/Logger adapter sufficient for INTG-02 compliance? INTG-02 says "at least one outbound adapter seam" — Test adapter satisfies the letter; Swoosh satisfies the spirit for a production library.

3. **Rendered content in `%Chimeway.Delivery{}`**: How does rendered content (email subject, body, etc.) flow from notifier to adapter? The delivery struct needs to carry it, or the dispatcher must call a render callback before invoking the adapter. This shapes the `%Chimeway.Delivery{}` struct and may require a `rendered_content` field.

4. **`Chimeway.Planner` module location**: Was a planner stub introduced in Phase 1 (Phase 1 plan 01-01 "trigger pipeline")? If so, Phase 2 extends it rather than creating it fresh. Planner should verify before creating.

---

## 10. Confidence Summary

| Area | Confidence | Notes |
|------|------------|-------|
| Delivery + attempt schema shape | HIGH | Clear from architecture + Phase 3 context decisions |
| State machine states | HIGH | Locked by Phase 3 terminal state definition (D-05) |
| Adapter behaviour contract | HIGH | Standard Elixir behaviour pattern |
| Sync dispatcher pattern | HIGH | `Ecto.Multi` + attempt-before-status is well-established |
| Test/Logger adapter sufficiency | HIGH | Satisfies INTG-02; low risk |
| Swoosh adapter scope | MEDIUM | Depends on email renderer readiness; either decision is valid |
| Contract test structure | HIGH | `defmacro __using__` is standard ExUnit |
| Plan sequence (01 → 02 → 03) | HIGH | Data model before adapter, adapter before contract tests |

---

*Research completed: 2026-04-23*
*Confidence: HIGH overall*
*Ready for planning: yes*
