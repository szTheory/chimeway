---
phase: 68
slug: admin-truth-alignment
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-04
---

# Phase 68 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit 1.19.5 with Phoenix LiveViewTest |
| **Config file** | Root `mix.exs`, `chimeway_admin/mix.exs`, `examples/chimeway_demo_host/mix.exs` |
| **Quick run command** | `cd chimeway_admin && mix test test/chimeway_admin/routes_test.exs test/chimeway_admin/live/trace_search_live_test.exs` |
| **Full suite command** | `mix ci.verify_gates && (cd chimeway_admin && mix test) && (cd examples/chimeway_demo_host && mix test test/demo_host_web/admin_trace_live_test.exs)` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run the narrow command for the touched surface: admin package tests for route/nav/page edits, root doc-contract tests for docs edits.
- **After every plan wave:** Run `mix ci.verify_gates && (cd chimeway_admin && mix test)`.
- **Before `$gsd-verify-work`:** Run the full suite command above.
- **Max feedback latency:** 120 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 68-01-01 | 01 | 1 | ADMIN-03 | T-68-01 | Demo/admin copy does not misroute operators with stale trace-only or out-of-scope claims | doc contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | yes | pending |
| 68-01-02 | 01 | 1 | ADMIN-01 | T-68-02 | `/admin/chimeway` presents Command Center with Trace Lookup primary and Health, Recovery, Definitions, Feed Debug secondary paths | LiveView unit | `cd chimeway_admin && mix test test/chimeway_admin/live/trace_search_live_test.exs` | yes | pending |
| 68-02-01 | 02 | 1 | ADMIN-02 | T-68-03 | Route helpers, mounted pages, sidebar labels, and page hierarchy match the seven-page operator route map | route + LiveView unit | `cd chimeway_admin && mix test test/chimeway_admin/routes_test.exs test/chimeway_admin/live/trace_search_live_test.exs` | yes | pending |
| 68-02-02 | 02 | 1 | ADMIN-01, ADMIN-02 | T-68-03 | Host-mounted admin pages remain nonblank and navigable through the existing demo-host route pattern | host LiveView test | `cd examples/chimeway_demo_host && mix test test/demo_host_web/admin_trace_live_test.exs` | yes | pending |

---

## Wave 0 Requirements

- [ ] `test/chimeway/doc_contract_test.exs` - add a focused demo-host README admin truth block for ADMIN-03.
- [ ] `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs` - add sidebar labels and command-center secondary-path assertions.
- [ ] `chimeway_admin/test/chimeway_admin/routes_test.exs` - ensure route helper coverage includes Command Center, Trace Lookup, Trace Detail, Feed Debug, Definitions, Health, and Recovery.
- [ ] `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` - extend host-mounted proof only if the planner chooses host route coverage for ADMIN-01/ADMIN-02.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | ADMIN-01, ADMIN-02, ADMIN-03 | All phase behaviors are suitable for automated route, LiveView, host-mounted, or doc-contract assertions | N/A |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency < 120s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-06-04
