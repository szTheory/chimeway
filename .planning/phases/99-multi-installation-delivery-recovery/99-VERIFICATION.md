---
phase: 99-multi-installation-delivery-recovery
verified: 2026-08-20T14:55:10Z
status: gaps_found
score: 3/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  gaps_closed:
    - "Public Oban dispatch now recomputes an empty push snapshot to suppressed/no_eligible_targets."
    - "Stale closeout now locks parent -> target -> attempt and normalizes retryable transaction errors."
  gaps_remaining: []
  regressions:
    - "An unrestricted public retry transition can change provider_accepted to pending and authorize another provider request."
    - "Target and attempt migrations permit cross-tenant foreign-key relationships."
gaps:
  - truth: "Repeated planning, execution, or recovery produces neither a duplicate target nor an unexplained additional provider request."
    status: failed
    reason: "schedule_retry/3 has no allowed source-state predicate; it can transition a provider_accepted target to pending, after which normal Sync, Oban, or recovery execution can claim it and invoke the provider again."
    artifacts:
      - path: "lib/chimeway/delivery_targets.ex"
        issue: "transition_target/4 locks only id/delivery_id/tenant_id and updates any status to :pending; it accepts terminal provider_accepted input."
    missing:
      - "Replace the arbitrary transition helper with locked, operation-specific allowed source states; permit ordinary retry only from documented retryable failure states and add a regression proving an accepted target is unchanged and never reaches the adapter."
  - truth: "Each target preserves independent, tenant-safe target truth beneath one logical delivery."
    status: failed
    reason: "The target and attempt tables store tenant_id but foreign keys reference only IDs. PostgreSQL therefore permits a target whose tenant differs from its delivery and an attempt whose tenant differs from its target, corrupting tenant ownership at the durable boundary."
    artifacts:
      - path: "priv/repo/migrations/20260819000001_create_chimeway_delivery_targets.exs"
        issue: "delivery_id, delivery_target_id, and prior_attempt_id references are not tenant-qualified composite constraints."
      - path: "priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs"
        issue: "The adopter-facing generated migration repeats the same unqualified references."
    missing:
      - "Enforce parent/target tenant ownership structurally (composite tenant/id keys and foreign keys, plus same-target prior-attempt validation) and add migration-contract proof that cross-tenant inserts fail."
---

# Phase 99: Multi-Installation Delivery & Recovery Verification Report

**Phase Goal:** A host can deliver one notification decision to all eligible opaque installations while preserving independent, tenant-safe target truth and recovery.
**Verified:** 2026-08-20T14:55:10Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A host resolver can return opaque tenant-scoped eligible binding revisions and Chimeway records one durable target per selected revision. | ✓ VERIFIED | `TargetResolver.normalize/2` is wired through push planning to `DeliveryTargets.plan_targets/3`; the unique `(delivery_id, binding_revision_ref)` identity and focused target tests establish duplicate convergence and target creation. |
| 2 | Operators can see each target's independent claim, attempt, retry, expiry, invalidation, and trace history beneath one logical delivery with tenant-safe durable ownership. | ✗ FAILED | Query-level tenant filters and trace tests exist, but both migrations allow cross-tenant target/delivery and attempt/target foreign-key rows, so durable tenant truth is not preserved. |
| 3 | Repeated planning, execution, or recovery cannot create a duplicate target or an unexplained additional provider request; bounded tenant recovery has evidence. | ✗ FAILED | `schedule_retry/3` delegates to unrestricted `transition_target/4` at `lib/chimeway/delivery_targets.ex:516-518, 640-676`. A `provider_accepted` target can become `pending`, then `begin_target_attempt/2` authorizes another adapter handoff. |
| 4 | A no-target delivery is suppressed with a stable reason; mixed terminal outcomes expose partial failure and succeed only with provider acceptance. | ✓ VERIFIED | `Oban.dispatch_delivery/2` empty-snapshot regression and the sync mixed-outcome paths passed in the 49-test focused suite; aggregation counts accepted/terminal targets and uses only provider-handoff vocabulary. |
| 5 | A possible post-I/O crash becomes explicit ambiguous handoff evidence rather than an automatic resend or an exactly-once claim. | ✓ VERIFIED | `begin_target_attempt/2` persists `attempt_started` before `TargetAdapter.deliver/2`; stale closeout is parent-first and finalization requires the exact claimed target and started attempt. Focused recovery/worker tests passed. |

