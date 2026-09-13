# Phase 99: Multi-Installation Delivery & Recovery - Context

**Gathered:** 2026-08-19 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver one logical push decision to every active eligible opaque installation while preserving independent, tenant-safe target truth. This phase defines the public target-resolution boundary, durable per-binding-revision targets, target-scoped claim/attempt/retry/expiry/invalidation history, aggregate logical-delivery outcomes, and bounded recovery for stranded planning or target work. Concrete APNs request construction and reason mapping, CrossWake registration and protected opens, the hermetic adopter twin, and physical-device proof remain owned by Phases 100–103.

</domain>

<decisions>
## Implementation Decisions

### Opaque Target Model and Logical Outcome

- **D-01:** Keep one canonical logical push delivery per notification and channel. Fan-out is represented by durable child targets beneath that delivery, not by one top-level delivery per installation.
- **D-02:** The public resolver returns every active eligible installation as an opaque, tenant-scoped binding revision. Chimeway persists one target per selected revision and never stores raw tokens, endpoints, credentials, or uncontrolled resolver payloads.
- **D-03:** Target identity is unique within the logical delivery. Repeated resolution or planning converges on the same target row for the same selected binding revision.
- **D-04:** No eligible targets suppresses the logical delivery with one stable explainable reason. After every target terminates, the logical delivery succeeds only when at least one target has provider acceptance; target-level terminal failures remain visible as partial-failure evidence and the aggregate must never claim all-device delivery.

### Target-Scoped Handoff Truth

- **D-05:** The child target is the independent state machine for claim, attempt-start, retry, expiry, invalidation, and provider outcome. The logical delivery aggregates target truth but does not replace it.
- **D-06:** Persist target claim and attempt-start evidence before provider I/O. Attempt history remains append-only and ordered so every possible provider request has a durable explanation.
- **D-07:** If execution stops after provider processing may have occurred but before a conclusive response is durably recorded, close the interrupted attempt with an explicit indeterminate/ambiguous handoff outcome. Do not silently treat it as an unsent failure or automatically resend it.
- **D-08:** Any later policy-authorized re-drive after an indeterminate handoff must create linked new attempt evidence and preserve the duplicate-risk explanation. It must never be presented as exactly-once delivery.
- **D-09:** Provider acceptance means observed provider handoff only. It never implies device receipt, display, app handling, protected open, inbox seen/read, or engagement.

### Tenant-Scoped Recovery and Idempotency

- **D-10:** Extend the existing recovery spine with an explicit tenant-scoped, bounded worker for stranded event planning and target work. Every discovery, claim, reload, mutation, and dispatch decision retains the resolved tenant predicate.
- **D-11:** Recovery claims are atomic and converge duplicate planning, execution, jobs, and recovery onto the existing target revision. Terminal, already-claimed, expired, invalidated, and otherwise ineligible targets short-circuit before provider I/O.
- **D-12:** Recovery evidence uses the Phase 98 safe-evidence vocabulary and records why work was claimed, skipped, resumed, or left indeterminate without exposing host-owned identity or endpoint data.

### the agent's Discretion

- Exact behaviour, callback, struct, table, and enum names, provided the public contract is data-first, tenant-explicit, opaque, and stable.
- Exact target lifecycle transition implementation, claim lease mechanics, worker batch size, and concurrency limits, provided work is bounded, atomically claimed, and executable evidence proves convergence under races.
- Exact aggregate recomputation mechanism and stable reason strings, provided no-target suppression, provider-acceptance semantics, partial failures, and indeterminate handoffs remain distinguishable.
- Exact migration sequencing and internal module boundaries, provided copied migrations remain deterministic in both supported static storage modes.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active milestone contract

- `.planning/ROADMAP.md` — Phase 99 goal, dependency, fixed boundary, and five success criteria.
- `.planning/REQUIREMENTS.md` — Binding PUSH-01 through PUSH-04 and RECOV-01/02 acceptance requirements; APNs, open, and analytics non-goals.
- `.planning/PROJECT.md` — v1.18 local-first ownership split, durable lifecycle spine, explainability posture, and adopter-alpha target features.
- `.planning/METHODOLOGY.md` — cohesive recommendation, high-impact escalation, research-first ownership, durable explainability, and least-surprise DX lenses.
- `.planning/phases/97-tenant-identity-compatible-upgrade/97-CONTEXT.md` — locked tenant identity, fail-closed scoping, non-disclosure, and static storage decisions inherited by Phase 99.
- `.planning/phases/98-privacy-safe-delivery-evidence/98-CONTEXT.md` — locked safe-evidence vocabulary, opaque reference boundary, and prohibition on persisted raw tokens/endpoints/provider bodies.

