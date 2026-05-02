---
phase: 34
slug: feedback-contract-e2e-proof
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-02
---

# Phase 34 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.x) |
| **Config file** | `mix.exs`, `config/test.exs`, `examples/chimeway_demo_host/config/test.exs` |
| **Quick run command** | `mix test test/chimeway/traces_test.exs` (root) and `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` (host) |
| **Full suite command** | `mix test && cd examples/chimeway_demo_host && mix test` |
| **Estimated runtime** | ~60 seconds (root) + ~15 seconds (host E2E) |

---

## Sampling Rate

- **After every task commit:** Run the touched file's quick test (`mix test path/to/file.exs`)
- **After every plan wave:** Run the relevant suite (root or host) end-to-end
- **Before `/gsd-verify-work`:** `mix test` (root) AND `cd examples/chimeway_demo_host && mix test` BOTH green
- **Max feedback latency:** ≤90 seconds (root + host combined)

---

## Per-Task Verification Map

> Boundaries B1–B7 from `34-RESEARCH.md` Validation Architecture. Concrete plan/task IDs are filled in by the planner; this map names the boundaries each plan must cover.

| Boundary | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| **B1: HTTP entry → Ingress write** | 34-01 | 1 | FLOW-01 | — | Endpoint returns 2xx; one `Chimeway.Webhooks.Ingress` row written with `normalized_status` populated and `tenant_id` set | E2E controller | `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` | ❌ W0 | ⬜ pending |
| **B2: Worker drain → DeliveryAttempt + canonical signal emit** | 34-01 | 1 | FLOW-01 | — | After `Oban.drain_queue(:chimeway_delivery)`: one `DeliveryAttempt` with canonical outcome atom (`:succeeded` or `:bounced`); one `Signal` row with `event_name == "chimeway.delivery.succeeded"` (or `.bounced`) | E2E controller | `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` | ❌ W0 | ⬜ pending |
| **B3: Synchronous workflow progression hook (worker call stack)** | 34-01 | 1 | FLOW-02 | — | **Stop path (synchronous):** after `Oban.drain_queue(:chimeway_delivery)` (no signals drain yet), `WorkflowRun.state` already at terminal state via `record_attempt/2 → progress_run/2` from inside the worker call stack. **Progress path (signal-router-driven, intentional per CONTEXT D-06.1):** the `:waiting` run keyed on `pending_signals: ["chimeway.delivery.succeeded"]` flips `:waiting → :active` during DRAIN #2 (`SignalRouterWorker → route_signal/1`), not during DRAIN #1. B3's synchronous-progression boundary is exercised on the stop path; the progress path covers the same end-state through B4. | E2E controller | `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` | ❌ W0 | ⬜ pending |
| **B4: Signal router drain → signal_received transition with delivery_id** | 34-01 | 1 | FLOW-02 | — | After `Oban.drain_queue(:chimeway_signals)`: one `WorkflowTransition` with `reason == "signal_received"` AND `delivery_id == delivery.id` (Phase 32 D-02 wiring) | E2E controller | `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` | ❌ W0 | ⬜ pending |
| **B5: Trace projection — joint timeline assembly** | 34-01 | 1 | FLOW-01, FLOW-02 | — | `Chimeway.Traces.explain_delivery(delivery.id).timeline` carries `:webhook_received` (rank 13) AND at least one `:workflow_*` projection atom (`:workflow_progressed` for progress path, `:workflow_stopped` for stop path) | E2E controller | `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` | ❌ W0 | ⬜ pending |
| **B6: Stop-path equivalence (bounced)** | 34-01 | 1 | FLOW-01, FLOW-02 | — | Repeat B1–B5 with a bounced webhook: signal `event_name == "chimeway.delivery.bounced"`, `WorkflowRun` reaches terminal state, timeline carries `:workflow_stopped` | E2E controller | `cd examples/chimeway_demo_host && mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` | ❌ W0 | ⬜ pending |
| **B7: Trace fixture vocabulary alignment** | 34-02 | 1 | FLOW-01 | — | After fixture edit at `test/chimeway/traces_test.exs:416,523`: `mix test test/chimeway/traces_test.exs` green; `grep -n "chimeway.delivery.delivered" test/chimeway/traces_test.exs` returns 0 lines | unit (existing test rerun) | `mix test test/chimeway/traces_test.exs` | ✅ | ⬜ pending |
| **B8: Audit-closure artifact (FLOW-01/FLOW-02 mapping)** | 34-VERIFICATION | 2 | FLOW-01, FLOW-02 | — | `34-VERIFICATION.md` exists with requirements table mapping FLOW-01 and FLOW-02 to evidence cells citing Phase 31 emission code, Phase 32 trace projection code, and the new Phase 34 E2E test (33-VERIFICATION.md:115-118 format); each plan SUMMARY frontmatter declares `requirements-completed: [FLOW-01, FLOW-02]` | manual file-shape check | `grep -E "^\| FLOW-0[12]" .planning/phases/34-feedback-contract-e2e-proof/34-VERIFICATION.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — new E2E file with progress + stop scenarios (B1–B6)
- [ ] `test/chimeway/traces_test.exs:416,523` — fixture edits replacing `chimeway.delivery.delivered` with `chimeway.delivery.succeeded` / `.bounced` as appropriate (B7)
- [ ] `.planning/phases/34-feedback-contract-e2e-proof/34-VERIFICATION.md` — FLOW-01/FLOW-02 requirements table + Audit Notes section (B8)
- [ ] Existing `test_helper.exs` and sandbox/Oban.Testing setup at `examples/chimeway_demo_host/test/` — already wired by Phase 33; reuse, do not modify

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Audit-stale callout in `34-VERIFICATION.md` Audit Notes section | FLOW-01, FLOW-02 (audit closure) | The callout is documentation prose, not a code-checkable predicate; the next milestone-audit pass reads it | Open `34-VERIFICATION.md`, confirm "Audit Notes" section exists, dated, ≤6 lines, points at `33-VERIFICATION.md:115-118` for FEED-01/02 closure |
| `requirements-completed: [FLOW-01, FLOW-02]` frontmatter on every Phase 34 plan SUMMARY | FLOW-01, FLOW-02 (audit closure pattern) | Closure pattern enforced by milestone-audit tooling, not unit tests | After execute-phase: `grep -E "requirements-completed:" .planning/phases/34-feedback-contract-e2e-proof/*-SUMMARY.md` shows `[FLOW-01, FLOW-02]` on every SUMMARY |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (B1–B6, B8 are MISSING; B7 reuses an existing test)
- [ ] No watch-mode flags
- [ ] Feedback latency ≤90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
