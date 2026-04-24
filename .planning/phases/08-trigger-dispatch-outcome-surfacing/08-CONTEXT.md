# Phase 08: trigger-dispatch-outcome-surfacing - Context

**Gathered:** 2026-04-24 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Ensure trigger callers receive explicit dispatch/enqueue outcomes with trace correlation context. This phase focuses on caller-visible outcome contracts for sync and async dispatch paths, plus durable links back to trace data. It does not add new channel capabilities or alter idempotency guarantees.

</domain>

<decisions>
## Implementation Decisions

### Trigger API outcome envelope
- **D-01:** Keep the top-level trigger tuple contract as `{:ok, map} | {:duplicate, event} | {:error, reason}`.
- **D-02:** Surface dispatch/enqueue outcome details inside the `{:ok, map}` payload instead of introducing new tuple shapes.

### Dispatch failure surfacing
- **D-03:** Trigger must stop swallowing dispatch/enqueue failures; caller-visible structured outcomes are required for these failures.
- **D-04:** Structured dispatch/enqueue failure outcomes must remain compatible with existing sync and Oban dispatcher error contracts.

### Sync vs Oban outcome semantics
- **D-05:** Treat parity as stage-aware: sync reports immediate execution outcomes, while Oban reports enqueue acceptance plus durable identifiers for later trace lookup.
- **D-06:** Do not block trigger calls waiting for async worker completion in Oban mode.

### Trace correlation contract
- **D-07:** Caller-visible outcomes must include durable trace pointers (`event_id`, `correlation_id`, and delivery/job identifiers when available).

### Idempotency and duplicate behavior
- **D-08:** Duplicate idempotency triggers remain non-dispatching and non-enqueuing.
- **D-09:** If duplicate outcomes need surfacing detail, they reference existing durable rows instead of re-running dispatch.

### Claude's Discretion
- Exact field naming and nesting for the enriched `{:ok, map}` outcome payload, as long as decisions D-01 through D-09 remain true.
- Whether duplicate outcome metadata is returned via `{:duplicate, event}` only or accompanied by optional read-only summary fields derived from durable records.
- Exact sync/Oban outcome key taxonomy (`execution_outcome`, `enqueue_outcome`, etc.) provided it clearly encodes stage semantics from D-05.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and requirements
- `.planning/ROADMAP.md` - Phase 08 goal, gap-closure intent, and success criteria.
- `.planning/REQUIREMENTS.md` - Requirement mapping for `DLVR-04` and `OPS-01`.
- `.planning/PROJECT.md` - Core explainability value and non-negotiable architecture constraints.
- `.planning/STATE.md` - Current sequencing and active milestone position.

### Prior locked decisions to carry forward
- `.planning/phases/04-explainability-and-operator-surfaces/04-CONTEXT.md` - Correlation and trace explainability expectations.
- `.planning/phases/06-delivery-planning-and-policy-checkpoint-repair/06-CONTEXT.md` - Shared planning and dispatch parity contracts.
- `.planning/phases/07-delayed-fallback-runtime-wiring/07-CONTEXT.md` - Suppression parity and trigger-driven durable behavior continuity.

### Runtime implementation surfaces
- `lib/chimeway.ex` - Public trigger entrypoint contract.
- `lib/chimeway/trigger.ex` - Trigger return normalization and post-trigger dispatch handling.
- `lib/chimeway/dispatch/sync.ex` - Sync dispatch error/outcome behavior.
- `lib/chimeway/dispatch/oban.ex` - Oban enqueue behavior and planning failure contract.
- `lib/chimeway/dispatch/oban_worker.ex` - Async perform semantics that occur after enqueue.
- `lib/chimeway/dispatch/executor.ex` - Delivery execution + attempt persistence path used by sync/Oban worker.
- `lib/chimeway/traces.ex` - Operator trace surfaces and delivery explanation contracts.
- `lib/chimeway/events/event.ex` - Durable `correlation_id` persistence on events.
- `lib/chimeway/deliveries.ex` - Delivery/attempt durable outcomes used for trace linkage.
- `lib/chimeway/delivery_planning.ex` - Shared planning failure source consumed by dispatchers.

### Verification surfaces
- `test/chimeway/trigger_pipeline_test.exs` - Trigger contract and planning fanout expectations.
- `test/chimeway/integration/delivery_lifecycle_test.exs` - End-to-end trigger idempotency and lifecycle durability scenarios.
- `test/chimeway/dispatch/sync_test.exs` - Sync dispatch outcome and suppression assertions.
- `test/chimeway/dispatch/oban_test.exs` - Oban enqueue and worker behavior expectations.
- `test/chimeway/dispatch/oban_transactional_test.exs` - Oban transactional enqueue consistency expectations.
- `test/chimeway/traces_test.exs` - Trace/explainability query behavior and correlation surfaces.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Trigger.normalize_trigger_result/3`: existing trigger result envelope that can absorb richer dispatch/enqueue metadata.
- `Chimeway.Dispatch.Sync.dispatch/2` and `Chimeway.Dispatch.Oban.dispatch/2`: existing structured error sources (`{:planning_failed, reason}`) suitable for caller-visible surfacing.
- `Chimeway.Traces` APIs and `Event.correlation_id`: durable explainability path for linking trigger responses to operator traces.

### Established Patterns
- Tuple-based public API style with explicit tagged outcomes (`{:ok, ...}`, `{:error, ...}`, `{:duplicate, ...}`).
- Explicit separation between sync execution and async enqueue/perform stages.
- Durable, queryable lifecycle rows (`event -> notification -> delivery -> attempt`) as explainability backbone.

### Integration Points
- `dispatch_after_trigger/4` in `trigger.ex` is the primary insertion point for Phase 08 outcome surfacing.
- `Chimeway` public facade should preserve compatibility while exposing enriched outcome payload details from `Trigger`.
- Trace pointer fields surfaced by trigger must align with `Chimeway.Traces` lookup entrypoints (`event_id`, `correlation_id`, delivery IDs).

</code_context>

<specifics>
## Specific Ideas

- Keep API evolution low-risk for existing adopters by preserving top-level tuple matching while enriching payload internals.
- Ensure caller outcomes are directly usable by support workflows: response fields should map 1:1 to trace query handles.
- Preserve strict idempotency behavior: no duplicate-trigger side effects.

</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within phase scope.

</deferred>

---

*Phase: 08-trigger-dispatch-outcome-surfacing*
*Context gathered: 2026-04-24*