### Existing delivery and recovery contracts

- `lib/chimeway/delivery.ex` — canonical logical delivery schema and current `{notification_id, channel}` uniqueness contract.
- `lib/chimeway/delivery_attempt.ex` — append-only ordered attempt history pattern.
- `lib/chimeway/delivery_planning.ex` — shared fan-out planning seam used by dispatch strategies.
- `lib/chimeway/deliveries.ex` — idempotent planning, tenant-scoped recovery claims, attempt insertion, and lifecycle transitions.
- `lib/chimeway/dispatch/executor.ex` — current adapter-I/O seam and the pre-I/O evidence gap Phase 99 must close.
- `lib/chimeway/dispatch/oban_worker.ex` — bounded retries, terminal short-circuiting, and delivery-based job uniqueness that must become target-aware.
- `lib/chimeway/dispatch/oban.ex` — transactional planning/enqueue integration.
- `lib/chimeway/traces.ex` — existing safe lifecycle projection to extend with target-level truth.
- `lib/chimeway/safe_evidence.ex` — shared privacy boundary and closed evidence vocabulary.
- `priv/chimeway_migrations/003_create_chimeway_deliveries.exs` — copied-migration source for the canonical delivery identity this phase extends.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Chimeway.DeliveryPlanning`: the mandatory shared planning seam and natural integration point for resolver-driven target fan-out.
- `Chimeway.Deliveries`: existing idempotent delivery creation, tenant resolution, atomic recovery claims, attempt numbering, and status transitions.
- `Chimeway.DeliveryAttempt`: append-only provider-call evidence pattern that target attempts should preserve or extend.
- `Chimeway.Dispatch.ObanWorker`: terminal short-circuit, bounded retries, exhaustion handling, and durable-row source-of-truth patterns.
- `Chimeway.SafeEvidence` and trace DTO builders: reusable privacy and projection boundaries for target and recovery evidence.
- Existing recovery, delivery-planning, lifecycle, trace, runtime-prefix, installer-golden, and release-gate tests: executable proof seams for race, tenant, migration, and privacy acceptance.

### Established Patterns

- One canonical delivery currently exists per notification/channel; installation fan-out should be subordinate to that durable identity.
- Attempts are append-only and numbered under transactional coordination; provider work must remain explainable from durable history.
- Tenant scope is resolved explicitly and retained in every recovery query and mutation; wrong-tenant and absent work share non-disclosing outcomes.
- Static storage routing belongs to Repo configuration, never tenant or binding identity.
- Dispatch workers treat the durable lifecycle row as truth, short-circuit terminal state, and use bounded Oban retry behavior.
- Machine-testable concurrency, privacy, idempotency, recovery, and migration acceptance requires executable evidence rather than conversational UAT.

### Integration Points

- Public target-resolution behaviour and normalized opaque binding-revision value objects.
- `Chimeway.DeliveryPlanning` and `Chimeway.Deliveries.plan_delivery/3` for logical delivery creation plus idempotent child-target persistence.
- New copied migrations and Ecto schemas for durable targets, target claims, and target attempt history in both static storage modes.
- `Chimeway.Dispatch.Executor`, sync dispatch, and Oban dispatch for target-scoped pre-I/O claims and attempt starts.
- Event and delivery recovery APIs/workers for bounded tenant-scoped planning and target recovery.
- `Chimeway.Traces`, explanations, admin DTOs, telemetry, and proof contracts for safe per-target and aggregate evidence.

</code_context>

<specifics>
## Specific Ideas

- Use `provider_accepted` or equivalently explicit handoff terminology; never use unqualified `delivered` for an APNs-success response.
- Make an indeterminate post-handoff crash visibly different from both a conclusive provider rejection and affirmative evidence that no handoff occurred.
- Preserve one operator narrative: logical decision at the parent, independent installation truth underneath, and an aggregate that never erases partial failure.
- Make duplicate planning and recovery visibly converge through uniqueness and atomic claims rather than relying only on short-lived job uniqueness.

</specifics>

<deferred>
## Deferred Ideas

- APNs-specific status/reason mapping, stable `apns-id`, payload construction, expiry header, retry classification, and optional collapse behavior — Phase 100.
- CrossWake token registration, binding rotation/revocation, one-time protected opens, offline queueing, and authorization — Phase 101.
- Hermetic adopter twin and physical-iPhone evidence — Phases 102 and 103.

</deferred>

---

*Phase: 99-multi-installation-delivery-recovery*
*Context gathered: 2026-08-19*