**Score:** 3/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| Target/attempt migrations | Durable tenant-safe identity and ordered attempt history in repository and copied storage modes | ✗ PARTIAL | Both are substantive and generated-mode artifacts exist, but their ID-only foreign keys permit cross-tenant durable relations. |
| `lib/chimeway/target_resolver.ex` + `delivery_planning.ex` | Opaque tenant-explicit resolution and idempotent child planning | ✓ VERIFIED | Normalization and `plan_targets/3` are substantive, wired, and covered by target tests. |
| `lib/chimeway/delivery_targets.ex` | Claim/start, lifecycle transitions, aggregation, and recovery authority | ✗ PARTIAL | Pre-I/O claims, exact finalization, and aggregation exist; generic transition authority can reopen accepted terminal state. |
| `lib/chimeway/dispatch/{sync,oban,executor,oban_worker}.ex` | All-target target-attempt execution | ✓ VERIFIED | Sync and Oban snapshot durable targets; executor enters adapter only after `begin_target_attempt/2`; focused dispatch tests passed. |
| `lib/chimeway/{traces.ex,target_recovery.ex,safe_evidence.ex}` | Real tenant-qualified projections and bounded recovery evidence | ✓ VERIFIED | Ecto-backed target/attempt data flows through the trace and safe-evidence projections; 49-test focused suite passed. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `delivery_planning.ex` | `delivery_targets.ex` | resolver normalization -> durable target insert/reload | ✓ WIRED | Automated plan link check passed. |
| `sync.ex` | `executor.ex` | ordered actionable target snapshot -> exact `run_target/2` | ✓ WIRED | Automated plan link check and focused target tests passed. |
| `executor.ex` | `delivery_targets.ex` | claim/start -> adapter -> exact result finalization | ✓ WIRED | `run_target/2` calls `begin_target_attempt/2` before adapter invocation; focused adapter assertions pass. |
| `delivery_targets.ex` | target lifecycle | retry state -> later adapter authority | ✗ UNSAFE | The connection is live but permits terminal `provider_accepted` -> `pending` -> claim -> adapter execution. |
| target/attempt migrations | parent ownership | durable tenant relation | ✗ NOT_WIRED | Tenant_id is stored but not part of either foreign-key contract. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Target planning | normalized binding revisions | configured resolver -> `TargetResolver.normalize/2` -> `plan_targets/3` | Yes | ✓ FLOWING |
| Dispatch | ordered pending target IDs | tenant-qualified `DeliveryTarget` Ecto query | Yes | ✓ FLOWING |
| Operator traces | target/attempt histories | tenant-qualified Ecto preloads | Yes | ✓ FLOWING |
| Durable ownership | target/attempt tenant relationship | migrations | No structural proof | ✗ HOLLOW SAFETY BOUNDARY |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Target lifecycle, Sync/Oban fan-out, recovery, traces, and tenant query guards | `env MIX_ENV=test mix test test/chimeway/delivery_target_test.exs test/chimeway/dispatch/target_worker_test.exs test/chimeway/dispatch/oban_test.exs test/chimeway/orchestration/target_recovery_test.exs test/chimeway/traces_target_test.exs test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors` | 49 tests, 0 failures | ✓ PASS |
| Formatting of critical production/test artifacts | `mix format --check-formatted …` | Exit 0 | ✓ PASS |
| Accepted target cannot be retried/resubmitted | Existing targeted tests | No test exercises `schedule_retry/3` from `provider_accepted`; source proves it is allowed | ✗ FAIL |
| Generated migration execution suite | `env MIX_ENV=test mix test test/chimeway/migration_contract_test.exs … --warnings-as-errors` | Could not start because PostgreSQL rejected additional clients (`FATAL 53300 too_many_connections`) | ? NOT CREDITED |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PUSH-01 | 99-01, 03, 07, 09, 11 | Opaque tenant-scoped resolution of eligible installation revisions | ✓ SATISFIED | Resolver normalization/planning and target tests. |
| PUSH-02 | 99-01–10, 11 | Independent durable target lifecycle and trace history | ✗ BLOCKED | Database permits tenant-mismatched target and attempt durable history. |
| PUSH-03 | 99-02–10, 11 | No duplicate target or unexplained provider request | ✗ BLOCKED | Accepted target can be reset to pending by public retry API and sent again. |
| PUSH-04 | 99-01, 03, 07, 09–11 | Stable no-target suppression and honest aggregate result | ✓ SATISFIED | Empty Oban and sync paths exercised in focused tests. |
| RECOV-01 | 99-05, 07, 10, 11 | Bounded tenant-scoped recovery with explainable evidence | ✓ SATISFIED | Parent-first stale closeout and recovery suite are wired and pass. |
| RECOV-02 | 99-01, 04–07, 10, 11 | Pre-I/O evidence and ambiguous possible-handoff recovery | ✓ SATISFIED | Started-attempt persistence, closeout/finalization conditions, focused recovery tests. |

All six plan-declared IDs are present in `REQUIREMENTS.md`; no Phase 99 requirement is orphaned. `roadmap.analyze` has no later phase that explicitly defers either failure.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/delivery_targets.ex` | 516-518, 640-676 | Generic terminal-state rewrite | 🛑 BLOCKER | Can authorize a duplicate provider request after accepted handoff. |
| Repository and copied target migrations | target FK definitions | Tenant ID not enforced across relationships | 🛑 BLOCKER | Durable tenant history can be malformed by a bad write. |
| Phase-owned production/test files | — | `TBD`/`FIXME`/`XXX` markers | ℹ️ None | No debt-marker blocker found. |

### Gaps Summary

The prior empty-Oban and stale-closeout gaps are closed and their focused tests now pass. Phase 99 nevertheless does not achieve its tenant-safe, independently recoverable delivery goal: a public lifecycle API can reopen an accepted target and resend it, and the database does not preserve tenant ownership across the target/attempt relationship. Both are machine-testable BLOCKER gaps. No conversational UAT is requested under the project’s executable-evidence policy.

---

_Verified: 2026-08-20T14:55:10Z_
_Verifier: the agent (gsd-verifier)_
