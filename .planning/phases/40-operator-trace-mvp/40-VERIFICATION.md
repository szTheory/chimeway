---
status: passed
phase: 40-operator-trace-mvp
verified: 2026-05-28
---

# Phase 40 Verification

## Must-haves

| ID | Check | Result |
|----|-------|--------|
| M1 | `chimeway_admin/` compiles with path dep on chimeway, no Phoenix in core `mix.exs` | PASS |
| M2 | `ChimewayAdmin.Auth` + fail-closed `LiveAuth` | PASS |
| M3 | Mountable router with search + detail routes | PASS |
| M4 | Search uses `find_traces_for_recipient/2` and `find_traces_by_correlation_id/1` | PASS |
| M5 | Detail uses `explain_delivery/1` + timeline, no Repo in LiveViews | PASS |
| M6 | Redaction masks recipient + timeline detail keys | PASS |
| M7 | Demo host mounts `/admin/chimeway` with `DemoHost.AdminAuth` | PASS |
| M8 | README + golden-path operator UI cross-links | PASS |

## Automated

- `cd chimeway_admin && mix test` — pass
- `cd examples/chimeway_demo_host && mix test` — pass
- `mix test` (root) — 597 pass

## Human verification (optional)

- Browser walkthrough per demo host README after `mix demo.trace` and `mix phx.server`
