# Phase 24: Workflow Contracts & State Spine - Context

**Gathered:** 2026-04-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Persist stable workflow identity, declarations, run state, and transition history for journey-enabled notifications. This phase defines the durable workflow contract and state spine only. Time-based progression, outcome branching, escalations, stop conditions, host signal APIs, and richer operator traces remain in later phases.

</domain>

<decisions>
## Implementation Decisions

### Workflow declaration model
- **D-01:** Phase 24 should persist workflow declarations as first-class durable records with stable `workflow_key` + `workflow_version` and ordered step definitions, rather than hiding workflow shape inside `Notification.orchestration`, `Delivery.planning_context`, or other opaque metadata maps.
- **D-02:** Durable workflow identity must remain decoupled from notifier module names and callback re-entry, matching Chimeway's existing string-based identity posture for notifications, digests, and rendering declarations.

### Workflow run spine
- **D-03:** Each journey-enabled recipient notification should create one durable workflow run record anchored to the canonical notification row, while per-step delivery rows remain the execution artifacts for channel sends and attempt history.
- **D-04:** The workflow run record should own the run's current lifecycle state and active step identity so later phases can advance, stop, or inspect a run without reconstructing truth from queue state or mutable callbacks.

### Transition history
- **D-05:** Workflow state changes should persist as explicit append-only transition history rows with machine-readable reasons and links to the relevant workflow step and delivery rows when applicable.
- **D-06:** Transition history must answer why the run entered its current state and which step is active from persisted Chimeway-owned data alone; job state, timestamp inference, or ad hoc JSON diffs are not acceptable truth sources.

### Declaration seam and phase scope
- **D-07:** Phase 24 should introduce a workflow declaration seam that resolves to explicit durable data at trigger time, following the same posture as persisted rendering and orchestration declarations.
- **D-08:** Phase 24 should stop at declaration persistence, run creation, current-state persistence, and historical transition capture; wait gates, outcome branching, escalations, and stop conditions belong to Phases 25-26.

### the agent's Discretion
- Exact schema and module names for workflow declarations, steps, runs, and transition history.
- Whether step definitions live in a dedicated steps table or an equivalent explicit durable shape, provided ordered step definitions remain queryable, versioned, and independent from notifier module names.
- Exact enum/state names for initial workflow run states and transition event types, provided they preserve explainability and align with the later roadmap split for progression, escalations, and stop conditions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and requirement scope
- `.planning/ROADMAP.md` — Phase 24 goal, success criteria, and milestone sequencing for Phases 24-28.
- `.planning/REQUIREMENTS.md` — Locked requirements for `WRK-01`, `WRK-03`, and `API-02`.
- `.planning/PROJECT.md` — Product posture for local-first explainability, durable identity, and workflow milestone scope.
- `.planning/STATE.md` — Current milestone direction and prior durable-identity/orchestration decisions that Phase 24 must extend.
- `.planning/METHODOLOGY.md` — Active project lenses: durable explainability, least-surprise DX, and cohesive recommendation posture.

### Prior phase context
- `.planning/phases/19-digest-data-model-accumulation/19-CONTEXT.md` — First-class durable declaration/state pattern for stable identity and auditable joins.
- `.planning/phases/20-digest-emission-explainability/20-CONTEXT.md` — Explicit reasoning/history posture for operator explainability from persisted facts.
- `.planning/phases/21-template-versioning-rendering-contracts/21-CONTEXT.md` — Durable declaration persistence independent from callback re-entry.
- `.planning/phases/21.1-rendering-durability-and-preview-hardening/21.1-CONTEXT.md` — Trigger-time declaration persistence and replay without notifier re-entry.
- `.planning/phases/22-recovery-outcome-analytics/22-CONTEXT.md` — Recovery and operator surfaces should derive from Chimeway-owned persisted state, not job state.

