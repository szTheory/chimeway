---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Delivery Orchestration
status: planning
stopped_at: Phase 18 context gathered (assumptions mode)
last_updated: "2026-04-28T11:25:35.321Z"
last_activity: 2026-04-28
progress:
  total_phases: 6
  completed_phases: 1
  total_plans: 3
  completed_plans: 3
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-28)

**Core value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.
**Current focus:** Phase 17 - Delivery Windows & Deferral Semantics

## Current Position

Phase: 18
Plan: Not started
Status: Ready to plan
Last activity: 2026-04-28

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

### Pending Todos

None.

### Blockers/Concerns

None.

### Deferred Items

- Workflow journeys and escalation trees beyond digest/window orchestration.
- Broad provider expansion beyond the existing outbound seam.

### Session Continuity

Last session: --stopped-at
Stopped at: Phase 18 context gathered (assumptions mode)
Resume file: --resume-file

**Planned Phase:** 17
