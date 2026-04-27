# Phase 10: Telemetry Correlation Enrichment - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning
**Source:** AI self-discuss (headless mode)

<domain>
## Phase Boundary

Enrich existing Chimeway telemetry spans with consistent correlation metadata (`notification_key`, `correlation_id`, `event_id`) so operators can reconstruct the full lifecycle path from telemetry alone. No new spans, no new allowed keys, no schema changes. The target is delivery-tier and attempt-tier spans that currently emit only `delivery_id` — making cross-span correlation impossible without a DB query.
</domain>

<decisions>
## Implementation Decisions

### Root cause: metadata not threaded through dispatch opts

- **D-01:** Thread `notification_key`, `correlation_id`, and `event_id` as explicit keys into `dispatch_opts` inside `Chimeway.Trigger.dispatch_after_trigger/4`. All three are available there from `event.notification_key`, `event.correlation_id`, and `event.id`. Add them with `Keyword.put_new` so callers invoking dispatch directly are unaffected.

### Persist correlation metadata in delivery rows at plan time

- **D-02:** In `Chimeway.DeliveryPlanning.plan_notification/2`, extract `notification_key`, `correlation_id`, and `event_id` from opts (after D-01 threads them) and forward them as metadata opts to `Chimeway.Deliveries.plan_delivery/3`. `plan_delivery` merges them into `delivery.metadata` under string keys `"notification_key"`, `"correlation_id"`, `"event_id"`. These are non-sensitive identifier strings — no redaction needed. This is the same pattern already used for `"delayed_fallback_source"` and `"policy_checkpoint"`.
- **D-03:** The `on_conflict: :nothing` + reload pattern in `plan_delivery/3` means an idempotent re-plan returns the already-stored metadata. Correlation metadata written on first plan survives subsequent idempotent calls — no special handling needed.

### Enrich [:deliveries, :plan] span

- **D-04:** `plan_deliveries_span/3` in `trigger.ex` already receives `result` as its first argument (which is `{:ok, %{event: event, ...}}` on success). Pattern-match on the event to enrich the span start meta with `event_id: event.id` and `correlation_id: event.correlation_id`. Keep `notification_key: notifier.notification_key()` already present. Pass `%{}` on non-ok result to avoid crash in error paths.

### Enrich [:policy, :evaluate] span

- **D-05:** `Policy.evaluate/2` already receives the delivery struct. Read `delivery.metadata["notification_key"]` and add it to the start meta via `safe_meta/1`. No DB query — metadata is already loaded on the delivery struct.

### Enrich [:dispatch, :sync] span

- **D-06:** `do_dispatch_with_telemetry/1` in `sync.ex` already receives delivery. Add `notification_key: Map.get(delivery.metadata || %{}, "notification_key")` to the start meta. `notification_key` is already in `@allowed_meta_keys` — `safe_meta/1` passes it through.

### Enrich [:dispatch, :enqueue] span

- **D-07:** `enqueue_one/1` in `oban.ex` already receives delivery. Add `notification_key` (from delivery.metadata) and `channel` (from delivery.channel, already on the struct) to the start meta.

### Enrich [:dispatch, :perform] span

- **D-08:** `perform/1` in `oban_worker.ex` already has delivery loaded before the span. Add `notification_key: Map.get(delivery.metadata || %{}, "notification_key")` to the start meta.

### Enrich [:attempts, :record] span

- **D-09:** `record_attempt/2` in `deliveries.ex` already receives delivery. Add `notification_key` (from delivery.metadata) and `channel` (from delivery.channel) to the start meta. Both are on the already-loaded delivery — no extra queries.

### No new allowed keys needed

- **D-10:** All keys added (`notification_key`, `event_id`, `correlation_id`, `channel`) are already in `Chimeway.Telemetry.@allowed_meta_keys`. The `safe_meta/1` allowlist does not change.

### Test coverage

- **D-11:** Add a new describe block in `telemetry_integration_test.exs` asserting correlation key presence:
  - `[:chimeway, :deliveries, :plan, :stop]` must include `:event_id` and `:notification_key`.
  - `[:chimeway, :dispatch, :sync, :stop]` must include `:notification_key` and `:channel`.
  - `[:chimeway, :attempts, :record, :stop]` must include `:notification_key` and `:channel`.
  - `[:chimeway, :policy, :evaluate, :stop]` must include `:notification_key`.
- **D-12:** Add a redaction assertion confirming `correlation_id` (which comes from Logger metadata / request id) does not appear in spans that don't emit it, preventing accidental leakage via metadata merges.

### AI Discretion

