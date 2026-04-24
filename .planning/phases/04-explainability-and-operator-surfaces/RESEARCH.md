# Phase 4 Research: Explainability and Operator Surfaces

**Phase**: 4 — Explainability and Operator Surfaces
**Requirements**: OPS-01, OPS-02
**Researched**: 2026-04-23
**Status**: RESEARCH COMPLETE

---

## Executive Summary

Phase 4 delivers the "why wasn't this sent?" operator capability as first-class data, not an afterthought UI. The two plans divide cleanly: **04-01** adds query surfaces and correlation helpers over the durable lifecycle spine built in Phases 1–3; **04-02** wires `:telemetry` spans at key lifecycle transitions with redaction guarantees. Both are Elixir/Ecto/telemetry patterns with high confidence and no unusual dependencies. The roadmap marks this phase with a "UI hint: yes" but the success criteria require *queryable trace data* and *telemetry emission*, not a mounted LiveView admin — the admin UI is explicitly v2 scope (ADMN-01, ADMN-02). Phase 4 is the API-only substrate that a later UI would project.

---

## 1. Technical Domain: Trace Query Surfaces

### What the schema spine gives us (confidence: HIGH)

After Phases 1–3, the following durable tables exist and are queryable:

| Table | Key columns | Phase added |
|-------|-------------|-------------|
| `chimeway_events` | `id`, `notification_key`, `idempotency_key`, `inserted_at` | 1 |
| `chimeway_notifications` | `id`, `event_id`, `recipient_id`, `read_at`, `seen_at`, `archived_at` | 1 |
| `chimeway_deliveries` | `id`, `notification_id`, `channel`, `status`, `suppression_reason`, `delay_fallback` | 2/3 |
| `chimeway_delivery_attempts` | `id`, `delivery_id`, `outcome`, `inserted_at` (+ provider metadata) | 2 |
| `chimeway_notification_preferences` | `recipient_id`, `notification_key`, `channel`, `enabled` | 3 |

The chain `event → notification → delivery → attempt` is fully joinable by foreign key. OPS-01 requires operators to trace this chain using durable identifiers — the data already exists; Phase 4 adds the query API.

### Recommended pattern: `Chimeway.Traces` context module (confidence: HIGH)

Create a `Chimeway.Traces` public context that exposes:

1. **`get_trace/1`** — accepts `event_id` (UUID), returns a structured map with the event, its notifications, each notification's deliveries, and each delivery's attempts. This is the primary "why wasn't this sent?" entry point.
2. **`find_traces_for_recipient/2`** — accepts `recipient_id` and options (`notification_key`, date range, status filter), returns a list of notification-level trace summaries. Useful for support workflows.
3. **`find_traces_by_correlation_id/1`** — accepts a correlation ID string stored in metadata (see §3), returns matching events/deliveries.
4. **`explain_delivery/1`** — accepts `delivery_id`, returns a human-readable explanation struct: `{:suppressed, reason, detail}` | `{:failed, last_attempt}` | `{:succeeded, attempt}` | `{:pending, :not_yet_dispatched}`. This is the operability differentiator.

All queries must use Ecto associations and `Repo.preload/2` or explicit joins — no N+1 patterns. Use `select:` clauses to keep result sets narrow and avoid fetching full payload blobs where not needed.

### Ecto preload pattern (confidence: HIGH)

```elixir
# Pattern: single-query trace load
def get_trace(event_id) do
  Repo.one(
    from e in Event,
    where: e.id == ^event_id,
    preload: [notifications: [deliveries: :attempts]]
  )
end
```

For large recipient fanouts, preload in batches rather than a single deeply nested join to avoid cartesian explosions.

### Correlation identifier strategy (confidence: HIGH)

OPS-01 requires correlation across event → delivery → attempt. Three durable correlation surfaces exist:

