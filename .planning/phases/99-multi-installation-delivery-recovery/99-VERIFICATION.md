---
phase: 99-multi-installation-delivery-recovery
verified: 2026-08-20T00:50:57Z
status: gaps_found
score: 3/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Operators can see each target's independent claim, attempt, retry, expiry, invalidation, and trace history beneath one logical delivery."
    status: failed
    reason: "After a target adapter returns an error or an unexpected value, the executor returns without finalizing the claimed target or its attempt. The durable row remains claimed with attempt_started only, so the provider outcome and retry/failure state are not recorded."
    artifacts:
      - path: "lib/chimeway/dispatch/executor.ex"
        issue: "run_target/2 uses a with-chain that calls record_target_result/4 only for {:ok, facts}; all adapter error branches bypass target-result persistence."
    missing:
      - "Finalize every adapter return with an honest closed target/attempt outcome; distinguish known pre-handoff retryable failures from possible-handoff ambiguity and test both paths."
  - truth: "Repeated planning, execution, or recovery produces neither a duplicate target nor an unexplained additional provider request; a bounded tenant-scoped worker recovers stranded work with evidence."
    status: failed
    reason: "The recovery worker misses event-only trigger-commit gaps, shares an incompatible cursor between event and target UUID streams, scans all stale attempts without batch/cursor bounds, and drops its generated recovery summary."
    artifacts:
      - path: "lib/chimeway/target_recovery.ex"
        issue: "discover_stranded_events/2 inner-joins notifications; recover_tenant/2 exposes only the target cursor; close_stale_attempts/2 ignores paging; executor errors are mislabeled as invalidation."
      - path: "lib/chimeway/dispatch/recovery_worker.ex"
        issue: "The closed recovery summary is assigned to _result and then discarded."
    missing:
      - "Discover tenant-scoped events with no notification as well as notifications with no delivery."
      - "Use independent typed/keyset continuations for event, target, and stale-attempt streams, all capped at the validated batch limit."
      - "Emit or persist the closed recovery summary and preserve accurate executor error reasons."
---

# Phase 99: Multi-Installation Delivery & Recovery Verification Report

**Phase Goal:** A host can deliver one notification decision to all eligible opaque installations while preserving independent, tenant-safe target truth and recovery.
**Verified:** 2026-08-20T00:50:57Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A resolver returns all active eligible tenant-scoped opaque revisions and one durable target is recorded per selected revision. | ✓ VERIFIED | `TargetResolver.normalize/2` validates tenant/ref shape, sorts and de-duplicates exact refs; `DeliveryTargets.plan_targets/3` has a DB unique conflict target and authoritative tenant-qualified reload. Fresh focused tests: `delivery_target_test.exs` passed (8 tests). |
| 2 | Operators can see every target's independent claim, attempt, retry, expiry, invalidation, and trace history beneath one delivery. | ✗ FAILED | Trace projection is tenant-scoped and ordered, but `Executor.run_target/2` does not record any adapter error/unexpected outcome: the target remains `:claimed` and its attempt `:attempt_started`. This fails the durable per-target-outcome contract. |
| 3 | Repeated planning/execution/recovery is duplicate-safe, and bounded tenant-scoped recovery handles stranded work with evidence. | ✗ FAILED | Target claims serialize normal races, but recovery is incomplete/unbounded/unobservable: event-only gaps are excluded by an inner join; one target cursor pages two UUID streams; stale closure loads every eligible row; worker discards its summary. |
| 4 | No eligible target suppresses with a stable reason; mixed terminal target results retain partial failures while succeeding only after provider acceptance. | ✓ VERIFIED | `maybe_plan_push_targets/4` suppresses `:no_eligible_targets`; `recompute_delivery/2` derives target aggregate state. `delivery_target_test.exs` explicitly proves empty suppression and accepted-plus-failed aggregate behavior. |
| 5 | A crash after possible provider handoff is represented as ambiguous, rather than silently resent or described as exactly-once delivery. | ✓ VERIFIED | `close_stale_started_attempt/2` changes both target and open attempt to `:ambiguous_handoff`; the focused target-worker test proves no adapter call after stale closeout. |

