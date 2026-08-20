---
phase: 99-multi-installation-delivery-recovery
verified: 2026-08-19T22:03:00-04:00
status: gaps_found
score: 2/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  gaps_closed:
    - "Adapter errors and unexpected adapter results now close their claimed target attempt through record_target_failure/4."
    - "Recovery now discovers both trigger-commit gap shapes, uses separate bounded event/target/stale-attempt cursors, and emits its closed summary."
  gaps_remaining:
    - "Independent target history is omitted by common operator trace projections."
    - "Sync delivery fans out to only one target."
    - "Target Oban work lacks a terminal-parent gate and retry-exhaustion transition."
    - "A late provider success can overwrite an ambiguous-handoff closeout."
  regressions: []
gaps:
  - truth: "Operators can see each target's independent claim, attempt, retry, expiry, invalidation, and trace history beneath one logical delivery."
    status: failed
    reason: "The full event trace preloads targets, but recipient, correlation, and delivery-explanation projections preload only parent delivery attempts; SafeEvidence then renders unloaded targets as an empty list."
    artifacts:
      - path: "lib/chimeway/traces.ex"
        issue: "find_traces_for_recipient/2 (line 143), find_traces_by_correlation_id/2 (line 179), and explain_delivery/2 (line 211) omit target/target-attempt preloads."
    missing:
      - "Use the tenant-qualified target and target-attempt preload in every operator trace/explanation path and test all three paths with multi-target data."
  - truth: "One notification decision is delivered to all eligible opaque installation targets."
    status: failed
    reason: "Sync dispatch calls Executor.run_target/1 exactly once; its no-target-id claim query deliberately selects only the first pending target. Remaining selected targets stay pending."
    artifacts:
      - path: "lib/chimeway/dispatch/sync.ex"
        issue: "do_dispatch/1 at lines 113-117 makes one target execution call."
      - path: "lib/chimeway/delivery_targets.ex"
        issue: "begin_target_attempt/2 at lines 109-118 selects limit: 1 when no target ID is supplied."
    missing:
      - "Enumerate all tenant-qualified pending targets at the sync dispatcher boundary, execute each by target ID, and prove two-target sync fan-out."
  - truth: "Repeated planning, execution, or recovery creates neither a duplicate target nor an unexplained additional provider request."
    status: failed
    reason: "A target-id Oban job returns retryable errors without inspecting its attempt budget or calling exhaust_target/3. After Oban discards it, recovery can invoke the provider again indefinitely."
    artifacts:
      - path: "lib/chimeway/dispatch/oban_worker.ex"
        issue: "The target-job clause at lines 121-129 has no attempt/max_attempts pattern or terminal exhaustion path."
    missing:
      - "On a final pre-handoff retryable target job, atomically mark that target retry_exhausted, append terminal evidence, recompute its parent, and prove recovery does not resend it."
  - truth: "A terminal/suppressed/deferred parent cannot authorize a queued target provider request."
    status: failed
    reason: "The target-job fetch and target claim predicate qualify tenant and target status but do not require parent status :pending and orchestration_state :ready. A queued job may hand off after a concurrent suppression/cancellation/deferral and later overwrite the parent aggregate."
    artifacts:
      - path: "lib/chimeway/delivery_targets.ex"
        issue: "fetch_target_delivery/2 (lines 60-72) and begin_target_attempt/2 (lines 90-167) do not join/lock and predicate the parent lifecycle state."
    missing:
      - "Make target claim a single locked tenant-qualified target-plus-parent transaction requiring pending/ready; return a non-disclosing noop otherwise and add suppress/cancel/defer interleaving coverage."
  - truth: "A crash after possible provider handoff remains an explicit ambiguous outcome and is never silently converted to acceptance."
    status: failed
    reason: "record_target_result/4 writes caller-supplied stale structs directly, unlike the locked failure path. A late success after close_stale_started_attempt/2 can overwrite ambiguous_handoff with provider_accepted."
    artifacts:
      - path: "lib/chimeway/delivery_targets.ex"
        issue: "record_target_result/4 at lines 302-325 neither reloads/locks the target and attempt nor requires claimed/attempt_started states."
    missing:
      - "Lock and tenant-qualify the exact target and attempt, require claimed plus attempt_started before acceptance, noop on conflict, and add the stale-closeout/late-success interleaving test."