1. **`event.id`** — primary trace root; all downstream rows link back transitively
2. **`event.idempotency_key`** — caller-assigned; useful for cross-system correlation (the caller knows their key)
3. **`correlation_id`** — an optional freeform string that the host app can attach at trigger time (from `conn.assigns[:request_id]`, `Logger.metadata()[:request_id]`, or Oban job args)

For Phase 4, add a `correlation_id` nullable column to `chimeway_events` if not already present, and expose it in `Chimeway.Traces.find_traces_by_correlation_id/1`. The host app integration seam doc establishes that "host app assigns correlation ids and Chimeway stores them" — Phase 4 makes this queryable.

**Migration scope**: One `alter table chimeway_events add column :correlation_id :string` migration if the column was not included in Phase 1.

---

## 2. Technical Domain: Telemetry Instrumentation

### `:telemetry` standard patterns (confidence: HIGH)

Elixir's `:telemetry` library is the standard instrumentation substrate. The `Chimeway.Telemetry` module (referenced in engineering DNA) should wrap `:telemetry.span/3` for all lifecycle spans.

**4-level event naming convention** (from engineering DNA — must follow this):
```
[:chimeway, :domain, :resource, :start | :stop | :exception]
```

For Phase 4, the concrete event names should be:

| Span | Events emitted |
|------|---------------|
| Event creation | `[:chimeway, :events, :create, :start/stop/exception]` |
| Delivery planning | `[:chimeway, :deliveries, :plan, :start/stop/exception]` |
| Policy evaluation | `[:chimeway, :policy, :evaluate, :start/stop/exception]` |
| Dispatch (sync) | `[:chimeway, :dispatch, :sync, :start/stop/exception]` |
| Dispatch (oban enqueue) | `[:chimeway, :dispatch, :enqueue, :start/stop/exception]` |
| Oban worker perform | `[:chimeway, :dispatch, :perform, :start/stop/exception]` |
| Attempt record | `[:chimeway, :attempts, :record, :start/stop/exception]` |

### Metadata shape (confidence: HIGH)

Each span's metadata should include:
- `notification_key` — always safe
- `event_id` — UUID, safe reference
- `recipient_id` — string, safe reference (not email/phone)
- `channel` — atom
- `delivery_id` — UUID, safe
- `outcome` / `suppression_reason` — on stop events only
- **Never**: full payload body, email address, phone number, webhook URL, template content

### Span implementation pattern (confidence: HIGH)

```elixir
defmodule Chimeway.Telemetry do
  def span(event_suffix, meta, func) do
    :telemetry.span([:chimeway | event_suffix], meta, func)
  end
end
```

Usage at each call site:
```elixir
Chimeway.Telemetry.span([:deliveries, :plan], %{notification_key: key, event_id: id}, fn ->
  {result, result}
end)
```

The `stop` metadata automatically merges the function's return with the start metadata.

### Redaction guarantees (confidence: HIGH)

Redaction must be structural, not string-based. Two enforcement mechanisms:

1. **Compile-time**: A Credo custom check (referenced in engineering DNA) that flags any telemetry `meta` map containing keys from a deny-list (`:email`, `:phone`, `:body`, `:payload`, `:content`, `:template`, `:url`). This makes redaction a lint failure, not a runtime surprise.
2. **Structural**: `Chimeway.Telemetry.safe_meta/1` helper that accepts a raw metadata map and returns only the allowed keys. Call sites use `safe_meta(%{...})` rather than passing raw maps.

The Credo check can be added in Phase 4 or Phase 5 (CI hardening). Phase 4 must at minimum ensure no PII is emitted by convention and document the allowed key list.

---

## 3. Technical Domain: Correlation ID Propagation

### Logger metadata pattern (confidence: HIGH)

Elixir's `Logger.metadata/0` is the standard way to attach contextual data to log lines and telemetry within a process. The host app integration seam should document how to thread correlation IDs:

```elixir
# In host app Plug/controller:
Logger.metadata(request_id: conn.assigns[:request_id])

# In Chimeway trigger:
correlation_id = Logger.metadata()[:request_id]
Chimeway.trigger(notifier, params, correlation_id: correlation_id)
```

