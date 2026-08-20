---
phase: 99-multi-installation-delivery-recovery
verified: 2026-08-20T18:15:00Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  gaps_closed:
    - "Repeated planning, execution, or recovery produces neither a duplicate target nor an unexplained additional provider request."
    - "Operators can see each target's independent claim, attempt, retry, expiry, invalidation, and trace history beneath one logical delivery with tenant-safe durable ownership."
  gaps_remaining: []
  regressions: []
---

# Phase 99: Multi-Installation Delivery & Recovery Verification Report

**Phase Goal:** A host can deliver one notification decision to all eligible opaque installations while preserving independent, tenant-safe target truth and recovery.
**Verified:** 2026-08-20T18:15:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A host resolver can return every active eligible installation as an opaque tenant-scoped binding revision, and Chimeway records one durable target for each selected revision. | ✓ VERIFIED | `TargetResolver.normalize/2` validates tenant-matched opaque revisions, sorts/deduplicates them, and `DeliveryTargets.plan_targets/3` persists them under the canonical delivery with DB conflict convergence. `delivery_target_test.exs` passed (21 tests in the lifecycle suite). |
| 2 | Operators can see each target's independent claim, attempt, retry, expiry, invalidation, and trace history beneath one logical delivery. | ✓ VERIFIED | Target/attempt lifecycle rows are projected by the shared tenant-qualified `target_history_preload/1` into full, recipient, correlation, and explanation traces. Migration 036 structurally binds target → delivery and attempt → target tenant ownership; the 14-test PostgreSQL contract passed. |
| 3 | Repeated planning, execution, or recovery produces neither a duplicate target nor an unexplained additional provider request; a bounded tenant-scoped worker recovers stranded work with evidence. | ✓ VERIFIED | Unique target identity plus locked `begin_target_attempt/2` is the I/O authority. Ordinary retry only admits `:failed`, so an accepted target cannot become pending; the explicit regression observes no adapter call. Recovery uses separate durable-ID cursors with a 1..100 limit and passed recovery/worker tests. |
| 4 | A delivery with no eligible target is suppressed with a stable reason, while mixed terminal target results succeed only when at least one target receives APNs acceptance and retain partial failures. | ✓ VERIFIED | Planning and public Oban dispatch recompute an empty push snapshot to `suppressed/no_eligible_targets`; `aggregate/1` counts independent terminal states and only succeeds with `provider_accepted`. Oban and target lifecycle regressions passed. |
| 5 | A crash after possible provider handoff records an explicit ambiguous outcome from pre-I/O claim and attempt-start evidence rather than silently resending or promising exactly-once delivery. | ✓ VERIFIED | `begin_target_attempt/2` inserts `attempt_started` before `Executor` enters `TargetAdapter.deliver/2`; stale closeout records `ambiguous_handoff`/`possible_provider_handoff`, and exact locked finalization prevents a late result from overwriting it. Recovery tests passed. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/target_resolver.ex` and `lib/chimeway/delivery_planning.ex` | Opaque tenant-explicit resolution into canonical child targets | ✓ VERIFIED | Substantive validation/normalization is wired to push planning and durable child persistence. |
| `lib/chimeway/delivery_targets.ex` | Idempotent planning, locked claims, lifecycle transitions, aggregation, and recovery closeout | ✓ VERIFIED | All operations query tenant-qualified rows; retry/expiry/invalidation have explicit source-state predicates. |
| `lib/chimeway/dispatch/{sync,oban,executor,oban_worker}.ex` | Deterministic all-target fan-out through claim/start authority | ✓ VERIFIED | Sync iterates the ordered actionable snapshot; Oban enqueues exact target IDs or persists empty suppression; executor claims before adapter I/O. |
| `lib/chimeway/{traces.ex,traces/explanation.ex,safe_evidence.ex}` | Tenant-safe independent target/attempt operator history | ✓ VERIFIED | Shared preloads apply tenant predicates and deterministic ordering before closed evidence projection. |
| `lib/chimeway/target_recovery.ex` and `lib/chimeway/dispatch/recovery_worker.ex` | Bounded tenant-owned recovery with closed evidence | ✓ VERIFIED | Separate event/target/stale-attempt keyset streams, batch cap, closed summary, and durable target claim authority are wired. |
| `priv/repo/migrations/20260820000000_enforce_delivery_target_tenant_integrity.exs` | Repository structural tenant ownership repair | ✓ VERIFIED | Named composite indexes/FKs enforce delivery, target, and prior-attempt lineage relationships. |
| `priv/chimeway_migrations/036_enforce_delivery_target_tenant_integrity.exs` | Prefix-safe equivalent repair for generated public/prefixed storage | ✓ VERIFIED | Uses only fixed static relation qualification; migration-contract test passed repository and generated modes. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `delivery_planning.ex` | `delivery_targets.ex` | resolver normalization → `plan_targets/3` | ✓ WIRED | Push planning resolves normalized bindings and persists/reloads authoritative tenant-scoped children. |
| `sync.ex` | `executor.ex` | ordered actionable target snapshot → exact `run_target/2` | ✓ WIRED | Each target ID is passed through the durable claim/start seam; target errors do not short-circuit later targets. |
| `executor.ex` | `delivery_targets.ex` | `begin_target_attempt/2` → adapter → exact result/failure closeout | ✓ WIRED | Attempt insert occurs in the claim transaction before `TargetAdapter.deliver/2`; late result handling is conditional. |
| lifecycle public operations | `begin_target_attempt/2` | source-state-authorized retry → pending target eligibility | ✓ WIRED | `schedule_retry/3` permits only `:failed`; accepted target regression passed and observed no adapter handoff. |
| migration 036 | target/attempt durable ownership | composite tenant/id foreign keys | ✓ WIRED | Contract test proves cross-tenant target, cross-tenant attempt, and cross-target predecessor inserts fail with named constraints. |
| `target_recovery.ex` | `delivery_targets.ex` | bounded discovery → tenant-qualified fetch/claim/closeout | ✓ WIRED | Discovery alone never calls a provider; every selected target still enters `begin_target_attempt/2`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Target planning | normalized binding revisions | Host resolver → `TargetResolver.normalize/2` → `plan_targets/3` | Tenant-matched opaque revisions | ✓ FLOWING |
| Dispatch | actionable target IDs | Tenant-qualified `DeliveryTarget` Ecto query | Persisted pending target rows in stable order | ✓ FLOWING |
| Operator traces | target and attempt histories | Tenant-qualified Ecto preloads → `SafeEvidence.trace_delivery/1` | Persisted rows, not hardcoded collections | ✓ FLOWING |
| Recovery | event/target/stale target ID pages | Three tenant-qualified Ecto queries → locked lifecycle service | Persisted, capped keyset pages | ✓ FLOWING |
| Durable ownership | target/attempt parent relations | Repository and copied migration 036 composite constraints | PostgreSQL rejects malformed cross-tenant/cross-target rows | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Accepted target cannot be retried or reach adapter again | `CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 env MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/dispatch/target_worker_test.exs --max-cases 1 --warnings-as-errors` | 21 tests, 0 failures | ✓ PASS |
| Repository and generated migration 036 reject malformed tenant ownership and lineage | `CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 env MIX_ENV=test mix test test/chimeway/migration_contract_test.exs --max-cases 1 --warnings-as-errors` | 14 tests, 0 failures | ✓ PASS |
| Bounded recovery, empty Oban suppression, and tenant-safe target traces | `CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 env MIX_ENV=test mix test test/chimeway/orchestration/target_recovery_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/traces_target_test.exs --max-cases 1 --warnings-as-errors` | 23 tests, 0 failures | ✓ PASS |
| Cross-phase regression gate | Recorded post-recovery gate evidence | 688 tests, 0 failures | ✓ PASS (provided machine evidence) |

### Probe Execution

Step 7c: SKIPPED — no Phase 99 probe script is declared by the plans/summaries and no conventional `scripts/*/tests/probe-*.sh` file exists.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PUSH-01 | 99-01, 03, 07, 09, 11, 12 | Opaque tenant-scoped resolution of every eligible installation revision | ✓ SATISFIED | Public resolver contract, stable normalization/planning, all-target sync/Oban fan-out. |
| PUSH-02 | 99-01–12 | Independent durable target lifecycle/history beneath one delivery | ✓ SATISFIED | Child schemas, independent target attempts/traces, and migration-036 tenant/lineage constraints. |
| PUSH-03 | 99-02–12 | No duplicate target or unexplained additional provider request | ✓ SATISFIED | DB uniqueness, locked claims, terminal retry guard, concurrent recovery and adapter-observation tests. |
| PUSH-04 | 99-01, 03, 07, 09–12 | Stable no-target suppression and honest aggregate result | ✓ SATISFIED | Empty-snapshot recomputation, stable `no_eligible_targets`, and partial-failure aggregation regressions. |
| RECOV-01 | 99-05, 07, 10–12 | Bounded tenant-scoped recovery with explainable evidence | ✓ SATISFIED | Three independent capped cursor streams, closed summary/telemetry, tenant-qualified claim authority. |
| RECOV-02 | 99-01, 04–07, 10–12 | Pre-I/O durable evidence and ambiguous post-handoff recovery | ✓ SATISFIED | Claim/start ordering, stale closeout, exact finalization race protection, policy-labelled redrive lineage. |

All six Phase 99 requirement IDs are declared by plan frontmatter and present in `REQUIREMENTS.md`; none is orphaned. No later roadmap phase explicitly defers any Phase 99 must-have.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| Phase-owned production/migration/test artifacts | — | `TBD`/`FIXME`/`XXX`/placeholder scan | ℹ️ None | No unreferenced debt-marker or implementation stub found. |
| `lib/chimeway/target_recovery.ex` | 232-240 | Malformed non-empty UUID cursor is passed to UUID comparison | ⚠️ WARNING | A corrupt/manual Oban recovery job can fail during UUID casting instead of returning a closed summary. This does not authorize I/O, weaken tenant predicates, duplicate a target, or alter durable recovery truth for valid self-generated cursors; therefore it is follow-up hardening, not a Phase 99 goal blocker. |

### Gaps Summary

No blocking gaps remain. The previous accepted-target reauthorization and database tenant-ownership failures are closed by locked source-state transitions and the migration-036 composite constraints, respectively. The malformed recovery-cursor warning from `99-REVIEW.md` remains suitable for a follow-up regression, but it does not invalidate the stated normal recovery, safety, or explainability contract and is not deferred to a later phase.

---

_Verified: 2026-08-20T18:15:00Z_
_Verifier: the agent (gsd-verifier)_
