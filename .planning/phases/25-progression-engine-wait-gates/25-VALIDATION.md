---
phase: 25
slug: progression-engine-wait-gates
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-29
---

# Phase 25 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + DataCase/integration tests |
| **Config file** | `config/test.exs` |
| **Quick run command** | `mix test test/chimeway/delivery_attempt_test.exs test/chimeway/trigger_pipeline_test.exs` |
| **Full suite command** | `mix test test/chimeway/**/*workflow* test/chimeway/**/*delivery*` |
| **Estimated runtime** | ~30 seconds for the targeted slice, full suite longer |

---

## Sampling Rate

- **After every task commit:** Run the smallest affected progression-focused test slice.
- **After every plan wave:** Run `mix test test/chimeway/**/*workflow* test/chimeway/**/*delivery*`.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 30 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 25-01-01 | 01 | 1 | WRK-02 | T-25-01 | Workflow progression derives one stable, explainable branch outcome from persisted delivery facts and refuses non-branchable states. | unit | `mix test test/chimeway/delivery_attempt_test.exs test/chimeway/trigger_pipeline_test.exs` | ✅ existing suites; Phase 25 mapper tests pending | ⬜ pending |
| 25-02-01 | 02 | 2 | WRK-02, ESC-03 | T-25-02 | Due-step claims advance at most once and persist wait/branch evidence on workflow transitions under retries. | integration | `mix test test/chimeway/**/*workflow* test/chimeway/**/*delivery*` | ⚠ workflow progression tests to add in Phase 25 | ⬜ pending |
| 25-03-01 | 03 | 3 | ESC-03 | T-25-03 | Concurrent due-run workers and duplicate claims do not emit duplicate next-step deliveries or mutate historical delivery rows. | integration + concurrency | `mix test test/chimeway/**/*workflow* test/chimeway/**/*delivery*` | ⚠ concurrency-focused Phase 25 tests to add | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [ ] Add a focused progression outcome mapper test file covering the curated outcome vocabulary against delivery status, suppression reason, and latest-attempt evidence.
- [ ] Add workflow progression integration coverage for due-time advancement and outcome-based branching from persisted rows.
- [ ] Add concurrency-focused regression coverage proving duplicate claims/retries cannot emit duplicate next-step deliveries.

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Operator-facing wait anchor facts remain readable from durable workflow transitions | WRK-02 | Final journey inspection surfaces land in Phase 27, so this phase can only prove the durable facts exist, not the final operator API | After targeted tests pass, inspect persisted `workflow_transitions` rows and confirm wait/progression entries include anchor source, delivery, outcome, and timestamp facts without relying on queue state. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
