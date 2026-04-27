---
phase: 15
slug: observability-and-supportability
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-27
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `mix.exs`, `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/chimeway/traces_test.exs test/chimeway/telemetry_integration_test.exs test/chimeway/telemetry_correlation_test.exs` |
| **Full suite command** | `mix test` |

---

## Sampling Rate

- **After every task commit:** Run the task specific test file
- **After every plan wave:** Run `mix test test/chimeway/traces_test.exs test/chimeway/telemetry_integration_test.exs test/chimeway/telemetry_correlation_test.exs`
- **Before `/gsd-verify-work`:** Full suite must be green

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 1 | OBS-01, OBS-03 | T-15-02, T-15-03 | Tenancy prefix options securely propagated | unit | `mix test test/chimeway/traces_test.exs` | ✅ `test/chimeway/traces_test.exs` | ⬜ pending |
| 15-01-02 | 01 | 1 | OBS-02 | T-15-01 | Telemetry safe meta correctly strips PII | unit | `mix test test/chimeway/telemetry_integration_test.exs test/chimeway/telemetry_correlation_test.exs` | ✅ `test/chimeway/telemetry_integration_test.exs` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/chimeway/traces_test.exs`
- [x] `test/chimeway/telemetry_integration_test.exs`
- [x] `test/chimeway/telemetry_correlation_test.exs`

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter
