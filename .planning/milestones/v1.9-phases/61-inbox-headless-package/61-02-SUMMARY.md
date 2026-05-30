---
phase: 61-inbox-headless-package
plan: 02
subsystem: ui
tags: [phoenix, liveview, inbox, bell-dropdown, auth]

requires:
  - phase: 61-01
    provides: Chimeway.unread_count/2, paginated list_for_recipient/2 with DTO maps
provides:
  - chimeway_inbox optional Phoenix package (v0.1.0)
  - ChimewayInbox.Auth behaviour with current_recipient/2
  - ChimewayInbox.LiveAuth fail-closed on_mount and ensure_authorized
  - chimeway_inbox_routes macro mounting BellDropdownLive
  - BellDropdownLive with UI-SPEC DOM hooks, copy, and contractual events
affects: [61-03, 62]

tech-stack:
  added: [chimeway_inbox package]
  patterns:
    - "Clone chimeway_admin optional package layout with path dep on core"
    - "Recipient auth via behaviour + LiveAuth fail-closed redirect"
    - "Package LiveView calls Chimeway public API only"

key-files:
  created:
    - chimeway_inbox/mix.exs
    - chimeway_inbox/lib/chimeway_inbox/auth.ex
    - chimeway_inbox/lib/chimeway_inbox/live_auth.ex
    - chimeway_inbox/lib/chimeway_inbox/router.ex
    - chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex
    - chimeway_inbox/test/chimeway_inbox/router_test.exs
  modified: []

key-decisions:
  - "Test endpoint on port 4003 to avoid collision with chimeway_admin (4002)"
  - "BellDropdownLive stub in Task 3 expanded to full UI-SPEC in Task 4"
  - "Router smoke test asserts phoenix_live_view metadata tuple not plug module"

patterns-established:
  - "Pattern: ChimewayInbox.Auth.current_recipient/2 resolves recipient identity from session"
  - "Pattern: Bell dropdown uses data-cw-inbox-* hooks and Chimeway.* public API only"

requirements-completed: [INBX-02]

duration: 30min
completed: 2026-05-30
---

# Phase 61 Plan 02: chimeway_inbox Package Bootstrap Summary

**Optional chimeway_inbox Phoenix package with fail-closed recipient auth, mountable router macro, and unstyled BellDropdownLive implementing the locked UI-SPEC contract.**

## Performance

- **Duration:** ~30 min
- **Tasks:** 4
- **Files modified:** 18 (new package tree)

## Accomplishments

- Bootstrapped `chimeway_inbox/` sibling package with path dep on core, Phoenix/LiveView deps, and empty supervisor.
- Added `ChimewayInbox.Auth` behaviour and fail-closed `LiveAuth` with AllowAuth/DenyAuth test doubles on port 4003.
- Exposed `chimeway_inbox_routes/0` macro with `live_session :chimeway_inbox_bell` and router smoke test.
- Implemented `BellDropdownLive` with UI-SPEC copy, `data-cw-inbox-*` hooks, and events calling `Chimeway.unread_count/1`, `list_for_recipient/2`, `mark_read/3`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Package scaffold (D-04)** - `2fb6c94` (feat)
2. **Task 2: Auth + LiveAuth + test harness (D-05)** - `b56ca02` (feat)
3. **Task 3: Router macro + mount smoke test (D-06)** - `69b7d8b` (feat)
4. **Task 4: BellDropdownLive UI-SPEC implementation (D-07)** - `f4c58be` (feat)

**Plan metadata:** `3e614ec` (docs)

## Files Created/Modified

- `chimeway_inbox/mix.exs` - Package definition v0.1.0 with chimeway path dep
- `chimeway_inbox/lib/chimeway_inbox/auth.ex` - current_recipient/2 behaviour
- `chimeway_inbox/lib/chimeway_inbox/live_auth.ex` - on_mount :inbox_bell + ensure_authorized
- `chimeway_inbox/lib/chimeway_inbox/router.ex` - chimeway_inbox_routes macro
- `chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex` - Bell dropdown LiveView
- `chimeway_inbox/test/chimeway_inbox/router_test.exs` - Route compile smoke test

## Decisions Made

- Added `config/dev.exs` (empty import) — required by config.exs import_config chain; not listed in plan file list.
- Task 3 includes minimal BellDropdownLive stub so router macro compiles; Task 4 replaces with full UI-SPEC implementation.
- Router test matches `metadata[:phoenix_live_view]` tuple (Phoenix 1.8 route shape) rather than legacy plug module assertion.

## Deviations from Plan

### Auto-fixed Issues

**1. Missing config/dev.exs blocked mix compile**
- **Found during:** Task 1 verification
- **Issue:** `import_config "#{config_env()}.exs"` requires dev.exs
- **Fix:** Added minimal `config/dev.exs` with `import Config`
- **Files modified:** `chimeway_inbox/config/dev.exs`
- **Committed in:** `2fb6c94` (Task 1 commit)

**2. BellDropdownLive stub required for Task 3 router compile**
- **Found during:** Task 3 implementation
- **Issue:** Router macro references BellDropdownLive module before Task 4
- **Fix:** Minimal stub LiveView in Task 3; full UI-SPEC in Task 4
- **Files modified:** `chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex`
- **Committed in:** `69b7d8b`, `f4c58be`

**3. Router test assertion adapted for Phoenix 1.8 route metadata**
- **Found during:** Task 3 verification
- **Issue:** `Phoenix.Router.routes/1` returns `plug: Phoenix.LiveView.Plug` not `Phoenix.LiveView.Router`
- **Fix:** Assert on `metadata[:phoenix_live_view]` tuple
- **Files modified:** `chimeway_inbox/test/chimeway_inbox/router_test.exs`
- **Committed in:** `69b7d8b`

---

**Total deviations:** 3 auto-fixed (1 blocking compile, 2 task-order coupling)
**Impact on plan:** No scope or API changes. LiveViewTest journey proof remains in 61-03.

## Issues Encountered

None beyond deviations above.

## User Setup Required

None - no external service configuration required.

## Verification Results

| Check | Result |
|-------|--------|
| `cd chimeway_inbox && mix compile --warnings-as-errors` | PASS |
| `cd chimeway_inbox && mix test test/chimeway_inbox/router_test.exs --warnings-as-errors` | PASS (1 test) |
| No `Chimeway.Inbox` references in chimeway_inbox/lib | PASS |
| BellDropdownLive contains `data-cw-inbox-bell` and `Notifications` copy | PASS |

## Next Phase Readiness

- Ready for 61-03: LiveViewTest journey (list → mark_read → badge refresh) using AllowAuth and package test harness.
- Demo host mount deferred to Phase 62.

---
*Phase: 61-inbox-headless-package*
*Completed: 2026-05-30*
