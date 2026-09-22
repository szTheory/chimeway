---
phase: 106-idempotent-seen-lifecycle-workflow-proof
status: complete
created: 2026-09-12
---

# Phase 106 Research

## Existing seams

- `Chimeway.mark_seen/3` conditionally updates `seen_at`, emits `chimeway.notification.seen` only on the first transition, and publishes the Phase 105 reload hint after durable success.
- `BellDropdownLive` already reauthorizes each event, owns the visible `items` page, reloads authoritative state, and receives exact PubSub reload hints.
- `Chimeway.Workflows.route_signal/1` matches waiting runs by exact tenant, actor, and pending event, then atomically clears pending signals and records `signal_received`.
- Demo-host tests already drain the real `:chimeway_signals` Oban queue and assert workflow transitions.

## Implementation guidance

Keep orchestration in the optional LiveView: operate only on scoped item IDs already loaded, call the public core API, and refresh once after the batch. Do not infer seen from disconnected render. The publisher echo is safe because core first-transition idempotency stops repeat signals and repeat change hints.

The end-to-end proof should mount the actual route, open the actual bell, drain the real queue, and assert exactly one seen signal and one workflow transition. Negative variants must exercise exact scope mismatches rather than mocking the router.

## Risks and controls

| Risk | Control |
| --- | --- |
| Closed bell records engagement | Guard all seen marking on the transition to/open state. |
| Page two is marked before visibility | Mark only first-page items on open; mark fetched rows after load-more. |
| PubSub echo loops | Conditional lifecycle update emits only once; repeated calls are no-ops. |
| Authorization changes between mount and action | Reuse `LiveAuth.ensure_authorized/2` before marking. |
| Cross-scope workflow progression | Demo proof asserts tenant and actor mismatches remain waiting. |
