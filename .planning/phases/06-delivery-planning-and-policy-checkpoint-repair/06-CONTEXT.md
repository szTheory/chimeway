# Phase 6: Delivery Planning and Policy Checkpoint Repair - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Repair delivery planning fanout and planning-time policy checkpoints so sync and Oban paths enforce the same contract. This phase must restore per-recipient, per-channel planning and ensure policy enforcement happens during planning/enqueue as well as perform time, without expanding feature scope beyond existing roadmap intent.

</domain>

<decisions>
## Implementation Decisions

### Channel fanout contract
- **D-01:** Keep `Notifier.recipients/1` as recipient identity resolution only; introduce `Notifier.channels/2` as the explicit channel-derivation contract per recipient.
- **D-02:** Ship `channels/2` as optional in Phase 6 with a temporary backward-compatible fallback to `[:in_app]`, plus deprecation messaging for notifiers that rely on fallback.
- **D-03:** Add a shared planner (`Chimeway.DeliveryPlanning`) that deterministically expands recipient x channel intents, normalizes channel types, deduplicates channels, and emits stable order.

### Planning-time policy checkpoint semantics
- **D-04:** Run `Policy.evaluate/2` at planning/enqueue time for every planned delivery row in both sync and Oban flows (not only during worker perform).
- **D-05:** Persist planning-time suppressions as first-class delivery rows (`status: :suppressed`) with explicit `suppression_reason`; do not silently skip row creation.
- **D-06:** Suppressed deliveries never enqueue jobs and never call adapters; only dispatchable pending deliveries continue into sync execution or Oban enqueue.
- **D-07:** Preserve perform-time policy checks for drift-sensitive scenarios (for example delayed fallback/read-state), and mark suppression checkpoint source in delivery metadata (`planning` vs `perform`) for trace clarity.

### Sync/Oban parity architecture
- **D-08:** Centralize fanout and planning-time policy logic in one shared planning context, then keep `Dispatch.Sync` and `Dispatch.Oban` thin strategy layers.
- **D-09:** Extract shared adapter-attempt execution logic used by sync and Oban worker paths to prevent outcome-classification drift.
- **D-10:** Apply a staged migration: extract planner with behavior parity first, route sync, route Oban, then remove duplicated hardcoded planning code.

### Verification strategy for Phase 6
- **D-11:** Use a hybrid verification strategy: thin end-to-end spine tests for standard outbound success flow, plus parity matrix tests, plus focused unit tests for edge behavior.
- **D-12:** Add two canonical end-to-end tests (sync and Oban) that assert full durable chain invariants: event -> notification -> delivery fanout -> attempt/suppression outcomes.
- **D-13:** Add a shared parity harness that runs equivalent scenarios across sync and Oban for fanout and planning-time policy enforcement.
- **D-14:** Keep delayed fallback/read-state checks in targeted policy tests; avoid duplicating those checks in every broad integration test.

### Claude's Discretion
- Exact module naming (`DeliveryPlanning`, `DeliveryExecutor`, or equivalent) as long as boundaries in D-08 and D-09 remain explicit.
- Deprecation messaging style and transition timeline details for `channels/2` fallback removal, as long as Phase 6 stays non-breaking.
- Exact test helper structure under `test/support`, provided parity assertions remain behavior-oriented and mode-symmetric.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and scope
- `.planning/ROADMAP.md` - Phase 6 goal, gap-closure intent, and success criteria.
- `.planning/REQUIREMENTS.md` - Requirement mapping for `DLVR-01`, `INTG-02`, `POLC-01`, `POLC-02`.
- `.planning/PROJECT.md` - Core value, constraints, and architectural non-negotiables.

### Prior locked decisions to carry forward
- `.planning/phases/02-first-outbound-delivery-slice/02-CONTEXT.md` - Delivery/attempt architecture and adapter seam constraints.
- `.planning/phases/03-async-dispatch-and-policy-hardening/03-CONTEXT.md` - Dual-checkpoint policy model, Oban guardrails, suppression semantics.
- `.planning/phases/04-explainability-and-operator-surfaces/04-CONTEXT.md` - Explainability/traceability expectations.

