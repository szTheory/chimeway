---
phase: 70
slug: recovery-auth-and-tenancy-hardening
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-04
---

# Phase 70 — Validation Strategy

> Per-phase validation contract for recovery authorization, stale/noop handling, durable evidence, and tenant-scoped admin reads.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit / Phoenix LiveViewTest |
| **Config file** | `mix.exs`, `config/test.exs`, `chimeway_admin/mix.exs` |
| **Quick run command** | `mix test test/chimeway/admin_test.exs test/chimeway/deliveries_test.exs test/chimeway/orchestration/recovery_test.exs chimeway_admin/test/chimeway_admin/live_auth_test.exs` |
| **Full suite command** | `mix test test/chimeway/admin_test.exs test/chimeway/deliveries_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/traces_test.exs --warnings-as-errors && cd chimeway_admin && mix test --warnings-as-errors` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick command above or the narrower changed-file ExUnit command named in the task.
- **After every plan wave:** Run `mix test test/chimeway/admin_test.exs test/chimeway/deliveries_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/traces_test.exs --warnings-as-errors && cd chimeway_admin && mix test --warnings-as-errors`.
- **Before `$gsd-verify-work`:** The targeted root tests and `chimeway_admin` package tests must be green.
- **Max feedback latency:** 60 seconds for quick checks, 180 seconds for the admin gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 70-01-01 | 01 | 1 | SAFE-01, SAFE-04 | T-70-01-01 / T-70-01-02 | Host actor, action, params, session, tenant scope, and resource facts flow through the existing `authorize/3` seam; safe recovery opts exclude raw params/session. | live/unit | `cd chimeway_admin && mix test test/chimeway_admin/live_auth_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 70-01-02 | 01 | 1 | SAFE-04 | T-70-01-03 / T-70-01-04 | Dashboard, health, feed, definitions, and recovery reads use one host-derived tenant scope, and scoped recovery candidates omit unproven event candidates. | unit | `mix test test/chimeway/admin_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 70-02-01 | 02 | 2 | SAFE-01, SAFE-02, SAFE-03, SAFE-04 | T-70-02-01 / T-70-02-02 / T-70-02-03 / T-70-02-04 | Recovery submit requires reason plus confirmation, re-authorizes with selected candidate facts, calls public recovery APIs only, and treats stale/noop as normal. | live | `cd chimeway_admin && mix test test/chimeway_admin/live/recovery_live_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 70-02-02 | 02 | 2 | SAFE-02, SAFE-03, SAFE-04 | T-70-02-04 | Recovery confirmation and tenant-scope UI stay scoped under `.chimeway-admin`, wrap long evidence, and add no dependency. | live/css contract | `cd chimeway_admin && mix test test/chimeway_admin/live/recovery_live_test.exs test/chimeway_admin/design_system_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 70-03-01 | 03 | 2 | SAFE-02, SAFE-03 | T-70-03-01 / T-70-03-02 / T-70-03-03 | Core recovery persists only allowlisted safe evidence and duplicate attempts preserve the first durable metadata. | unit | `mix test test/chimeway/deliveries_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 70-03-02 | 03 | 2 | SAFE-02, SAFE-03 | T-70-03-01 / T-70-03-04 | Public recovery APIs preserve noop/no-duplicate behavior and trace projection exposes safe recovery evidence only. | integration/unit | `mix test test/chimeway/orchestration/recovery_test.exs test/chimeway/traces_test.exs --warnings-as-errors` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs` — create in Plan 70-02 for SAFE-01, SAFE-02, SAFE-03, and SAFE-04 LiveView proof.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or existing Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all MISSING references.
- [x] No watch-mode flags.
- [x] Feedback latency target recorded.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-06-04
