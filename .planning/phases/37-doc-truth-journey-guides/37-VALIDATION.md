---
phase: 37
slug: doc-truth-journey-guides
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-28
---

# Phase 37 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution (docs + lightweight doc-contract test).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`doc_contract_test.exs`) + manual grep checklist |
| **Config file** | `mix.exs` aliases — `ci.docs`, `ci` |
| **Quick run command** | `mix test test/chimeway/doc_contract_test.exs` |
| **Docs command** | `mix ci.docs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~5s doc-contract test; ~20s with full CI |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/doc_contract_test.exs` (when test exists) + grep gates on edited guides
- **After every plan wave:** Run `mix ci.docs`
- **Before `/gsd-verify-work`:** Full suite green; manual checklist in this file complete
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 37-01-01 | 01 | 1 | DOCS-03 #1 | — | Journey guide uses Notifier `workflow/2` with `wait_until`/`on_outcome`/`stop` | grep | `rg 'wait_until|on_outcome|stop' guides/flows/multi-step-journeys.md` | ❌ W0 | ⬜ pending |
| 37-01-02 | 01 | 1 | DOCS-03 #1 | — | No aspirational APIs in primary flow | grep | `rg 'Chimeway\.Workflow|stop_conditions|:wait' guides/flows/multi-step-journeys.md` expect 0 | ❌ W0 | ⬜ pending |
| 37-01-03 | 01 | 1 | DOCS-03 #2 | — | INV-002 deferred callout present | grep | `rg 'Deferred|READ-0|pending_signals' guides/flows/multi-step-journeys.md` | ❌ W0 | ⬜ pending |
| 37-01-04 | 01 | 1 | DOCS-03 #1 | — | Correct trigger/signal APIs | grep | `rg 'Chimeway\.trigger/3' guides/flows/multi-step-journeys.md`; `rg 'Chimeway\.Trigger\.trigger' guides/flows/` expect 0 | ❌ W0 | ⬜ pending |
| 37-02-01 | 02 | 2 | DOCS-03 #1 | — | Oban worker paths corrected | grep | `rg 'Chimeway\.Dispatch\.(WorkflowProgressionWorker|SignalRouterWorker)' guides/recipes/oban-integration.md`; `rg 'Workflows\.Workers' guides/` expect 0 | ✅ | ⬜ pending |
| 37-03-01 | 03 | 3 | DOCS-03 #3 | — | Doc-contract test forbids/requires journey guide strings | unit | `mix test test/chimeway/doc_contract_test.exs` | ❌ W0 | ⬜ pending |
| 37-03-02 | 03 | 3 | DOCS-03 #3 | — | HexDocs + CI pass | integration | `mix ci.docs && mix ci` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Journey guide doc-contract describe block in `doc_contract_test.exs` (D-15)
- [ ] Rewritten `guides/flows/multi-step-journeys.md` (primary deliverable)
- [ ] Fixed `guides/recipes/oban-integration.md` worker modules and queue guidance

Already available:

- [x] `mix ci.docs`
- [x] `mix ci`
- [x] Engine test fixtures (`workflow_progression_test.exs`, `workflows_test.exs`, `feedback_pipeline_e2e_test.exs`)
- [x] Phase 36 validation pattern template

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Semantic accuracy (WR-02, pending_signals gap) | DOCS-03 #1, #2 | Prose correctness beyond grep | Verify guide describes `temporary_failure` early-fire warning; Deferred section cites `enter_waiting` does not set `pending_signals` |
| Fresh-host escalation timing | DOCS-03 #1 | No automated doc-contract CI until Phase 41 | Trigger notifier with `wait_until` fixture; converge in_app → run `:waiting`; past-due `progress_run/2` → email step; `Workflows.explain/2` shows expected `status_reason` |
| Delivery-feedback signal path | DOCS-03 #1 | Cross-link existence + narrative | Confirm guide links demo E2E test and golden-path webhook appendix |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
