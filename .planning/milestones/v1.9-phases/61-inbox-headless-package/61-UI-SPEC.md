---
phase: 61
slug: inbox-headless-package
status: approved
shadcn_initialized: false
preset: none
reviewed_at: 2026-05-30
created: 2026-05-30
---

# Phase 61 — UI Design Contract

> Visual and interaction contract for the optional `chimeway_inbox` bell-dropdown LiveView package (INBX-02). Headless API polish (INBX-01) has no end-user chrome; this contract governs Wave 2–3 UI surfaces only.

**Sources:** `.planning/ROADMAP.md` (Phase 61), `.planning/REQUIREMENTS.md` (INBX-01/02), `.planning/STATE.md` (clone `chimeway_admin`), `prompts/chimeway-brand-book.md` (§28 tokens), `chimeway_admin` package patterns.

**Out of scope (deferred):** Real-time PubSub badge refresh (INBX-03), campaign/marketing UI, operator trace surfaces (`chimeway_admin`), host-specific branding beyond CSS hooks.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (host-owned CSS) |
| Preset | not applicable |
| Component library | Phoenix LiveView 1.x + function components |
| Icon library | Host supplies; package uses semantic hooks only (`data-cw-inbox-bell`, SVG slot optional in v1.9) |
| Font | Host stack; recommend `--cw-font-sans` from brand book |
| Wrapper class | `.chimeway-inbox` on root element (parity with `.chimeway-admin`) |
| Styling model | Unstyled structural markup + `data-*` hooks; no Tailwind/shadcn in package |

Hosts mount via `ChimewayInbox.Router` macro and implement `ChimewayInbox.Auth` (recipient identity from session), mirroring `ChimewayAdmin.Auth` / `ChimewayAdmin.LiveAuth`.

---

## Spacing Scale

Declared values (multiples of 4; align with `--cw-space-*` where host imports brand tokens):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Badge offset from bell, icon–count gap |
| sm | 8px | Row internal padding (compact) |
| md | 16px | Dropdown panel padding, row vertical rhythm |
| lg | 24px | Panel header/footer padding |
| xl | 32px | Gap between bell and dropdown anchor |
| 2xl | 48px | Max dropdown width padding on large viewports (host) |
| 3xl | 64px | — (unused in package defaults) |

Exceptions:

| Exception | Value | Justification |
|-----------|-------|---------------|
| Touch target | 44px min height/width | Bell trigger and row tap targets (WCAG 2.5.5) |
| Unread rail | 3px | Left border accent on unread rows — decorative, not layout grid |

---

## Typography

Four sizes, two weights (brand-aligned):

| Role | Size | Weight | Line Height | CSS hook |
|------|------|--------|-------------|----------|
| Label | 12px (0.75rem / `--cw-text-xs`) | 600 (semibold) | 1.2 | `.chimeway-inbox__meta`, badge count |
| Body | 14px (0.875rem / `--cw-text-sm`) | 400 (regular) | 1.5 | Row title, timestamps |
| Heading | 16px (1rem / `--cw-text-md`) | 600 (semibold) | 1.2 | Panel title "Notifications" |
| Display | 20px (1.25rem / `--cw-text-lg`) | 600 (semibold) | 1.2 | Empty-state heading only |

Unread row title uses weight 600; read rows use 400 (state via `data-unread="true"`).

---

## Color

60/30/10 contract (host maps to `--cw-*` variables):

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#FFFDF8` (`--cw-paper`) | Page/chrome behind bell; dropdown backdrop bleed |
| Secondary (30%) | `#F7F4EA` (`--cw-porcelain`) | Dropdown panel surface, row hover wash |
| Accent (10%) | `#0E7C86` (`--cw-teal`) | Unread count badge fill, unread left rail, focused bell ring |
| Muted text | `#5E6B72` (`--cw-muted`) | Timestamps, secondary line preview |
| Border | `#D8D3C7` (`--cw-line`) | Panel border, row dividers |
| Destructive | `#B83232` (`--cw-danger`) | Archive action text only (if exposed in v1.9 list) |

**Accent reserved for:** unread count badge, unread row left rail (3px), primary text link "Mark all as read", focus-visible outline on bell trigger. **Not** for: read rows, panel background, body copy, archive icon default state.

**Focal hierarchy (Dimension 2):**

