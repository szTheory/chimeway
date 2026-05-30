# Phase 61: Inbox Headless + Package - Context

**Gathered:** 2026-05-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Headless inbox API is UI-ready on core `chimeway`, and an optional `chimeway_inbox` Phoenix package provides mountable bell-dropdown LiveView components for the Feature Developer JTBD (SEED-004 INBX slice).

**In scope:** `unread_count/1`, paginated `list_for_recipient/2` with DTO maps, `chimeway_inbox` package (Auth, LiveAuth, Router macro, BellDropdownLive), package LiveViewTest coverage.

**Out of scope (later phases):** Demo host mount + journey proof (Phase 62 DEMO-08), inbox integration guide + doc-contract (Phase 62 DOCS-08/09), `mix verify.inbox` CI gate (Phase 62 GATE-05), real-time PubSub badge refresh (INBX-03 / v1.10).

**Depends on:** v1.7 inbox lifecycle + read/seen signal emission (Phases 48–49 shipped).

**Requirements:** INBX-01, INBX-02
</domain>

<decisions>
## Implementation Decisions

### Headless API polish (Wave 61-01)
- **D-01:** Add `Chimeway.unread_count/1` (delegate to `Chimeway.Inbox`) counting notifications where `read_at IS NULL`, honoring `exclude_archived` (default `true`).
- **D-02:** Extend `list_for_recipient/2` with pagination opts: `limit` (default **20** per UI-SPEC), cursor via `before_inserted_at` + `before_id` tie-break, `exclude_archived: true` default. When pagination opts present, return `%{items: [dto_maps], has_more: boolean}`; when absent, retain current `%Notification{}` struct list for backward compatibility (existing tests/guides).
- **D-03:** Stable DTO maps include UI-SPEC keys: `id`, `title`, `body_preview`, `inserted_at`, `read_at`, `seen_at`, optional `href`. Map `title` from `metadata["subject"] || metadata["title"]`; `body_preview` from `body` / `preview` / `body_preview` with sensible truncation; timestamps as ISO8601 strings.

### Package bootstrap (Wave 61-02)
- **D-04:** New sibling package `chimeway_inbox/` cloned from `chimeway_admin/` — path dep on `chimeway`, Phoenix/LiveView deps, `test/support` endpoint harness. Core `lib/chimeway` stays Phoenix-free.
- **D-05:** `ChimewayInbox.Auth` behaviour resolves `current_recipient/2` → `{:ok, recipient_identity}` | `{:error, :unauthorized}` (identity from session/assigns). `ChimewayInbox.LiveAuth` on_mount fail-closed mirroring `ChimewayAdmin.LiveAuth`.
- **D-06:** `ChimewayInbox.Router` macro mounts `ChimewayInbox.Live.BellDropdownLive` under host scope with live_session + LiveAuth. Hosts embed bell in layout chrome via scoped LiveView route (not full-page admin-style surface).

### UI contract & testing (Wave 61-02/03)
- **D-07:** Approved `.planning/phases/61-inbox-headless-package/61-UI-SPEC.md` is locked for Wave 2–3 — copy, DOM `data-*` hooks, LiveView events (`toggle_panel`, `mark_read`, `mark_all_read`, `load_more`, `retry_load`), accessibility. No PubSub badge refresh (INBX-03 deferred).
- **D-08:** Wave 61-03 package LiveViewTests prove list → mark_read/seen → badge count refresh using package test support (AllowAuth-style); no demo host glue — demo mount deferred to Phase 62.

### Claude's Discretion
- Exact cursor opt names (`before_inserted_at` vs `cursor`) and DTO mapper module location (`Chimeway.Inbox` vs `Chimeway.Inbox.Item`).
- Whether `href` comes from host-configured `item_link_fun` assign vs omitted in v1.9.
- Package version alignment with core hex release (0.1.0 bootstrap like `chimeway_admin`).
- Archive action exposure in bell UI (UI-SPEC allows optional single-step archive; may omit in v1.9 if scope tight).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

