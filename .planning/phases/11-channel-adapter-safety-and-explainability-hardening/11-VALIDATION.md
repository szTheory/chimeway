---
phase: 11
slug: channel-adapter-safety-and-explainability-hardening
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-24
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/traces_test.exs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/traces_test.exs`
- **After every plan wave:** Run `mix ci`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | INTG-02 | T-11-01 | Channel adapter config lookup never creates runtime atoms from channel strings | unit | `mix test test/chimeway/dispatch/sync_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/dispatch/oban_test.exs` | ✅ | ⬜ pending |
| 11-01-02 | 01 | 1 | OPS-01 | T-11-02 | Explainability returns non-raising channel metadata for valid custom channel strings | unit | `mix test test/chimeway/traces_test.exs` | ✅ | ⬜ pending |
| 11-01-03 | 01 | 1 | INTG-02, OPS-01 | T-11-03 | Project quality gate confirms hardened path with no regressions in lint/compile/tests | integration | `mix ci` | ✅ | ⬜ pending |

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