Store `correlation_id` on the event row at trigger time. The Oban worker picks it up from the delivery's event association and re-attaches it to `Logger.metadata` at perform time.

### Oban job args and metadata (confidence: HIGH)

Oban workers should NOT store correlation IDs in job args (PII risk, args are logged). Instead:
- Store correlation ID on the `chimeway_events` row
- Worker loads delivery → event → reads `correlation_id` → puts in `Logger.metadata` for the perform span

This keeps job args to `delivery_id` only (as established in Plan 03-01).

---

## 4. Technical Domain: Operator API Shape

### What "UI hint: yes" means for Phase 4 (confidence: HIGH)

The roadmap marks Phase 4 with `UI hint: yes` but the **success criteria** say nothing about a mounted LiveView UI. The admin UI (ADMN-01, ADMN-02) is v2 scope. "UI hint: yes" means this phase must produce a **query API that a future UI can project** — i.e., the `Chimeway.Traces` functions must return structured data that LiveView components could render without additional Ecto queries.

The operator surface for v1 is:
- **Public query functions** in `Chimeway.Traces`
- **Telemetry spans** that external observers (Datadog, OpenTelemetry, custom handlers) can consume
- **Structured `explain_delivery/1` result** that a support engineer can `IO.inspect` in IEx or a Rails-style console

A `Chimeway.Traces.explain_delivery/1` returning a rich struct is far more valuable for Phase 4 than a partial LiveView table.

### `explain_delivery/1` result shape (confidence: MEDIUM)

```elixir
%Chimeway.Traces.Explanation{
  delivery_id: uuid,
  notification_key: string,
  recipient_id: string,
  channel: atom,
  status: atom,          # :succeeded | :failed | :suppressed | :pending
  suppression_reason: string | nil,
  last_attempt: %{outcome: atom, inserted_at: datetime} | nil,
  event_id: uuid,
  correlation_id: string | nil,
  timeline: [%{at: datetime, event: string, detail: map}]
}
```

The `timeline` list is a flattened chronological view: `[{:event_created, ...}, {:delivery_planned, ...}, {:policy_evaluated, ...}, {:attempt_made, ...}]`. This is the "defensible trace" from the operator IA doc.

---

## 5. Key Pitfalls for This Phase

### Pitfall 1: N+1 queries in trace loading (confidence: HIGH)

Naive `Repo.preload` with deeply nested associations at scale can produce cartesian joins. For single-trace lookups (`get_trace/1`) this is acceptable. For list queries (`find_traces_for_recipient/2`), use explicit joins and `select_merge` to keep the query count to 1–3 regardless of recipient count.

### Pitfall 2: PII leaking through telemetry `:stop` metadata (confidence: HIGH)

`:telemetry.span/3` automatically merges the function's return value into stop metadata. If the return value is a full `%Delivery{}` struct with a `metadata` blob, any PII in that blob propagates to telemetry handlers. **Solution**: always return only safe scalar fields from span closures, or pass the return through `safe_meta/1` before merging.

### Pitfall 3: Correlation ID missing at worker perform time (confidence: MEDIUM)

If correlation IDs are only attached via `Logger.metadata` at request time, they will be absent when an Oban worker runs in a separate process. **Solution**: persist `correlation_id` on the `chimeway_events` row (not in Oban job args), load it from the DB in the worker, and re-attach to `Logger.metadata` before emitting spans.

### Pitfall 4: Telemetry handler registration (confidence: MEDIUM)

Telemetry handlers must be attached once at application startup, not inside request handlers. If `Chimeway` ships with built-in handlers (e.g., a default Logger handler), they must be attached in `Chimeway.Application` start or via a documented `Chimeway.Telemetry.attach_default_handlers/0` call the host app makes during startup. Failing to do this silently drops all telemetry.

### Pitfall 5: Confusing "operator surfaces" with "admin UI" scope (confidence: HIGH)