| Ref | Path | Why |
|-----|------|-----|
| Phase goal | `.planning/ROADMAP.md` (Phase 61) | Success criteria, waves 61-01..03, cross-cutting constraints |
| Requirements | `.planning/REQUIREMENTS.md` (INBX-01, INBX-02) | Locked acceptance for headless API + optional package |
| UI design contract | `.planning/phases/61-inbox-headless-package/61-UI-SPEC.md` | Locked copy, DOM, events, pagination, DTO keys — Wave 2–3 |
| Brand tokens | `prompts/chimeway-brand-book.md` (§28) | CSS hook recommendations referenced by UI-SPEC |
| Inbox core API | `lib/chimeway/inbox.ex` | Current list/mark_read/mark_seen/archive implementation |
| Public API | `lib/chimeway.ex` | Delegates to Inbox; add unread_count + pagination surface |
| Notification schema | `lib/chimeway/notifications/notification.ex` | Lifecycle columns, metadata/render_assigns for DTO mapping |
| Trigger metadata | `lib/chimeway/trigger.ex` | `build/2` output stored in `metadata` / `render_assigns` |
| Admin package template | `chimeway_admin/` (`Auth`, `LiveAuth`, `Router`, `Routes`, test support) | Clone target for chimeway_inbox structure |
| Demo host admin mount | `examples/chimeway_demo_host/lib/demo_host_web/router.ex` | Reference host integration pattern |
| v1.9 planning decisions | `.planning/STATE.md` | INBX via optional package; clone chimeway_admin; no PubSub |
| Inbox query tests | `test/chimeway/inbox_query_test.exs` | Baseline list/unread_only behavior to extend |
| Inbox integration tests | `test/chimeway/inbox_integration_test.exs` | Trigger → list → lifecycle transition spine |
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Chimeway.Inbox`** — `list_for_recipient/2`, `mark_read/3`, `mark_seen/3`, `archive/3` with first-transition signal emission (READ-02).
- **`Chimeway` public module** — delegates inbox lifecycle; add `unread_count/1` and paginated list here.
- **`Notification` schema** — `recipient_identity`, `read_at`, `seen_at`, `archived_at`, `metadata`, `inserted_at`.
- **`chimeway_admin` package** — Auth behaviour, LiveAuth on_mount, Router macro, Routes path_prefix, test endpoint/router/LiveViewCase pattern.
- **`DemoHost.AdminAuth`** — permissive dev auth reference for optional package behaviour implementation.

### Established Patterns
- Optional Phoenix packages as sibling dirs with path dep on core (`chimeway_admin/mix.exs`).
- Fail-closed LiveAuth: unexpected auth returns logged + treated as unauthorized.
- Build output from notifiers lands in `metadata` / `render_assigns` (same map) — DTO title/body extraction follows getting-started `metadata["subject"]` convention.
- v1.7 READ spine: mark_read/mark_seen emit signals on first transition only; lifecycle `:ok` independent of Signal.track result.

### Integration Points
- **Wave 61-01 → 61-02:** Package LiveView calls `Chimeway.unread_count/1`, paginated `list_for_recipient/2`, `mark_read/3`, `mark_seen/3` — no direct Inbox module access from package.
- **Wave 61-02 → 62:** Demo host will mount package router + implement `ChimewayInbox.Auth` (Phase 62).
- **Gap today:** No `unread_count`, no pagination, no DTO maps, no `exclude_archived` filter, no `chimeway_inbox` package directory.
</code_context>

<specifics>
## Specific Ideas

- UI-SPEC approved 2026-05-30 — treat as non-negotiable for bell-dropdown surfaces.
- Clone `chimeway_admin` vertical-slice pattern from v1.9 milestone planning (STATE.md).
- Default page size 20; `exclude_archived: true` by default in list opts.
</specifics>

<deferred>
## Deferred Ideas

- Real-time PubSub bell badge refresh (INBX-03) — v1.10+
- Demo host inbox mount + journey proof (DEMO-08) — Phase 62
- Inbox integration guide + doc-contract tests — Phase 62
- `mix verify.inbox` CI gate — Phase 62
- Campaign/marketing UI, operator trace surfaces — out of scope
</deferred>
