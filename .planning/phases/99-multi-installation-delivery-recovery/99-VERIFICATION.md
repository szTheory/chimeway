---
phase: 99-multi-installation-delivery-recovery
verified: 2026-08-20T10:05:00-04:00
status: gaps_found
score: 3/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/5
  gaps_closed:
    - "Common recipient, correlation, and explanation traces now preload and project tenant-scoped target and attempt histories."
    - "Synchronous push dispatch now snapshots and executes every actionable target by exact durable target ID."
    - "Final pre-handoff Oban retries now persist retry_exhausted before completion, preventing ordinary recovery resend."
    - "Target claim requires a locked pending/ready parent, and stale result finalization is conditional on the exact claimed target and started attempt."
  gaps_remaining:
    - "The Oban dispatch entry point strands an empty push target snapshot instead of recording no_eligible_targets suppression."
    - "Stale recovery locks target then parent, conflicting with the parent-then-target execution lock order and does not handle transaction errors."
  regressions: []
gaps:
  - truth: "A delivery with no eligible target is suppressed with a stable reason."
    status: failed
    reason: "Oban enqueue of a pending/ready push delivery with no actionable targets returns {:ok, []}; dispatch_delivery/2 reports success but never recomputes the parent, leaving it pending without no_eligible_targets."
    artifacts:
      - path: "lib/chimeway/dispatch/oban.ex"
        issue: "enqueue_delivery/1 lines 108-122 has no empty-snapshot recompute; normalize_dispatch_delivery_result/2 accepts the empty job list."
    missing:
      - "Atomically recompute the tenant-qualified parent when the actionable snapshot is empty and assert suppressed/no_eligible_targets through the public Oban dispatch path."
  - truth: "A bounded tenant-scoped worker recovers stranded work with durable, race-safe evidence."
    status: failed
    reason: "Stale closeout acquires the target lock before recompute_delivery/2 acquires the parent lock, while claims and result finalization lock parent then target. A concurrent finalizer can deadlock; the closeout result case handles only :not_found and raises on the database transaction error, aborting the recovery pass."
    artifacts:
      - path: "lib/chimeway/delivery_targets.ex"
        issue: "close_stale_started_attempt/2 lines 183-232 locks target/attempt then invokes recompute_delivery/2; begin_target_attempt/2 and record_target_result/4 use the inverse parent-first order."
    missing:
      - "Use a single tenant-qualified parent → target → attempt lock order for stale closeout and aggregate persistence, return safe retryable transaction errors, and add deterministic closeout-versus-finalizer concurrency coverage."
---

# Phase 99: Multi-Installation Delivery & Recovery Verification Report

**Phase Goal:** A host can deliver one notification decision to all eligible opaque installations while preserving independent, tenant-safe target truth and recovery.
**Verified:** 2026-08-20T10:05:00-04:00
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A host resolver returns every active eligible opaque tenant-scoped binding revision and records one durable target per selected revision. | ✓ VERIFIED | `TargetResolver.normalize/2` validates and stable-sorts tenant-qualified revisions; `DeliveryTargets.plan_targets/3` uses the `{delivery_id, binding_revision_ref}` unique key and authoritative tenant reload. Focused delivery-target tests passed. |
| 2 | Operators can see independent claim, attempt, retry, expiry, invalidation, and trace history for each target beneath one logical delivery. | ✓ VERIFIED | All four trace loaders use `target_history_preload(tenant_id)` and closed `SafeEvidence` target projection; the 57-test trace/tenant suite passed. |
| 3 | Repeated planning, execution, or recovery creates no duplicate target or unexplained provider request, and bounded tenant recovery remains race-safe. | ✗ FAILED | Claim, target-ID fan-out, retry exhaustion, and ordinary recovery are covered, but stale recovery can deadlock against finalization and then raises instead of completing safely. |
| 4 | No eligible target is always suppressed with `no_eligible_targets`; mixed terminal targets retain partial failure and only accepted targets produce a succeeded aggregate. | ✗ FAILED | Sync executes the no-target recompute path, but the public Oban dispatcher returns successful empty enqueue without changing its pending parent. |
| 5 | A possible post-I/O crash is represented as an explicit ambiguous outcome rather than silently resent or accepted. | ✓ VERIFIED | Stale claimed attempts close to `ambiguous_handoff`; acceptance reloads and locks the exact claimed target/started attempt, so a stale success is a noop. Target-worker regression coverage passed. |

