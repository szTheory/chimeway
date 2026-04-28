# Phase 22: Recovery & Outcome Analytics - Context

**Gathered:** 2026-04-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Recovery and Outcome Analytics for deliveries that fail trigger-time dispatch or require post-dispatch aggregate inspection. This phase covers detecting stuck rows, reconciling them via re-enqueueing to dispatch, and exposing aggregate query functions for operator dashboards. Workflow journeys, escalation trees, and channel expansion remain out of scope.
</domain>

<decisions>
## Implementation Decisions

### Reconciliation Mechanism
- **D-01:** Reconciliation will recover "stuck" deliveries by re-enqueuing them to the dispatcher and mutating the canonical delivery rows in place, without deleting or replacing them.

### Stuck Delivery Detection
- **D-02:** Detection of undispatched persisted deliveries will rely on querying Chimeway's schema state (e.g., `status == :pending` and `orchestration_state == :ready` past a safe time threshold) without interrogating the Oban queue.

### Aggregate Outcomes API
- **D-03:** Aggregate query capabilities will be implemented as new functions within `Chimeway.Traces` rather than introducing a separate top-level module (like `Chimeway.Analytics`).

### Outcome Aggregation Data Source
- **D-04:** Outcome analytics will aggregate directly over `chimeway_deliveries.status`, `chimeway_deliveries.orchestration_state`, and `chimeway_deliveries.suppression_reason` rather than traversing the `chimeway_delivery_attempts` history.

### Claude's Discretion
None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 22 goal and description.
- `.planning/REQUIREMENTS.md` — `OPS-01` and `OPS-02` requirements.
- `.planning/PROJECT.md` — Local-first ownership, stable identity, explainability, and operator DX posture.
- `.planning/phases/20-digest-emission-explainability/20-CONTEXT.md` — Explains the decision to keep queue records as execution artifacts rather than business truth.
- `lib/chimeway/deliveries.ex` — Canonical lifecycle transitions, in-place row mutation patterns, and terminal states.
- `lib/chimeway/traces.ex` — Established trace query APIs and explainability surfaces.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Deliveries.list_due_deferred_deliveries/1`: An existing pattern for querying actionable pending rows using Ecto.
- `Chimeway.Deliveries.transition_status/2` and `apply_planning_decision/2`: In-place mutation helpers that should be mirrored or reused for reconciliation.
- `Chimeway.Traces`: Already serves as the unified operator debugging surface, natural home for aggregate queries.

### Established Patterns
- Canonical rows are mutated or linked in place rather than replaced.
- Operator explainability stays under `Chimeway.Traces` as the primary entrypoint. Data must be durable and sanitized.
- The `oban_jobs` table is an execution artifact, not business truth; Chimeway queries its own state.

### Integration Points
- Reconciliation links back into the existing dispatch path (`Chimeway.Dispatch.*`).
- Aggregate analytics hook into the current `chimeway_deliveries` state without rewriting historical attempt data.
</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches
</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope
</deferred>
