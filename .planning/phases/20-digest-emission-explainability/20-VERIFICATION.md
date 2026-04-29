---
phase: 20-digest-emission-explainability
verified: 2026-04-29T02:10:35Z
status: passed_with_followup
score: 6/6 digest truths verified
overrides_applied: 0
follow_up:
  full_suite_gate:
    command: mix ci.test
    runtime: PostgreSQL 15.17 (Homebrew)
    status: failed
    failing_test: "Chimeway.Integration.DeliveryLifecycleTest resume_deferred_delivery promotes the existing row to orchestration_state == :ready"
    scope: "Unrelated ORCH-03 deferred-resume regression surfaced while gathering PostgreSQL 15+ evidence for DIGEST-02/DIGEST-03."
---

# Phase 20: Digest Emission & Explainability Verification Report

**Phase Goal:** Close digest emission and explainability with durable emitted identity reuse, source-row convergence, and operator-facing reasoning.
**Verified:** 2026-04-29T02:10:35Z
**Status:** passed with follow-up
**Verification scope:** Production-shaped PostgreSQL 15+ evidence for the Phase 23 closure path.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | The primary Oban-backed happy path is `trigger/persist -> digest_held accumulation -> scheduled DigestFlushWorker -> emitted digest dispatch`, not a manual `emit_bucket/2` shortcut. | ✓ VERIFIED | [test/chimeway/integration/digest_delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/digest_delivery_lifecycle_test.exs:90) now asserts `DigestFlushWorker` scheduling, performs the worker, and proves the emitted digest job is enqueued by canonical `delivery_id`. |
| 2 | Emitted digest dispatch reuses one canonical digest delivery identity even if the scheduled flush worker executes more than once. | ✓ VERIFIED | The same integration test performs `DigestFlushWorker` twice and confirms exactly one emitted delivery row survives for the bucket while dispatch still occurs by `delivery_id`. |
| 3 | Source rows converge durably after flush with explicit included or immediate outcomes on the canonical delivery row. | ✓ VERIFIED | The scheduled worker path asserts source deliveries move to `:digested` or `:emitted_immediately`, retain `digest_delivery_id`, and only dispatch the canonical emitted/immediate rows through [lib/chimeway/dispatch/oban_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban_worker.ex:140). |
| 4 | Recovery-replayed digest-held notifications participate in the same bucket semantics as ordinary digest-held rows. | ✓ VERIFIED | [test/chimeway/integration/digest_delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/digest_delivery_lifecycle_test.exs:165) recovers a persisted digest-held notification, joins it to a peer delivery in the same bucket, and flushes both through `DigestFlushWorker`. |
| 5 | DIGEST-03 explainability remains anchored to durable digest resolution facts rather than payload/provider leaks. | ✓ VERIFIED | Prior Phase 20 explainability coverage still stands in [test/chimeway/orchestration/digest_explainability_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/digest_explainability_test.exs:17) and [test/chimeway/traces_test.exs](/Users/jon/projects/chimeway/test/chimeway/traces_test.exs:592), while the scheduled-worker integration proof now closes the missing runtime path. |
| 6 | Built-in automatic scheduling closure in this phase is limited to Oban-backed hosts; non-Oban hosts retain the documented host-managed `emit_bucket/2` seam. | ✓ VERIFIED | [lib/chimeway/digests.ex](/Users/jon/projects/chimeway/lib/chimeway/digests.ex:7) and Phase 23 Plan 01 intentionally scope automatic `DigestFlushWorker` scheduling to Oban-backed installs only, which this verification preserves explicitly. |

**Score:** 6/6 digest truths verified

## Runtime Evidence

### PostgreSQL 15+ Targeted Verification

| Item | Value |
| --- | --- |
| PostgreSQL Runtime: | `15.17 (Homebrew)` |
| Runtime Command: | `MIX_ENV=test DATABASE_URL=postgres://$USER@localhost:55432/chimeway_test mix test test/chimeway/integration/digest_delivery_lifecycle_test.exs test/chimeway/digests/flush_scheduling_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/traces_test.exs --trace` |
| Result | `48 tests, 0 failures` |
| Relevant commit | `09b412a` (`feat(23-03): prove scheduled digest worker lifecycle`) |

