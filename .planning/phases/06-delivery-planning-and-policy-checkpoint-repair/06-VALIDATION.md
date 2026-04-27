---
phase: 06
slug: delivery-planning-and-policy-checkpoint-repair
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-24
---

# Phase 06 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix test) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/policy_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~55 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/policy_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | DLVR-01 | T-06-01 / TM-06-01-CALLBACK-DRIFT | `Notifier.channels/2` contract enforces explicit channel resolution without silent shape coercion | unit | `mix test test/chimeway/trigger_pipeline_test.exs` | ✅ | ⬜ pending |
| 06-01-02 | 01 | 1 | POLC-01, POLC-02 | T-06-02 / TM-06-01-POLICY-BYPASS | Planning-time policy runs before enqueue/adapter call in sync and Oban paths | unit | `mix test test/chimeway/policy_test.exs` | ✅ | ⬜ pending |
| 06-01-03 | 01 | 1 | DLVR-01, INTG-02 | T-06-03 / TM-06-01-HARDCODED-CHANNEL | Planner fans out per recipient x channel and enqueues only pending deliveries | integration | `mix test test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs` | ✅ | ⬜ pending |
| 06-02-01 | 02 | 2 | POLC-02 | T-06-04 / TM-06-02-CHECKPOINT-LOSS | Suppression checkpoint source is persisted for explainability (`planning` vs `perform`) | unit | `mix test test/chimeway/policy_test.exs` | ✅ | ⬜ pending |
| 06-02-02 | 02 | 2 | INTG-02 | T-06-05 / TM-06-02-EXECUTOR-DRIFT | Sync and Oban worker share adapter-attempt execution semantics | unit | `mix test test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs` | ✅ | ⬜ pending |
| 06-03-01 | 03 | 2 | DLVR-01 | T-06-06 / TM-06-03-FANOUT-GAP | Fanout test matrix covers multi-channel and fallback behavior | integration | `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/integration/delivery_lifecycle_test.exs` | ✅ | ⬜ pending |
| 06-03-02 | 03 | 2 | POLC-01, POLC-02 | T-06-07 / TM-06-03-ASYMMETRIC-CHECKPOINTS | Parity harness proves sync and Oban enforce equivalent planning-time policy gates | integration | `mix test test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/policy/delayed_fallback_test.exs` | ✅ | ⬜ pending |
| 06-03-03 | 03 | 2 | DLVR-01, INTG-02 | T-06-08 / TM-06-03-SPINE-REGRESSION | Standard outbound success chain remains durable and explainable post-refactor | integration | `mix test test/chimeway/integration/delivery_lifecycle_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending - ✅ green - ❌ red - ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing ExUnit infrastructure covers all phase requirements.
- [x] Existing fixture helpers in `test/support/chimeway/dispatch_helpers.ex` support policy and dispatch setup.
- [x] Existing Oban test setup (`use Oban.Testing`) is already present.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or existing test dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
