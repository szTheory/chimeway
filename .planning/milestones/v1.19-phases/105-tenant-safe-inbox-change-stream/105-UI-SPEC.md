---
phase: "105"
slug: tenant-safe-inbox-change-stream
status: approved
shadcn_initialized: false
preset: none
created: "2026-09-12"
---

# Phase 105 — UI Design Contract

> Interaction-only contract for real-time inbox refresh. Phase 105 intentionally preserves the shipped visual design and copy.

## Design System

| Property | Value |
|----------|-------|
| Tool | none |
| Preset | not applicable |
| Component library | existing Phoenix HEEx structural markup |
| Icon library | none |
| Font | host-owned/inherited |

## Spacing Scale

No spacing values change in this phase. Existing host-owned and `data-cw-inbox-*` styling remains authoritative.

## Typography

No typography changes. The bell accessible label, panel heading, item fields, and buttons retain current roles and DOM order.

## Color

No color changes. Real-time refresh introduces no new visual state color and does not bypass host theming.

## Copywriting Contract

| Element | Copy |
|---------|------|
| Bell zero state | `Notifications` |
| Bell populated state | `Notifications, {count} unread` |
| Empty state heading | `No notifications yet` |
| Empty state body | `When something needs your attention, it will show up here.` |
| Error state heading | `Couldn't load notifications` |
| Error recovery | `Check your connection and try again.` / `Try again` |
| Row action | `Mark as read` |
| Bulk action | `Mark all as read` |
| Pagination action | `Load more notifications` |

## Interaction Contract

- Disconnected mount renders existing authoritative state but never subscribes.
- Connected mount subscribes once only after host authorization and opaque-recipient validation.
- A relevant closed reload message reauthorizes, reloads unread count and the first page, preserves panel open/closed state, and clears stale load errors only after a successful fetch.
- An unrelated message changes no assigns or DOM.
- Authorization drift redirects before any reload query.
- Real-time reload replaces a previously paginated collection with the authoritative first page; the existing `Load more notifications` affordance remains available when applicable.
- No optimistic row insertion, badge increment, notification ID handling, animation, toast, or new loading treatment is introduced.

## UI Considerations

Applicable state considerations resolved: 8 covered, 0 backstop, 0 unresolved.

| Category | Element(s) | Status | Resolution / Reason |
|----------|------------|--------|---------------------|
| zero/one/many | bell badge | ✅ covered | Zero hides the badge and uses `Notifications`; one or many renders the authoritative unread count and plural-safe current label. |
| empty/populated | item collection | ✅ covered | Relevant reloads preserve the existing empty copy or replace the collection with current first-page items. |
| partial/overflow | paginated collection | ✅ covered | A reload resets to page one and recomputes `has_more`; older pages are never merged with a new snapshot. |
| loading | badge and item collection | ✅ covered | Existing synchronous reload behavior remains; this phase adds no spinner, skeleton, optimistic content, or intermediate loading copy. |
| error/recovery | load failure | ✅ covered | Reload failures retain the existing bounded error state and retry control without exposing adapter or query details. |
| open/closed | bell panel | ✅ covered | Background reload updates data without changing `panel_open`. |
| authorized/revoked | connected subscription | ✅ covered | Every reload rechecks host authorization; drift redirects before querying or rendering another scope. |
| relevant/unrelated | process messages | ✅ covered | Only the exact closed reload tuple invokes reload; every other message is ignored. |

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| none | none | not required |

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS — all existing exact copy is preserved.
- [x] Dimension 2 Visuals: PASS — no visual redesign or new state treatment.
- [x] Dimension 3 Color: PASS — no color changes.
- [x] Dimension 4 Typography: PASS — semantic roles and DOM order stay stable.
- [x] Dimension 5 Spacing: PASS — no spacing changes.
- [x] Dimension 6 Registry Safety: PASS — no external UI registry.
- [x] Dimension 7 Inventory Provenance: PASS — no design system/component inventory applies.

**Approval:** approved 2026-09-12
