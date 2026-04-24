---
plan: 04-02
phase: 4
title: Add Structured Telemetry Instrumentation and Redaction Guarantees
status: not_started
requirements: [OPS-02]
depends_on: [04-01]
---

# Plan 04-02: Add Structured Telemetry Instrumentation and Redaction Guarantees

## Goal
Instrument all key notification lifecycle transitions with `:telemetry` spans using a `Chimeway.Telemetry` wrapper module, enforce structural PII redaction via a `safe_meta/1` helper, and provide a default Logger-based handler that host apps can attach at startup — all without leaking sensitive payload fields.

## Context
After 04-01, `Chimeway.Traces` provides query-side observability. OPS-02 requires the system to also emit structured telemetry for real-time observation by external handlers (Datadog, OpenTelemetry, custom Logger handlers). Phases 1–3 built the lifecycle pipeline — trigger, policy evaluation, dispatch (sync + Oban), and attempt recording — but no `:telemetry` spans were emitted. This plan wires spans at 7 key points following the 4-level event naming convention established in the engineering DNA.

## Tasks

### Task 1: Create `Chimeway.Telemetry` Span Wrapper and Safe Metadata Helper
**What**: Create `Chimeway.Telemetry` as the single instrumentation façade for all Chimeway telemetry calls. Implement:

1. **`span/3`** — wraps `:telemetry.span/3` with Chimeway's 4-level event prefix:
   ```elixir
   def span(event_suffix, meta, func) do
     :telemetry.span([:chimeway | event_suffix], meta, func)
   end
   ```

2. **`safe_meta/1`** — accepts any map and returns a new map containing only the allowed keys: `[:notification_key, :event_id, :recipient_id, :channel, :delivery_id, :outcome, :suppression_reason, :correlation_id]`. Drops any key not in this list. This prevents PII from propagating through `:telemetry.span/3`'s automatic stop-metadata merge.

3. **`attach_default_handlers/0`** — attaches a Logger-based telemetry handler under the name `:chimeway_default_logger` that emits `Logger.info/2` for `[:chimeway, :*, :*, :stop]` events and `Logger.warning/2` for `[:chimeway, :*, :*, :exception]` events. Uses `:telemetry.attach_many/4`. The handler must be idempotent — calling it twice does not crash or double-attach (use `catch` on `:already_exists`). Documents in `@moduledoc` that host apps should call this in `Application.start/2` if they want default logging.

**Where**:
- `lib/chimeway/telemetry.ex` — all three functions; `@moduledoc` includes the telemetry event catalog table and integration snippet

**Acceptance criteria**:
- [ ] `Chimeway.Telemetry.span([:events, :create], %{notification_key: "k"}, fn -> {:ok, {:ok}} end)` executes without error
- [ ] `safe_meta(%{notification_key: "k", email: "user@example.com", event_id: "uuid"})` returns `%{notification_key: "k", event_id: "uuid"}` — email dropped
- [ ] `attach_default_handlers/0` called twice does not raise; calling it once and then triggering a span produces a Logger line
- [ ] Module doc contains the full telemetry event catalog with event names, metadata keys, and when each fires

**Done when**: `Chimeway.Telemetry.span/3` and `safe_meta/1` are functional and tested in isolation; default handler attaches without error.

---

### Task 2: Instrument Lifecycle Call Sites with Telemetry Spans
**What**: Wire `Chimeway.Telemetry.span/3` at the 7 key lifecycle transitions. Each call site wraps the existing logic — the span's `func` argument executes the existing code and returns `{result, result}` as `:telemetry.span/3` requires. All metadata passed to `span/3` must go through `safe_meta/1` first.

