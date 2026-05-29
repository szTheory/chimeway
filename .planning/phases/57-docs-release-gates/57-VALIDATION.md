---
phase: 57
slug: docs-release-gates
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-29
---

# Phase 57 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs`, `config/test.exs` |
| **Quick run command** | `mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix verify.mailglass` |
| **Estimated runtime** | ~60–120 seconds (Mailglass harness + demo proof) |

---

## Sampling Rate

- **After every task commit:** Run quick doc-contract or targeted test from task verify field
- **After every plan wave:** Run `mix ci.verify_gates` (wave 2+) and `mix verify.mailglass` (after plan 03)
- **Before `/gsd-verify-work`:** `mix ci`, `mix ci.verify_gates`, `mix verify.journeys`, `mix verify.mailglass` green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 57-01-01 | 01 | 1 | DOCS-06 | T-57-01 | Guide uses Webhooks.process not Mailglass Plug | doc | `mix test test/chimeway/doc_contract_test.exs` (after 02) | ⬜ | ⬜ pending |
| 57-01-02 | 01 | 1 | DOCS-06 | — | Cross-links bidirectional | manual | Read guide + blueprint Related sections | ✅ | ⬜ pending |
| 57-02-01 | 02 | 2 | DOCS-07 | — | Required phrases locked | unit | `mix ci.verify_gates` | ✅ | ⬜ pending |
| 57-03-01 | 03 | 1 | GATE-04 | T-57-02 | Journey tests exclude mailglass | integration | `mix verify.journeys` | ✅ | ⬜ pending |
| 57-03-02 | 03 | 1 | GATE-04 | — | Named gate runs mailglass only | integration | `mix verify.mailglass` | ⬜ | ⬜ pending |
| 57-03-03 | 03 | 1 | GATE-04 | — | MAINTAINING lists 6 commands | doc | `grep verify.mailglass MAINTAINING.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:
- Mailglass adapter tests (Phase 54–55)
- DEMO-06 proof (Phase 56)
- Doc-contract harness (Phase 33+)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Guide readability | DOCS-06 | Prose quality | Skim all 6 sections for copy-paste runnable blocks |
| HexDocs grouping | D-19 | ExDoc render | `mix docs` and confirm Introduction group lists new guide |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or manual instructions above
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set after execution

**Approval:** pending
