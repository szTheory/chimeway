---
phase: 97-tenant-identity-compatible-upgrade
plan: 02
subsystem: tenant-scoped core APIs
tags: [elixir, ecto, tenant-isolation, inbox, admin]
requires:
  - phase: 97-tenant-identity-compatible-upgrade
    provides: persisted tenant identity and scope resolution
provides:
  - Tenant-scoped inbox reads, counts, lifecycle transitions, and signals
  - Tenant-scoped admin DTO and aggregate read models
affects:
  - phase-97-plan-03-optional-package-auth-surfaces
  - phase-97-plan-07-recovery-scope-matrix
tech-stack:
  added: []
  patterns:
    - Resolve one tenant before every lifecycle query or mutation
    - Treat tenant identity as a row predicate, never storage routing
key-files:
  created:
    - .planning/phases/97-tenant-identity-compatible-upgrade/97-02-SUMMARY.md
  modified:
    - lib/chimeway.ex
    - lib/chimeway/inbox.ex
    - lib/chimeway/admin.ex
    - test/chimeway/tenant_scope_contract_test.exs
    - test/chimeway/inbox_query_test.exs
    - test/chimeway/inbox_state_transition_test.exs
    - test/chimeway/admin_test.exs
key-decisions:
  - "[97-02]: Inbox keyword options carry tenant_id and optional at, while DateTime third arguments remain compatibility-only."
  - "[97-02]: Inbox first-transition signals use the tenant_id from the scoped notification mutation predicate."
  - "[97-02]: Admin read models predicate on the owning Event, Notification, or Delivery row and fail closed without scope."
metrics:
  duration: 3 min
  completed: 2026-08-12
status: complete
---

# Phase 97 Plan 02: Core Tenant-Scoped Inbox and Admin Summary

Inbox lifecycle operations and admin read models now require a resolved tenant and preserve absence-safe outcomes across tenants.

## Tasks Completed

1. Scoped inbox recipient reads, counts, atomic transitions, reloads, and direct-tenant lifecycle signals.
2. Replaced permissive admin tenant filters with required owning-row predicates.

## Verification

- `mix format --check-formatted lib/chimeway.ex lib/chimeway/tenant_scope.ex lib/chimeway/inbox.ex lib/chimeway/admin.ex test/chimeway/tenant_scope_contract_test.exs test/chimeway/inbox_query_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/admin_test.exs`
- `mix test test/chimeway/tenant_scope_contract_test.exs test/chimeway/inbox_query_test.exs test/chimeway/inbox_state_transition_test.exs test/chimeway/admin_test.exs --warnings-as-errors` — 24 tests, 0 failures.

## Decisions Made

- Explicit tenant keyword options authorize inbox transitions; legacy DateTime forms resolve only configured single-tenant compatibility.
- Signal emission receives the tenant already bound by the notification mutation, avoiding workflow and delivery ownership recovery.
- Admin collection and aggregate reads fail closed before query construction when tenant scope is unavailable.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Updated stale test fixtures for required tenant identity**
   - **Found during:** Task 1 and Task 2
   - **Issue:** Pre-Phase-97 fixtures created Events and Notifications without required tenant IDs.
   - **Fix:** Made fixtures tenant-owned and updated obsolete no-tenant assumptions to explicit compatibility/fail-closed assertions.
   - **Files modified:** inbox and admin contract test suites.
   - **Verification:** Focused inbox, tenant-scope, and admin suites pass.

**Total deviations:** 1 auto-fixed. **Impact:** Test fixtures now reflect the persisted tenant contract introduced by Plan 97-01.

## Self-Check: PASSED

- All seven declared implementation/test files exist.
- Task commits `74d50d4`, `4f35c8a`, `a2e0cab`, and `abe7f4b` exist in git history.