---

# Phase 99: Multi-Installation Delivery & Recovery Verification Report

**Phase Goal:** A host can deliver one notification decision to all eligible opaque installations while preserving independent, tenant-safe target truth and recovery.
**Verified:** 2026-08-19T22:03:00-04:00
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A resolver returns all active eligible tenant-scoped opaque revisions and one durable target is recorded per selected revision. | ✓ VERIFIED | `TargetResolver` normalizes/sorts exact opaque revisions; planning inserts conflict-safe target children. `delivery_target_test.exs` passes its normalization and canonical-target cases. |
| 2 | Operators can see every target's independent claim, attempt, retry, expiry, invalidation, and trace history beneath one delivery. | ✗ FAILED | Only `get_trace/2` preloads target history. The other normal operator projections omit it; see `Traces` lines 143, 179, and 211. |
| 3 | Repeated planning/execution/recovery is duplicate-safe and bounded without unexplained provider requests. | ✗ FAILED | Planning/claim tests pass, but target Oban retries never exhaust and recovery can resend indefinitely. |
| 4 | No eligible target suppresses with a stable reason; terminal mixed target results retain partial failure and succeed only when accepted. | ✓ VERIFIED | `DeliveryTargets.aggregate/1` and `aggregate_status/2` preserve pending state until all targets terminal and derive no-target/partial outcomes. Focused tests pass. The separate parent-gate gap prevents this from being safe for a queued job after suppression. |
| 5 | A possible post-I/O crash is represented as ambiguous rather than silently resent or accepted. | ✗ FAILED | Stale closeout writes ambiguity, but a late success is allowed to overwrite it because acceptance is not conditional on the current locked state. |

