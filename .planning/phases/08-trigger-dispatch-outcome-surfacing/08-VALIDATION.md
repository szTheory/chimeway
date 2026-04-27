---
phase: 8
slug: trigger-dispatch-outcome-surfacing
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-24
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/integration/delivery_lifecycle_test.exs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/integration/delivery_lifecycle_test.exs`
- **After every plan wave:** Run `mix ci.test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | DLVR-04 | T-08-01 | Trigger exposes dispatch/enqueue result instead of swallowing errors | unit | `mix test test/chimeway/trigger_pipeline_test.exs` | ✅ | ⬜ pending |
| 08-01-02 | 01 | 1 | OPS-01 | T-08-02 | Trigger returns durable trace pointers (`event_id`, `correlation_id`, `delivery_ids`) | unit | `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/traces_test.exs` | ✅ | ⬜ pending |
| 08-02-01 | 02 | 2 | DLVR-04 | T-08-03 | Sync and Oban modes expose stage-aware caller-visible outcomes | integration | `mix test test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs` | ✅ | ⬜ pending |
| 08-02-02 | 02 | 2 | DLVR-04, OPS-01 | T-08-04 | Duplicate idempotency path remains non-dispatching and non-enqueuing | integration | `mix test test/chimeway/trigger_pipeline_test.exs test/chimeway/integration/delivery_lifecycle_test.exs` | ✅ | ⬜ pending |
| 08-03-01 | 03 | 3 | OPS-01 | T-08-05 | Caller outcome trace pointers map to durable trace lookup APIs | integration | `mix test test/chimeway/integration/delivery_lifecycle_test.exs test/chimeway/traces_test.exs` | ✅ | ⬜ pending |
| 08-03-02 | 03 | 3 | DLVR-04, OPS-01 | T-08-06 | Full regression gates pass with enriched trigger outcomes | integration | `mix ci` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