**Score:** 3/5 truths verified (0 present, behavior-unverified)

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `priv/repo/migrations/20260819000001_create_chimeway_delivery_targets.exs` | Target/ordered-attempt schema | ✓ VERIFIED | Substantive migration with target and attempt uniqueness constraints. |
| `priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs` | Prefix-aware copied schema | ✓ VERIFIED | Template uses static prefix helpers; dynamically discovered by installer template enumeration. |
| `lib/chimeway/target_resolver.ex` | Opaque tenant-scoped resolver contract | ✓ VERIFIED | Validates, normalizes, sorts, and exact-de-duplicates binding revisions. |
| `lib/chimeway/delivery_targets.ex` | Target lifecycle and aggregation | ⚠️ PARTIAL | Core planning/claim/ambiguous lifecycle is substantive and wired, but cannot receive an adapter-error finalization from the executor. |
| `lib/chimeway/target_adapter.ex` | Replaceable target handoff seam | ✓ VERIFIED | Used by `Executor.run_target/2` after durable claim/start. |
| `test/chimeway/delivery_target_test.exs` | End-to-end one-target tracer | ✓ VERIFIED | Exercises resolver → canonical delivery → target → pre-I/O attempt → accepted aggregate → trace. |
| Public/prefixed golden migration fixtures | Generated static-storage copies | ✓ VERIFIED | Present and covered by installer template discovery/golden tests. |
| `test/chimeway/migration_contract_test.exs` | Dual-mode uniqueness proof | ✓ VERIFIED | Substantive PostgreSQL contract test. |
| `lib/chimeway/traces.ex` and `test/chimeway/traces_target_test.exs` | Tenant-safe ordered target/attempt history | ✓ VERIFIED | Tenant predicates and order assertions are present; fresh trace-focused suite passed. |
| `lib/chimeway/dispatch/executor.ex` and `test/chimeway/dispatch/target_worker_test.exs` | Shared target execution/ambiguity proof | ⚠️ PARTIAL | Successful and stale paths work; adapter-error finalization has no implementation or test. |
| `lib/chimeway/dispatch/oban_worker.ex` | Target-ID/tenant-ID worker | ✓ VERIFIED | Calls the shared execution/claim seam with durable IDs. |
| `lib/chimeway/target_recovery.ex` and recovery test | Bounded tenant recovery | ✗ FAILED | Exists and is wired, but has the recovery completeness/bounding defects documented below. |
| `lib/chimeway/dispatch/recovery_worker.ex` | Recovery worker entry point | ⚠️ PARTIAL | Delegates with validated args, but discards the only recovery evidence summary. |
| `99-VALIDATION.md` | Executable validation map | ⚠️ STALE | It marks recovery requirements green despite missing event-only recovery, independent cursors, stale bounds, error-finalization coverage, and emitted worker evidence. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `delivery_planning.ex` | `delivery_targets.ex` | Resolver → normalize → child persistence | ✓ WIRED | `maybe_plan_push_targets/4` calls both seams. |
| `sync.ex` / `oban_worker.ex` | `executor.ex` | Target execution | ✓ WIRED | Both target dispatch paths invoke `run_target`. |
| `executor.ex` | `target_adapter.ex` / target attempt | Claim/start before callback | ⚠️ PARTIAL | `begin_target_attempt/2` precedes `deliver/2`, but callback errors bypass result recording. |
| Migration template | `install/migrations.ex` | Template discovery/generation | ✓ WIRED | The installer dynamically enumerates `priv/chimeway_migrations/*`; direct literal-pattern probe was a false negative. |
| `recovery_worker.ex` | `target_recovery.ex` | Worker delegation | ⚠️ PARTIAL | Delegation works, but result evidence is discarded. |
| `target_recovery.ex` | `deliveries.ex` / `delivery_targets.ex` | Event recovery and target recovery | ✗ FAILED | Both links exist, but the event query cannot select no-notification gaps and stale target processing is unbounded. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Target planning | Binding revisions | Configured host resolver → normalized DB child rows | Yes | ✓ FLOWING |
| Target trace | Targets and attempts | Tenant-qualified delivery/target/attempt associations | Yes | ✓ FLOWING |
| Recovery | Event IDs, target IDs, cursor, closed reasons | Tenant-qualified Ecto queries → `SafeEvidence.recovery_summary/1` | Partially | ✗ HOLLOW: event-only gaps are filtered out, stale selection is unbounded, and worker output is thrown away. |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Target planning, idempotency, suppression, partial aggregate, trace ordering | `env MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/traces_target_test.exs --warnings-as-errors` | 8 tests, 0 failures | ✓ PASS |
| Target pre-I/O claim, stale ambiguity, normal bounded target paging and recovery race | `env MIX_ENV=test mix test test/chimeway/orchestration/target_recovery_test.exs test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors` | 6 tests, 0 failures | ✓ PASS — insufficient coverage for the failed paths |
| Full regression suite | `mix test` | Reported current regression evidence: 1483 tests, 0 failures, 551.4 seconds | ℹ️ NOT relied on to dismiss the uncovered failure paths |

