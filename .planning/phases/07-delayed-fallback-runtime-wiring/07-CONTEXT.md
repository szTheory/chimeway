# Phase 07: delayed-fallback-runtime-wiring - Context

**Gathered:** 2026-04-24 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make delayed fallback suppression a first-class runtime behavior in normal trigger planning. This phase wires `delay_fallback` intent into runtime delivery planning, preserves sync/Oban suppression parity, and validates end-to-end behavior from trigger through planning and perform-time checks. It does not introduce new channels, new product capabilities, or broader policy domains.

</domain>

<decisions>
## Implementation Decisions

### Fallback intent contract
- **D-01:** Keep `Notifier.channels/2` focused on channel selection and add an optional `Notifier.delayed_fallback_channels/2` callback for delayed-fallback intent.
- **D-02:** Add an additive deliveries API (`plan_delivery/3`) so planning can persist `delay_fallback` at insert time while retaining `plan_delivery/2` for compatibility.
- **D-03:** Planner must validate that delayed-fallback channels are a subset of resolved channels and fail with typed errors when invalid (no silent fallback).

### Resolution precedence and defaults
- **D-04:** Use deterministic precedence for `delay_fallback` resolution: notifier explicit override > policy/config override > default rule.
- **D-05:** Default to `delay_fallback: false` unless explicitly declared by notifier or policy override.
- **D-06:** Never mark `in_app` deliveries as delayed fallback; delayed fallback governs outbound channels whose send should be skipped after in-app read.

### Runtime suppression checkpoints
- **D-07:** Preserve dual-checkpoint policy behavior: planning checkpoint for early suppression plus perform checkpoint for drift-sensitive suppression.
- **D-08:** Perform-time suppression remains the final gate by evaluating `Policy.evaluate(delivery, check_read_state: delivery.delay_fallback)` before adapter execution in both sync and Oban paths.
- **D-09:** Suppressed deliveries create zero attempts and never call adapters; `failed` remains retryable.

### Suppression data contract and explainability
- **D-10:** Keep `delivery.status`, `delivery.suppression_reason`, and `delivery.metadata["policy_checkpoint"]` as the authoritative suppression contract.
- **D-11:** Adopt and document a strict suppression reason taxonomy for this phase (`channel_disabled`, `already_read`) with tests preventing unknown-code drift.
- **D-12:** Persist delayed-fallback decision provenance metadata (for example, source: `default`, `notifier`, `policy`) to maintain explainability for operator traces.

### Verification strategy
- **D-13:** Add trigger-driven integration tests that prove runtime planning sets `delay_fallback` without fixture-only shortcuts.
- **D-14:** Run parity evidence across sync and Oban for delayed fallback outcomes (`status`, `suppression_reason`, `policy_checkpoint`, `attempt_count`) from real trigger flow.
- **D-15:** Keep fixture-built delivery tests as branch-level guards, but do not treat them as sufficient evidence of Phase 07 closure.

### Claude's Discretion
- Exact callback naming and return-shape normalization details, as long as D-01 through D-03 remain explicit and backwards-compatible.
- Exact metadata key naming for fallback provenance, as long as source-of-decision remains durable and queryable in traces.
- Exact placement of parity helpers/tests (`test/support` organization), as long as D-13 through D-15 evidence remains clear and reproducible.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and requirements
- `.planning/ROADMAP.md` - Phase 07 goal, scope boundary, and success criteria.
- `.planning/REQUIREMENTS.md` - Requirement `POLC-03` mapped to this phase.
- `.planning/PROJECT.md` - Core value and constraints (local-first, explainability, composability).
- `.planning/STATE.md` - Current project position and active phase marker.

### Prior locked phase context
- `.planning/phases/06-delivery-planning-and-policy-checkpoint-repair/06-CONTEXT.md` - Shared planner and planning-time checkpoint contract to extend.
- `.planning/phases/03-async-dispatch-and-policy-hardening/03-CONTEXT.md` - Perform-time delayed fallback semantics and Oban guardrails.
- `.planning/phases/04-explainability-and-operator-surfaces/04-CONTEXT.md` - Trace explainability expectations for suppression diagnostics.