**Score:** 2/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `priv/repo/migrations/20260819000001_create_chimeway_delivery_targets.exs` | Target and ordered-attempt schema | ✓ VERIFIED | Static-storage checks pass; migration has target/attempt identity constraints. |
| `priv/chimeway_migrations/035_create_chimeway_delivery_targets.exs` | Prefix-aware copied schema | ✓ VERIFIED | `mix verify.runtime_prefix` and `mix verify.install_golden` pass. |
| `lib/chimeway/target_resolver.ex` | Opaque tenant-scoped resolver contract | ✓ VERIFIED | Substantive normalized resolver used by push planning. |
| `lib/chimeway/delivery_targets.ex` | Target lifecycle, aggregation, and race safety | ✗ STUB FOR REQUIRED RACES | Core lifecycle is substantive, but acceptance finalization and claim authority lack required state predicates. |
| `lib/chimeway/dispatch/sync.ex` | All-target synchronous fan-out | ✗ PARTIAL | Wired to `Executor.run_target/1`, but calls it once. |
| `lib/chimeway/dispatch/oban_worker.ex` | Parent-gated bounded target execution | ✗ PARTIAL | Target worker is wired but omits parent terminal gate and retry exhaustion. |
| `lib/chimeway/target_recovery.ex` | Bounded tenant recovery | ✓ VERIFIED | Separate event, target, and stale-attempt cursors and batch cap are present and covered by focused tests. |
| `lib/chimeway/dispatch/recovery_worker.ex` | Closed observable recovery evidence | ✓ VERIFIED | Emits `[:chimeway, :recovery, :completed]` with the closed summary. |
| `lib/chimeway/traces.ex` | Tenant-safe target history in operator views | ✗ PARTIAL | Full event trace works; recipient/correlation/explanation views are hollow for targets. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `delivery_planning.ex` | `delivery_targets.ex` | resolver normalization and child insertion | ✓ WIRED | Production planning uses `TargetResolver` and `DeliveryTargets`. |
| `sync.ex` | `executor.ex` | execute each selected durable target | ✗ PARTIAL | Link exists, but one `run_target/1` cannot fan out. |
| `oban_worker.ex` | `delivery_targets.ex` | target worker claim/retry authority | ✗ PARTIAL | Fetch/execute link exists but lacks terminal parent and retry-budget predicates. |
| `executor.ex` | `delivery_targets.ex` | pre-I/O start then durable outcome | ✗ PARTIAL | Failure finalization is locked; success finalization is not. |
| `traces.ex` | `safe_evidence.ex` | target history projection | ✗ PARTIAL | Target DTO exists, but common loaders do not supply its data. |
| `recovery_worker.ex` | `target_recovery.ex` | bounded tenant recovery and telemetry | ✓ WIRED | Summary is returned and emitted. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `Traces.get_trace/2` | `delivery.targets[].attempts` | Tenant-qualified preloads | Yes | ✓ FLOWING |
| Recipient/correlation/explanation traces | `delivery.targets` | Parent-attempt-only preloads | No | ✗ DISCONNECTED |
| Recovery telemetry | `summary.counts/reasons/continuations` | `TargetRecovery.recover_tenant/2` | Yes, closed projection | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Existing target/recovery contract matrix | `env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs test/chimeway/orchestration/target_recovery_test.exs test/chimeway/delivery_target_test.exs test/chimeway/traces_target_test.exs test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors` | 27 tests, 0 failures | ✓ PASS — incomplete for the five gaps above |
| Static prefix routing | `mix verify.runtime_prefix` | 19 tests, 0 failures | ✓ PASS |
| Generated migration parity | `mix verify.install_golden` | Exited 0 | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PUSH-01 | 99-01, 99-03, 99-07 | Opaque tenant-scoped resolver returns eligible revisions without raw tokens. | ✓ SATISFIED | Resolver/normalization and focused planning tests. |
| PUSH-02 | 99-01, 02, 03, 04, 06, 07 | One logical delivery retains independent durable target lifecycle and trace history. | ✗ BLOCKED | Common operator trace paths omit target histories. |
| PUSH-03 | 99-02, 03, 04, 05, 06, 07 | No duplicate target or unexplained additional provider request. | ✗ BLOCKED | Target-job retry exhaustion is absent, allowing recovery resend after Oban exhaustion. |
| PUSH-04 | 99-01, 03, 07 | Stable no-target suppression and honest aggregate terminal result. | ✗ BLOCKED | A stale queued target job can hand off after parent suppression/cancel/defer and acceptance can overwrite the parent aggregate. |
| RECOV-01 | 99-05, 07 | Bounded tenant-scoped recovery with evidence. | ✓ SATISFIED | Both trigger gaps, independent bounded cursors, and closed telemetry are implemented/tested. |
| RECOV-02 | 99-01, 04, 05, 06, 07 | Pre-I/O evidence and honest ambiguous post-handoff outcome. | ✗ BLOCKED | Late result race can erase `ambiguous_handoff`. |

All six requirement IDs declared by Phase 99 plans appear in `REQUIREMENTS.md`; none are orphaned. No later roadmap phase explicitly schedules correction of these Phase 99 core-delivery gaps, so none are deferred.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/chimeway/dispatch/sync.ex` | 115-117 | Single-target execution | 🛑 BLOCKER | Multi-installation fan-out is not achieved. |
| `lib/chimeway/dispatch/oban_worker.ex` | 121-129 | Missing lifecycle/budget guard | 🛑 BLOCKER | Can issue post-terminal or unbounded requests. |
| `lib/chimeway/delivery_targets.ex` | 302-325 | Unconditional stale-struct success write | 🛑 BLOCKER | Can erase durable ambiguity. |
| `lib/chimeway/traces.ex` | 143, 179, 211 | Hollow target data flow | 🛑 BLOCKER | Operators cannot see required per-target truth. |
| Phase-owned files scanned | — | `TBD`/`FIXME`/`XXX` debt markers | ℹ️ None | No unresolved debt-marker blocker found. |

### Gaps Summary

The prior re-verification gaps for adapter-outcome closure and bounded recovery are closed. The phase goal is still not achieved: the actual delivery entry points can miss selected installations, run after their parent becomes terminal, exceed the provider-request retry budget, and overwrite an intentionally ambiguous handoff. Operator views also hide target history outside the full-event trace. The passing matrix proves narrower paths only and contains no two-target sync, terminal-parent race, target-exhaustion, late-result interleaving, or common-trace projection test.

---

_Verified: 2026-08-19T22:03:00-04:00_
_Verifier: the agent (gsd-verifier)_
