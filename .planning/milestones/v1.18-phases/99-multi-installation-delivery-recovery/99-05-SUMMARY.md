---
phase: 99-multi-installation-delivery-recovery
plan: "05"
subsystem: delivery-recovery
tags: [elixir, ecto, oban, postgres, tenant-safety, recovery]
requires:
  - phase: 99-multi-installation-delivery-recovery
    provides: tenant-qualified durable targets, pre-I/O attempt claims, and ambiguous handoff closeout
provides:
  - Bounded tenant-qualified event and target recovery with durable-ID keyset cursors
  - A recovery Oban worker and closed recovery evidence DTOs
  - Executable tenant, race, stale-handoff, and static-prefix recovery proof
affects: [phase-100-apns, phase-101-crosswake, phase-99-verification]
tech-stack:
  added: []
  patterns:
    - Recovery discovery is bounded and tenant-qualified; durable claims remain provider-I/O authority.
    - Expired attempt_started work is closed as ambiguous before recovery considers actionable targets.
key-files:
  created:
    - lib/chimeway/target_recovery.ex
    - lib/chimeway/dispatch/recovery_worker.ex
    - test/chimeway/orchestration/target_recovery_test.exs
  modified:
    - lib/chimeway/delivery_targets.ex
    - lib/chimeway/safe_evidence.ex
    - test/chimeway/dispatch/target_worker_test.exs
    - test/chimeway/tenant_scope_contract_test.exs
    - test/chimeway/runtime_prefix_integration_test.exs
    - .planning/phases/99-multi-installation-delivery-recovery/99-VALIDATION.md
key-decisions:
  - "[99-05]: Recovery uses explicit tenant IDs, ID keyset cursors, a default batch of 50, and a hard maximum of 100."
  - "[99-05]: Lease expiry never reauthorizes target I/O; started expired work becomes ambiguous_handoff before any dispatch decision."
  - "[99-05]: Recovery results expose only tenant-authorized durable IDs, counts, cursors, and closed reason tokens."
patterns-established:
  - "Concurrent recovery delegates final I/O authority to the existing tenant-qualified target claim transaction."
requirements-completed: [PUSH-03, RECOV-01, RECOV-02]
coverage:
  - id: D1
    description: Bounded tenant-scoped recovery finds stranded planning and pages pending target work by durable ID.
    requirement: RECOV-01
    verification:
      - kind: integration
        ref: test/chimeway/orchestration/target_recovery_test.exs#discovers tenant-qualified targets in bounded durable-ID pages
        status: pass
      - kind: integration
        ref: test/chimeway/tenant_scope_contract_test.exs#target recovery keeps missing and foreign scopes non-disclosing
        status: pass
    human_judgment: false
  - id: D2
    description: Recovery workers converge on durable target identity and claim state with a single adapter handoff.
    requirement: PUSH-03
    verification:
      - kind: integration
        ref: test/chimeway/orchestration/target_recovery_test.exs#concurrent recovery workers converge on one target claim and adapter handoff
        status: pass
    human_judgment: false
  - id: D3
    description: Expired started attempts become ambiguous rather than automatically resendable, including ordinary target workers.
    requirement: RECOV-02
    verification:
      - kind: integration
        ref: test/chimeway/dispatch/target_worker_test.exs#stale started target work closes as ambiguous instead of becoming eligible for resend
        status: pass
    human_judgment: false
  - id: D4
    description: Ordinary recovery discovery runs through configured public or prefixed static storage without a domain prefix argument.
    requirement: RECOV-01
    verification:
      - kind: integration
        ref: mix verify.runtime_prefix
        status: pass
      - kind: integration
        ref: mix verify.install_golden
        status: pass
    human_judgment: false
metrics:
  duration: 29m
  completed: 2026-08-20
status: complete
---

# Phase 99 Plan 05: Multi-Installation Delivery Recovery Summary

**Tenant-qualified bounded recovery now resumes stranded planning and safely converges target execution without turning an expired possible handoff into a resend.**

## Performance

- **Duration:** 29m
- **Started:** 2026-08-19T23:54:00Z
- **Completed:** 2026-08-20T00:23:38Z
- **Tasks:** 1/1
- **Files modified:** 10

## Accomplishments

- Added `Chimeway.TargetRecovery` with explicit tenant scope, ID-keyset pagination, a default batch of 50, and a maximum batch of 100.
- Added `Chimeway.Dispatch.RecoveryWorker`, closed recovery reason/count/cursor evidence, and tenant-safe non-disclosing noops.
- Closed expired `attempt_started` work as `ambiguous_handoff` before recovery; ordinary target execution no longer treats a lease expiry as resend authority.
- Completed the Phase 99 Nyquist map and proved recovery in public and prefixed static storage.

## Task Commits

1. **Task 1: Recover bounded tenant-owned event and target work without blind resend** — `567d9da` (RED test), `4e865ce` (implementation and validation evidence).

## Verification

- PASS: `mix format --check-formatted` for all plan-owned source and test files.
- PASS: `env MIX_ENV=test mix test test/chimeway/orchestration/target_recovery_test.exs test/chimeway/dispatch/target_worker_test.exs test/chimeway/tenant_scope_contract_test.exs test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` (25 tests, 0 failures).
- PASS: `mix verify.runtime_prefix`.
- PASS: `mix verify.install_golden`.
- PASS: `mix ci.test`.
- PASS: Phase 99 `parseMustHavesBlock` contract for all five plans.

## Decisions Made

- Tenant identity is an explicit worker/service input and is repeated across each recovery query and target fetch.
- The target row plus `begin_target_attempt/2` remains the only provider-call authority; recovery discovery never broadens that authority.
- Recovery evidence intentionally excludes host identity, endpoint, credential, payload, and provider-body data.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Split nil-cursor queries before Ecto interpolation.**
- **Found during:** Task 1 focused recovery test.
- **Issue:** Comparing a durable ID to a nil cursor is forbidden by Ecto.
- **Fix:** Added cursor-specific query branches while preserving ordered keyset paging.
- **Files modified:** `lib/chimeway/target_recovery.ex`.
- **Verification:** Recovery paging tests pass.
- **Committed in:** `4e865ce`.

**2. [Rule 2 - Security] Removed expired claimed rows from target attempt eligibility.**
- **Found during:** Task 1 stale-handoff review.
- **Issue:** Lease expiry alone could previously make a claimed target eligible for a new provider handoff.
- **Fix:** Only pending targets can begin a new attempt; stale started claims are closed through the ambiguous path.
- **Files modified:** `lib/chimeway/delivery_targets.ex`, `test/chimeway/dispatch/target_worker_test.exs`.
- **Verification:** Stale target-worker and recovery tests pass with no adapter call before closeout.
- **Committed in:** `4e865ce`.

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 2).

## Known Stubs

None. Plan-owned files contain no runtime placeholder or TODO/FIXME stubs.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 99 now has executable recovery coverage across tenant scope, durable claims, ambiguity, and both supported static storage modes. Phase 100 can build its provider adapter on the same no-blind-resend handoff boundary.

## Self-Check: PASSED

- Found the new recovery service, worker, focused test, validation matrix, and task commits `567d9da` and `4e865ce`.
- No tracked file deletions were introduced by either task commit.

---
*Phase: 99-multi-installation-delivery-recovery*
*Completed: 2026-08-20*
