---
phase: 40-operator-trace-mvp
name: operator-trace-mvp
status: issues_found
reviewed_at: 2026-05-28
depth: standard
diff_base: b59d2553^
files_reviewed: 28
files_reviewed_list:
  - chimeway_admin/.formatter.exs
  - chimeway_admin/config/config.exs
  - chimeway_admin/config/dev.exs
  - chimeway_admin/config/test.exs
  - chimeway_admin/lib/chimeway_admin.ex
  - chimeway_admin/lib/chimeway_admin/application.ex
  - chimeway_admin/lib/chimeway_admin/auth.ex
  - chimeway_admin/lib/chimeway_admin/components/timeline_event.ex
  - chimeway_admin/lib/chimeway_admin/live.ex
  - chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex
  - chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex
  - chimeway_admin/lib/chimeway_admin/live_auth.ex
  - chimeway_admin/lib/chimeway_admin/redaction.ex
  - chimeway_admin/lib/chimeway_admin/router.ex
  - chimeway_admin/mix.exs
  - chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs
  - chimeway_admin/test/chimeway_admin/live_auth_test.exs
  - chimeway_admin/test/chimeway_admin/redaction_test.exs
  - chimeway_admin/test/support/allow_auth.ex
  - chimeway_admin/test/support/deny_auth.ex
  - chimeway_admin/test/support/endpoint.ex
  - chimeway_admin/test/support/live_view_case.ex
  - chimeway_admin/test/support/router.ex
  - chimeway_admin/test/test_helper.exs
  - examples/chimeway_demo_host/README.md
  - examples/chimeway_demo_host/config/config.exs
  - examples/chimeway_demo_host/lib/demo_host/admin_auth.ex
  - examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex
  - examples/chimeway_demo_host/lib/demo_host_web/router.ex
  - examples/chimeway_demo_host/mix.exs
  - guides/introduction/golden-path.md
findings:
  critical: 1
  warning: 6
  info: 4
  total: 11
---

# Phase 40 Code Review

**Reviewed:** 2026-05-28  
**Depth:** standard  
**Diff base:** `b59d2553^`  
**Status:** issues_found

## Summary

Phase 40 delivers the intended package shape: sibling `chimeway_admin` Mix project, `ChimewayAdmin.Auth` behaviour, fail-closed `LiveAuth` on mount, mountable router macro, LiveViews that call `Chimeway.Traces` (no direct `Repo` access), view-layer redaction, and demo host wiring with documented prod deny pattern.

Architecture matches D-01–D-18. One **critical** navigation bug breaks the primary demo-host integration path. Several **warnings** affect redaction completeness, auth edge cases, and operator-query DoS. No evidence that dev auth stub bypasses production by default (`DemoHost.AdminAuth` denies unless `ALLOW_DEMO_ADMIN=true`).

**Positive observations:**

- LiveViews correctly delegate to `Chimeway.Traces` — no `Repo` imports in admin lib code.
- Router macro attaches `LiveAuth` to both routes; default config uses `DenyAuth` (fail closed).
- Timeline rendering passes through `Redaction.safe_timeline_detail/1`; nested sensitive keys (`planning_context`, `adapter_module`, `provider_message_id`, `recipient_id`) are excluded by whitelist.
- Demo host documents prod auth replacement and scopes admin under `/admin/chimeway` with CSRF on browser pipeline.

---

## Critical Issues

### CR-01: Hardcoded absolute paths break scoped host mounts

**Files:** `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex:57`, `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex:28,37`

**Issue:** Navigation uses root-absolute paths (`push_navigate(..., to: "/deliveries/#{id}")`, `href="/"`) while the blessed integration mounts routes under a host prefix (demo host: `/admin/chimeway`). Correct detail URL is `/admin/chimeway/deliveries/:id`; search is `/admin/chimeway/`. Clicking a search result navigates to `/deliveries/:id` (404 on demo host). “Back to search” links go to host `/`, not the admin index.

**Impact:** OPER-01 → OPER-02 flow is broken in the documented demo-host walkthrough despite passing unit tests (test router mounts at `/` with no prefix).

**Fix:** Introduce a configurable mount prefix (e.g. `config :chimeway_admin, path_prefix: "/admin/chimeway"`) or use LiveView verified routes / `~p` sigils relative to the mounted scope. Add an integration test with a prefixed router matching demo host.

---

## Warnings

### WR-01: Correlation search is unbounded — operator DoS vector

**File:** `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex:38-39`

**Issue:** Correlation mode calls `Traces.find_traces_by_correlation_id/1` with no `limit`. A broad or shared correlation ID can preload all matching events, notifications, deliveries, and attempts into memory and render a large result list.

**Fix:** Pass a limit (mirror recipient search’s 50) or paginate; consider adding a default limit to the Traces API in a follow-up phase.

---

### WR-02: `redact_recipient/1` passthrough leaks non-email, non-`user:` identities

