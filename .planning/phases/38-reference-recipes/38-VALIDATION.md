---
phase: 38
slug: reference-recipes
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-28
---

# Phase 38 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution (docs-only phase).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit doc-contract + `mix ci.docs` |
| **Config file** | `mix.exs` aliases — `ci.docs` for HexDocs build |
| **Quick run command** | `mix test test/chimeway/doc_contract_test.exs` |
| **Full suite command** | `mix ci.docs && mix test` |
| **Estimated runtime** | ~25 seconds |

---

## Sampling Rate

- **After every task commit:** Grep gates on edited recipe/guide files
- **After every plan wave:** `mix test test/chimeway/doc_contract_test.exs`
- **Before `/gsd-verify-work`:** `mix ci.docs` green; manual RECP-01 IEx walkthrough recommended
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 38-01-01 | 01 | 1 | RECP-01 | — | Password-reset recipe file created with persona sections | manual | File exists + section checklist | ❌ W0 | ⬜ pending |
| 38-01-02 | 01 | 1 | RECP-01 | — | Real APIs only in RECP-01 | grep | `rg 'Chimeway\.trigger|find_traces_for_recipient|explain_delivery' guides/recipes/password-reset-support-trace.md` | ❌ W0 | ⬜ pending |
| 38-01-03 | 01 | 1 | RECP-01 | — | Three diagnostic branches present | grep | `rg 'quiet_hours|retries_exhausted|succeeded' guides/recipes/password-reset-support-trace.md` | ❌ W0 | ⬜ pending |
| 38-02-01 | 02 | 1 | RECP-02 | — | Feedback escalation recipe created | manual | File exists + progress/stop subsections | ❌ W0 | ⬜ pending |
| 38-02-02 | 02 | 1 | RECP-02 | — | Webhook → signal → trace chain documented | grep | `rg 'ProcessFeedbackWorker|SignalRouterWorker|chimeway\.delivery' guides/recipes/feedback-escalation-workflow.md` | ❌ W0 | ⬜ pending |
| 38-02-03 | 02 | 1 | RECP-02 | — | Demo E2E cross-link present | grep | `rg 'feedback_pipeline_e2e_test' guides/recipes/feedback-escalation-workflow.md` | ❌ W0 | ⬜ pending |
| 38-03-01 | 03 | 2 | RECP-01, RECP-02 | — | Both recipes in mix.exs extras | grep | `rg 'password-reset-support-trace|feedback-escalation-workflow' mix.exs` | ❌ W0 | ⬜ pending |
| 38-03-02 | 03 | 2 | RECP-01, RECP-02 | — | Golden-path + journey cross-links | grep | `rg 'password-reset-support-trace|feedback-escalation-workflow' guides/introduction/golden-path.md guides/flows/multi-step-journeys.md` | ❌ W0 | ⬜ pending |
| 38-03-03 | 03 | 2 | RECP-01, RECP-02 | D-15 | Recipe doc-contract tests pass | unit | `mix test test/chimeway/doc_contract_test.exs` | ❌ W0 | ⬜ pending |
| 38-03-04 | 03 | 2 | RECP-01, RECP-02 | — | HexDocs + CI docs green | integration | `mix ci.docs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers phase requirements — doc-contract extended in plan 03, not Wave 0.

- [x] `mix ci.docs` — HexDocs build with warnings-as-errors
- [x] `test/chimeway/doc_contract_test.exs` — pattern from Phase 37

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Support Operator IEx walkthrough | RECP-01 | No automated doc render test | Follow RECP-01 snippets in host IEx after trigger |
| Product Manager reads feedback story | RECP-02 | Narrative quality | Read recipe; open demo E2E describe blocks |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or manual map row
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