### Gap evidence and planning inputs
- `.planning/v1.0-MILESTONE-AUDIT.md` - Audit evidence identifying runtime `delay_fallback` wiring gap.
- `.planning/phases/06-delivery-planning-and-policy-checkpoint-repair/06-VERIFICATION.md` - Existing parity baseline and checkpoint behavior evidence.

### Runtime implementation surfaces
- `lib/chimeway/delivery_planning.ex` - Shared planning seam where `delay_fallback` must be marked.
- `lib/chimeway/notifier.ex` - Notifier callback contract (`channels/2`) to extend/additively evolve.
- `lib/chimeway/deliveries.ex` - Delivery planning and suppression persistence APIs.
- `lib/chimeway/delivery.ex` - Delivery schema fields (`delay_fallback`, `suppression_reason`, `metadata`).
- `lib/chimeway/policy.ex` - Preference and read-state suppression logic.
- `lib/chimeway/dispatch/sync.ex` - Sync perform-time policy gate.
- `lib/chimeway/dispatch/oban.ex` - Oban enqueue path from planned deliveries.
- `lib/chimeway/dispatch/oban_worker.ex` - Oban perform-time policy gate.
- `lib/chimeway/dispatch/executor.ex` - Adapter execution and attempt recording behavior.
- `lib/chimeway/trigger.ex` - Trigger-to-dispatch orchestration entrypoint.

### Verification surfaces
- `test/chimeway/policy/delayed_fallback_test.exs` - Existing delayed fallback behavior tests (currently fixture-heavy).
- `test/chimeway/dispatch/sync_test.exs` - Sync suppression parity assertions.
- `test/chimeway/dispatch/oban_test.exs` - Oban planning/perform suppression parity assertions.
- `test/chimeway/dispatch/oban_worker_test.exs` - Worker idempotency and terminal-state behavior.
- `test/chimeway/integration/delivery_lifecycle_test.exs` - Trigger-driven lifecycle integration baseline.
- `test/support/chimeway/dispatch_helpers.ex` - Current fixture helper patterns to keep as branch-level tests only.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.DeliveryPlanning.plan_notification/2`: centralized planning seam already shared by sync and Oban.
- `Chimeway.Deliveries.suppress_delivery/3`: durable suppression writer with checkpoint metadata support.
- `Chimeway.Policy.evaluate/2`: existing dual-checkpoint policy evaluator with read-state option.
- `Chimeway.Test.DispatchHelpers.delivery_signature/1`: reusable parity assertion shape for status/checkpoint/attempt outcomes.

### Established Patterns
- Explicit behaviour contracts and additive callbacks (`Notifier`, `Dispatch`, `Adapter`) over hidden DSLs.
- Deterministic planner-first flow with durable records before external side effects.
- Explainability-first suppression provenance (`suppression_reason` plus `policy_checkpoint`) consumed by traces.

### Integration Points
- Planner resolution path in `delivery_planning.ex` is the insertion point for delayed-fallback intent wiring.
- `deliveries.ex` plan API is the insertion point for persist-at-create `delay_fallback` semantics.
- Trigger-driven integration tests must validate the same behavior through both dispatcher strategies.

</code_context>

<specifics>
## Specific Ideas

- Optimize for least surprise in OSS DX: explicit callback contracts, deterministic precedence, and actionable planner errors.
- Keep policy behavior coherent across sync and Oban by sharing planning semantics and preserving perform-time drift checks.
- Treat explainability as a product surface: every suppression should be inspectable with reason, checkpoint, and decision source.

</specifics>

<deferred>
## Deferred Ideas

- Advanced pluggable intent-resolver architecture for broader policy dimensions (quiet hours, caps, digest orchestration) beyond delayed fallback.
- Dedicated append-only suppression events table; current phase keeps compact delivery-row suppression contract.
- Convention-default strategy of auto-marking all outbound channels as delayed fallback; intentionally deferred in favor of explicit defaults for v1 predictability.

</deferred>

---

*Phase: 07-delayed-fallback-runtime-wiring*
*Context gathered: 2026-04-24*