- Whether to use `Map.get(delivery.metadata || %{}, "notification_key")` inline or extract a private helper in each call site — either is fine; inline is preferred for simplicity given three occurrences.
- Whether `[:deliveries, :plan]` stop extra meta should include `event_id` (it can, since it's in the allowed set) — leaving this to the planner to assess if stop-meta enrichment is worth the pattern change.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and requirements
- `.planning/ROADMAP.md` — Phase 10 goal, success criteria, and OPS-02 scope.
- `.planning/REQUIREMENTS.md` — OPS-02: "System emits structured telemetry for core lifecycle events without leaking sensitive payload fields by default."
- `.planning/PROJECT.md` — Core constraints around local-first operation and explainability.

### Prior locked context
- `.planning/phases/04-explainability-and-operator-surfaces/04-CONTEXT.md` — Explainability/correlation expectations.
- `.planning/phases/08-trigger-dispatch-outcome-surfacing/08-CONTEXT.md` — D-07: Caller-visible outcomes must include `event_id`, `correlation_id` — same identifiers this phase propagates through telemetry.

### Primary implementation surfaces
- `lib/chimeway/telemetry.ex` — `safe_meta/1`, `@allowed_meta_keys`, span wrapper. **Do not change `@allowed_meta_keys`** — all needed keys are already present.
- `lib/chimeway/trigger.ex` — `dispatch_after_trigger/4` (thread opts, D-01), `plan_deliveries_span/3` (enrich start meta, D-04).
- `lib/chimeway/delivery_planning.ex` — `plan_notification/2` (extract and forward correlation metadata, D-02).
- `lib/chimeway/deliveries.ex` — `plan_delivery/3` (merge into metadata, D-02), `record_attempt/2` (enrich span, D-09).
- `lib/chimeway/policy.ex` — `evaluate/2` (enrich span start, D-05).
- `lib/chimeway/dispatch/sync.ex` — `do_dispatch_with_telemetry/1` (enrich span start, D-06).
- `lib/chimeway/dispatch/oban.ex` — `enqueue_one/1` (enrich span, D-07).
- `lib/chimeway/dispatch/oban_worker.ex` — `perform/1` (enrich span, D-08).

### Test surface
- `test/chimeway/telemetry_integration_test.exs` — Extend with correlation key presence assertions (D-11, D-12).
</canonical_refs>

<code_context>
## Existing Code Insights

### Current metadata storage pattern (established)
`delivery.metadata` already stores `"policy_checkpoint"`, `"delayed_fallback_source"` as string-keyed values. Using the same pattern for `"notification_key"`, `"correlation_id"`, `"event_id"` is consistent and requires no schema changes.

### Delivery struct always loaded before all dispatch/attempt spans
Every span enrichment point already holds the delivery struct — no additional DB queries introduced by this phase.

### `safe_meta/1` is the single PII enforcement point
All metadata passed to spans routes through `safe_meta/1`. The allowed key set covers all keys this phase emits. The implementation is correct — just call it with the enriched map.

### `plan_deliveries_span/3` receives result as first arg
```elixir
defp plan_deliveries_span(result, notifier, params, opts) do
  Telemetry.span(
    [:deliveries, :plan],
    Telemetry.safe_meta(%{notification_key: notifier.notification_key()}),
    ...
  )
end
```
Pattern-match result to extract event for `event_id`/`correlation_id` enrichment.

### Oban multi-path does not call `enqueue_one/1`
The multi-path in `oban.ex` (`enqueue_deliveries/2` with a struct arg) does not use `enqueue_one/1` — it doesn't emit `[:dispatch, :enqueue]` spans. The telemetry gap there predates this phase; do not add spans to the multi path in Phase 10 (out of scope per Phase 12 boundary).

### Reusable Assets
- `Chimeway.Telemetry.safe_meta/1`: zero-cost allowlist filter, call with enriched map.
- `delivery.metadata`: already a `%{}` map loaded with delivery — string key access via `Map.get(delivery.metadata || %{}, "notification_key")`.
- `telemetry_integration_test.exs`: existing test infra with handler setup; extend rather than replace.
</code_context>

<specifics>
## Specific Ideas

- Use `Keyword.put_new` (not `Keyword.put`) in D-01 so callers that bypass trigger and invoke dispatch directly with their own metadata opts are not overwritten.
- In `plan_notification/2`, guard the metadata extraction with `Map.get(delivery.metadata || %{}, "notification_key", nil)` fallback to handle any edge case where opts don't carry these keys (e.g., direct dispatch without trigger context).
- The `telemetry_integration_test.exs` test that runs a full trigger cycle already collects all stop events via `receive` — the new assertions can be added as a new `describe` block that runs the same trigger and checks enriched keys.
</specifics>

<deferred>
## Deferred Ideas

- Adding `correlation_id` to delivery-tier spans via metadata — `correlation_id` comes from Logger request_id and may be nil in non-HTTP contexts. Threading it into delivery metadata is correct but operators should be aware it may be absent. Handling nil gracefully is the executor's responsibility — no special behavior needed here.
- Emitting Oban multi-path enqueue spans (`[:dispatch, :enqueue]`) — the multi path skips `enqueue_one/1` entirely, so it has no telemetry today. Adding spans there belongs to Phase 12 scope, which restructures the Oban dispatcher.
- Operator UI for telemetry correlation (ADMN-01, ADMN-02) — v2 scope.
</deferred>

---

*Phase: 10-telemetry-correlation-enrichment*
*Context gathered: 2026-04-24*
