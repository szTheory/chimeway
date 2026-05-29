---
phase: 50
slug: natural-escalation-demo
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-29
---

# Phase 50 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `examples/chimeway_demo_host/config/test.exs` — Sync dispatcher, Oban manual |
| **Quick run command** | `cd examples/chimeway_demo_host && mix test --only jour_03 --warnings-as-errors` |
| **Full suite command** | `mix verify.journeys` + `mix ci.verify_gates` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run targeted `jour_03` or `doc_contract_test.exs`
- **After every plan wave:** Wave 1 → `mix verify.journeys`; Wave 2 → `mix ci.verify_gates`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 50-01-01 | 01 | 1 | DEMO-03 | — | N/A | code review | grep `wait_until` in payment_reminder.ex | ✅ modify | ✅ green |
| 50-01-02 | 01 | 1 | DEMO-03 | — | N/A | code review | grep absence of `stage_escalation_webhook` | ✅ delete | ✅ green |
| 50-01-03 | 01 | 1 | DEMO-03 | — | N/A | code review | file deleted | ✅ delete | ✅ green |
| 50-01-04 | 01 | 1 | DEMO-03 | — | N/A | journey | `mix test --only jour_03` | ❌ W0 | ✅ green |
| 50-02-01 | 02 | 2 | DEMO-04 | — | N/A | doc contract | `mix ci.verify_gates` | ❌ W0 | ✅ green |
| 50-02-02 | 02 | 2 | DEMO-04 | — | N/A | doc contract | `mix ci.verify_gates` | ❌ W0 | ✅ green |
| 50-02-03 | 02 | 2 | DEMO-04 | — | N/A | doc contract | `mix ci.verify_gates` | ❌ W0 | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `payment_reminder.ex` — `wait_until` + `cancel_signals` workflow
- [x] `seeds.ex` — trigger-only; remove adapter swap + `stage_escalation_webhook/1`
- [x] Delete `pending_webhook_adapter.ex`
- [x] `journey_test.exs` — JOUR-03 READ path
- [x] Create `guides/recipes/mention-escalation.md`
- [x] `multi-step-journeys.md` — intro line 7 + recipe link
- [x] `doc_contract_test.exs` — mention-escalation describe block
- [x] `mix.exs` — docs extras entry

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Recipe in Hex docs extras | DEMO-04 | Grep-only in CI | Confirm `mix.exs` docs extras lists mention-escalation |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** retroactive sign-off via plan 53-01 (2026-05-29)
