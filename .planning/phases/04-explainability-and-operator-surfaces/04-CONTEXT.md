# Phase 4: Explainability and Operator Surfaces - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning
**Source:** AI self-discuss (headless mode)

## Phase Boundary

Deliver query-based trace surfaces (`Chimeway.Traces`) and lifecycle telemetry instrumentation (`Chimeway.Telemetry`). No admin UI — "operator surfaces" means queryable data and telemetry events, not LiveView. Correlation ID propagation across the async boundary is included here because it enables the trace queries to be useful.

## Implementation Decisions

### Trace Query API Shape

- **D-01:** `get_trace/1` takes a single `event_id` (UUID binary string). Event is the root of the trace chain; it's the most durable handle. Returns `{:ok, %Event{notifications: [%Notification{deliveries: [...]}]}}` or `{:error, :not_found}`.

- **D-02:** `find_traces_for_recipient/2` signature is `(recipient_id, opts \\ [])` where opts accepts `[notification_key: string, status: atom, limit: integer (default 20)]`. Returns a list of preloaded events filtered to notifications matching that recipient. Uses a single join query — no N+1.

- **D-03:** `find_traces_by_correlation_id/1` takes a `correlation_id` string. Returns `[%Event{...}]` (list, never error tuple). Empty list when no match. Correlation IDs are user-supplied and may not be unique, so list is the right return shape.

- **D-04:** `explain_delivery/1` takes a `delivery_id` UUID. Returns `{:ok, %Chimeway.Traces.Explanation{}}` or `{:error, :not_found}`. The explanation struct fields:
  ```
  %Explanation{
    delivery_id:         uuid string,
    event_id:            uuid string,
    correlation_id:      string | nil,
    notification_key:    string,
    recipient_id:        string,
    channel:             atom,
    status:              :succeeded | :failed | :suppressed | :pending | :cancelled,
    suppression_reason:  string | nil,
    last_attempt:        %{outcome: atom, inserted_at: datetime} | nil,
    timeline:            [%{timestamp: datetime, event: atom, detail: string}]
  }
  ```
  Timeline entries are sorted ascending by timestamp. Events include `:event_created`, `:notification_created`, `:delivery_planned`, `:attempt_recorded`, `:suppressed`.

### Correlation ID

- **D-05:** `correlation_id` is persisted as a nullable string column on `chimeway_events`. At trigger time, resolution order: (1) explicit `correlation_id:` option passed to `trigger/3`; (2) `Logger.metadata()[:request_id]` as automatic fallback; (3) nil. This follows the "explicit over magic, but practical" principle — host apps using Plug/Phoenix get correlation for free.

- **D-06:** The column is added in a Phase 4 migration. The trigger path reads it from opts or Logger.metadata and writes it at event insert time. Existing events will have `nil` — acceptable.

### Telemetry Module

- **D-07:** `Chimeway.Telemetry.span/3` wraps `:telemetry.span/3`. Signature: `span(name_suffix, start_meta, fun)` where `name_suffix` is a list appended to `[:chimeway]`, `start_meta` is a map, and `fun` is `fn -> {result, stop_extra_meta} end`. Internally calls `safe_meta/1` on both start_meta and the merged stop map before emission. Returns `result`.

- **D-08:** `safe_meta/1` is a public function that filters any map to allowed keys only. Allowed set:
  ```
  [:notification_key, :event_id, :recipient_id, :channel, :delivery_id,
   :attempt_id, :outcome, :suppression_reason, :correlation_id]
  ```
  `:attempt_id` is included because attempt recording spans need it. All other keys are silently dropped. Atom and string keys both handled (normalize to atom before filter).

- **D-09:** `attach_default_handlers/0` is a public function that must be called explicitly by the host app (e.g., in `Application.start/2`). Chimeway does NOT auto-attach at library startup. This follows the "explicit over magic" principle from Phase 1. The function is idempotent — safe to call multiple times. It attaches a Logger-based handler that logs `:stop` and `:exception` events at `:debug` level.

- **D-10:** Oban-guarded spans (`[:chimeway, :dispatch, :enqueue]` and `[:chimeway, :dispatch, :perform]`) are wrapped with `if Code.ensure_loaded?(Oban)` at the call site. Consistent with Phase 3 Oban guard pattern (D-04 in Phase 3 context).

- **D-11:** The 7 canonical span names are:
  ```
  [:chimeway, :events, :create]
  [:chimeway, :deliveries, :plan]
  [:chimeway, :policy, :evaluate]
  [:chimeway, :dispatch, :sync]
  [:chimeway, :dispatch, :enqueue]   # Oban-guarded
  [:chimeway, :dispatch, :perform]   # Oban-guarded
  [:chimeway, :attempts, :record]
  ```
  These are the event names documented in `Chimeway.Telemetry` moduledoc as the stable public API.

### Query Performance

- **D-12:** `get_trace/1` uses a single `Repo.get` + `Repo.preload` with nested preloads. Acceptable for single-event trace inspection. List functions (`find_traces_for_recipient`, `find_traces_by_correlation_id`) use explicit `join` + `preload` to avoid N+1. No lazy loading anywhere in `Chimeway.Traces`.

### Module Layout

- **D-13:** Two new files only: `lib/chimeway/traces.ex` (context with all four query functions) and `lib/chimeway/traces/explanation.ex` (defstruct). Telemetry lives in `lib/chimeway/telemetry.ex`. No sub-namespacing beyond `Traces.Explanation`.

## AI Discretion

- **Timeline granularity:** Chose to derive timeline from existing schema timestamps (`inserted_at` on events/notifications/deliveries/attempts) rather than a separate audit log table. This keeps the implementation simple and avoids a new table while still answering "what happened when."
- **`safe_meta/1` as public API:** Made it public (not private) so host apps can use it in their own telemetry handlers when they want to forward Chimeway metadata safely.
- **Explanation status mapping:** `:pending` covers deliveries that are planned but have no attempts yet (not started or enqueued). Matches the natural delivery state machine from Phase 2.

## Existing Code Insights

### Reusable Assets
- `chimeway_events → chimeway_notifications → chimeway_deliveries → chimeway_delivery_attempts` chain: fully traversable with Ecto preloads; the trace query layer is pure context code over existing schemas.
- Phase 1 `notifications.read_at` field: available in preload; `explain_delivery` can reference it in timeline.
- Phase 3 `Chimeway.Policy` suppression_reason string pattern: `explain_delivery` reads the `suppression_reason` column directly.
- Phase 2 `Ecto.Multi` delivery pipeline: `correlation_id` write slots into the event insert step.

### Established Patterns
- Behaviour-first contracts and explicit configuration: `attach_default_handlers/0` is opt-in, documented in moduledoc with example.
- UUID primary keys throughout: `delivery_id`, `event_id` in explanation struct are binary UUIDs, consistent with prior schemas.
- `Code.ensure_loaded?(Oban)` guard: reused verbatim from Phase 3 Oban dispatcher pattern.
- Suppression reason as plain string atom name: `explain_delivery` casts back to atom for the struct field.

## Deferred Ideas

- **Admin LiveView / web dashboard:** explicitly out of scope for v1; belongs in `chimeway_admin` extraction (noted in Phase 1 D-02).
- **Compile-time Credo check for PII keys:** flagged in research as future work; not implemented in Phase 4.
- **Custom telemetry event catalog documentation site:** belongs in Phase 5 release hardening.
- **`explain_event/1` covering the full fan-out:** could be added later; Phase 4 scopes to `explain_delivery/1` per-channel.
