---
phase: 23
slug: digest-flush-scheduling-audit-closure
status: ready
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-28
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Ecto SQL Sandbox + Oban.Testing where async worker paths are involved |
| **Config file** | `config/test.exs` |
| **Quick run command** | `mix test test/chimeway/digests/accumulation_test.exs test/chimeway/digests/emission_test.exs test/chimeway/integration/digest_delivery_lifecycle_test.exs test/chimeway/orchestration/digest_explainability_test.exs test/chimeway/orchestration/recovery_test.exs` |
| **Full suite command** | `mix test` or `mix ci.test` |
| **Estimated runtime** | ~30 seconds for the targeted slice, full suite longer |

---

## Sampling Rate

- **After every task commit:** Run the smallest affected digest/recovery slice.
- **After every plan wave:** Run `mix ci.test`.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 30 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 23-01-01 | 01 | 1 | DIGEST-02 | T-23-01 | Accumulation schedules exactly one future `DigestFlushWorker` per bucket window using durable bucket identity, and duplicate scheduling or worker execution still collapses onto one emitted digest identity. | integration | `mix test test/chimeway/digests/flush_scheduling_test.exs test/chimeway/digests/emission_test.exs test/chimeway/integration/digest_delivery_lifecycle_test.exs` | ❌ W0 | ⬜ pending |
| 23-02-01 | 02 | 1 | DIGEST-03 | T-23-02 | Recovered events that originally required digest accumulation replay persisted orchestration semantics and remain `:digest_held` instead of degrading to immediate send. | integration | `mix test test/chimeway/orchestration/recovery_test.exs test/chimeway/orchestration/digest_explainability_test.exs test/chimeway/traces_test.exs` | ✅ partial / ❌ scheduler-specific gaps | ⬜ pending |
| 23-03-01 | 03 | 2 | DIGEST-02, DIGEST-03 | T-23-03 | Production-shaped verification proves the scheduled bucket job, not a manual `emit_bucket/2` call, drives canonical digest dispatch and the documentation/traceability artifacts reflect the verified implementation. | integration | `mix test test/chimeway/integration/digest_delivery_lifecycle_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/traces_test.exs` | ✅ partial / ❌ verification-doc gap | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/digests/flush_scheduling_test.exs` — prove accumulation schedules exactly one future `DigestFlushWorker` per bucket window and respects deterministic `scheduled_at`.
- [ ] Extend `test/chimeway/integration/digest_delivery_lifecycle_test.exs` — prove a scheduled flush job, not a manual `emit_bucket/2` call, drives emitted digest dispatch through the canonical delivery path.
- [ ] Extend `test/chimeway/orchestration/recovery_test.exs` — add a regression for recovered events whose original orchestration is `:digest_held`.
- [ ] Create `20-VERIFICATION.md` — document the verified production-shaped path named by the roadmap.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Production-shaped confidence on PostgreSQL 15+ | DIGEST-02, DIGEST-03 | Local tooling currently confirms a PostgreSQL 14.17 client, while project guidance targets PostgreSQL 15+ | Verify the final scheduled digest flow in CI or a confirmed PostgreSQL 15+ runtime before claiming milestone closure. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** ready for execution
