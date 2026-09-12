---
phase: 106-idempotent-seen-lifecycle-workflow-proof
status: ready_for_planning
created: 2026-09-12
---

# Phase 106 Context

## Boundary

Opening an authorized bell marks the currently visible first page seen. Loading another page marks only the newly revealed rows. A relevant stream refresh marks refreshed rows only when the panel is already open; a closed panel never implies engagement. Reconnect reloads durable state and starts closed.

## Decisions

- Reauthorize before every panel-open, load-more, or stream-driven seen attempt.
- Use the existing idempotent `Chimeway.mark_seen/3` API; do not add bulk lifecycle semantics or new persistence.
- Mark only IDs already returned by the tenant/recipient-scoped inbox query.
- Contain individual mark failures and reload authoritative state after the batch; publisher echoes may cause reloads but never duplicate transitions/signals.
- Preserve all Phase 105 markup and copy. Seen has no new visual treatment in this phase.
- Prove the workflow path in the demo host through the mounted bell, a waiting run keyed to `chimeway.notification.seen`, and the real signal queue/router.
- Replay, wrong tenant, wrong recipient, and authorization drift must leave the waiting run unchanged.

## Deferred

- Seen/read operator timeline presentation and public adoption guidance belong to Phase 107.
- Read receipts, analytics, per-item visibility observers, and background/mobile engagement remain out of scope.

## Open Questions

None.