**File:** `chimeway_admin/lib/chimeway_admin/redaction.ex:26-34`

**Issue:** Identities that are neither `user:` prefixed nor email-shaped (phone numbers, raw webhook URLs, opaque tokens) are returned unchanged in list and detail views. This conflicts with D-13 (“tokenize phone/email where shown”) and the admin IA redaction-by-default rule.

**Fix:** Add explicit branches for common identity shapes (phone, `webhook:`, etc.) or default to a generic mask (e.g. show first/last 2 chars only) when format is unrecognized.

---

### WR-03: `ALLOW_DEMO_ADMIN` production escape hatch

**File:** `examples/chimeway_demo_host/lib/demo_host/admin_auth.ex:17-19`

**Issue:** Production authorization is bypassed when `ALLOW_DEMO_ADMIN=true`. Documented as staging-only, but a mis-set env var on a prod deploy fully opens trace lookup to anyone who can reach `/admin/chimeway` (session actor is set unconditionally by `AdminActor` plug).

**Fix:** Remove env bypass before real prod use; or gate behind explicit compile-time `:dev`/`:test` only and require host-implemented auth for `:prod` releases. Add a compile-time warning when `DemoHost.AdminAuth` is configured in prod.

---

### WR-04: `LiveAuth` has no catch-all for unexpected `authorize/3` returns

**File:** `chimeway_admin/lib/chimeway_admin/live_auth.ex:21-27`

**Issue:** The `case` handles only `:ok` and `{:error, :unauthorized}`. A host auth module returning `{:error, :forbidden}`, `false`, or raising returns `CaseClauseError` — a 500 rather than a controlled deny. Fail-closed in effect, but noisy and harder to reason about than an explicit deny path.

**Fix:** Add a catch-all clause that logs and halts with redirect (or 403), and document allowed return values on `ChimewayAdmin.Auth`.

---

### WR-05: Authorization checked only at LiveView mount, not on events

**Files:** `chimeway_admin/lib/chimeway_admin/live_auth.ex`, `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex:23-57`

**Issue:** `on_mount` gates initial page load; `handle_event("search", ...)` and `handle_event("open_delivery", ...)` do not re-invoke auth. A session revoked after mount (logout elsewhere, role change) can still query traces until disconnect.

**Fix:** Re-check auth in sensitive events or use a shared helper called from mount and event handlers; alternatively document that hosts must rely on LiveView disconnect on session invalidation.

---

### WR-06: `error_class` on detail summary rendered without sanitization

**File:** `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex:69-72`

**Issue:** Last-attempt `error_class` is shown raw. Provider/adapter error classes can embed PII or internal paths. Timeline attempt details correctly filter `error_class` via whitelist, but the summary block bypasses redaction.

**Fix:** Apply the same sensitive-key filter or truncate/hash error classes for display; align with D-14.

---

## Info

### IN-01: Test coverage misses scoped navigation and detail view

**Files:** `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs`, `chimeway_admin/test/chimeway_admin/live_auth_test.exs`

**Issue:** Tests cover mount-only search form render and deny-auth halt. Missing: search execution with Traces, detail LiveView render, `open_delivery` navigation, redaction in rendered HTML, and prefixed-router integration (would have caught CR-01).

**Fix:** Add LiveView tests with AllowAuth + sandbox DB fixtures; add router test under `/admin/chimeway` prefix.

---

### IN-02: Unauthorized redirect target is hardcoded to `/`

**File:** `chimeway_admin/lib/chimeway_admin/live_auth.ex:26`

**Issue:** Denied users redirect to host root, not login page or admin mount path. On demo host, `/` may 404 or expose unrelated content.

**Fix:** Make redirect target configurable (`config :chimeway_admin, unauthorized_redirect: ...`) or accept a host callback.

---

### IN-03: `chimeway_admin` declares Oban as a required runtime dep

**File:** `chimeway_admin/mix.exs:25`

**Issue:** Admin UI does not use Oban directly; dependency exists because `chimeway` path dep pulls Oban modules at compile time. Increases host integration surface for a UI-only package.

**Fix:** Acceptable for MVP; revisit if a `:optional` chimeway surface or compile-time split becomes available.

---

### IN-04: Action-level auth only — no per-delivery or tenancy hook

**Files:** `chimeway_admin/lib/chimeway_admin/auth.ex`, `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex`

**Issue:** `:view_trace` grants access to any delivery ID once authorized. Multi-tenant hosts must enforce tenant scoping inside `authorize/3` or by wrapping Traces calls — not documented in behaviour moduledoc.

**Fix:** Document that hosts should inspect `context` and optionally filter Traces queries by tenant; future phase could pass `delivery_id` in context on detail mount.

---

## Recommendation

**Do not ship browser walkthrough as verified until CR-01 is fixed.** Warnings WR-01, WR-02, and WR-03 should be addressed or explicitly accepted before marking OPER-01/OPER-02 complete for production-adjacent hosts. Info items can roll into Phase 41 verification expansion.