The targeted PostgreSQL 15.17 run is the production-shaped evidence path for `DIGEST-02` and `DIGEST-03`. It exercises the scheduled `DigestFlushWorker` path, durable bucket scheduling, recovery replay, and trace explainability on the same runtime family used by CI (`postgres:15` in [.github/workflows/ci.yml](/Users/jon/projects/chimeway/.github/workflows/ci.yml:35)).

### Full Verification Gate Attempt

| Item | Value |
| --- | --- |
| PostgreSQL Runtime: | `15.17 (Homebrew)` |
| Runtime Command: | `MIX_ENV=test DATABASE_URL=postgres://$USER@localhost:55432/chimeway_test mix ci.test` |
| Result | `361 tests, 1 failure` |
| Failing test | `Chimeway.Integration.DeliveryLifecycleTest resume_deferred_delivery promotes the existing row to orchestration_state == :ready` |

`mix ci.test` was executed as required while gathering the PostgreSQL 15+ evidence. The only failure was an unrelated deferred-resume integration regression outside the digest files changed by Plan 23-03:

```text
** (CaseClauseError) no case clause matching:
{:defer, %{orchestration_state: :deferred, planning_reason: "quiet_hours", ...}}
```

This blocker affects the full-suite gate, but it does not change the targeted digest closure evidence above. The digest-specific runtime path required by Phase 23 is verified; the unrelated ORCH-03 failure remains follow-up work.

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Scheduled digest worker integration path | `mix test test/chimeway/integration/digest_delivery_lifecycle_test.exs --trace` | `3 tests, 0 failures` on the host runtime before PostgreSQL 15 replay | ✓ PASS |
| PostgreSQL 15 targeted digest/recovery/traces slice | `mix test test/chimeway/integration/digest_delivery_lifecycle_test.exs test/chimeway/digests/flush_scheduling_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/traces_test.exs --trace` | `48 tests, 0 failures` | ✓ PASS |
| Full verification gate attempt | `mix ci.test` | `361 tests, 1 failure` due to unrelated deferred-resume regression | ⚠ FOLLOW-UP |

## Requirements Coverage

| Requirement | Status | Evidence |
| --- | --- | --- |
| `DIGEST-02` | ✓ SATISFIED | The scheduled `DigestFlushWorker` path now proves one emitted digest identity per bucket, canonical `delivery_id` dispatch, and durable source-row convergence via [test/chimeway/integration/digest_delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/digest_delivery_lifecycle_test.exs:90) plus [test/chimeway/digests/flush_scheduling_test.exs](/Users/jon/projects/chimeway/test/chimeway/digests/flush_scheduling_test.exs:27). |
| `DIGEST-03` | ✓ SATISFIED | Explainability remains covered by [test/chimeway/orchestration/digest_explainability_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/digest_explainability_test.exs:17) and [test/chimeway/traces_test.exs](/Users/jon/projects/chimeway/test/chimeway/traces_test.exs:592), with the missing scheduled/recovery runtime path now closed by the new integration coverage. |

## Closure Summary

Phase 23 closes the missing digest scheduling audit gap for `DIGEST-02` and `DIGEST-03`: the scheduled `DigestFlushWorker` runtime path is now proven on PostgreSQL 15.17, the recovery replay path joins the same durable bucket semantics, and the scope boundary remains explicit for Oban-backed versus host-managed installs. The follow-up full-suite blocker is operational debt outside the digest closure path, not a remaining gap in the digest verification itself.

## Scope Boundary

Automatic digest flush scheduling is **closed only for Oban-backed hosts** in this phase. Non-Oban hosts still use the documented host-managed flush seam through `emit_bucket/2`; this verification does not claim automatic scheduling beyond that boundary.

## Follow-Up

| Area | Status | Notes |
| --- | --- | --- |
| `mix ci.test` on PostgreSQL 15.17 | Follow-up required | Full-suite attempt exposed an unrelated deferred-resume regression in `test/chimeway/integration/delivery_lifecycle_test.exs:815`. |
| Digest scheduling / explainability closure | Complete | No digest-specific failures remained in the targeted PostgreSQL 15.17 regression slice. |

---

_Verified: 2026-04-29T02:10:35Z_
_Verifier: Codex (gsd-executor)_
