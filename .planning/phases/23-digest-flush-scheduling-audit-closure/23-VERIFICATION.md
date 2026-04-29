---
phase: 23-digest-flush-scheduling-audit-closure
verified: 2026-04-29T02:20:50Z
status: gaps_found
score: 6/8 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Phase 23 final verification gate (`MIX_ENV=test mix ci.test`) passes before DIGEST closure is claimed."
    status: failed
    reason: "A fresh full-suite run still fails in the deferred-resume lifecycle path with a `CaseClauseError` after `Policy.evaluate/2` returns `{:defer, ...}`."
    artifacts:
      - path: "test/chimeway/integration/delivery_lifecycle_test.exs"
        issue: "The `resume_deferred_delivery promotes the existing row to orchestration_state == :ready` scenario still fails during `perform_job(ObanWorker, %{delivery_id: resumed_delivery.id})`."
      - path: "lib/chimeway/dispatch/oban_worker.ex"
        issue: "`handle_delivery/3` only matches `{:suppress, reason}` and `{:ok, :proceed}`, so a deferred-policy result crashes the worker."
      - path: ".planning/phases/20-digest-emission-explainability/20-VERIFICATION.md"
        issue: "The artifact records the final gate as failed rather than closed."
    missing:
      - "Fix the deferred-resume regression so the Oban worker handles the resumed-delivery policy path without crashing."
      - "Re-run `MIX_ENV=test mix ci.test` successfully and update the Phase 20 evidence artifact."
  - truth: "Audit closure state reflects verified reality and does not mark Phase 23 or DIGEST-02/DIGEST-03 complete while the required final gate is still failing."
    status: failed
    reason: "Phase 23's audit artifacts mark closure as complete even though the plan's wave/final gate remains red."
    artifacts:
      - path: ".planning/phases/20-digest-emission-explainability/20-VERIFICATION.md"
        issue: "Uses noncanonical `status: passed_with_followup` while also recording a failed `mix ci.test` gate."
      - path: ".planning/REQUIREMENTS.md"
        issue: "Marks `DIGEST-02` and `DIGEST-03` complete and traced to Phase 23 despite the unsatisfied final gate."
      - path: ".planning/ROADMAP.md"
        issue: "Marks Phase 23 complete and says digest scheduling verification is complete even though the required gate still fails."
    missing:
      - "Either satisfy the final gate or downgrade the closure state in the roadmap/requirements/audit artifacts so they match verified reality."
      - "Regenerate the verification artifact with canonical verifier status semantics after the gate outcome is resolved."
---

# Phase 23: Digest Flush Scheduling & Audit Closure Verification Report

**Phase Goal:** close the digest flush scheduling gap, make recovery replay durable for digest-held notifications, and finish the audit trail with production-shaped verification evidence for DIGEST-02 and DIGEST-03.
**Verified:** 2026-04-29T02:20:50Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Oban-backed installs automatically schedule one future flush job from durable bucket state, while non-Oban installs keep the explicit `emit_bucket/2` seam. | ✓ VERIFIED | [lib/chimeway/digests/accumulation.ex](/Users/jon/projects/chimeway/lib/chimeway/digests/accumulation.ex:315) schedules only when the dispatcher is `Chimeway.Dispatch.Oban`, and [lib/chimeway/digests.ex](/Users/jon/projects/chimeway/lib/chimeway/digests.ex:2) documents the non-Oban boundary explicitly. |
| 2 | Repeated accumulation, repeated scheduling attempts, and repeated worker execution converge on one emitted digest delivery identity with a thin `bucket_id` worker contract. | ✓ VERIFIED | [lib/chimeway/dispatch/digest_flush_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/digest_flush_worker.ex:5) keeps job args to `bucket_id` with scheduled-time uniqueness, while [test/chimeway/digests/emission_test.exs](/Users/jon/projects/chimeway/test/chimeway/digests/emission_test.exs:88) and [test/chimeway/integration/digest_delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/digest_delivery_lifecycle_test.exs:128) prove duplicate execution reuses one canonical digest delivery. |
| 3 | Trigger-time persistence stores a durable normalized orchestration snapshot on notification rows. | ✓ VERIFIED | [lib/chimeway/trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:146) serializes orchestration into notification inserts, [lib/chimeway/notifications/notification.ex](/Users/jon/projects/chimeway/lib/chimeway/notifications/notification.ex:16) persists the `orchestration` field, and [test/chimeway/trigger_pipeline_test.exs](/Users/jon/projects/chimeway/test/chimeway/trigger_pipeline_test.exs:290) asserts the stored snapshot shape. |
| 4 | Recovered digest-held notifications replay persisted orchestration instead of degrading to immediate send. | ✓ VERIFIED | [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:219) enables `use_persisted_orchestration: true`, [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:320) feeds the snapshot back through notifier override normalization, and [test/chimeway/orchestration/recovery_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/recovery_test.exs:319) shows recovery keeps `orchestration_state == :digest_held`. |
| 5 | Recovery replay preserves digest planning context and explainability facts. | ✓ VERIFIED | [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:446) reconstructs `planning_context` with digest key and source, and [test/chimeway/orchestration/recovery_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/recovery_test.exs:333) asserts `"source" => "planner_override"` and the preserved digest key. |
| 6 | The end-to-end path from digest-held accumulation through scheduled `DigestFlushWorker` to canonical `delivery_id` dispatch is proven and documented with production-shaped PostgreSQL 15.17 evidence. | ✓ VERIFIED | [test/chimeway/integration/digest_delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/digest_delivery_lifecycle_test.exs:90) exercises the scheduled-worker happy path and recovery replay path, and [20-VERIFICATION.md](/Users/jon/projects/chimeway/.planning/phases/20-digest-emission-explainability/20-VERIFICATION.md:40) records the PostgreSQL 15.17 targeted run. |
| 7 | Phase 23 final verification gate (`MIX_ENV=test mix ci.test`) passes before DIGEST closure is claimed. | ✗ FAILED | A fresh `MIX_ENV=test mix ci.test` run still fails with `361 tests, 1 failure`: [test/chimeway/integration/delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:815) crashes through [lib/chimeway/dispatch/oban_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban_worker.ex:141) on `{:defer, %{...}}`. |
| 8 | Audit closure state and requirement closure reflect verified reality rather than overstating completion. | ✗ FAILED | [20-VERIFICATION.md](/Users/jon/projects/chimeway/.planning/phases/20-digest-emission-explainability/20-VERIFICATION.md:4) uses `passed_with_followup` while recording a failed final gate, and both [REQUIREMENTS.md](/Users/jon/projects/chimeway/.planning/REQUIREMENTS.md:18) and [ROADMAP.md](/Users/jon/projects/chimeway/.planning/ROADMAP.md:130) mark DIGEST/Phase 23 closure as complete. |

