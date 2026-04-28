---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Delivery Orchestration
status: executing
stopped_at: Completed 22-01-PLAN.md
last_updated: "2026-04-28T21:58:58.154Z"
last_activity: 2026-04-28 -- Plan 22-01 completed
progress:
  total_phases: 7
  completed_phases: 6
  total_plans: 22
  completed_plans: 20
  percent: 91
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-28)

**Core value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.
**Current focus:** Phase 22 — Recovery & Outcome Analytics

## Current Position

Phase: 22 — EXECUTING
Plan: 2 of 3
Status: Plan 22-01 completed; Phase 22 execution continues
Last activity: 2026-04-28 -- Plan 22-01 completed

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
- Phase 21 local preview uses the same production rendering declaration and channel validation path as dispatch planning.
- The Mix task remains a convenience shell that parses local inputs, delegates to Chimeway.preview_rendering/3, and prints stable render identity plus validated payload data.
- Recovery detection for Phase 22 now relies on canonical event/notification/delivery tables only and never inspects Oban job state.
- Recovery claims stamp recovery_source, recovery_reason, and recovered_at on the canonical delivery row exactly once, with duplicate attempts converging to {:noop, delivery}.

### Pending Todos

None.

### Blockers/Concerns

None.

### Roadmap Evolution

- Phase 21.1 inserted after Phase 21: Rendering durability and preview hardening (URGENT)

### Deferred Items

- Workflow journeys and escalation trees beyond digest/window orchestration.
- Broad provider expansion beyond the existing outbound seam.

### Session Continuity

Last session: 2026-04-28T21:57:58Z
Stopped at: Completed 22-01-PLAN.md
Resume file: .planning/phases/22-recovery-outcome-analytics/22-01-SUMMARY.md

**Planned Phase:** 22 (recovery-outcome-analytics) — 3 plans — 2026-04-28T21:57:58Z
