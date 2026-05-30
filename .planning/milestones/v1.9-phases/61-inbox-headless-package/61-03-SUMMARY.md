---
phase: 61-inbox-headless-package
plan: 03
subsystem: testing
tags: [phoenix, liveview, exunit, inbox, bell-dropdown]

requires:
  - phase: 61-02
    provides: BellDropdownLive, AllowAuth/DenyAuth test doubles, test router with live_session on_mount
provides:
  - chimeway_inbox LiveViewCase SQL sandbox + insert_inbox_notification!/2 fixtures
  - bell_dropdown_live_test.exs proving INBX-02 list → mark_read → badge refresh
  - verify.example chimeway_inbox lane (GATE-05 prep)
affects: [62]

tech-stack:
  added: []
  patterns:
    - "LiveView tests mount via test router live/2 so live_session on_mount runs before mount"
    - "Shared SQL sandbox owner in LiveViewCase for DB-backed LiveView journeys"

key-files:
  created:
    - chimeway_inbox/test/support/fixtures.ex
    - chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs
  modified:
    - chimeway_inbox/test/support/live_view_case.ex
    - mix.exs

key-decisions:
  - "Use live/2 on TestSupport.Router instead of live_isolated — opts on_mount not merged without live_session"
  - "mark_seen omitted from LiveView tests — BellDropdownLive v1.9 does not invoke mark_seen (D-08 discretion)"
  - "verify.inbox CI job deferred to Phase 62; verify.example lane only in 61-03"

patterns-established:
  - "Pattern: ChimewayInbox.TestSupport.Fixtures.insert_inbox_notification!/2 for package LiveView DB seeds"
  - "Pattern: Unauthorized bell mount asserted via DenyAuth + {:error, {:redirect, _}}"

requirements-completed: [INBX-02]

duration: 20min
completed: 2026-05-30
---

# Phase 61 Plan 03: Package LiveViewTest Coverage Summary

**Five LiveViewTests prove INBX-02 inbox bell journey (list → mark_read → badge refresh, unauthorized fail-closed, UI-SPEC copy) using package test harness only — no demo host glue.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Extended `ChimewayInbox.LiveViewCase` with SQL sandbox ownership and `insert_inbox_notification!/2` fixture helper.
- Added `bell_dropdown_live_test.exs` with five tests covering mount/list, mark_read badge refresh, unauthorized redirect, empty-state copy, and load-more footer copy.
- Appended `chimeway_inbox` test lane to root `mix.exs` `verify.example` alias (selective `verify.inbox` CI deferred to Phase 62).

## Task Commits

Each task was committed atomically:

1. **Task 1: LiveViewCase sandbox + notification fixtures (D-08)** - `73d9ee6` (test)
2. **Task 2: Bell dropdown LiveView tests (D-07, D-08)** - `d041283` (test)
3. **Task 3: verify.example parity for chimeway_inbox** - `510f556` (feat)

**Plan metadata:** `d0a2ebe` (docs)

## Files Created/Modified

- `chimeway_inbox/test/support/fixtures.ex` - Event + Notification insert helper for LiveView tests
- `chimeway_inbox/test/support/live_view_case.ex` - Sandbox owner, AllowAuth default, fixture import
- `chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs` - INBX-02 package proof (5 tests)
- `mix.exs` - verify.example includes chimeway_inbox shell command

## Decisions Made

- Mount tests through `ChimewayInbox.TestSupport.Router` at `/` so `live_session` `on_mount` assigns `recipient_identity` before `BellDropdownLive.mount/3`.
- Skipped mark_seen LiveView assertion — v1.9 bell dropdown only wires mark_read from row actions.

## Deviations from Plan

### Auto-fixed Issues

**1. live_isolated on_mount opts do not run LiveAuth before mount**
- **Found during:** Task 2 (bell_dropdown_live_test.exs)
- **Issue:** `live_isolated/3` with `on_mount:` option does not merge hooks into lifecycle without router `live_session`; mount raised KeyError on missing `recipient_identity`
- **Fix:** Use `init_test_session/2` + `live(conn, "/")` through test router (matches production mount path)
- **Files modified:** `chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs`
- **Verification:** All 5 LiveView tests green
- **Committed in:** `d041283` (Task 2 commit)

**2. Phoenix.ConnTest deprecation blocked --warnings-as-errors**
- **Found during:** Task 2 verification (`mix test --warnings-as-errors`)
- **Issue:** `use Phoenix.ConnTest` emits deprecation warning treated as error
- **Fix:** Switch LiveViewCase to `import Plug.Conn` + `import Phoenix.ConnTest`
- **Files modified:** `chimeway_inbox/test/support/live_view_case.ex`
- **Verification:** `cd chimeway_inbox && mix test --warnings-as-errors` exits 0
- **Committed in:** `d041283` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking test harness, 1 warnings-as-errors)
**Impact on plan:** No scope or API changes. mark_seen optional per plan discretion remains deferred.

## Issues Encountered

None beyond deviations above.

## User Setup Required

None - no external service configuration required.

## Verification Results

| Check | Result |
|-------|--------|
| `cd chimeway_inbox && mix test --warnings-as-errors` | PASS (6 tests) |
| `bell_dropdown_live_test.exs` has 4+ tests with mark_read badge assert | PASS (5 tests) |
| `grep chimeway_inbox mix.exs` | PASS |
| No demo host files modified | PASS |

## Next Phase Readiness

- Phase 61 complete — all three plans executed; INBX-01/02 satisfied.
- Phase 62 ready: demo host mount, inbox guide, doc-contract, and `mix verify.inbox` CI gate.

---
*Phase: 61-inbox-headless-package*
*Completed: 2026-05-30*
