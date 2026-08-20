---
phase: 99
slug: multi-installation-delivery-recovery
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: validated
nyquist_compliant: true
wave_0_complete: true
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
| 99-W0-PUSH-01 | 99-01/03 | 1/2 | PUSH-01 | T-99-01 / T-99-03 | Reject unscoped, raw, or uncontrolled resolver input; accept only opaque tenant-scoped revisions | unit/integration | `MIX_ENV=test mix test test/chimeway/delivery_target_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 99-W0-PUSH-02 | 99-01/03/06 | 1/2/5 | PUSH-02 | T-99-01 / T-99-03 | Every typed adapter error or unexpected return finalizes its exact target attempt without retaining callback material | integration/fault injection | `env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs test/chimeway/delivery_target_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 99-W0-PUSH-03 | 99-02/04/05/06/07 | 1/3/4/5/6 | PUSH-03 | T-99-02 / T-99-07-03 | Concurrent planning, jobs, retryable errors, ambiguity, and recovery converge without duplicate targets or unexplained requests | integration/concurrency | `env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs test/chimeway/orchestration/target_recovery_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 99-W0-PUSH-04 | 99-03 | 2 | PUSH-04 | T-99-04 | Keep no-target suppression and partial/mixed provider outcomes distinct and truthful | integration | `MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/traces_target_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 99-W0-RECOV-01 | 99-05/07 | 4/6 | RECOV-01 | T-99-05-01 / T-99-05-02 / T-99-07-01..05 | Discover tenant-owned event-only and notification-without-delivery gaps, then page event, target, and stale-attempt work through independent capped continuations | integration | `env MIX_ENV=test mix test test/chimeway/orchestration/target_recovery_test.exs test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 99-W0-RECOV-02 | 99-04/05/06/07 | 3/4/5/6 | RECOV-02 | T-99-05-03 / T-99-05-05 / T-99-07-04 | Persist pre-I/O evidence; map provable pre-handoff retry separately from possible handoff ambiguity and never resend ambiguous work | integration/fault injection | `env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs test/chimeway/orchestration/target_recovery_test.exs --warnings-as-errors` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/chimeway/delivery_target_test.exs` — resolver normalization, unique target rows, state transitions, and no-target/mixed aggregation.
- [x] `test/chimeway/dispatch/target_worker_test.exs` — claim/start-before-I/O and crash-window fault injection.
- [x] `test/chimeway/orchestration/target_recovery_test.exs` — bounded tenant recovery and concurrent claims.
- [x] `test/chimeway/traces_target_test.exs` — target histories and safe target trace DTO projection.
- [x] Existing migration, runtime-prefix, and golden-install suites cover both supported static storage modes.

---

## Manual-Only Verifications

All Phase 99 tracer and acceptance behavior is objectively machine-testable and must use executable evidence. No conversational UAT or `checkpoint:human-verify` gate is permitted for these requirements.

---

## Validation Sign-Off

- [x] Every planned task has an automated verification command or an explicit Wave 0 dependency.
- [x] Sampling continuity: no three consecutive tasks lack automated verification.
- [x] Wave 0 covers every currently missing test reference.
- [x] No watch-mode flags are used.
- [x] Focused feedback latency is below 120 seconds.
- [x] `nyquist_compliant: true` is set in frontmatter after validation.

**Approval:** executable evidence complete — the gap-closure command, `mix verify.runtime_prefix`, `mix verify.install_golden`, and `mix ci.test` passed on 2026-08-19.

## Plans 99-06/99-07 Gap-Closure Evidence

| Repaired path | Requirements | Plans / waves | Exact evidence | Observed result |
|---------------|--------------|---------------|----------------|-----------------|
| Adapter error and unexpected-return finalization | PUSH-02 | 99-06 / Wave 5 | `env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs test/chimeway/delivery_target_test.exs --warnings-as-errors` | PASS |
| Retryable-pre-handoff and ambiguous recovery races do not issue a duplicate provider call | PUSH-03, RECOV-02 | 99-06/07 / Waves 5/6 | `env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs test/chimeway/orchestration/target_recovery_test.exs --warnings-as-errors` | PASS |
| Event-only and notification-without-delivery trigger-commit gaps, plus bounded `event_cursor`, `target_cursor`, and `stale_attempt_cursor` continuations | RECOV-01 | 99-07 / Wave 6 | `env MIX_ENV=test mix test test/chimeway/orchestration/target_recovery_test.exs test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors` | PASS |
| RecoveryWorker closed-summary telemetry excludes tenant and target material | RECOV-01 | 99-07 / Wave 6 | `env MIX_ENV=test mix test test/chimeway/orchestration/target_recovery_test.exs --warnings-as-errors` | PASS |
| Complete focused repaired-path matrix | PUSH-01, PUSH-02, PUSH-03, PUSH-04, RECOV-01, RECOV-02 | 99-06/07 / Waves 5/6 | `env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs test/chimeway/orchestration/target_recovery_test.exs test/chimeway/delivery_target_test.exs test/chimeway/traces_target_test.exs test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors` | PASS — 27 tests, 0 failures |
| Static runtime prefix routing | all Phase 99 requirements | 99-07 / Wave 6 | `mix verify.runtime_prefix` | PASS — 19 tests, 0 failures |
| Copied migration installer golden contract | all Phase 99 requirements | 99-07 / Wave 6 | `mix verify.install_golden` | PASS |
| Full CI test gate | all Phase 99 requirements | 99-07 / Wave 6 | `mix ci.test` | PASS |
