# Phase 10: Telemetry Correlation Enrichment — Research

**Phase:** 10
**Goal:** Enrich delivery-tier and attempt-tier telemetry spans with consistent correlation metadata (`notification_key`, `event_id`, `correlation_id`) so operators can reconstruct the full lifecycle path from telemetry alone.
**Researched:** 2026-04-24
**Status:** Complete — all findings verified against current source

---

## 1. Current Telemetry State (Verified)

### What each span currently emits

| Span | Start meta (current) | Gap |
|------|----------------------|-----|
| `[:events, :create]` | `notification_key`, `correlation_id` → stop adds `event_id`, `notification_key`, `correlation_id` | **None — already complete** |
| `[:deliveries, :plan]` | `notification_key` only | Missing `event_id`, `correlation_id` |
| `[:policy, :evaluate]` | `delivery_id`, `channel` | Missing `notification_key` |
| `[:dispatch, :sync]` | `delivery_id`, `channel` | Missing `notification_key` |
| `[:dispatch, :enqueue]` | `delivery_id` | Missing `notification_key`, `channel` |
| `[:dispatch, :perform]` | `delivery_id`, `channel` | Missing `notification_key` |
| `[:attempts, :record]` | `delivery_id` → stop adds `attempt_id`, `outcome` | Missing `notification_key`, `channel` |

**Confidence: HIGH** — read all span call sites directly.

---

## 2. Allowed Keys (Verified)

`Chimeway.Telemetry.@allowed_meta_keys` (telemetry.ex:79–82):

```elixir
~w(notification_key event_id recipient_id channel
   delivery_id attempt_id outcome suppression_reason correlation_id)a
```

**All keys this phase needs to add are already in the allowlist.** `safe_meta/1` will pass them through without any changes to telemetry.ex.

**Confidence: HIGH**

---

## 3. Correlation Metadata Threading Path

The root cause: `notification_key`, `event_id`, `correlation_id` from the event are never threaded into `dispatch_opts`, so downstream spans can't access them.

### Call chain (verified):

```
trigger.ex:do_trigger/6
  → plan_deliveries_span(result, notifier, params, opts)   [line 84]
      → dispatch_after_trigger(result, notifier, params, opts)  [line 248]
          → dispatcher.dispatch(notifications, dispatch_opts)   [line 262]
              → DeliveryPlanning.plan_notifications/plan_notification  [sync/oban]
                  → Deliveries.plan_delivery(notification.id, channel, opts)  [line 41 delivery_planning.ex]
                      → delivery.metadata written to DB  [line 46-58 deliveries.ex]
```

### Threading strategy (from CONTEXT decisions):

**D-01** — In `dispatch_after_trigger/4` (trigger.ex:254-268), `event` is already bound. Add to `dispatch_opts`:
```elixir
dispatch_opts =
  opts
  |> Keyword.put_new(:notifier, notifier)
  |> Keyword.put_new(:trigger_params, params)
  |> Keyword.put_new(:notification_key, event.notification_key)
  |> Keyword.put_new(:correlation_id, event.correlation_id)
  |> Keyword.put_new(:event_id, event.id)
```
Use `put_new` so callers invoking dispatch directly with their own metadata opts are unaffected.

**D-02** — In `DeliveryPlanning.plan_notification/2` (delivery_planning.ex:32-53), extract the three keys from opts and forward them to `plan_delivery`:
```elixir
Deliveries.plan_delivery(notification.id, channel,
  delay_fallback: ...,
  delayed_fallback_source: ...,
  notification_key: Keyword.get(opts, :notification_key),
  correlation_id: Keyword.get(opts, :correlation_id),
  event_id: Keyword.get(opts, :event_id)
)
```

**D-02 continued** — In `Deliveries.plan_delivery/3` (deliveries.ex:37-72), extend the metadata construction block to include the three new keys if present:
```elixir
metadata =
  opts
  |> Keyword.get(:metadata, %{})
  |> ensure_metadata_map()
  |> Map.put("delayed_fallback_source", delayed_fallback_source)
  |> maybe_put_opt("notification_key", opts)
  |> maybe_put_opt("correlation_id", opts)
  |> maybe_put_opt("event_id", opts)
```
Or inline with `Map.put` guarded by nil-check. This follows the same pattern as `"delayed_fallback_source"` already in use.

**D-03** — The `on_conflict: :nothing` + reload pattern in `plan_delivery` means an idempotent re-plan returns the already-stored metadata. No special handling needed.

