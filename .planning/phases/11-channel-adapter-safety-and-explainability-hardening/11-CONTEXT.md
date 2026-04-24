# Phase 11: channel-adapter-safety-and-explainability-hardening - Context

**Gathered:** 2026-04-24 (assumptions mode)  
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove unsafe channel atom conversion paths and preserve explainability for valid custom channels. This phase hardens adapter-channel resolution and trace explainability behavior for custom channels, and adds regression coverage so sync/Oban execution paths remain reliable. It does not add new channel capabilities.

</domain>

<decisions>
## Implementation Decisions

### Adapter configuration resolution safety
- **D-01:** Replace runtime atom creation in executor channel config lookup with a non-dynamic resolver that does not create atoms from runtime `delivery.channel` strings.
- **D-02:** Preserve deterministic adapter config behavior with a compatibility-safe lookup contract so existing host-app config can migrate without surprising runtime changes.

### Explainability channel handling
- **D-03:** Keep delivery channel values string-safe in `Chimeway.Traces.explain_delivery/1`; do not cast runtime channel strings with `String.to_existing_atom/1`.
- **D-04:** Update explainability contract/tests so valid custom channels produce structured explanations without conversion failures.

### Safety hardening scope boundary
- **D-05:** Treat dynamic atom usage in Oban enqueue step naming as adjacent safety debt and defer that remediation to Phase 12 to keep Phase 11 aligned to channel adapter and explainability hardening scope.

### Regression coverage and parity
- **D-06:** Add regression tests that exercise custom channel adapter lookup through shared executor behavior across sync and Oban paths.
- **D-07:** Add explainability regressions asserting custom channel traces remain readable and non-raising.

### Claude's Discretion
- Exact config shape for channel adapter resolution (for example, per-channel map vs compatibility wrapper), as long as no runtime atoms are created from channel strings.
- Exact test helper structure and fixture organization for custom-channel parity tests.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and requirements
- `.planning/ROADMAP.md` - Phase 11 goal, scope, and success criteria.
- `.planning/REQUIREMENTS.md` - Requirement mapping for `INTG-02` and `OPS-01`.
- `.planning/PROJECT.md` - Core constraints around explainability, composability, and local-first operation.

### Prior locked context
- `.planning/phases/06-delivery-planning-and-policy-checkpoint-repair/06-CONTEXT.md` - Fanout/planning contracts and sync/Oban parity constraints.
- `.planning/phases/07-delayed-fallback-runtime-wiring/07-CONTEXT.md` - Runtime suppression parity and explainability metadata contracts.

### Gap and audit evidence
- `.planning/v1.0-MILESTONE-AUDIT.md` - Gap evidence driving Phase 11 hardening scope.
- `.planning/phases/06-delivery-planning-and-policy-checkpoint-repair/06-REVIEW.md` - Prior review findings around dynamic atom risk and flow reliability.
- `.planning/phases/07-delayed-fallback-runtime-wiring/07-REVIEW.md` - Prior review findings covering dynamic atom and explainability conversion failures.

### Current implementation surfaces
- `lib/chimeway/dispatch/executor.ex` - Runtime adapter config key resolution path.
- `lib/chimeway/dispatch/oban.ex` - Oban enqueue step naming path and scope-boundary adjacent safety debt.
- `lib/chimeway/traces.ex` - Explainability channel conversion path.
- `lib/chimeway/delivery_planning.ex` - Channel normalization and string channel planning contract.
- `lib/chimeway/delivery.ex` - Durable delivery channel storage contract.
- `lib/chimeway/dispatch/sync.ex` - Sync dispatch path that consumes shared executor behavior.
- `lib/chimeway/dispatch/oban_worker.ex` - Oban perform path that consumes shared executor behavior.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Dispatch.Executor.run_delivery/1`: single shared execution seam used by sync and Oban worker paths.
- `Chimeway.DeliveryPlanning.normalize_channels/1`: existing normalized string channel contract for planner outputs.
- `Chimeway.Deliveries.plan_delivery/3`: durable insert path that persists channel strings and metadata.

### Established Patterns
- Channel identifiers are normalized and persisted as strings, not atoms.
- Sync and Oban dispatch routes converge into shared executor behavior.
- Explainability relies on durable lifecycle rows and metadata, not transient runtime state.

### Integration Points
- Adapter config resolution change lands in `dispatch/executor.ex` and propagates to both sync and Oban runtime paths.
- Explainability hardening lands in `traces.ex` and `traces/explanation.ex` contract behavior.
- Regression coverage should bind these changes through dispatch + traces tests to protect custom-channel behavior.

</code_context>

<specifics>
## Specific Ideas

- Custom channels should be first-class and safe without requiring pre-created atoms.
- Operator explainability must remain robust for both built-in and custom channels.
- Hardening should avoid breaking existing host-app adapter configuration unexpectedly.

</specifics>

<deferred>
## Deferred Ideas

- Remove dynamic atom creation used for Oban enqueue step names in `dispatch/oban.ex` (deferred to Phase 12 by scope decision D-05).

</deferred>

---

*Phase: 11-channel-adapter-safety-and-explainability-hardening*  
*Context gathered: 2026-04-24*