## Probe Execution

Step 7c: SKIPPED — no Phase 99 probes were declared or found under `scripts/*/tests/probe-*.sh`.

## Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PUSH-01 | 99-01, 99-03 | Resolver returns opaque tenant-scoped revisions without raw tokens. | ✓ SATISFIED | Resolver contract, normalization, malformed-input test, and target tracer. |
| PUSH-02 | 99-01, 99-02, 99-03, 99-04 | One logical delivery has independently recorded target lifecycle/outcomes. | ✗ BLOCKED | Adapter error leaves only open `attempt_started`/`:claimed` state; no independent provider outcome or retry/failure evidence is recorded. |
| PUSH-03 | 99-02, 99-03, 99-04, 99-05 | Duplicate planning, execution, and recovery do not create duplicate targets/provider requests. | ✓ SATISFIED | DB identity constraints plus target claim transaction and focused concurrent tests show no duplicate call for selected work. |
| PUSH-04 | 99-01, 99-03 | No-target suppression and honest mixed terminal aggregation. | ✓ SATISFIED | Explicit no-target and partial-failure aggregate tests. |
| RECOV-01 | 99-05 | Bounded tenant-scoped recovery of trigger-commit gaps with explainable evidence. | ✗ BLOCKED | Event-only trigger gap excluded; cursors are unsafe across streams; stale closure ignores bounds; worker emits no evidence. |
| RECOV-02 | 99-01, 99-04, 99-05 | Pre-I/O evidence and explicit ambiguous possible handoff. | ✓ SATISFIED | Durable attempt-start pre-I/O and stale-closeout tests preserve ambiguity/no automatic resend. |

No orphaned Phase 99 requirements were found: all six roadmap requirements appear in plan frontmatter.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/target_recovery.ex` | 53 | Inner join against `Notification` | 🛑 BLOCKER | Makes the required event-with-no-notification recovery state undiscoverable. |
| `lib/chimeway/target_recovery.ex` | 23-31, 49, 76, 90 | One cursor used for two distinct UUID streams | 🛑 BLOCKER | Can skip events or prevent event-page progression. |
| `lib/chimeway/target_recovery.ex` | 113-133 | Unbounded stale-attempt query/mutation loop | 🛑 BLOCKER | Violates the hard recovery batch bound. |
| `lib/chimeway/dispatch/executor.ex` | 69-78 | `with` exits on adapter error without finalization | 🛑 BLOCKER | Leaves durable target truth incomplete and claimed. |
| `lib/chimeway/dispatch/recovery_worker.ex` | 16-17 | Recovery summary discarded | ⚠️ WARNING | No operational recovery evidence remains after a worker run. |
| `lib/chimeway/target_recovery.ex` | 147-153 | All execution errors labeled invalidated | ⚠️ WARNING | Recovery evidence is materially misleading. |

No `TBD`, `FIXME`, `XXX`, placeholder, or empty-runtime implementation markers were found in the phase-owned source files.

## Disconfirmation Pass

- **Partial requirement:** RECOV-01’s normal target-page test passes, but it never creates an event with no notification, so it cannot prove recovery of the stated trigger-commit interruption.
- **Misleading passing test:** The two recovery tests only exercise target paging and one stale target; they do not exercise `RecoveryWorker.perform/1`, stream-cursor interaction, batch bounds for stale closure, or recovery evidence emission.
- **Uncovered error path:** All target adapters in the Phase 99 tests return `{:ok, facts}`. No test forces `{:error, reason}` or an unexpected return after `attempt_started`, which is precisely the branch that strands a claimed target.

## Gaps Summary

The target identity, privacy boundary, accepted/partial aggregation, and stale-handoff ambiguity mechanisms are real and exercised. The phase goal is nevertheless not achieved: the recovery subsystem cannot reliably recover the required interruption or remain bounded/evidenced, and target adapter failures leave no honest terminal/retryable per-target outcome.

These are not deferred: later Phase 100 is an optional APNs adapter and does not specify remediation of Phase 99’s generic recovery or lifecycle contracts.

---

_Verified: 2026-08-20T00:50:57Z_
_Verifier: the agent (gsd-verifier)_