**Confidence: HIGH**

---

## 4. Span Enrichment Points (Verified)

### 4a. `[:deliveries, :plan]` — trigger.ex:243-252

Current:
```elixir
defp plan_deliveries_span(result, notifier, params, opts) do
  Telemetry.span(
    [:deliveries, :plan],
    Telemetry.safe_meta(%{notification_key: notifier.notification_key()}),
    fn -> ...
```

Enrich start meta by pattern-matching `result` (D-04):
```elixir
start_meta =
  case result do
    {:ok, %{event: event}} ->
      %{notification_key: notifier.notification_key(),
        event_id: event.id,
        correlation_id: event.correlation_id}
    _ ->
      %{notification_key: notifier.notification_key()}
  end
Telemetry.safe_meta(start_meta)
```

### 4b. `[:policy, :evaluate]` — policy.ex:42-65

Current start meta: `%{delivery_id: delivery.id, channel: delivery.channel}`

Add `notification_key` (D-05):
```elixir
Telemetry.safe_meta(%{
  delivery_id: delivery.id,
  channel: delivery.channel,
  notification_key: Map.get(delivery.metadata || %{}, "notification_key")
})
```
`delivery.metadata` is always loaded at the call site — no extra query.

### 4c. `[:dispatch, :sync]` — sync.ex:67-77

Current start meta: `%{delivery_id: delivery.id, channel: delivery.channel}`

Add `notification_key` (D-06):
```elixir
Telemetry.safe_meta(%{
  delivery_id: delivery.id,
  channel: delivery.channel,
  notification_key: Map.get(delivery.metadata || %{}, "notification_key")
})
```

### 4d. `[:dispatch, :enqueue]` — oban.ex:78-87

Current start meta: `%{delivery_id: delivery.id}`

Add `notification_key` and `channel` (D-07):
```elixir
Telemetry.safe_meta(%{
  delivery_id: delivery.id,
  notification_key: Map.get(delivery.metadata || %{}, "notification_key"),
  channel: delivery.channel
})
```

### 4e. `[:dispatch, :perform]` — oban_worker.ex:46-53

Current start meta: `%{delivery_id: delivery.id, channel: delivery.channel}`

Add `notification_key` (D-08):
```elixir
Telemetry.safe_meta(%{
  delivery_id: delivery.id,
  channel: delivery.channel,
  notification_key: Map.get(delivery.metadata || %{}, "notification_key")
})
```

### 4f. `[:attempts, :record]` — deliveries.ex:157-202

Current start meta: `%{delivery_id: delivery.id}`

Add `notification_key` and `channel` (D-09):
```elixir
Telemetry.safe_meta(%{
  delivery_id: delivery.id,
  notification_key: Map.get(delivery.metadata || %{}, "notification_key"),
  channel: delivery.channel
})
```
`delivery.channel` is already on the struct; no extra query.

**Confidence: HIGH** — all delivery structs are loaded before span calls at every site.

---

## 5. Oban Multi-Path Gap (Scoped Out)

`enqueue_deliveries/2` with an `Ecto.Multi` argument (oban.ex:65-76) does NOT call `enqueue_one/1` — it inserts directly into the Multi without a telemetry span. This means `[:dispatch, :enqueue]` is never emitted on the multi path. This gap **predates Phase 10** and is explicitly out of scope (Phase 12 boundary). Do not add spans to the multi path here.

**Confidence: HIGH**

---

## 6. Test Coverage Requirements (Verified)

Existing test: `test/chimeway/telemetry_integration_test.exs`
- Has handler setup via `telemetry.attach_many` in `setup`
- Already runs a full trigger cycle with `run_trigger/0` using `Chimeway.Test.SupportNotifier`
- Has `receive` pattern for each stop event
- PII key list: `[:email, :phone, :body, :payload, :content, :template, :url]`

### New assertions needed (D-11):

Add a new `describe "correlation metadata enrichment"` block that runs the same trigger and asserts:
- `[:chimeway, :deliveries, :plan, :stop]` includes `:event_id` and `:notification_key`
- `[:chimeway, :dispatch, :sync, :stop]` includes `:notification_key` and `:channel`
- `[:chimeway, :attempts, :record, :stop]` includes `:notification_key` and `:channel`
- `[:chimeway, :policy, :evaluate, :stop]` includes `:notification_key`

### Redaction assertion (D-12):

