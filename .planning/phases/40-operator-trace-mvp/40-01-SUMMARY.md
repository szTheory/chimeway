---
phase: 40-operator-trace-mvp
plan: "01"
subsystem: ui
tags: [phoenix, liveview, auth, operator-trace]

requires: []
provides:
  - chimeway_admin sibling Mix project
  - ChimewayAdmin.Auth behaviour and LiveAuth on_mount
  - Mountable router macro with search/detail LiveView stubs
affects: [40-02, 40-03]

tech-stack:
  added: [phoenix, phoenix_live_view]
  patterns: [fail-closed LiveAuth, mountable router macro]

key-files:
  created:
    - chimeway_admin/mix.exs
    - chimeway_admin/lib/chimeway_admin/auth.ex
    - chimeway_admin/lib/chimeway_admin/live_auth.ex
    - chimeway_admin/lib/chimeway_admin/router.ex
    - chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex
    - chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex
  modified: []

key-decisions:
  - "Separate live_sessions for search (:search_traces) and detail (:view_trace) auth actions"
  - "Unauthorized mounts redirect to / with {:halt, redirect}"

patterns-established:
  - "Host auth via config :auth_module implementing ChimewayAdmin.Auth"

requirements-completed: [OPER-01]

duration: 15min
completed: 2026-05-28
---

# Phase 40 Plan 01 Summary

**Scaffolded optional `chimeway_admin` package with fail-closed auth seam and mountable trace routes.**

## Accomplishments

- Created sibling Mix project with path dep on chimeway (no Phoenix in core).
- Implemented `ChimewayAdmin.Auth` and `ChimewayAdmin.LiveAuth` with tests.
- Added `chimeway_admin_routes/0` macro registering search and detail LiveViews (stubs).

## Self-Check: PASSED

- `cd chimeway_admin && mix compile --warnings-as-errors` — OK
- `cd chimeway_admin && mix test` — OK
