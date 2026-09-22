---
phase: 106-idempotent-seen-lifecycle-workflow-proof
type: interaction-only
status: locked
---

# Phase 106 UI Contract

No visual redesign is authorized. Preserve the bell, badge, panel, item list, footer, accessibility attributes, copy, and `data-cw-inbox-*` hooks from Phase 105.

## Interaction states

- Closed → open: reauthorize, mark the currently rendered first page seen, then show authoritative state.
- Open → closed: no lifecycle write.
- Load more while open: reauthorize, append the next page, mark only newly visible rows seen.
- Relevant reload while open: reauthorize, reload page one, mark its visible rows seen.
- Relevant reload while closed: reload badge/items, but do not mark seen.
- Authorization drift: redirect before any lifecycle write.
- Partial marking failure: keep the panel usable and reconcile from durable state; no error copy exposes identifiers.

Seen state does not change unread badge or row controls; those remain read-state semantics.
