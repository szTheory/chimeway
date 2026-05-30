# Phase 61: Inbox Headless + Package — Research

**Researched:** 2026-05-30  
**Phase:** 61-inbox-headless-package  
**Requirements:** INBX-01, INBX-02  
**Status:** Ready for planning

---

## 1. Executive Summary

Phase 61 delivers the **v1.9 inbox adoption slice**: UI-ready headless queries on core `chimeway` (no Phoenix in `lib/chimeway`), then an optional sibling package `chimeway_inbox/` modeled on `chimeway_admin/` with mountable bell-dropdown LiveView.

**Gap today** [VERIFIED: `lib/chimeway/inbox.ex`]: `list_for_recipient/2` returns full `%Notification{}` structs, no `unread_count`, no pagination, no `exclude_archived`, no DTO maps.

**Planner takeaway:** Wave 61-01 must preserve backward compatibility — struct list when pagination opts absent; `%{items: [...], has_more: boolean}` when `limit` (or explicit pagination flag) present. Package (61-02) calls **only** `Chimeway` public API, never `Chimeway.Inbox` directly [CITED: 61-CONTEXT.md D-04/D-83].

**Deferred to Phase 62:** `mix verify.inbox`, demo host mount (DEMO-08), integration guide (DOCS-08/09), PubSub badge (INBX-03).

---

## 2. Standard Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Core | Elixir ~> 1.17, Ecto 3.x, PostgreSQL | Phoenix-free in `lib/chimeway` [CITED: AGENTS.md] |
| Optional package | Phoenix 1.7 + LiveView 1.x | Path dep `{:chimeway, path: ".."}` [CITED: chimeway_admin/mix.exs] |
| Test (core) | ExUnit + `Chimeway.DataCase` | Extend `inbox_query_test.exs`; add pagination test module |
| Test (package) | ExUnit + isolated endpoint | Clone `chimeway_admin/test/support/*` pattern [VERIFIED] |
| UI contract | `61-UI-SPEC.md` | Locked copy, DOM `data-*`, events — non-negotiable for 61-02/03 |

---

## 3. Headless API Design (INBX-01)

### 3.1 `unread_count/1`

```elixir
# Chimeway.Inbox.unread_count/1
Notification
|> where(recipient_identity == ^id)
|> where(is_nil(read_at))
|> maybe_exclude_archived(exclude_archived)  # default true
|> select(count())
|> Repo.one()
```

Delegate from `Chimeway.unread_count/1`. Opts: `exclude_archived: true` (default).

### 3.2 Paginated `list_for_recipient/2`

**Trigger pagination** when any of: `:limit`, `:before_inserted_at`, `:before_id` present (or explicit `:paginate, true`).

**Query ordering:** `order_by: [desc: :inserted_at, desc: :id]` for stable cursor.

**Cursor:** `(before_inserted_at, before_id)` — fetch rows strictly older than cursor tuple (tie-break on `id` when `inserted_at` equal).

**Page size:** `limit` default **20** [CITED: UI-SPEC §Pagination].

**`exclude_archived`:** default `true` — `where(is_nil(archived_at))`.

**Return shapes:**
- No pagination opts → `[ %Notification{} ]` (existing behaviour + tests)
- Pagination opts → `%{items: [dto_map], has_more: boolean}` where `has_more` = `length(items) > limit` after fetching `limit + 1`

### 3.3 DTO mapper

Recommend `Chimeway.Inbox.Item` module:

| Key | Source |
|-----|--------|
| `id` | `notification.id` as string |
| `title` | `metadata["subject"] \|\| metadata["title"] \|\| ""` |
| `body_preview` | `metadata["body_preview"] \|\| metadata["preview"] \|\| metadata["body"]` truncated (~120 chars) |
| `inserted_at` | `DateTime.to_iso8601(notification.inserted_at)` |
| `read_at` | ISO8601 or nil |
| `seen_at` | ISO8601 or nil |
| `href` | omitted in v1.9 unless host passes via future assign (Claude discretion) |

