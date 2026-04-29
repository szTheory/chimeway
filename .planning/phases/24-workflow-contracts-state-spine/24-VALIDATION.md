---
phase: 24
slug: workflow-contracts-state-spine
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-29
last_audited: 2026-04-29
---

# Phase 24 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Ecto SQL Sandbox |
| **Config file** | `config/test.exs` |
| **Quick run command** | `mix test test/chimeway/notifier_contract_test.exs test/chimeway/trigger_pipeline_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/integration/delivery_lifecycle_test.exs` |
| **Full suite command** | `mix test` or `mix ci.test` |
| **Estimated runtime** | ~30 seconds for the targeted slice, full suite longer |

---

## Sampling Rate

- **After every task commit:** Run the smallest affected workflow test slice.
- **After every plan wave:** Run `mix ci.test`.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 30 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 24-01-01 | 01 | 1 | WRK-01, API-02 | T-24-01 | Workflow declarations normalize into stable `workflow_key`/`workflow_version` plus ordered step rows, rejecting invalid shapes before persistence. | integration | `mix test test/chimeway/notifier_contract_test.exs` | ✅ `test/chimeway/notifier_contract_test.exs` | ✅ green |
| 24-02-01 | 02 | 2 | WRK-03, API-02 | T-24-04 | Trigger-time execution persists one workflow run per notification plus append-only `workflow_started` and `step_activated` history in the same transaction. | integration | `mix test test/chimeway/trigger_pipeline_test.exs` | ✅ `test/chimeway/trigger_pipeline_test.exs` | ✅ green |
| 24-03-01 | 03 | 3 | WRK-03, WRK-01, API-02 | T-24-08 | Canonical deliveries link to workflow run and step rows, and recovery reuses persisted workflow declarations without notifier callback re-entry. | integration | `mix test test/chimeway/orchestration/recovery_test.exs test/chimeway/integration/delivery_lifecycle_test.exs` | ✅ `test/chimeway/orchestration/recovery_test.exs`, `test/chimeway/integration/delivery_lifecycle_test.exs` | ✅ green |

*Status: ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [x] Extend `test/chimeway/notifier_contract_test.exs` with workflow declaration normalization and invalid-shape coverage.
- [x] Extend `test/chimeway/trigger_pipeline_test.exs` with workflow run and transition persistence assertions.
- [x] Extend `test/chimeway/orchestration/recovery_test.exs` with a callback-free persisted-workflow replay regression.
- [x] Extend `test/chimeway/integration/delivery_lifecycle_test.exs` with delivery linkage assertions for `workflow_run_id` and `workflow_step_id`.

Evidence:
- `test/chimeway/notifier_contract_test.exs` covers normalization, invalid declaration rejection, and replay-safe serialization.
- `test/chimeway/trigger_pipeline_test.exs` asserts persisted `workflow_started` and `step_activated` transitions plus per-notification workflow runs.
- `test/chimeway/orchestration/recovery_test.exs` proves `use_persisted_workflow: true` avoids workflow callback re-entry during recovery.
- `test/chimeway/integration/delivery_lifecycle_test.exs` proves canonical deliveries persist `workflow_run_id` and `workflow_step_id`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Explainability from persisted workflow data alone | WRK-03 | Operator-facing journey traces land in Phase 27, so Phase 24 can only prove the durable facts exist, not the final query API | Inspect persisted workflow definition, run, transition, and linked delivery rows after the targeted integration tests pass and confirm the active step and transition reasons are readable without queue state. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated after execution audit

## Validation Audit 2026-04-29

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Targeted verification passed:

- `mix test test/chimeway/notifier_contract_test.exs test/chimeway/trigger_pipeline_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/integration/delivery_lifecycle_test.exs`
- Result: 44 tests, 0 failures