1. **Primary focal:** Bell trigger + unread badge (highest contrast accent on porcelain/chrome).
2. **Secondary:** Open dropdown panel — first unread row (semibold title + rail).
3. **Tertiary:** "Mark all as read" / "Load more" actions in panel footer.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Bell `aria-label` (0 unread) | `Notifications` |
| Bell `aria-label` (n unread) | `Notifications, {n} unread` |
| Panel title | `Notifications` |
| Primary CTA (per item) | `Mark as read` |
| Primary CTA (bulk, when ≥1 unread) | `Mark all as read` |
| Pagination CTA | `Load more notifications` |
| Empty state heading | `No notifications yet` |
| Empty state body | `When something needs your attention, it will show up here.` |
| Error state heading | `Couldn't load notifications` |
| Error state body | `Check your connection and try again.` |
| Error retry CTA | `Try again` |
| Unauthorized (fail-closed mount) | No inbox chrome rendered; host redirect only (no copy in package) |
| Archive action (if shown) | `Archive` — no confirmation modal in v1.9 (single-step); host may override styling |

**Destructive confirmation:** Archive is low-risk hide-from-list; no modal in package v1.9. If host enables bulk archive later, use: `Archive {n} notifications?` / `Archive` / `Keep`.

---

## Component & Interaction Contract

### Surfaces (Wave ownership)

| Surface | Plan wave | Responsibility |
|---------|-----------|----------------|
| `Chimeway.unread_count/1`, paginated `list_for_recipient/2`, serializable item maps | 61-01 | Headless; no UI |
| `ChimewayInbox.Live.BellDropdownLive` (name may adjust in plan) | 61-02 | This contract |
| LiveViewTest journey list → mark_read/seen → badge | 61-03 | Asserts below |

### DOM structure (unstyled)

```
.chimeway-inbox
  button[data-cw-inbox-bell][aria-expanded][aria-label]
    span[data-cw-inbox-badge] (hidden when count 0)
  div[data-cw-inbox-panel][role="dialog"] (when open)
    header: h2 "Notifications"
    [data-cw-inbox-error] (conditional)
    ul[role="list"][id="chimeway-inbox-items"]
      li[role="listitem"][data-unread][data-notification-id]
        button "Mark as read" / link to host route (optional assign)
    footer: "Mark all as read" | "Load more notifications"
    [data-cw-inbox-empty] (when list empty, not loading)
```

### LiveView events (contractual)

| Event | Params | Effect |
|-------|--------|--------|
| `toggle_panel` | — | Open/close dropdown; update `aria-expanded` |
| `mark_read` | `%{"id" => id}` | `Chimeway.mark_read/3`; refresh count + row |
| `mark_all_read` | — | Batch mark visible unread; refresh badge |
| `load_more` | — | Next page via `list_for_recipient/2` cursor/limit |
| `retry_load` | — | Re-fetch after error assign |

**Deferred:** `phx-click` refresh on PubSub — not in v1.9; badge updates on user action and full mount only.

### Serializable item map (UI-facing keys)

Planner must ensure 61-01 DTO includes at minimum:

| Key | Type | UI use |
|-----|------|--------|
| `id` | UUID string | `data-notification-id`, mark_read |
| `title` | string | Row heading |
| `body_preview` | string (optional) | Muted second line |
| `inserted_at` | ISO8601 | Relative/absolute time (host formats) |
| `read_at` | nil \| datetime | Drives `data-unread` |
| `seen_at` | nil \| datetime | Optional subtle "seen" vs "read" (v1.9: visual same as read unless host styles) |
| `href` | string (optional) | Row navigation when host assigns `item_link_fun` |

### Accessibility

| Requirement | Implementation |
|-------------|----------------|
| Bell | `type="button"`, `aria-expanded`, dynamic `aria-label` |
| Panel | `role="dialog"`, `aria-labelledby` → panel title id |
| List | `role="list"` / `role="listitem"` |
| Keyboard | `Escape` closes panel; Tab order: bell → panel items → footer actions |
| Focus | On open, focus moves to panel title or first item (host-configurable assign) |
| Badge | `aria-live="polite"` on badge span when count changes |
| Motion | Respect `prefers-reduced-motion` for panel open (host CSS; no animation required in package) |

### Pagination

- Default page size: **20** items (configurable via `Application` env).
- `exclude_archived: true` by default in list opts.
- Footer shows **Load more notifications** when `has_more?` assign is true.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| — | — | not applicable (no shadcn / third-party UI registry) |

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-05-30
