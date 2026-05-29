---
phase: 40
slug: operator-trace-mvp
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-28
---

# Phase 40 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`chimeway_admin` + demo host) |
| **Config file** | `chimeway_admin/mix.exs`, `examples/chimeway_demo_host/mix.exs` |
| **Quick run command** | `cd chimeway_admin && mix test` |
| **Full suite command** | `cd chimeway_admin && mix test && cd ../examples/chimeway_demo_host && mix test` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** `cd chimeway_admin && mix compile --warnings-as-errors`
- **After Wave 1:** `cd chimeway_admin && mix test`
- **After Wave 3:** demo host full test suite
- **Before `/gsd-verify-work`:** manual browser walkthrough on `/admin/chimeway`
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 40-01-01 | 01 | 1 | OPER-01 | T-40-01 | Auth behaviour defined; no hard-coded host auth | compile | `cd chimeway_admin && mix compile --warnings-as-errors` | ⬜ W1 | ⬜ pending |
| 40-01-02 | 01 | 1 | OPER-01 | T-40-02 | Router macro exports two live routes only | grep | `rg 'TraceSearchLive|TraceDetailLive' chimeway_admin/lib` | ⬜ W1 | ⬜ pending |
| 40-01-03 | 01 | 1 | OPER-01 | T-40-01 | Unauthorized mount returns forbidden/redirect | unit | `cd chimeway_admin && mix test test/chimeway_admin/live_auth_test.exs` | ⬜ W1 | ⬜ pending |
| 40-02-01 | 02 | 2 | OPER-01 | T-40-03 | Search calls Traces API, not Repo | grep | `rg 'Chimeway\.Traces\.(find_traces|explain_delivery)' chimeway_admin/lib` | ⬜ W2 | ⬜ pending |
| 40-02-02 | 02 | 2 | OPER-01, OPER-02 | T-40-04 | Redaction helper masks email-like recipients | unit | `cd chimeway_admin && mix test test/chimeway_admin/redaction_test.exs` | ⬜ W2 | ⬜ pending |
| 40-02-03 | 02 | 2 | OPER-02 | — | Detail renders timeline events from Explanation | grep | `rg ':workflow_|webhook_received|attempt_recorded' chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex` | ⬜ W2 | ⬜ pending |
| 40-03-01 | 03 | 3 | OPER-01 | T-40-01 | Demo host configures auth_module | grep | `rg 'chimeway_admin|AdminAuth|auth_module' examples/chimeway_demo_host` | ⬜ W3 | ⬜ pending |
| 40-03-02 | 03 | 3 | OPER-01, OPER-02 | — | Golden-path cross-link present | grep | `rg 'admin/chimeway|chimeway_admin|operator' guides/introduction/golden-path.md` | ⬜ W3 | ⬜ pending |
| 40-03-03 | 03 | 3 | OPER-01 | — | Core mix.exs has no phoenix_live_view dep | grep | `! rg 'phoenix_live_view' mix.exs` (repo root) | ✅ | ⬜ pending |
| 40-03-04 | 03 | 3 | OPER-01 | — | Demo host tests pass | integration | `cd examples/chimeway_demo_host && mix test` | ⬜ W3 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing ExUnit + demo host test harness covers phase requirements. Wave 0 creates `chimeway_admin/test/` stubs in Plan 40-01.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Browser search → detail navigation | OPER-01, OPER-02 | LiveView UX | Start demo host, trigger trace via README/IEx, visit `/admin/chimeway`, search recipient, open delivery, confirm timeline shows webhook/workflow events when data exists |
| Production deny-by-default auth | OPER-01 | Documented pattern only in README | Confirm README states non-dev must implement real `AdminAuth` |

---

## Validation Architecture

See `40-RESEARCH.md` § Validation Architecture. Dimension 8 satisfied via this file and per-task grep/unit commands above.
