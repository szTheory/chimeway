---
phase: 99
slug: multi-installation-delivery-recovery
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-19
---

# Phase 99 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Ecto SQL sandbox; Oban test support where configured |
| **Config file** | `test/test_helper.exs`, `test/support/data_case.ex`, `config/test.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/orchestration/target_recovery_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.test` |
| **Estimated runtime** | Quick suite target: ≤120 seconds; measure during Wave 0 |

---

## Sampling Rate

- **After every task commit:** Run the focused ExUnit command for the target, recovery, trace, or migration files changed by that task.
- **After every plan wave:** Run `mix ci.test`; also run `mix verify.install_golden` and `mix verify.runtime_prefix` when copied migration or runtime-prefix behavior changes.
- **Before phase verification:** The full executable suite must be green.
- **Max feedback latency:** 120 seconds for the focused task-level suite.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 99-W0-PUSH-01 | TBD | 0 | PUSH-01 | T-99-01 / T-99-03 | Reject unscoped, raw, or uncontrolled resolver input; accept only opaque tenant-scoped revisions | unit/integration | `MIX_ENV=test mix test test/chimeway/delivery_target_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 99-W0-PUSH-02 | TBD | 0 | PUSH-02 | T-99-01 / T-99-03 | Preserve tenant isolation and safe evidence for independent target lifecycles | integration | `MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/traces_target_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 99-W0-PUSH-03 | TBD | 0 | PUSH-03 | T-99-02 | Concurrent planning, jobs, and recovery converge without duplicate targets or unexplained requests | integration/concurrency | `MIX_ENV=test mix test test/chimeway/orchestration/target_recovery_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 99-W0-PUSH-04 | TBD | 0 | PUSH-04 | T-99-04 | Keep no-target suppression and partial/mixed provider outcomes distinct and truthful | integration | `MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/traces_target_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 99-W0-RECOV-01 | TBD | 0 | RECOV-01 | T-99-01 / T-99-02 | Recover only bounded, tenant-qualified work and emit safe claim/skip/resume evidence | integration | `MIX_ENV=test mix test test/chimeway/orchestration/target_recovery_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 99-W0-RECOV-02 | TBD | 0 | RECOV-02 | Persist pre-I/O evidence; close possible post-handoff crashes as ambiguous without automatic resend | integration/fault injection | `MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/delivery_target_test.exs` — resolver normalization, unique target rows, state transitions, and no-target/mixed aggregation.
- [ ] `test/chimeway/dispatch/target_worker_test.exs` — claim/start-before-I/O and crash-window fault injection.
- [ ] `test/chimeway/orchestration/target_recovery_test.exs` — bounded tenant recovery and concurrent claims.
- [ ] `test/chimeway/traces_target_test.exs` — target histories and safe target trace DTO projection.
- [ ] Extend existing migration, runtime-prefix, and golden-install suites for every copied template in both supported static storage modes.

---

## Manual-Only Verifications

All Phase 99 tracer and acceptance behavior is objectively machine-testable and must use executable evidence. No conversational UAT or `checkpoint:human-verify` gate is permitted for these requirements.

---

## Validation Sign-Off

- [ ] Every planned task has an automated verification command or an explicit Wave 0 dependency.
- [ ] Sampling continuity: no three consecutive tasks lack automated verification.
- [ ] Wave 0 covers every currently missing test reference.
- [ ] No watch-mode flags are used.
- [ ] Focused feedback latency is below 120 seconds.
- [ ] `nyquist_compliant: true` is set in frontmatter after validation.

**Approval:** pending