### Current implementation surfaces to repair
- `lib/chimeway/notifier.ex` - Existing notifier callback contract to evolve with `channels/2`.
- `lib/chimeway/trigger.ex` - Trigger orchestration and dispatch handoff seam.
- `lib/chimeway/delivery.ex` - Delivery schema/status/suppression fields.
- `lib/chimeway/deliveries.ex` - Planning/transition/suppression/attempt persistence APIs.
- `lib/chimeway/policy.ex` - Policy checkpoint logic and suppression reasons.
- `lib/chimeway/dispatch/sync.ex` - Sync planning/dispatch flow (currently hardcoded `:in_app` planning).
- `lib/chimeway/dispatch/oban.ex` - Oban enqueue planning path (currently hardcoded `:in_app` planning).
- `lib/chimeway/dispatch/oban_worker.ex` - Perform-time execution and policy re-check behavior.

### Verification baselines
- `test/chimeway/trigger_pipeline_test.exs` - Recipient normalization and trigger contract expectations.
- `test/chimeway/dispatch/sync_test.exs` - Sync dispatch status/attempt lifecycle tests.
- `test/chimeway/dispatch/oban_test.exs` - Oban enqueue/worker path tests.
- `test/chimeway/policy_test.exs` - Planning/perf-time policy behavior checks.
- `test/chimeway/policy/delayed_fallback_test.exs` - Delayed fallback suppression parity scenarios.
- `test/chimeway/integration/delivery_lifecycle_test.exs` - End-to-end durable chain assertions.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Policy.evaluate/2` already supports planning-time and perform-time checkpoints.
- `Chimeway.Deliveries.plan_delivery/2` and `suppress_delivery/2` provide durable lifecycle primitives needed for fanout and suppression persistence.
- `Chimeway.Dispatch.Sync` and `Chimeway.Dispatch.ObanWorker` already implement adapter call and attempt recording paths that can be unified behind shared execution helpers.
- Existing tests already cover sync/Oban/policy slices and can be refactored into a parity harness rather than rebuilt.

### Established Patterns
- Explicit callback/behavior contracts over hidden magic (`Notifier`, `Dispatch`, `Adapter`).
- Durable row-first modeling (`event -> notification -> delivery -> attempt`) as the primary explainability backbone.
- Dual policy checkpoints are already conceptually established; this phase closes the planning-time enforcement gap in both dispatch strategies.

### Integration Points
- Delivery planning currently happens in dispatch modules with hardcoded `:in_app`; this is the insertion point for shared recipient x channel planning.
- Oban path must enforce the same planning-time policy gate before enqueue while preserving perform-time re-check.
- Trigger-level dispatch handoff should continue to call one dispatcher interface while consuming shared planning outputs.

</code_context>

<specifics>
## Specific Ideas

- Model channel selection after successful ecosystem patterns (for example Laravel `via`/Symfony channel resolution) while keeping Elixir-style explicit callbacks and deterministic normalization.
- Keep suppression durable and queryable, similar to operationally mature queue/delivery systems where skipped/suppressed outcomes remain visible for support.
- Optimize for least surprise in OSS DX: one planner contract, one lifecycle model, and symmetric behavior across sync and Oban.

</specifics>

<deferred>
## Deferred Ideas

- Configurable planner behavior/plugin boundary for host-defined custom planning strategies (defer until baseline parity is stable).
- Separate suppression-ledger table optimization (current phase prefers single-table lifecycle clarity over split-model complexity).
- Making `channels/2` strictly required should be considered in a later breaking-change window after migration/deprecation period.

</deferred>

---

*Phase: 06-delivery-planning-and-policy-checkpoint-repair*
*Context gathered: 2026-04-24*
