---
phase: 48
slug: wait-until-pending-signals
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-29
---

# Phase 48 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `mix.exs` aliases (`ci.test`, `ci.verify_gates`) |
| **Quick run command** | `mix test test/chimeway/orchestration/workflow_progression_test.exs test/chimeway/notifier_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.test` |
| **Estimated runtime** | ~30–90 seconds (quick); ~3–5 minutes (full CI) |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run `mix ci.test`
- **Before `/gsd-verify-work`:** `mix ci.test` + `mix ci.verify_gates` must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 48-01-01 | 01 | 1 | READ-01 | T-48-01 | `cancel_signals` validated at normalization; bounded list | contract | `mix test test/chimeway/notifier_contract_test.exs --warnings-as-errors` | ✅ extend | ✅ green |
| 48-01-02 | 01 | 1 | READ-01 | T-48-02 | `enter_waiting` sets `pending_signals` from rule | integration | `mix test test/chimeway/orchestration/workflow_progression_test.exs --warnings-as-errors` | ❌ W0 | ✅ green |
| 48-02-01 | 02 | 2 | READ-01 | T-48-03 | SignalRouterWorker matches without host glue | integration | `mix test test/chimeway/dispatch/signal_router_worker_test.exs test/chimeway/orchestration/workflow_progression_test.exs --warnings-as-errors` | ✅ extend | ✅ green |
| 48-03-01 | 03 | 3 | READ-01 | — | Journey guide documents `cancel_signals`; READ-01 gap removed | doc contract | `mix ci.verify_gates` | ✅ update | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/chimeway/orchestration/workflow_progression_test.exs` — describe `"wait_until auto-populates pending_signals (READ-01)"` with `cancel_signals` fixture
- [x] `test/chimeway/notifier_contract_test.exs` — accept valid `cancel_signals`, reject invalid shapes
- [x] `guides/flows/multi-step-journeys.md` — remove READ-01 gap; document DSL
- [x] `test/chimeway/doc_contract_test.exs` — add `cancel_signals` to `@required`

*Wave 0 covers new test fixtures and doc contract extensions before engine implementation tasks.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | — | — |

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 90s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** retroactive sign-off via plan 53-01 (2026-05-29)
