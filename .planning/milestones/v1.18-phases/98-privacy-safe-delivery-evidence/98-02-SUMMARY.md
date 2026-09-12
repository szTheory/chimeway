---
phase: 98-privacy-safe-delivery-evidence
plan: 02
subsystem: privacy-safe delivery evidence
tags: [elixir, ecto, privacy, trigger, inbox]
requires:
  - phase: 98-privacy-safe-delivery-evidence
    provides: closed safe-evidence builders and opaque-reference validation
provides:
  - Closed event, notification, delivery-planning, and render evidence writes
  - Tenant-scoped Inbox reads and transitions over validated opaque recipient references
affects:
  - Phase 98 privacy-safe diagnostic and projection work
tech-stack:
  added: []
  patterns:
    - Literal SafeEvidence builders before durable JSON/map writes
    - Host-supplied cw_ references retained as durable identity without raw identity fallback
key-files:
  created:
    - .planning/phases/98-privacy-safe-delivery-evidence/98-02-SUMMARY.md
  modified:
    - lib/chimeway/safe_evidence.ex
    - lib/chimeway/trigger.ex
    - lib/chimeway/deliveries.ex
    - lib/chimeway/inbox.ex
    - test/chimeway/trigger_sanitization_test.exs
    - test/chimeway/orchestration/delivery_planning_test.exs
    - test/chimeway/inbox_query_test.exs
    - test/chimeway/inbox_state_transition_test.exs
    - test/chimeway/tenant_scope_contract_test.exs
key-decisions:
  - "[98-02]: Trigger persists only a validated host-supplied cw_ recipient reference and optional opaque correlation reference; raw recipient data remains callback-only."
  - "[98-02]: Event, notification, planning, delivery metadata, and render fields use closed fact builders rather than sanitized arbitrary maps."
  - "[98-02]: Inbox validates recipient references after tenant resolution and uses the validated value for every query, mutation, reload, and first-transition signal."
metrics:
  duration: 12 min
  completed: 2026-08-12
status: complete
---

# Phase 98 Plan 02: Opaque Trigger and Inbox Evidence Summary

**Trigger, delivery planning, and Inbox operations now persist and query only tenant-bound opaque references plus explicit lifecycle facts.**

## Accomplishments

- Added closed SafeEvidence builders for event payloads, notification metadata, channel render identities, planning context, delivery metadata, and render data.
- Updated Trigger to validate `cw_` recipient/correlation references before its transaction, persist recipient refs exactly, and retain raw recipient maps only for notifier callbacks.
- Routed delivery planning map fields through named evidence builders so unrecognized, rendered, or sensitive map values are omitted before changesets.
- Updated every Inbox read and lifecycle transition predicate to resolve tenant scope first, validate the recipient ref, and reuse that reference for mutation reloads and signals.
- Extended focused persistence and Inbox tests with opaque-reference fixtures and closed render-data assertions.

## Task Commits

1. **Task 1: Close Trigger and delivery-planning write boundaries**
   - `2545e46` — close Trigger and planning evidence writes
2. **Task 2: Preserve tenant-scoped Inbox behavior over opaque recipient predicates**
   - `c5312b5` — scope Inbox operations by opaque refs

## Verification

- PASS: `mix format --check-formatted lib/chimeway/safe_evidence.ex lib/chimeway/trigger.ex lib/chimeway/deliveries.ex test/chimeway/trigger_sanitization_test.exs test/chimeway/orchestration/delivery_planning_test.exs`
- PASS: `env MIX_ENV=test mix test test/chimeway/trigger_sanitization_test.exs test/chimeway/orchestration/delivery_planning_test.exs --warnings-as-errors` — 15 tests, 0 failures.
- PASS: `mix format --check-formatted lib/chimeway/safe_evidence.ex lib/chimeway/inbox.ex test/chimeway/inbox_query_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/tenant_scope_contract_test.exs`
- PASS: `env MIX_ENV=test mix test test/chimeway/inbox_query_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/tenant_scope_contract_test.exs --warnings-as-errors` — 18 tests, 0 failures.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 3 - Blocking issue] Updated the tenant-scope compatibility fixture to use an opaque recipient reference**
   - **Found during:** Task 2 verification
   - **Issue:** The inherited tenant-scope contract fixture still supplied a raw recipient identity, so it correctly failed at the new Inbox validation boundary.
   - **Fix:** Updated the direct fixture and public Inbox calls to use `cw_compat_user`.
   - **Files modified:** `test/chimeway/tenant_scope_contract_test.exs`
   - **Commit:** `c5312b5`

## Known Stubs

None.

## Self-Check: PASSED

- Found all plan-owned implementation and test files.
- Found task commits `2545e46` and `c5312b5`.
- No tracked file deletions were introduced.