Preserve existing `:unread_only` filter alongside new opts.

---

## 4. Package Architecture (INBX-02)

Clone `chimeway_admin/` layout:

```
chimeway_inbox/
  mix.exs
  lib/chimeway_inbox.ex
  lib/chimeway_inbox/auth.ex          # current_recipient/2 behaviour
  lib/chimeway_inbox/live_auth.ex     # on_mount :inbox_bell
  lib/chimeway_inbox/router.ex        # chimeway_inbox_routes/0 macro
  lib/chimeway_inbox/live/bell_dropdown_live.ex
  lib/chimeway_inbox/application.ex
  test/support/{endpoint,router,allow_auth,deny_auth,live_view_case}.ex
  test/chimeway_inbox/live/bell_dropdown_live_test.exs  # Wave 61-03
```

**Auth (D-05):** `ChimewayInbox.Auth` — `@callback current_recipient(session, context) :: {:ok, recipient_identity} | {:error, :unauthorized}`. Config: `config :chimeway_inbox, auth_module: MyApp.InboxAuth`.

**LiveAuth:** Resolve recipient on mount; `{:halt, redirect}` on failure (no chrome). Re-check on events via `ensure_authorized/2` pattern from admin.

**Router macro:** Single `live_session :chimeway_inbox_bell` with `BellDropdownLive` at `/` (host scopes path, e.g. `/inbox/bell`).

**BellDropdownLive assigns:** `recipient_identity`, `unread_count`, `items`, `panel_open`, `has_more`, `load_error`, optional `item_link_fun`.

**Events (UI-SPEC):** `toggle_panel`, `mark_read`, `mark_all_read`, `load_more`, `retry_load` — each calls `Chimeway.*` and refreshes assigns (no PubSub).

**Root mix.exs:** Extend `verify.example` to include `chimeway_inbox` OR add `verify.inbox` stub in Phase 62 only [CITED: deferred GATE-05]. Phase 61: package runs via `cd chimeway_inbox && mix test` in plan acceptance; optional add to `verify.example` second shell line for parity with admin.

---

## 5. Security Notes

| ID | STRIDE | Threat | Severity | Mitigation |
|----|--------|--------|----------|------------|
| T-61-01 | Spoofing | LiveView marks read for another recipient | high | All inbox mutations pass `recipient_identity` from Auth behaviour; queries scoped by identity |
| T-61-02 | Info disclosure | DTO leaks cross-tenant metadata | medium | `list_for_recipient` already scopes by `recipient_identity`; tests assert isolation |
| T-61-03 | Elevation | Missing auth renders inbox chrome | high | LiveAuth fail-closed; DenyAuth in default test config |
| T-61-04 | Tampering | Cursor injection via malformed `before_id` | low | Validate UUID format; ignore invalid cursor → empty page |

---

## 6. Don't Hand-Roll

| Problem | Use instead |
|---------|-------------|
| Phoenix in core inbox | Keep queries in `Chimeway.Inbox`; package only |
| Custom pagination gem | Ecto `limit` + keyset cursor on `(inserted_at, id)` |
| Full page inbox app | Bell dropdown embed only (UI-SPEC) |
| PubSub badge refresh | Deferred INBX-03 |

---

## 7. Common Pitfalls

1. **Breaking `list_for_recipient` return type** — callers expect structs when no pagination opts; gate with explicit opt presence.
2. **Off-by-one `has_more`** — fetch `limit + 1`, trim, set `has_more` from overflow.
3. **Package importing `Chimeway.Inbox`** — violates host boundary; use `Chimeway` delegates only.
4. **Archive in list** — default `exclude_archived: true` must apply to `unread_count` and paginated list.
5. **ISO8601 in DTO vs DateTime in structs** — DTO path only; struct path unchanged.

---

## 8. Phase-Specific Patterns

### File placement (from CONTEXT canonical refs)

