# Phase 18: Scheduled Resume & Deferred Dispatch - Context

**Gathered:** 2026-04-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Resume deferred deliveries automatically through durable scheduling and lifecycle-safe async execution. This phase covers turning Phase 17's held `:deferred` delivery rows back into dispatchable work without breaking idempotency, trace continuity, or durable final-state convergence. Digest accumulation, new delivery-window semantics, and broader recovery tooling stay out of scope.

</domain>

<decisions>
## Implementation Decisions

### Resume Source of Truth
- **D-01:** Deferred resume scheduling should use the existing canonical `chimeway_deliveries` row as the durable source of truth, keyed by `orchestration_state == :deferred` and `next_eligible_at`, instead of introducing a second primary scheduling store.

### Resume Execution Path
- **D-02:** Scheduled resume should transition the existing deferred delivery row back to a dispatchable `:ready` state and then reuse the normal Oban worker execution path for that same delivery.

### Identity and Trace Continuity
- **D-03:** Resume jobs should continue to identify work by `delivery_id` only and must not create replacement delivery rows or move delivery identity into ad hoc scheduler payloads.

### Duplicate Prevention and Final Convergence
- **D-04:** Phase 18 must add durable resume idempotency on the existing delivery row so multiple resume attempts cannot produce duplicate sends, and resumed, cancelled, or superseded deliveries still converge to one durable final outcome.

### the agent's Discretion
- Exact naming of resume helpers, workers, and internal transition APIs.
- Whether scheduling is implemented as a direct-at-time Oban job, a sweep job over eligible deferred rows, or a hybrid, as long as delivery rows remain the source of truth and duplicate execution is prevented.
- Exact metadata or planning-context fields added to improve trace clarity, provided they do not become a second identity source.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase scope
- `.planning/ROADMAP.md` — Phase 18 goal, dependency, and success criteria.
- `.planning/REQUIREMENTS.md` — ORCH-03 requirement mapping for deferred resume behavior.
- `.planning/PROJECT.md` — milestone direction, local-first ownership, and explainability constraints.
- `.planning/STATE.md` — current milestone state and carried-forward orchestration decisions.

### Phase 17 carry-forward decisions
- `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md` — locked handoff that held rows stay pending with zero attempts until explicit resume scheduling exists.
- `.planning/phases/17-delivery-windows-deferral-semantics/17-VALIDATION.md` — validation boundary for Phase 17 and explicit warning not to dispatch held rows before Phase 18.

### Delivery orchestration model
- `priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` — durable orchestration columns and index on `[:orchestration_state, :next_eligible_at]`.
- `lib/chimeway/delivery.ex` — canonical delivery schema fields for orchestration state, planning facts, and lifecycle status.
- `lib/chimeway/deliveries.ex` — canonical planning-decision persistence and delivery status transitions.
- `lib/chimeway/delivery_planning.ex` — planning seam that creates held deliveries and applies policy deferral decisions.

### Dispatch and trace continuity
- `lib/chimeway/dispatch/oban.ex` — Oban enqueue path already restricted to pending, ready deliveries.
- `lib/chimeway/dispatch/oban_worker.ex` — delivery-id-based execution, retry behavior, and non-ready short-circuit.
- `lib/chimeway/dispatch/sync.ex` — matching ready-only execution rule in sync path.
- `lib/chimeway/traces.ex` — current operator explanation path for deferred deliveries and trace continuity expectations.
- `lib/chimeway/traces/explanation.ex` — public explanation contract including `planning_reason`, `planning_context`, and `next_eligible_at`.

### Existing behavior tests
- `test/chimeway/orchestration/dispatch_gating_test.exs` — held deliveries must not enqueue or execute before they become ready.
- `test/chimeway/orchestration/delivery_planning_test.exs` — one canonical delivery row per `(notification_id, channel)` under orchestration planning.
- `test/chimeway/orchestration/traces_deferral_test.exs` — deferred explanation contract for planning facts and timeline entries.
- `test/chimeway/integration/delivery_lifecycle_test.exs` — end-to-end proof that deferred rows preserve lifecycle continuity and zero-attempt behavior before resume scheduling.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Deliveries.apply_planning_decision/2`: already persists orchestration-state changes, planning reasons, and `next_eligible_at` on the canonical delivery row.
- `Chimeway.Dispatch.ObanWorker`: already provides delivery-id-based execution, retry mapping, and terminal-state convergence logic that resumed work should reuse.
- `Chimeway.Dispatch.Oban`: already owns transactional Oban enqueue behavior and filters planned rows down to pending, ready deliveries.
- `Chimeway.Traces.explain_delivery/2`: already reconstructs operator-visible history from the durable event -> notification -> delivery -> attempt chain.

### Established Patterns
- Delivery rows are canonical and idempotent per `(notification_id, channel)`; new orchestration behavior should mutate or advance that row rather than create replacements.
- Immediate execution paths are gated on `orchestration_state == :ready`; held rows remain `:pending` with zero attempts until explicitly resumed.
- Oban jobs store `delivery_id` only; the delivery row is the durable source of truth for correlation, notification identity, and explainability.
- Retry and terminal convergence semantics live in the shared delivery/worker pipeline, not in ad hoc scheduler state.

### Integration Points
- Phase 18 will connect to the delivery-row orchestration fields introduced in Phase 17 and the existing `[:orchestration_state, :next_eligible_at]` index.
- Resume scheduling will need to cooperate with `Chimeway.DeliveryPlanning`, `Chimeway.Dispatch.Oban`, and `Chimeway.Dispatch.ObanWorker` instead of bypassing them.
- Trace continuity depends on any resume transition remaining visible through `Chimeway.Traces` without splitting lifecycle history across multiple delivery rows.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches within the locked decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 18-scheduled-resume-deferred-dispatch*
*Context gathered: 2026-04-28*