Phase 4 success criteria do not include a mounted router, LiveView components, or HTML templates. Any time spent on UI in Phase 4 is out of scope and borrows from Phase 5 hardening time. Keep all Phase 4 output as Elixir modules and data structures.

---

## 6. Plan Scope Recommendations

### 04-01: Trace Query Surfaces and Correlation Helpers

**Scope**:
- `Chimeway.Traces` context with `get_trace/1`, `find_traces_for_recipient/2`, `find_traces_by_correlation_id/1`, `explain_delivery/1`
- Migration: add `correlation_id` to `chimeway_events` if missing
- `Chimeway.Traces.Explanation` struct (or plain map with defined shape)
- Host integration doc snippet: how to pass `correlation_id` at trigger time
- Test: a support-workflow test that seeds event → notification → delivery → attempt chain and asserts the explanation struct is correct for suppressed, failed, and succeeded cases

**Not in scope for 04-01**:
- LiveView components
- Any HTTP/JSON API endpoint
- Telemetry emission (that's 04-02)

### 04-02: Structured Telemetry and Redaction Guarantees

**Scope**:
- `Chimeway.Telemetry` span wrapper module
- Instrument 7 key lifecycle points (see §2 table above)
- `Chimeway.Telemetry.safe_meta/1` redaction helper
- `Chimeway.Telemetry.attach_default_handlers/0` for a Logger-based default handler (optional but useful for dev experience)
- Document the telemetry event catalog in guides or moduledoc
- Test: attach a test handler, trigger a notification, assert all expected events fired with correct keys and no PII keys

**Not in scope for 04-02**:
- Prometheus/StatsD/OpenTelemetry exporter adapters (these are adapter seam work, deferred)
- Credo custom PII check (acceptable to defer to Phase 5 CI hardening)

---

## 7. Dependency and Migration Analysis

### New modules (confidence: HIGH)

- `lib/chimeway/traces.ex` — public context
- `lib/chimeway/traces/explanation.ex` — result struct (or inline in traces.ex)
- `lib/chimeway/telemetry.ex` — span wrapper and safe_meta

### New migrations (confidence: MEDIUM)

- `add_correlation_id_to_chimeway_events` — single nullable string column; check Phase 1 schema to confirm it's absent before planning

### No new DB tables needed (confidence: HIGH)

Phase 4 is read-heavy: it queries existing tables and wraps lifecycle calls with telemetry. No new persistence surfaces are required.

---

## 8. Elixir Ecosystem Patterns to Follow

| Pattern | Confidence | Source |
|---------|------------|--------|
| 4-level telemetry event naming | HIGH | Engineering DNA, Chimeway prompt |
| `:telemetry.span/3` for start/stop/exception | HIGH | Standard Elixir telemetry practice |
| `safe_meta/1` redaction helper | HIGH | Engineering DNA (no PII in telemetry) |
| Ecto `preload:` for trace loading | HIGH | Standard Ecto pattern |
| `Logger.metadata` for correlation propagation | HIGH | Standard OTP/Logger pattern |
| Oban job args = delivery_id only | HIGH | Plan 03-01 established this |
| No LiveView in Phase 4 | HIGH | ADMN-01/02 are v2 scope |

---

## 9. Confidence Summary

| Area | Confidence | Notes |
|------|------------|-------|
| Trace query shape | HIGH | Clear schema, standard Ecto patterns |
| Telemetry event catalog | HIGH | 4-level naming is established; 7 spans identified |
| Redaction strategy | HIGH | `safe_meta` + Credo check pattern from DNA |
| Correlation ID flow | HIGH | Logger.metadata + event row column |
| Plan boundary (no UI) | HIGH | v2 scope confirmed by requirements |
| `explain_delivery` struct shape | MEDIUM | Shape is recommended; planner may refine |
| `correlation_id` column existence | MEDIUM | Need to verify Phase 1 migration — may already exist |

---

*Research completed: 2026-04-23*
*Confidence: HIGH overall*
*Ready for planning: yes*
