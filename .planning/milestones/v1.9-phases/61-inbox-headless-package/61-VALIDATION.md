---
phase: 61
slug: inbox-headless-package
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-30
---

# Phase 61 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `mix.exs` (core); `chimeway_inbox/mix.exs` (package) |
| **Quick run command** | `mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_pagination_test.exs --warnings-as-errors` |
| **Package command** | `cd chimeway_inbox && mix test --warnings-as-errors` |
| **Full suite command** | Core quick run + package command |
| **Estimated runtime** | ~15–45 seconds |

---

## Sampling Rate

- **After every task commit:** Run wave-appropriate quick command above
- **After Wave 61-01:** Core inbox tests only
- **After Wave 61-02/03:** Add `cd chimeway_inbox && mix test`
- **Before phase sign-off:** Full suite command green; `mix ci.test` unchanged (inbox not in default CI until Phase 62 GATE-05)
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 61-01-01 | 01 | 1 | INBX-01 | T-61-02 | unread_count scoped to recipient | unit | `mix test test/chimeway/inbox_pagination_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 61-01-02 | 01 | 1 | INBX-01 | T-61-04 | cursor pagination stable order | unit | same | ✅ | ✅ green |
| 61-01-03 | 01 | 1 | INBX-01 | — | struct list when no pagination opts | unit | `mix test test/chimeway/inbox_query_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 61-02-01 | 02 | 2 | INBX-02 | T-61-03 | package compiles; DenyAuth default | compile | `cd chimeway_inbox && mix compile --warnings-as-errors` | ✅ | ✅ green |
| 61-02-02 | 02 | 2 | INBX-02 | T-61-01 | LiveView uses Chimeway public API only | unit | `cd chimeway_inbox && mix test` | ✅ | ✅ green |
| 61-03-01 | 03 | 3 | INBX-02 | T-61-01 | mark_read cannot cross recipients | LiveView | `cd chimeway_inbox && mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs` | ✅ | ✅ green |
| 61-03-02 | 03 | 3 | INBX-02 | — | badge count updates after mark_read | LiveView | same | ✅ | ✅ green |
| 61-03-03 | 03 | 3 | INBX-02 | — | UI-SPEC copy + data-cw-inbox-bell hooks | LiveView | same | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers phase requirements:

- [x] `Chimeway.DataCase` + `inbox_query_test.exs` baseline
- [x] `chimeway_admin` package test harness precedent
- [x] `chimeway_inbox` package scaffold — delivered in Wave 61-02 (not pre-wave)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Host layout embed aesthetics | INBX-02 | Package is unstyled; host CSS | Mount bell in a host layout; confirm `data-cw-*` hooks accept host styles |

*Automated proof covers functional contract; visual polish is host-owned.*

---

## Validation Sign-Off

- [x] All tasks have automated verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter after execution

**Approval:** approved 2026-05-30
