---
gsd_state_version: 1.0
milestone: v1.4
milestone_name: Channel Feedback Loops
status: executing
stopped_at: Phase 32 context gathered (assumptions mode)
last_updated: "2026-05-01T20:11:15.725Z"
last_activity: 2026-05-01 -- Phase 32 execution started
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 12
  completed_plans: 10
  percent: 83
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-30)

**Core value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.
**Current focus:** Phase 32 — operator-traces-audit

## Current Position

Phase: 32 (operator-traces-audit) — EXECUTING
Plan: 1 of 2
Status: Executing Phase 32
Last activity: 2026-05-01 -- Phase 32 execution started

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: Persist stable `notification_key` + version for durable identity.
- [Init]: Treat explainability ("why wasn't this sent?") as core value.
- [Init]: Start with durable spine and one-channel slice before channel expansion.
- [10-01]: Thread `notification_key`, `event_id`, and `correlation_id` through the dispatch chain.
- [10-01]: Persist correlation identifiers in `Delivery.metadata` using string keys.
- [10-02]: Enrich all lifecycle telemetry spans with correlation metadata from delivery records.
- [11-01]: Resolve channel adapter configs without creating atoms from runtime channel strings.
- [12-01]: Make Oban planning and enqueueing transactionally consistent.
- [13-01]: Store category preferences separately from per-channel notification preferences.
- [13-02]: Persist recipient policy settings for quiet hours and delivery caps.
- [14-01]: Preserve durable attempt history and terminal convergence across sync and Oban paths.
- [15-01]: Keep trace queries tenancy-aware while preserving safe telemetry redaction.
- [16-01]: Treat installation and integration docs as first-class product surface.
- [v1.2]: Prioritize orchestration behavior before channel breadth to create the next large product-value jump.
- Persist deferred planning facts directly on chimeway_deliveries instead of metadata-only storage.
- Validate recipient time zones against the configured Calendar time zone database at changeset time.
- Handle DST ambiguity by choosing the later occurrence and DST gaps by choosing the first valid instant after the gap.
- Normalize notifier orchestration declarations into explicit immediate vs digest-held modes before persisting planning state.
- Persist quiet-hours deferrals through canonical delivery-row helpers instead of suppression fields or metadata-only storage.
- Keep quiet-hours deferral planning-only until Phase 17-03 adds orchestration readiness gates to dispatch paths.
- Held deliveries remain pending with zero attempts until a later phase adds resume scheduling.
- Dispatchers and workers now require orchestration_state == :ready before immediate execution.
- Trace explanations expose sanitized persisted planning facts and a normalized rule identity.
- Deferred resume mutates the existing delivery row instead of creating replacement deliveries or scheduler-owned state.
- Resume promotion succeeds only when the row is still pending, deferred, and due at update time.
- Supersession converges through status :cancelled plus a durable suppression_reason on the same row.
- Deferred rows now schedule a dedicated Oban resume worker at `next_eligible_at` instead of enqueueing the performer directly.
- Resume-worker job args remain limited to `delivery_id`, with all planning facts read from the canonical delivery row.
- Resume promotion and performer enqueue now share one transaction so `:ready` cannot persist without a canonical dispatch job.
- Digest rules persist stable identity with rule_key plus rule_version and never notifier module names.
- Digest buckets snapshot grouping facts and explicit window boundaries independently from deliveries.next_eligible_at.
- Digest accumulation stays anchored on the canonical delivery row and inserts one membership row per delivery_id instead of using queue-level uniqueness.
- Bucket counters advance only after a membership insert succeeds, using database uniqueness plus atomic updates to avoid retry drift.
- Boundary windows reuse the project’s DST-safe local-time conversion pattern and persist explicit UTC window boundaries independent from deliveries.next_eligible_at.
- Explicit digest declarations keep the persisted orchestration mode normalized to :digest_held and carry digest_key as separate planning metadata.
- DeliveryPlanning invokes digest accumulation only after policy evaluation returns the canonical delivery still pending and digest-held.
- Planner-side digest lookup snapshots category through Policy.delivery_category/1 so accumulation uses the same category resolution path as suppression checks.
- Digest buckets now persist flush claim state plus one emitted digest delivery identity to collapse duplicate executions on the database boundary.
- Digest memberships now persist immutable included/skipped/immediate resolution facts with emitted digest linkage and rule/window snapshots.
- Source deliveries now converge through explicit digest outcomes on the canonical row instead of remaining pending after flush.
- Emitted digests now hand off through dispatch_delivery by delivery_id, reusing the normal sync and Oban lifecycle seams.
- Chimeway.Traces now exposes digest reasoning for both source rows and emitted digest rows without leaking raw payload or provider response data.
- Trigger persistence now stores sanitized render_assigns once and projects the same durable data into metadata for compatibility.
- Canonical delivery inserts receive render_key and render_version before policy evaluation, with reused rows resynchronized through a dedicated helper.
- Planning prefers persisted notification.render_assigns over caller-supplied params when re-resolving per-channel render identity.
- Channel render contracts stay pure maps validated by Ecto changesets so the core library remains independent from Phoenix and Swoosh.
- Shared render dispatch wraps validation failures with channel-tagged errors to match existing planner normalization and test posture.
- Canonical delivery rows now persist validated render_data during planning so adapters and workers consume one durable render artifact.
- Trace explanations project render_key and render_version only; rendered bodies and raw render_data remain excluded from operator surfaces.
- Unsupported custom channels keep durable render identity and empty render_data rather than re-entering rendering inside adapters.
- Preview stays pure and non-persistent by routing through Notifier.resolve_rendering/3 and Rendering.render_delivery/4 without delivery-row writes.
- The Mix task remains a convenience shell that parses local inputs, delegates to Chimeway.preview_rendering/3, and prints stable render identity plus validated payload data.
- Phase 21 local preview uses the same production rendering declaration and channel validation path as dispatch planning.
- Recovery detection for Phase 22 now relies on canonical event/notification/delivery tables only and never inspects Oban job state.
- Recovery claims stamp recovery_source, recovery_reason, and recovered_at on the canonical delivery row exactly once, with duplicate attempts converging to {:noop, delivery}.
- Persisted render_channels remain recovery-only behind use_persisted_channels: true so ordinary notifier-less planning keeps the default in_app path.
- Failed recovery dispatch handoffs clear recovery metadata and restore recoverable age so operators can retry the same canonical row immediately.
- Automatic digest flush scheduling is enabled only when the configured dispatcher is Chimeway.Dispatch.Oban; all other dispatchers keep emit_bucket/2 as the explicit host-managed seam.
- Bucket state remains the scheduling source of truth: accumulation only schedules on the first persisted membership while emit_bucket/2 still owns due/idempotency checks.
- DigestFlushWorker stays thin and carries only bucket_id, mirroring the Phase 18 scheduled worker posture.
- Persist normalized orchestration snapshots on notifications with string-keyed durable fields instead of reconstructing digest semantics from notifier callbacks during recovery.
- Replay recovered orchestration through Notifier.resolve_orchestration/4 override normalization so recovered deliveries keep planner_override explainability while reusing the existing planner seam.
- Use a local PostgreSQL 15.17 runtime to gather production-shaped digest evidence because the host/server default was PostgreSQL 14.17.
- Record the unrelated PostgreSQL 15 full-suite blocker separately instead of weakening the digest closure evidence.
- ObanWorker now persists perform-time `{:defer, decision}` outcomes on the canonical delivery row and reuses the dispatcher seam for follow-up scheduling.
- Digest bucket identity remains derived from locked delivery, notification, and event records; caller lookup_attrs may only supply helper fields or matching identity keys.
- Rejected lookup identity overrides fail with {:invalid_lookup_attrs, mismatch} so ownership-boundary violations are explicit and testable.
- Phase 20 digest closure stays closed only after both the targeted PostgreSQL 15.17 slice and MIX_ENV=test mix ci.test pass.
- Phase 23 closure artifacts keep the automatic digest scheduling boundary explicit for Oban-backed hosts.
- Workflow declarations resolve through an optional workflow/2 callback and serialize into durable string-keyed workflow data.
- Workflow identity persists as definition rows plus ordered step rows keyed by workflow_key and workflow_version.
- Notifications persist nullable workflow_definition_id so trigger-time run creation can reuse durable workflow identity without hiding linkage in metadata.
- Initial workflow truth is split between one current-state workflow_run row and two explicit transition facts: workflow_started and step_activated.
- Canonical delivery linkage resolves from the durable workflow run current_step_id, and only the active-step channel receives workflow_run_id and workflow_step_id.
- Recovery keeps persisted workflow replay behind explicit use_persisted_workflow: true validation while still reading linkage from Chimeway-owned workflow rows.
- Tenant id is required on every WorkflowRun row, asserted via validate_required; legacy internal callers default to 'default' until host-supplied tenancy lands.
- Signals and the State Spine ship in a single migration so the schema arrives atomically before any downstream worker can be wired.
- Chimeway.Signal.track/4 wraps insert + Oban enqueue in one Ecto.Multi so the queued job is rolled back on insert failure — no orphaned signals or jobs.
- SignalRouterWorker ships barebones in 27-01 so the API can reference it; full routing logic is owned by 27-02.
- route_signal uses Ecto.Multi.reduce over matched runs so all updates and transition inserts share one transaction boundary — no partial fan-out possible.
- Cross-tenant isolation is structural: the query always includes tenant_id = ^signal.tenant_id in the WHERE clause; no opt-in required per T-27-03.
- Payload is never written to WorkflowTransition.context — only event_name is recorded, matching the structural-traces-only approach from 27-RESEARCH.md.
- SignalRouterWorker returns {:error, :signal_not_found} for missing signal rows so Oban schedules retry, and :ok for both zero-match and successful routing.
- explain/2 resolves current_step_name via a LEFT JOIN to chimeway_workflow_steps on current_step_id, so callers receive the step key in one query without a separate lookup.
- list_traces/3 uses a two-query pattern: first confirm tenant ownership (returning :not_found on mismatch), then fetch transitions. This keeps the tenant guard structurally mandatory.
- Both functions return {:error, :not_found} rather than an empty result for missing/cross-tenant IDs to prevent timing-based information disclosure.
- Payload safety is structural: WorkflowTransition.context only ever contains structural metadata (event_name, step_key, source); the inspection API does not need to redact anything at query time.
- Backfill legacy workflow runs to tenant_id = 'default' during migration instead of adding a schema default, so future inserts still have to provide tenant_id explicitly.
- Backfill pending_signals to an empty array for pre-27 rows so inspection code never sees NULL for the spine field.
- Keep empty-string tenant rejection at the changeset boundary to align WorkflowRun with the existing Signal validation contract.
- Trigger.trigger/3 now requires host-supplied tenant_id and returns {:error, :missing_tenant_id} when omitted rather than silently using a shared default.
- Workflow run creation keeps tenant identity as an explicit positional argument all the way into Workflows.create_initial_run/5.
- Trigger-created workflow runs are verified through persisted state alone by round-tripping Trigger.trigger/3 into Workflows.explain/2 and Workflows.route_signal/1.
- Keep route_signal/1 on a function-form Repo.transaction so the matching FOR UPDATE query and the resume writes share one database transaction while preserving the existing results-map shape.
- Standardize signal-routing jobs on :chimeway_signals to match the project’s chimeway_* Oban queue naming convention.
- Interpret list_traces(..., limit: 0) as an explicitly bounded empty result instead of falling back to an unbounded read.
- Signal routing enforces cross-tenant and cross-actor isolation structurally via Ecto joins before matching active workflows.
- Provided a realistic SaaS missed-mention escalation as the canonical example for multi-step journeys.
- Clarified synchronous vs async (Oban-backed) progression models in documentation.
- [v1.3]: Prioritize workflow journeys before channel breadth in v1.3. Workflow behavior is the next major product-value jump.
- [v1.4]: Expand outbound channel contracts and implement inbound feedback loops (webhooks) to drive workflow progression based on terminal outcomes (bounced, delivered).
- Wrapped feedback persistence and signal emission in atomic transactions by delegating to Chimeway.Signal.track/4.

### Pending Todos

None.

### Blockers/Concerns

None.

### Roadmap Evolution

- Milestone v1.4 initialized with 4 phases (29-32) focusing on Channel Feedback Loops.

### Deferred Items

- Broad provider expansion beyond the existing outbound seam.
- Read/unread-driven branching as a primary workflow driver.
- Reference operator UI and broader adoption-surface work after workflow semantics stabilize.

### Session Continuity

Last session: --stopped-at
Stopped at: Phase 32 context gathered (assumptions mode)
Resume file: --resume-file

**Planned Phase:** 32 (Operator Traces & Audit) — 2 plans — 2026-05-01T20:09:24.578Z