**Score:** 6/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/digests/accumulation.ex` | Schedule flush work from durable bucket state | ✓ VERIFIED | Schedules from `bucket.window_ends_at` only for Oban-backed installs. |
| `lib/chimeway/digests.ex` | Document explicit Oban/non-Oban boundary | ✓ VERIFIED | Public API docs preserve `emit_bucket/2` as the host seam outside Oban. |
| `lib/chimeway/dispatch/digest_flush_worker.ex` | Thin scheduled worker delegating to digest emission | ✓ VERIFIED | Unique on `bucket_id` + `scheduled_at`; delegates to `Digests.emit_bucket/2`. |
| `priv/repo/migrations/20260428230000_add_orchestration_snapshot_to_chimeway_notifications.exs` | Durable orchestration snapshot storage | ✓ VERIFIED | Adds non-null notification `orchestration` map column. |
| `lib/chimeway/trigger.ex` | Persist normalized orchestration snapshots at trigger time | ✓ VERIFIED | Inserts serialized orchestration with notification rows. |
| `test/chimeway/orchestration/recovery_test.exs` | Prove recovered digest-held rows stay digest-held | ✓ VERIFIED | Covers persisted-orchestration recovery replay and no notifier re-entry. |
| `test/chimeway/integration/digest_delivery_lifecycle_test.exs` | Production-shaped scheduled-worker integration proof | ✓ VERIFIED | Covers scheduled worker, duplicate execution, recovery replay, canonical dispatch handoff. |
| `.planning/phases/20-digest-emission-explainability/20-VERIFICATION.md` | Formal audit artifact for digest closure | ⚠ HOLLOW | Evidence content exists, but the artifact still records a failed final gate and overstates closure. |
| `.planning/REQUIREMENTS.md` | DIGEST requirement traceability closure | ⚠ PARTIAL | DIGEST rows are updated, but closure state depends on a still-failing final gate. |
| `.planning/ROADMAP.md` | Phase 23 traceability and closure summary | ⚠ PARTIAL | Success criteria are documented, but the summary still says Phase 23 is complete. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/chimeway/digests/accumulation.ex` | `lib/chimeway/dispatch/digest_flush_worker.ex` | schedule at `bucket.window_ends_at` with `%{bucket_id: bucket.id}` | ✓ WIRED | [lib/chimeway/digests/accumulation.ex](/Users/jon/projects/chimeway/lib/chimeway/digests/accumulation.ex:315) calls [Chimeway.Dispatch.Oban.enqueue_digest_flush/1](/Users/jon/projects/chimeway/lib/chimeway/dispatch/oban.ex:72). |
| `lib/chimeway/dispatch/digest_flush_worker.ex` | `lib/chimeway/digests/emission.ex` | worker delegates via `Digests.emit_bucket/2` | ✓ WIRED | [lib/chimeway/dispatch/digest_flush_worker.ex](/Users/jon/projects/chimeway/lib/chimeway/dispatch/digest_flush_worker.ex:14) routes back to the emission service. |
| `lib/chimeway/trigger.ex` | `lib/chimeway/notifications/notification.ex` | persist orchestration snapshot per notification | ✓ WIRED | Trigger inserts the serialized orchestration field stored by the schema. |
| `lib/chimeway/deliveries.ex` | `lib/chimeway/delivery_planning.ex` | `recover_event/2` opts into persisted orchestration replay | ✓ WIRED | Recovery dispatch sets `use_persisted_orchestration: true`; planner consumes it through `orchestration_override/2`. |
| `test/chimeway/integration/digest_delivery_lifecycle_test.exs` | `lib/chimeway/dispatch/digest_flush_worker.ex` | integration path performs scheduled worker rather than manual flush | ✓ WIRED | The happy path asserts the job and performs `DigestFlushWorker` directly. |
| `.planning/phases/20-digest-emission-explainability/20-VERIFICATION.md` | `.planning/REQUIREMENTS.md` | DIGEST closure evidence drives requirements state | ⚠ PARTIAL | The traceability link exists, but the artifact it points at still contains a failed final gate. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/chimeway/digests/accumulation.ex` | `bucket.window_ends_at` / `bucket.id` | Persisted `DigestBucket` row refreshed after membership insert | Yes | ✓ FLOWING |
| `lib/chimeway/dispatch/oban.ex` | Oban digest flush job args | `%{bucket_id: bucket.id}` plus `scheduled_at: bucket.window_ends_at` | Yes | ✓ FLOWING |
| `lib/chimeway/trigger.ex` | notification `orchestration` snapshot | `Notifier.resolve_orchestration/3` serialized into DB row | Yes | ✓ FLOWING |
| `lib/chimeway/delivery_planning.ex` | orchestration override / digest planning context | `notification.orchestration` persisted data replayed through `Notifier.persisted_orchestration_override/1` | Yes | ✓ FLOWING |
| `test/chimeway/integration/digest_delivery_lifecycle_test.exs` | emitted digest `delivery_id` handoff | `DigestFlushWorker` schedules canonical emitted delivery, then `ObanWorker` dispatches by `delivery_id` | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Targeted digest/recovery/traces regression slice | `mix test test/chimeway/integration/digest_delivery_lifecycle_test.exs test/chimeway/digests/flush_scheduling_test.exs test/chimeway/orchestration/recovery_test.exs test/chimeway/traces_test.exs --trace` | `48 tests, 0 failures` | ✓ PASS |
| Full phase final gate | `MIX_ENV=test mix ci.test` | `361 tests, 1 failure` in `Chimeway.Integration.DeliveryLifecycleTest` | ✗ FAIL |
| Local PostgreSQL runtime parity check | `psql --version` | `PostgreSQL 14.17 (Homebrew)` | ? SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `DIGEST-02` | `23-01`, `23-02`, `23-03` | Digest generation is idempotent and records which source events and notifications were included in each digest delivery. | ✓ SATISFIED | [test/chimeway/digests/emission_test.exs](/Users/jon/projects/chimeway/test/chimeway/digests/emission_test.exs:142), [test/chimeway/digests/flush_scheduling_test.exs](/Users/jon/projects/chimeway/test/chimeway/digests/flush_scheduling_test.exs:27), and [test/chimeway/integration/digest_delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/digest_delivery_lifecycle_test.exs:90) prove canonical emitted identity, membership resolution, and scheduled dispatch handoff. |
| `DIGEST-03` | `23-02`, `23-03` | Operators can explain why a notification was included in a digest, skipped from a digest, or emitted immediately instead. | ✓ SATISFIED | [test/chimeway/orchestration/recovery_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/recovery_test.exs:284), [test/chimeway/orchestration/digest_explainability_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/digest_explainability_test.exs:17), and [test/chimeway/traces_test.exs](/Users/jon/projects/chimeway/test/chimeway/traces_test.exs:592) keep explainability anchored to durable digest facts. |

No orphaned Phase 23 requirements were found in [.planning/REQUIREMENTS.md](/Users/jon/projects/chimeway/.planning/REQUIREMENTS.md:55); the phase plans and requirements table both account for `DIGEST-02` and `DIGEST-03`.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `.planning/phases/20-digest-emission-explainability/20-VERIFICATION.md` | 4 | Noncanonical `status: passed_with_followup` while the final gate is red | 🛑 Blocker | Lets the audit artifact overstate closure instead of surfacing `gaps_found`. |
| `.planning/ROADMAP.md` | 157 | Phase 23 summary row says `Complete` despite failed final gate | ⚠ Warning | Roadmap closure state no longer matches verified status. |
| `.planning/REQUIREMENTS.md` | 61 | `DIGEST-02` / `DIGEST-03` marked complete while closure gate is still red | ⚠ Warning | Requirements traceability overclaims completion. |

### Gaps Summary

Digest scheduling, durable recovery replay, and digest-specific explainability are implemented and verified by targeted tests. The phase still misses its goal because the declared final gate for Plan 23-03 does not pass: `MIX_ENV=test mix ci.test` still fails in the deferred-resume lifecycle path, and the audit artifacts were advanced to a complete state anyway.

The remaining work is not more digest wiring. It is closure integrity: fix the full-suite blocker, rerun the required gate, and then update the audit artifact, roadmap, and requirements so they reflect the real verified state with canonical verifier statuses.

---

_Verified: 2026-04-29T02:20:50Z_
_Verifier: Codex (gsd-verifier)_