**Score:** 3/5 truths verified (0 present, behavior-unverified)

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| Target/attempt migrations and generated static-mode fixtures | Durable target identity and attempt ordering | ✓ VERIFIED | All 99-01/02 artifact checks pass; supplied schema drift and UI-safety gates passed. |
| `lib/chimeway/target_resolver.ex` and `delivery_planning.ex` | Opaque tenant-qualified resolution and idempotent child persistence | ✓ VERIFIED | Production plan path is wired to normalization and `plan_targets/3`. |
| `lib/chimeway/delivery_targets.ex` | Lifecycle, aggregation, recovery and race authority | ✗ PARTIAL | Substantive and broadly wired, but stale recovery uses an unsafe lock order and incomplete error handling. |
| `lib/chimeway/dispatch/sync.ex` | All-target synchronous fan-out | ✓ VERIFIED | Snapshots `actionable_targets/1`, executes every exact target ID, then recomputes. |
| `lib/chimeway/dispatch/oban.ex` | Safe asynchronous push enqueue | ✗ PARTIAL | Per-target enqueue exists, but empty snapshot leaves the canonical parent pending. |
| `lib/chimeway/dispatch/oban_worker.ex` | Parent-gated bounded target execution | ✓ VERIFIED | Target job uses claim authority and final retry invokes guarded exhaustion; focused test passed. |
| `lib/chimeway/target_recovery.ex` and `recovery_worker.ex` | Bounded, tenant-scoped recovery and closed telemetry | ✗ PARTIAL | Discovery/cursors/telemetry are substantive and wired; stale-closeout transaction can abort this worker. |
| `lib/chimeway/traces.ex`, `traces/explanation.ex`, `safe_evidence.ex` | Tenant-safe operator target histories | ✓ VERIFIED | Recipient, correlation, full-event, and explanation paths preload real target/attempt data. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `delivery_planning.ex` | `delivery_targets.ex` | normalize → insert/reload durable children | ✓ WIRED | All relevant plan link checks passed. |
| `sync.ex` | `executor.ex` | execute every snapshot target through exact target ID | ✓ WIRED | Two-target, repeated, concurrent, mixed-outcome, and empty-sync tests pass. |
| `oban.ex` | `delivery_targets.ex` | actionable target snapshot → parent terminal outcome | ✗ PARTIAL | It reads the snapshot but does not recompute an empty parent. |
| `oban_worker.ex` | `delivery_targets.ex` | tenant/target job claim and final retry exhaustion | ✓ WIRED | Guarded parent/target transition and exhaustion path are exercised by the 38-test worker/recovery suite. |
| `target_recovery.ex` | `delivery_targets.ex` | stale closeout and recovery convergence | ✗ PARTIAL | Link is real but transitions have a deadlock-prone lock-order inversion. |
| `traces.ex` | `safe_evidence.ex` | tenant-qualified target/attempt history projection | ✓ WIRED | All trace shapes route loaded data into the closed projection. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Common traces/explanations | `delivery.targets[].attempts` | Tenant-qualified Ecto preloads | Yes | ✓ FLOWING |
| Sync dispatch | ordered actionable target IDs | Tenant-qualified `DeliveryTarget` query | Yes | ✓ FLOWING |
| Recovery summary | event/target/stale IDs, counts, continuations | Separate bounded tenant-scoped queries | Yes, except stale closeout may abort on a DB conflict | ⚠️ PARTIAL |
| Oban push enqueue | target-job list | `actionable_targets/1` | Empty list is real, but it is not fed into parent suppression | ✗ HOLLOW TERMINAL FLOW |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Operator target histories | `env MIX_ENV=test mix test test/chimeway/traces_target_test.exs test/chimeway/traces_test.exs test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors` | 57 tests, 0 failures | ✓ PASS |
| Sync fan-out and existing lifecycle regression | `env MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/dispatch/target_worker_test.exs test/chimeway/integration/delivery_lifecycle_test.exs --warnings-as-errors` | 36 tests, 0 failures | ✓ PASS |
| Target worker/recovery race and retry-exhaustion matrix | `env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/orchestration/target_recovery_test.exs test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors` | 38 tests, 0 failures | ✓ PASS — does not exercise either remaining blocker interleaving/path |
| Compilation | `mix compile --warnings-as-errors` | supplied run passed | ✓ PASS |
| Prior-phase exact regression suite | supplied exact regression command | 687 tests, 0 failures | ✓ PASS |
| Full suite | supplied `mix test` run | no assertion failures before configured 600-second timeout | ? INCONCLUSIVE — not credited as passing evidence |