| Span | Module | Event name |
|------|--------|-----------|
| Event creation | trigger pipeline | `[:events, :create]` |
| Delivery planning | trigger pipeline | `[:deliveries, :plan]` |
| Policy evaluation | `Chimeway.Policy` | `[:policy, :evaluate]` |
| Sync dispatch | `Chimeway.Dispatch.Sync` | `[:dispatch, :sync]` |
| Oban enqueue | `Chimeway.Dispatch.Oban` | `[:dispatch, :enqueue]` |
| Oban worker perform | `Chimeway.Dispatch.ObanWorker` | `[:dispatch, :perform]` |
| Attempt record | `Chimeway.Deliveries.record_attempt/2` | `[:attempts, :record]` |

The Oban-specific spans (`[:dispatch, :enqueue]` and `[:dispatch, :perform]`) must be guarded by the same `Code.ensure_loaded?(Oban)` compile-time check used in Plan 03-01 — they must not be emitted when Oban is not in the dependency tree.

**Where**: Each module listed in the table above — wrap the relevant logic with `Chimeway.Telemetry.span(suffix, safe_meta(%{...}), fn -> {result, result} end)`.

**Acceptance criteria**:
- [ ] All 7 span event names are emitted when a notification is triggered end-to-end in the test suite
- [ ] The 5 non-Oban spans fire in tests regardless of Oban availability
- [ ] No span metadata map contains keys `:email`, `:phone`, `:body`, `:payload`, `:content`, `:template`, or `:url`
- [ ] `:telemetry.span/3` stop metadata never contains full schema structs — only the safe scalar fields
- [ ] Existing tests in Phases 1–3 pass without regressions from the added spans

**Done when**: A test handler attached in the test suite confirms all 7 event names fire with correct metadata keys and no PII keys present.

---

### Task 3: Telemetry Integration Test and Event Catalog Documentation
**What**: Write a focused telemetry integration test that:
1. Attaches a custom in-process handler via `:telemetry.attach_many/4` in the test setup
2. Triggers a full notification (event → delivery planning → sync dispatch → attempt)
3. Asserts that every expected `[:chimeway, ...]` span stop event was received
4. Asserts the metadata of each stop event contains `notification_key` and `event_id`
5. Asserts the metadata of each stop event does NOT contain any key from the PII deny-list

Also add documentation to `guides/telemetry.md` (or as an embedded `@moduledoc` section in `Chimeway.Telemetry`) covering:
- The full event catalog with metadata shape for each span
- How to attach a custom handler
- The PII redaction guarantee and the allowed key list
- An example custom handler for Datadog/StatsD/OpenTelemetry bridging

**Where**:
- `test/chimeway/telemetry_integration_test.exs` — integration test as described above
- `lib/chimeway/telemetry.ex` `@moduledoc` — embed the event catalog and integration guide, or reference the guide file
- `guides/telemetry.md` (optional separate guide) — fuller narrative with handler examples

**Acceptance criteria**:
- [ ] Telemetry integration test passes with all 5 mandatory span names asserted (7 if Oban is in test deps)
- [ ] Test explicitly asserts absence of PII keys in all stop events
- [ ] `mix docs` renders the telemetry module doc without warnings
- [ ] Event catalog lists all 7 spans, their event name arrays, and their allowed metadata keys
- [ ] `mix test` passes

**Done when**: The integration test confirms all spans fire correctly, PII is absent from all stop events, and the catalog doc is renderable.

## Verification
**This plan is complete when**:
- [ ] `Chimeway.Telemetry.span/3` wraps `:telemetry.span/3` with `[:chimeway | suffix]` prefix
- [ ] `Chimeway.Telemetry.safe_meta/1` drops all keys not in the allowed list
- [ ] `attach_default_handlers/0` attaches idempotently and produces Logger output for stop/exception events
- [ ] All 7 lifecycle transitions emit telemetry spans (5 unconditionally; 2 Oban-guarded)
- [ ] No span's stop metadata contains email, phone, body, payload, content, template, or URL data
- [ ] Telemetry integration test attaches a handler, triggers a notification, and asserts all expected span names fired with correct and PII-free metadata
- [ ] Event catalog is documented in moduledoc or guide and renders via `mix docs`
- [ ] All tasks done conditions are met
- [ ] `mix test` passes for this plan's scope
