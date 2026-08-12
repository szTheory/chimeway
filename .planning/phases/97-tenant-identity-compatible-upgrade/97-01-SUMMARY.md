---
phase: 97-tenant-identity-compatible-upgrade
plan: 01
subsystem: durable-lifecycle-tenancy
tags: [elixir, ecto, postgresql, tenant-identity, idempotency]
requires:
  - phase: 97-tenant-identity-compatible-upgrade
    provides: locked D-01/D-02/D-08 tenant identity contract
provides:
  - Immutable event and notification tenant ownership
  - Tenant-scoped event idempotency and duplicate recovery
  - Fail-closed tenant resolution and tenant-scoped trace reads
affects:
  - phase-97-lifecycle-scope-expansion
  - phase-97-legacy-reconciliation
tech-stack:
  added: []
  patterns:
    - Tenant identity is a row predicate, never a dynamic storage prefix
    - Public trace reads resolve one concrete tenant before querying
key-files:
  created:
    - lib/chimeway/tenant_scope.ex
    - priv/repo/migrations/20260812000000_add_tenant_identity_to_events_and_notifications.exs
    - priv/chimeway_migrations/032_add_tenant_identity_to_events_and_notifications.exs
    - test/chimeway/tenant_identity_test.exs
    - test/chimeway/tenant_scope_contract_test.exs
  modified:
    - lib/chimeway/events/event.ex
    - lib/chimeway/notifications/notification.ex
    - lib/chimeway/trigger.ex
    - lib/chimeway/traces.ex
    - test/chimeway/traces_test.exs
    - test/support/data_case.ex
key-decisions:
  - "[97-01] Tenant ownership is persisted on new event and notification rows and remains immutable through changeset updates."
  - "[97-01] Idempotency is recovered only by the composite tenant_id and idempotency_key identity."
  - "[97-01] Trace APIs fail closed without explicit or concretely configured compatibility scope, preserving existing absent-row shapes."
duration: 24 min
completed: 2026-08-12
status: complete
---

# Phase 97 Plan 01: Tenant Identity Persistence and Trace Slice Summary

**Tenant-owned events and notifications now use composite idempotency and fail-closed trace access without changing Chimeway's static storage-prefix contract.**

## Accomplishments

- Added nullable additive tenant columns with no legacy-row backfill, replacing global event idempotency with `chimeway_events_tenant_id_idempotency_key_index` in both migration trees.
- Persisted the validated trigger tenant into the event and every notification row; changesets exclude tenant ownership from update casts.
- Added `Chimeway.TenantScope` for trimmed explicit scope or an explicit single-tenant compatibility configuration.
- Scoped every public trace root and nested lifecycle preload to the resolved tenant, returning established not-found or empty outcomes when scope is absent or mismatched.
- Added focused persistence, immutable ownership, compatibility, nested-scope, and sandbox-concurrency contracts.

## Task Commits

1. **Task 1 RED: Tenant identity contract** — `3d60f12` (`test`)
2. **Task 1 GREEN: Persist tenant-owned trigger lifecycle** — `bd3049c` (`feat`)
3. **Task 2 RED: Nested tenant trace contract** — `23a66d9` (`test`)
4. **Task 2 GREEN: Enforce tenant scope across trace queries** — `08a889b` (`feat`)

## Verification

- PASS: `mix format --check-formatted` for all plan-owned production and test files.
- PASS: `mix test test/chimeway/tenant_identity_test.exs test/chimeway/tenant_scope_contract_test.exs test/chimeway/traces_test.exs test/chimeway/trigger_pipeline_test.exs --warnings-as-errors` — 64 tests, 0 failures.
- PASS: Test migration applied successfully with `MIX_ENV=test mix ecto.migrate`.

## TDD Gate Compliance

- RED commits `3d60f12` and `23a66d9` preceded the corresponding production changes.
- GREEN commits `bd3049c` and `08a889b` passed their focused behavioral tests.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Test infrastructure] Exposed SQL sandbox owner to concurrency tests**
- **Found during:** Task 2
- **Issue:** Concurrent trigger tasks need the sandbox owner PID to obtain database access safely.
- **Fix:** `Chimeway.DataCase` now returns `sandbox_owner`, allowing the tenant identity contract to authorize spawned task processes explicitly.
- **Files modified:** `test/support/data_case.ex`, `test/chimeway/tenant_identity_test.exs`
- **Commit:** `08a889b`

**2. [Rule 2 - Regression coverage] Updated legacy trace fixture to declare one configured compatibility tenant**
- **Found during:** Task 2
- **Issue:** Existing trace fixtures exercised unscoped reads and rows, contradicting the new fail-closed public contract.
- **Fix:** The fixture explicitly configures and persists the concrete `default` compatibility tenant while focused contracts cover fail-closed paths.
- **Files modified:** `test/chimeway/traces_test.exs`
- **Commit:** `08a889b`

**Total deviations:** 2 auto-fixed. **Impact:** No production-surface expansion; changes make required concurrency and compatibility evidence executable.

## Known Stubs

None.

## Self-Check: PASSED

- Found all created migration, scope, and test files.
- Found task commits `3d60f12`, `bd3049c`, `23a66d9`, and `08a889b` in git history.
- No plan-owned stubs, TODOs, or placeholder runtime paths found.