### Current code contracts
- `lib/chimeway/trigger.ex` — Trigger-time persistence path for notification-level declarations.
- `lib/chimeway/notifier.ex` — Existing declaration resolution/serialization posture that workflow contracts should mirror.
- `lib/chimeway/notifications/notification.ex` — Current notification-level durable snapshot fields and recipient anchor.
- `lib/chimeway/delivery.ex` — Canonical per-channel execution artifact and lifecycle state carrier.
- `lib/chimeway/delivery_planning.ex` — Current planner seam that reuses persisted declarations and applies orchestration per delivery.
- `lib/chimeway/deliveries.ex` — Canonical persistence helpers for planning decisions, recovery, transition helpers, and durable convergence.
- `lib/chimeway/traces.ex` — Operator trace posture: explain from durable rows and explicit associations.
- `lib/chimeway/traces/explanation.ex` — Current single-delivery explanation contract and explainability expectations.
- `lib/chimeway/digests/digest_rule.ex` — Stable declaration identity pattern (`rule_key` + `rule_version`).
- `lib/chimeway/digests/digest_bucket.ex` — Durable run-state-style aggregate record pattern.
- `lib/chimeway/digests/digest_membership.ex` — Append-only, auditable history/fact row pattern linking canonical deliveries to higher-level orchestration state.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Trigger` already resolves notifier declarations at trigger time and persists sanitized notification-level snapshots (`render_channels`, `orchestration`) for replay-safe planning.
- `Chimeway.Notifier` already provides normalization and serialization patterns for durable declaration data that a workflow declaration seam can parallel.
- `Chimeway.DeliveryPlanning` already applies persisted notification-level declarations to canonical delivery rows without re-entering notifier callbacks during recovery-style flows.
- `Chimeway.Deliveries` already owns named persistence helpers for explicit lifecycle transitions, replay/recovery entrypoints, and idempotent row updates that later workflow phases can extend.
- Digest schemas (`DigestRule`, `DigestBucket`, `DigestMembership`) provide the clearest in-repo model for explicit multi-row durable identity, state, and history.

### Established Patterns
- Chimeway prefers first-class schemas and unique indexes over JSON-only truth for durable orchestration concepts.
- Stable string identities plus versions are the norm; module names are intentionally excluded from durable product truth.
- Notification rows are the per-recipient anchor; delivery rows are the per-channel execution spine.
- Recovery and operator explainability must work from persisted Chimeway-owned data without depending on Oban job state or callback re-entry.
- Reason-bearing fields and append-only history facts are favored over implicit inference from timestamps or mutable blobs.

### Integration Points
- Trigger-time workflow declaration persistence will likely integrate beside existing notification snapshot persistence in `Chimeway.Trigger`.
- Workflow-run creation should attach to the existing event -> notification -> delivery lifecycle without replacing canonical notification or delivery rows.
- Delivery planning and later progression phases will need a stable way to associate step deliveries back to the workflow run and active step.
- Trace surfaces in `Chimeway.Traces` will eventually consume workflow run and transition history rows to answer journey-level inspection questions.
- Recovery paths that already use persisted rendering/orchestration declarations set the expectation that workflow declarations must also replay from durable data alone.

</code_context>

<specifics>
## Specific Ideas

- Reuse the digest posture for explicit declaration/state/history tables, but do not copy hosted workflow-engine complexity.
- Keep the workflow model anchored to Chimeway's existing lifecycle spine rather than inventing a parallel orchestration subsystem.
- Treat transition reasons the way Chimeway already treats suppression, deferral, digest resolution, and recovery reasons: durable, machine-readable, and operator-visible.

</specifics>

<deferred>
## Deferred Ideas

- Time-based wait gates and due-step execution semantics — Phase 25.
- Outcome-based branching and duplicate-safe progression claims — Phase 25.
- Escalations and terminal stop/cancel behavior — Phase 26.
- Journey inspection APIs and host-submitted progression signals — Phase 27.
- Reference workflow examples, broader docs polish, and milestone closure work — Phase 28.
- Read/unread-driven branching as a primary workflow driver — deferred beyond this milestone's core time/outcome spine.

</deferred>

---

*Phase: 24-workflow-contracts-state-spine*
*Context gathered: 2026-04-29*
