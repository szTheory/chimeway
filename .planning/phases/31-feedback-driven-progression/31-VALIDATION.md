---
phase: 31
slug: feedback-driven-progression
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-01
---

# Phase 31 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` |
| **Full suite command** | `mix test` |

## Sampling Rate

- **After every task commit:** Run the task's automated verification command.
- **Before `/gsd-verify-work`:** Full suite must be green.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command |
|---------|------|------|-------------|-----------|-------------------|
| 01-T1 | 01 | 1 | FLOW-01, FLOW-02 | ExUnit (mix ecto.migrate) | `mix ecto.migrate` |
| 01-T2 | 01 | 1 | FLOW-01, FLOW-02 | ExUnit | `mix test test/chimeway/deliveries_test.exs test/chimeway/orchestration/delivery_planning_test.exs test/chimeway/orchestration/workflow_progression_test.exs` |
| 02-T1 | 02 | 2 | FLOW-01, FLOW-02 | ExUnit | `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` |

## Validation Sign-Off

- [x] All tasks have `<automated>` verify blocks
- [x] `nyquist_compliant: true` set