Add assertion that `correlation_id` does NOT appear in spans that don't explicitly emit it (e.g., `[:dispatch, :sync, :stop]`, `[:attempts, :record, :stop]`). Prevents accidental leakage through metadata merges.

**Pattern: the existing `run_trigger/0` helper can be reused as-is.**

**Confidence: HIGH**

---

## 7. Risks and Pitfalls

### `nil` values in metadata
If `dispatch_after_trigger` is not the entry point (e.g., direct dispatch bypassing trigger), opts won't carry `notification_key`/`correlation_id`/`event_id`. `Map.get(delivery.metadata || %{}, "notification_key")` will return `nil`. `safe_meta/1` passes `nil` values through the allowlist — telemetry handlers receive `notification_key: nil`. This is acceptable; operators see the key with nil vs missing the key entirely.

**Mitigation:** No special handling needed. The nil case is documented in CONTEXT.md deferred items.

**Confidence: HIGH**

### `correlation_id` may be nil in non-HTTP contexts
`correlation_id` originates from `Logger.metadata()[:request_id]` in trigger.ex:25-27. In non-HTTP (e.g., test, background job initiation) contexts this will be nil. Threading nil into delivery metadata is harmless — it's stored as `nil` under `"correlation_id"` key.

**Confidence: HIGH**

### `plan_deliveries_span` currently wraps `dispatch_after_trigger`
The span wraps the entire dispatch call. Enriching the **start** meta with event_id/correlation_id from `result` is correct because `result` is available before the span body executes.

**Confidence: HIGH**

---

## 8. Files to Modify

| File | Change | Decision |
|------|--------|----------|
| `lib/chimeway/trigger.ex` | Thread opts in `dispatch_after_trigger/4`; enrich start meta in `plan_deliveries_span/4` | D-01, D-04 |
| `lib/chimeway/delivery_planning.ex` | Forward correlation keys from opts to `plan_delivery` | D-02 |
| `lib/chimeway/deliveries.ex` | Merge correlation keys into `delivery.metadata` in `plan_delivery/3`; enrich `record_attempt/2` span | D-02, D-09 |
| `lib/chimeway/policy.ex` | Add `notification_key` to `[:policy, :evaluate]` start meta | D-05 |
| `lib/chimeway/dispatch/sync.ex` | Add `notification_key` to `[:dispatch, :sync]` start meta | D-06 |
| `lib/chimeway/dispatch/oban.ex` | Add `notification_key` + `channel` to `[:dispatch, :enqueue]` start meta | D-07 |
| `lib/chimeway/dispatch/oban_worker.ex` | Add `notification_key` to `[:dispatch, :perform]` start meta | D-08 |
| `test/chimeway/telemetry_integration_test.exs` | Add correlation enrichment describe block + redaction assertion | D-11, D-12 |

**No changes to `lib/chimeway/telemetry.ex`** — `@allowed_meta_keys` already covers all new keys.

---

## 9. Success Criteria Mapping

| Criterion | How it's met |
|-----------|--------------|
| Lifecycle spans emit consistent correlation metadata | D-01 through D-09 thread `notification_key` into all delivery/attempt spans |
| Operators can reconstruct deep lifecycle paths from telemetry | `event_id` + `notification_key` on plan span; `notification_key` + `channel` on dispatch/attempt spans |
| Tests assert metadata presence and redaction behavior | D-11 + D-12 assertions in `telemetry_integration_test.exs` |

---

## 10. Recommended Plan Split (2 plans)

**Plan 10-01: Thread and persist correlation metadata**
- D-01: thread opts in `dispatch_after_trigger`
- D-02: forward opts in `plan_notification`, merge in `plan_delivery`
- D-03: verify idempotent re-plan (no code, just confirmed by design)
- D-04: enrich `plan_deliveries_span` start meta
Scope: trigger.ex, delivery_planning.ex, deliveries.ex

**Plan 10-02: Enrich dispatch/attempt spans + tests**
- D-05: policy.ex enrichment
- D-06: sync.ex enrichment
- D-07: oban.ex enrichment
- D-08: oban_worker.ex enrichment
- D-09: deliveries.ex record_attempt enrichment
- D-11, D-12: test assertions
Scope: policy.ex, sync.ex, oban.ex, oban_worker.ex, deliveries.ex, telemetry_integration_test.exs

---

*Research complete. All findings HIGH confidence — verified against current source files.*
