---
phase: 51
slug: journey-admin-proof
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-29
---

# Phase 51 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `examples/chimeway_demo_host/config/test.exs` — Oban manual |
| **Quick run command** | `cd examples/chimeway_demo_host && mix test --only jour_06 --warnings-as-errors` (or `jour_07` / `jour_08`) |
| **Full suite command** | `mix verify.journeys` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run targeted `--only jour_XX` for the task's journey tag
- **After every plan:** Run `mix verify.journeys` (expect 8 tests, 0 failures)
- **Before `/gsd-verify-work`:** `mix verify.journeys` must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 51-01-01 | 01 | 1 | JOUR-06 | — | N/A | journey | `mix test --only jour_06` (read-cancel) | ❌ W0 | ✅ green |
| 51-01-02 | 01 | 1 | JOUR-06 | — | N/A | journey | `mix test --only jour_06` (time-fallback) | ❌ W0 | ✅ green |
| 51-02-01 | 02 | 1 | JOUR-07 | — | N/A | journey | `mix test --only jour_07` | ❌ W0 | ✅ green |
| 51-02-02 | 02 | 1 | JOUR-08 | — | N/A | journey | `mix test --only jour_08` | ❌ W0 | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `journey_test.exs` — JOUR-06 read-cancel test (`mark_read` → no email, `initial_notice` step)
- [x] `journey_test.exs` — JOUR-06 time-fallback test (`progress_run` past `due_at` → one email)
- [x] `admin_trace_live_test.exs` — JOUR-07 Sam suppression admin trace
- [x] `admin_trace_live_test.exs` — JOUR-08 Morgan escalation admin trace

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 45s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** retroactive sign-off via plan 53-01 (2026-05-29)
