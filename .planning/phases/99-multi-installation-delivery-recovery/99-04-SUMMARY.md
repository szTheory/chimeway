---
phase: 99-multi-installation-delivery-recovery
plan: "04"
subsystem: delivery
tags: [elixir, ecto, oban, push, idempotency, recovery]
requires:
  - phase: 99-multi-installation-delivery-recovery
    provides: durable opaque target rows and ordered target-attempt evidence
provides:
  - Tenant-qualified target-ID Oban execution with durable pre-I/O claims
  - Stale started-attempt closeout as explicit ambiguous handoff
  - Policy-gated, duplicate-risk linked target redrive evidence
affects: [phase-99-recovery, phase-100-apns]
tech-stack:
  added: []
  patterns: [durable target claim as I/O authority, target ID-only job args, ambiguous handoff before redrive]
key-files:
  created:
    - test/chimeway/dispatch/target_worker_test.exs
  modified:
    - lib/chimeway/delivery_targets.ex
    - lib/chimeway/dispatch/executor.ex
    - lib/chimeway/dispatch/oban.ex
    - lib/chimeway/dispatch/oban_worker.ex
key-decisions:
  - "[99-04]: Target ID plus explicit tenant ID are the only target-worker job facts; the durable target row decides I/O eligibility."
  - "[99-04]: An expired started attempt is closed as ambiguous_handoff with possible_provider_handoff evidence and is never automatically resent."
  - "[99-04]: A policy_authorized redrive preserves the predecessor link and marks the next target attempt duplicate_risk=true."
patterns-established:
  - "Target execution claims the selected target under a row lock and persists attempt_started before invoking the replaceable target adapter."
  - "Wrong tenant or stale target worker inputs converge to a non-disclosing noop."
requirements-completed: [PUSH-02, PUSH-03, RECOV-02]
coverage:
  - id: D1
    description: Target-ID Oban work claims and records its attempt before target-adapter handoff.
    requirement: PUSH-02
    verification:
      - kind: integration
        ref: test/chimeway/dispatch/target_worker_test.exs#target-id Oban jobs start the durable target attempt before adapter handoff
        status: pass
    human_judgment: false
  - id: D2
    description: Expired started target work remains an explicit ambiguous handoff and requires linked policy redrive.
    requirement: RECOV-02
    verification:
      - kind: integration
        ref: test/chimeway/dispatch/target_worker_test.exs#stale started target work closes as ambiguous instead of becoming eligible for resend
        status: pass
    human_judgment: false
  - id: D3
    description: Existing delivery-worker and lifecycle behavior remains compatible with target-aware Oban execution.
    requirement: PUSH-03
    verification:
      - kind: integration
        ref: env MIX_ENV=test mix test test/chimeway/dispatch/oban_worker_test.exs test/chimeway/integration/delivery_lifecycle_test.exs --warnings-as-errors
        status: pass
    human_judgment: false
duration: 8 min
completed: 2026-08-19
status: complete
---

# Phase 99 Plan 04: Race-Safe Target Execution and Honest Handoff Recovery Summary

**Target delivery now uses tenant-qualified durable claims before adapter I/O, while interrupted handoffs remain ambiguous until an explicitly risk-labeled redrive.**

## Accomplishments

- Routed push Oban jobs with only `delivery_target_id` and `tenant_id`, keeping target rows as the authority for provider-call eligibility.
- Persisted source-qualified target attempts before target-adapter invocation and preserved non-push delivery worker behavior.
- Added stale-start closeout to terminal `ambiguous_handoff` and policy-gated linked redrive attempts with duplicate-risk evidence.

## Task Commits

1. **Task 1: Gate every sync and Oban target request on one durable claim/start** — `0c6ac0e` (RED), `7e35696` (implementation).
2. **Task 2: Close stale starts as ambiguous and link policy-authorized redrives** — `691de10` (implementation).

## Files Created/Modified

- `lib/chimeway/delivery_targets.ex` — tenant-qualified target claim, stale closeout, and linked redrive lifecycle operations.
- `lib/chimeway/dispatch/executor.ex` — carries target execution source and target ID into the shared claim seam.
- `lib/chimeway/dispatch/oban.ex` — schedules actionable push targets as target-ID jobs.
- `lib/chimeway/dispatch/oban_worker.ex` — runs target-ID jobs as non-disclosing noops when the durable row is not eligible.
- `test/chimeway/dispatch/target_worker_test.exs` — target worker pre-I/O and ambiguous-handoff/redrive contract evidence.

## Verification

- PASS: `mix format --check-formatted lib/chimeway/delivery_targets.ex lib/chimeway/dispatch/executor.ex lib/chimeway/dispatch/sync.ex lib/chimeway/dispatch/oban.ex lib/chimeway/dispatch/oban_worker.ex test/chimeway/dispatch/target_worker_test.exs`
- PASS: `env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs test/chimeway/dispatch/oban_worker_test.exs test/chimeway/integration/delivery_lifecycle_test.exs --warnings-as-errors` (34 tests, 0 failures).
- PASS: `env MIX_ENV=test mix test test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors` (2 tests, 0 failures).

## Decisions Made

- Durable target rows, not Oban job uniqueness, are the provider-call authorization boundary.
- The post-handoff crash boundary records `possible_provider_handoff`; it never implies a known-unsent request or exactly-once delivery.
- Redrive authorization accepts only the bounded `policy_authorized` reason and retains an immutable link to the ambiguous predecessor.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected a nullable target-ID SQL predicate.**
- **Found during:** Task 1
- **Issue:** PostgreSQL could not infer the type of the nullable target-ID parameter in the initial conditional target query.
- **Fix:** Used separate target-ID and delivery-selection query branches, preserving the same tenant-qualified eligibility contract.
- **Files modified:** `lib/chimeway/delivery_targets.ex`
- **Verification:** Focused target-worker test passed after the correction.
- **Committed in:** `7e35696`

**Total deviations:** 1 auto-fixed (Rule 1).
**Impact on plan:** No scope change; the correction is necessary for target-specific durable claims to execute.

## Known Stubs

None. Stub-pattern scan found no placeholder or TODO/FIXME content in plan-owned implementation and test files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 99 recovery and the Phase 100 provider adapter can rely on target-ID job facts, durable claim-start evidence, and an explicit ambiguous handoff/redrive contract.

## Self-Check: PASSED

- Found plan-owned execution and worker files plus `test/chimeway/dispatch/target_worker_test.exs`.
- Found task commits: `0c6ac0e`, `7e35696`, and `691de10`.
- No tracked file deletions were introduced by task commits.

---
*Phase: 99-multi-installation-delivery-recovery*
*Completed: 2026-08-19*