| File | Action |
|------|--------|
| `lib/chimeway/inbox.ex` | Add `unread_count/1`, pagination query, `exclude_archived` |
| `lib/chimeway/inbox/item.ex` | New — `to_map/1` |
| `lib/chimeway.ex` | Delegate `unread_count/1` |
| `test/chimeway/inbox_query_test.exs` | Keep struct-path tests green |
| `test/chimeway/inbox_pagination_test.exs` | New — DTO, cursor, has_more, archived filter |
| `chimeway_inbox/*` | New package (clone admin) |

### chimeway_admin clone checklist

- [ ] `mix.exs` deps mirror admin (oban, phoenix, live_view, floki/lazy_html test)
- [ ] `config/test.exs` — Repo sandbox on `Chimeway.Repo`
- [ ] `TestSupport.AllowAuth` returns `{:ok, "user:42"}`
- [ ] Router imports macro in test router

---

## 9. Validation Architecture (Nyquist Dimension 8)

### 9.1 Test framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.17+) |
| Core quick run | `mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_pagination_test.exs --warnings-as-errors` |
| Package quick run | `cd chimeway_inbox && mix test --warnings-as-errors` |
| Phase gate (61) | Core tests + package tests (verify.inbox = Phase 62) |
| Default CI | `mix ci.test` (inbox package not in ci.test until GATE-05) |

### 9.2 ROADMAP success criteria → verification map

| # | Success criterion | Requirement | Automated command | Wave |
|---|-------------------|-------------|-------------------|------|
| 1 | `unread_count`, paginated list, DTO maps on public API | INBX-01 | `mix test test/chimeway/inbox_* --warnings-as-errors` | 61-01 |
| 2 | `chimeway_inbox` router, auth, bell LiveView | INBX-02 | `cd chimeway_inbox && mix test` (compile + mount smoke) | 61-02 |
| 3 | Package tests: list → mark_read/seen → badge | INBX-02 | `cd chimeway_inbox && mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs` | 61-03 |

### 9.3 Per-behaviour verification map

| Behavior | Test type | Command | File exists? |
|----------|-----------|---------|--------------|
| Struct list backward compat | unit | `inbox_query_test.exs` | ✅ |
| unread_count excludes read | unit | `inbox_pagination_test.exs` | ❌ 61-01 |
| Pagination cursor + has_more | unit | same | ❌ 61-01 |
| exclude_archived default | unit | same | ❌ 61-01 |
| DTO keys per UI-SPEC | unit | assert map keys | ❌ 61-01 |
| LiveAuth deny → no panel | LiveView | `bell_dropdown_live_test.exs` | ❌ 61-03 |
| mark_read updates badge | LiveView | same | ❌ 61-03 |
| UI-SPEC copy in HTML | LiveView | floki/assert html | ❌ 61-03 |

### 9.4 Sampling rate

- **After 61-01 commit:** `mix test test/chimeway/inbox_* --warnings-as-errors`
- **After 61-02 commit:** `cd chimeway_inbox && mix compile && mix test` (smoke)
- **After 61-03 / phase sign-off:** full package test file green + core inbox tests

### 9.5 Wave 0 gaps

All test files created within waves — no separate Wave 0 plan. Existing `Chimeway.DataCase` + admin test harness pattern cover infrastructure.

---

## 10. Planner Handoff

**Wave 1 (61-01):** `Chimeway.Inbox.Item`, `unread_count/1`, pagination + DTO branch, `Chimeway` delegate, tests.

**Wave 2 (61-02):** Scaffold `chimeway_inbox`, Auth/LiveAuth/Router, `BellDropdownLive` implementing UI-SPEC DOM/events (unstyled).

**Wave 3 (61-03):** LiveViewTest with AllowAuth, seed notifications via `Chimeway` trigger or DataCase inserts, assert badge + mark_read flow.

**Requirement coverage:** INBX-01 → 61-01; INBX-02 → 61-02 + 61-03.

---

*Research complete — ready for PLAN.md generation*
