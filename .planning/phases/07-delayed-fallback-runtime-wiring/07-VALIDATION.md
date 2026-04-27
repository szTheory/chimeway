---
phase: 07
slug: delayed-fallback-runtime-wiring
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-24
---

# Phase 07 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix test aliases) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/chimeway/policy/delayed_fallback_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/integration/delivery_lifecycle_test.exs` |
| **Full suite command** | `mix ci.test` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/policy/delayed_fallback_test.exs test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/integration/delivery_lifecycle_test.exs`
- **After every plan wave:** Run `mix ci.test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | POLC-03 | TM-07-01 / TM-07-02 | Planner persists valid delayed-fallback intent only for outbound channels | unit+integration | `mix test test/chimeway/integration/delivery_lifecycle_test.exs` | ✅ | ✅ green |
| 07-02-01 | 02 | 1 | POLC-03 | TM-07-03 | Sync and Oban perform-time policy suppresses read notifications before adapter send | unit | `mix test test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/dispatch/oban_worker_test.exs` | ✅ | ✅ green |
| 07-03-01 | 03 | 2 | POLC-03 | TM-07-04 | Trigger-driven evidence covers runtime wiring and zero-attempt suppression outcomes | integration | `mix test test/chimeway/policy/delayed_fallback_test.exs test/chimeway/integration/delivery_lifecycle_test.exs` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved (2026-04-24)

## Validation Audit 2026-04-24
| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
