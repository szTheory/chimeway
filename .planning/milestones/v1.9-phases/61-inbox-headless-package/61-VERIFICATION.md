---
phase: 61
slug: inbox-headless-package
status: passed
score: 27/27
requirements:
  INBX-01: passed
  INBX-02: passed
verified_at: 2026-05-30
---

# Phase 61 Verification: Inbox Headless + Package (INBX-01, INBX-02)

**Goal:** Headless inbox API is UI-ready and an optional `chimeway_inbox` package provides mountable bell-dropdown LiveView components for end-user JTBD.

**Status:** `passed` — all must-haves from plans 61-01, 61-02, and 61-03 verified against codebase and automated tests.

## Requirements Traceability

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| **INBX-01** | Headless inbox API exposes UI-ready queries: `unread_count/1`, paginated `list_for_recipient/2` with `exclude_archived`, stable serializable item maps | **passed** | `Chimeway.unread_count/2`, paginated `list_for_recipient/2` returning `%{items, has_more}`, `Chimeway.Inbox.Item.to_map/1`; 6 core inbox tests green |
| **INBX-02** | Optional `chimeway_inbox` package provides mountable router macro, recipient auth behaviour, and unstyled bell-dropdown LiveView | **passed** | Package v0.1.0 with `chimeway_inbox_routes/0`, `ChimewayInbox.Auth`, `BellDropdownLive`; 6 package tests green |

## ROADMAP Success Criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| SC #1: Public API exposes unread_count, paginated list, exclude_archived, DTO maps | **passed** | `lib/chimeway.ex` delegates; `inbox_pagination_test.exs` covers count, DTO keys, has_more, cursor, archived filter |
| SC #2: `chimeway_inbox` exposes router macro, auth behaviour, unstyled bell LiveView | **passed** | `router.ex`, `auth.ex`, `live_auth.ex`, `bell_dropdown_live.ex` with UI-SPEC `data-cw-inbox-*` hooks |
| SC #3: Package tests prove list → mark_read/seen from LiveView handlers | **passed** | LiveViewTest covers mount → list → mark_read → badge refresh; `mark_seen` not wired in BellDropdownLive v1.9 per D-08 plan discretion (API remains on `Chimeway.mark_seen/3`) |

## Plan 61-01 Must-Haves (INBX-01)

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| `unread_count/1` excludes archived by default (D-01) | **passed** | `exclude_archived?/1` default `true`; test `@tag :unread_count` asserts 2 vs 3 |
| Paginated `list_for_recipient/2` returns `%{items, has_more}` (D-02) | **passed** | `list_for_recipient_paginated/2`; `limit: 2` test with cursor second page |
| Non-paginated path returns `[%Notification{}]` (D-02) | **passed** | `list_for_recipient_legacy/2`; `inbox_query_test.exs` green (1 test) |
| DTO maps include id, title, body_preview, inserted_at, read_at, seen_at (D-03) | **passed** | `Item.to_map/1`; DTO keys test; no `href` key |
| Artifact: `lib/chimeway/inbox/item.ex` with `def to_map` | **passed** | Module present |
| Artifact: `lib/chimeway/inbox.ex` with `unread_count` | **passed** | Lines 27–37 |
| Artifact: `lib/chimeway.ex` public `unread_count` delegate | **passed** | Lines 54–55 |
| Artifact: `test/chimeway/inbox_pagination_test.exs` with `has_more` | **passed** | 5 tests |
| Key link: `inbox.ex` → `Item.to_map/1` on paginated branch | **passed** | Line 82 |
| Key link: `chimeway.ex` → `Inbox.unread_count/2` | **passed** | `defdelegate` pattern |
| No Phoenix imports under `lib/chimeway/` | **passed** | `grep Phoenix lib/chimeway` → 0 matches |