## Code Review Blockers Reassessed

| Finding | Assessment | Evidence | Result |
| --- | --- | --- | --- |
| BL-01: Empty-target Oban stranding | Confirmed live | `enqueue_delivery/1` reduces an empty `actionable_targets/1` to `{:ok, []}` at `lib/chimeway/dispatch/oban.ex:108`; lines 149-151 normalize that as success and contain no recompute. | 🛑 BLOCKER — breaks no-target suppression through a supported dispatch entry point. |
| BL-02: Parent/target lock-order deadlock | Confirmed live | `close_stale_started_attempt/2` locks target at `delivery_targets.ex:183-205` then calls `recompute_delivery/2` (parent `FOR UPDATE`, lines 576-599). Claim/result paths lock parent first (lines 94-116 and 335-364); closeout handles no transaction error other than `:not_found` (lines 229-232). | 🛑 BLOCKER — can abort bounded recovery on a legitimate concurrent finalizer. |

## Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PUSH-01 | 99-01, 03, 07, 09 | Opaque tenant-scoped resolver returns eligible revisions without raw tokens. | ✓ SATISFIED | Normalization, tenant scope, resolver/planning and focused tests. |
| PUSH-02 | 99-01–10 | One logical delivery has independently durable target lifecycle and trace history. | ✓ SATISFIED | Durable schema, ordered history, all common trace projections, and target lifecycle suites. |
| PUSH-03 | 99-02–10 | Duplicate planning/job/recovery cannot create duplicate target or unexplained provider request. | ✓ SATISFIED | Unique target identity, exact target claims, duplicate noops, and durable retry exhaustion are covered. |
| PUSH-04 | 99-01, 03, 07, 09, 10 | No-target suppression and honest terminal aggregate. | ✗ BLOCKED | Public Oban empty-target path strands pending delivery instead of recording `no_eligible_targets`. |
| RECOV-01 | 99-05, 07, 10 | Bounded tenant-scoped recovery with explainable evidence. | ✗ BLOCKED | Recovery discovery is bounded, but stale-closeout lock inversion can deadlock and raises on the transaction error. |
| RECOV-02 | 99-01, 04–07, 10 | Pre-I/O evidence and explicit ambiguous post-handoff outcome. | ✓ SATISFIED | Started-attempt evidence, stale ambiguity closeout, conditional success finalization, and focused worker tests. |

All six IDs declared by the ten plan frontmatters exist in `REQUIREMENTS.md`; none are orphaned. No later roadmap phase explicitly schedules either Phase 99 correction, so neither failure is deferred.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/dispatch/oban.ex` | 108-122, 149-151 | Empty target list normalized as successful dispatch | 🛑 BLOCKER | Canonical pending push delivery can remain permanently unexplained. |
| `lib/chimeway/delivery_targets.ex` | 183-232, 576-599 | Target → parent lock order and incomplete transaction-error match | 🛑 BLOCKER | Recovery can deadlock/raise against a normal finalizer. |
| Phase-owned code/tests | — | `TBD`/`FIXME`/`XXX` debt markers | ℹ️ None | No debt-marker blocker found. |

## Gaps Summary

Plans 99-08 through 99-10 close the five gaps recorded by the previous verification; their artifacts are substantive, wired, and covered by their focused executable suites. The phase nevertheless misses its goal on two supported asynchronous/recovery paths. An empty Oban push snapshot cannot produce the required no-target truth, and stale recovery cannot safely complete under the lock interleaving that ordinary claim/finalization establishes. Both are machine-testable BLOCKER gaps; per project policy, no conversational UAT or human-verification item is emitted.

---

_Verified: 2026-08-20T10:05:00-04:00_
_Verifier: the agent (gsd-verifier)_
