---
phase: 49
slug: inbox-read-signal
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-29
---

# Phase 49 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17+) |
| **Config file** | `mix.exs` aliases (`ci.test`, `ci.verify_gates`) |
| **Quick run command** | `mix test test/chimeway/inbox_state_transition_test.exs test/chimeway/orchestration/workflow_progression_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (inbox + progression tests)
- **After every plan wave:** Run `mix ci.test`
- **Before `/gsd-verify-work`:** `mix ci.test` + `mix ci.verify_gates` must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 49-01-01 | 01 | 1 | READ-02 | T-49-01 | Tenant resolved from run/delivery on same notification — never caller-supplied | unit | `mix test test/chimeway/inbox_state_transition_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 49-01-02 | 01 | 1 | READ-02 | T-49-02 | First-transition only; re-mark no duplicate signals | unit | same | ❌ W0 | ⬜ pending |
| 49-01-03 | 01 | 1 | READ-02 | T-49-03 | mark_read does not emit seen signal (INBX-02/03) | unit | same | ✅ | ⬜ pending |
| 49-02-01 | 02 | 2 | READ-02/03 | T-49-04 | mark_read → worker → waiting run resumes without host Signal.track | integration | `mix test test/chimeway/orchestration/workflow_progression_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 49-02-02 | 02 | 2 | READ-03 | T-49-05 | signal_received transition has event_name only, no payload keys | integration | same | ✅ | ⬜ pending |
| 49-03-01 | 03 | 3 | D-09 | — | Journey guide documents inbox emission; READ-02 deferral removed | doc contract | `mix ci.verify_gates` | ✅ | ⬜ pending |
| 49-03-02 | 03 | 3 | READ-02 | — | Doc contract forbids stale deferral phrases | doc contract | same | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `inbox_state_transition_test.exs` — describe `"inbox signal emission (READ-02)"` with Oban.Testing enqueue assertions
- [ ] `inbox_state_transition_test.exs` — re-mark idempotency (signal count == 1)
- [ ] `inbox_state_transition_test.exs` — tenant-unresolved skip (notification-only row, no delivery)
- [ ] `workflow_progression_test.exs` — describe `"mark_read resumes waiting run (READ-02/03)"` using `Chimeway.mark_read` instead of manual `Signal.track`
- [ ] `multi-step-journeys.md` — remove READ-02 deferral; document inbox emission path
- [ ] `doc_contract_test.exs` — replace deferral regex test; add `@required` inbox strings; forbid stale deferral phrases

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | — | — |

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