## Plan 61-02 Must-Haves (INBX-02)

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| `chimeway_inbox` compiles with path dep on chimeway (D-04) | **passed** | `mix.exs` `{:chimeway, path: ".."}`; compile + test green |
| `ChimewayInbox.Auth` exposes `current_recipient/2`; LiveAuth fail-closed (D-05) | **passed** | `auth.ex` callback; `live_auth.ex` halt redirect + `ensure_authorized/2` |
| `ChimewayInbox.Router` macro mounts BellDropdownLive with live_session + LiveAuth (D-06) | **passed** | `chimeway_inbox_routes/0`; `router_test.exs` smoke |
| BellDropdownLive UI-SPEC DOM hooks and contractual events (D-07) | **passed** | `data-cw-inbox-bell`, panel, items, badge; handlers toggle_panel, mark_read, mark_all_read, load_more, retry_load |
| LiveView uses `Chimeway` public API only — never `Chimeway.Inbox` (D-04) | **passed** | `grep -r 'Chimeway\.Inbox' chimeway_inbox/lib` → empty |
| Artifact: `chimeway_inbox/mix.exs` v0.1.0 | **passed** | `app: :chimeway_inbox` |
| Artifact: `bell_dropdown_live.ex` with `data-cw-inbox-bell` | **passed** | Template line 99 |
| Artifact: `router.ex` with `chimeway_inbox_routes` | **passed** | Macro line 19 |
| Key link: BellDropdownLive → `Chimeway.unread_count`, `list_for_recipient`, `mark_read` | **passed** | Lines 43, 56, 176, 205 |
| Key link: LiveAuth → `auth_module.current_recipient/2` | **passed** | `resolve_recipient/2` |

## Plan 61-03 Must-Haves (INBX-02)

| Truth / Artifact / Link | Status | Evidence |
|-------------------------|--------|----------|
| LiveViewTest: mount → list → mark_read → badge decreases (D-08) | **passed** | `mark_read updates badge count after row click` test |
| `mark_seen` path callable without host glue (D-08) | **passed** | `Chimeway.mark_seen/3` public; LiveView v1.9 defers auto-seen (documented in test comment) |
| Unauthorized auth does not render inbox chrome (D-05) | **passed** | `unauthorized mount redirects without inbox chrome` with DenyAuth |
| UI-SPEC copy and `data-cw-inbox-*` hooks asserted in HTML (D-07) | **passed** | Tests assert `Notifications`, `Mark as read`, `No notifications yet`, `Load more notifications` |
| Artifact: `bell_dropdown_live_test.exs` with mark_read proof | **passed** | 5 tests (≥4 required) |
| Artifact: `mix.exs` `verify.example` includes chimeway_inbox lane | **passed** | Line 88 shell command |
| Key link: LiveViewTest → `Chimeway.mark_read` side effects | **passed** | Asserts `persisted.read_at` after click |

## Automated Gates

| Gate | Result |
|------|--------|
| `mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_pagination_test.exs --warnings-as-errors` | PASS (6 tests, 0 failures) |
| `cd chimeway_inbox && mix test --warnings-as-errors` | PASS (6 tests, 0 failures) |
| `grep -r 'Chimeway\.Inbox' chimeway_inbox/lib` | PASS (0 matches) |
| `mix ci.test` | PASS (825 tests, 0 failures; 27 excluded) |

## Human Verification

**human_needed:** none — functional contract fully automated via core + package ExUnit suites.

Manual-only (per 61-VALIDATION.md): host layout CSS polish when embedding bell in a real host — out of phase 61 scope (unstyled package by design).

## Gaps / Deferred (Out of Phase 61 Scope)

| Item | Phase | Notes |
|------|-------|-------|
| Demo host inbox mount (DEMO-08) | 62 | Journey test in demo host |
| Inbox integration guide + doc-contract (DOCS-08/09) | 62 | |
| `mix verify.inbox` CI gate (GATE-05) | 62 | `verify.example` lane added; selective gate deferred |
| LiveView auto-`mark_seen` on panel open | v1.10+ / INT-03 | D-08 discretion; API ready on core |

## Notes

- INBX-01 and INBX-02 checkboxes in `.planning/REQUIREMENTS.md` remain at planning-doc level; functional closure verified here.
- Package test count: 1 router smoke + 5 LiveView tests.
- Core pagination tests: 5 in `inbox_pagination_test.exs` + 1 legacy struct test in `inbox_query_test.exs`.
