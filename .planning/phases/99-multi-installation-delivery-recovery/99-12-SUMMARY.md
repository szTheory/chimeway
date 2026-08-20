---
phase: 99-multi-installation-delivery-recovery
plan: "12"
subsystem: delivery-lifecycle
tags: [elixir, ecto, postgres, migrations, installer, tenant-integrity]
requires:
  - phase: 99-multi-installation-delivery-recovery
    provides: durable target attempts and static storage migration generation
provides:
  - Locked operation-specific target lifecycle authorization
  - Composite PostgreSQL tenant ownership and same-target attempt lineage
  - Repository, public, and prefixed installer parity for migration 036
affects: [push-delivery, recovery, installer, tenant-safety]
tech-stack:
  added: []
  patterns:
    - Operation-specific source-state predicates are part of locked lifecycle queries.
    - Composite foreign keys use fixed, quoted migration SQL backed by named unique indexes.
key-files:
  created:
    - priv/repo/migrations/20260820000000_enforce_delivery_target_tenant_integrity.exs
    - priv/chimeway_migrations/036_enforce_delivery_target_tenant_integrity.exs
  modified:
    - lib/chimeway/delivery_targets.ex
    - test/chimeway/migration_contract_test.exs
    - test/chimeway/install/golden_diff_test.exs
key-decisions:
  - "[99-12]: Ordinary retry is authorized only from failed; expiry and invalidation only from pending."
  - "[99-12]: Tenant ownership and prior-attempt lineage are enforced by named composite PostgreSQL foreign keys in repository and copied migrations."
requirements-completed: [PUSH-01, PUSH-02, PUSH-03, PUSH-04, RECOV-01, RECOV-02]
coverage:
  - id: D1
    description: Locked target lifecycle transitions cannot reauthorize an accepted target.
    requirement: PUSH-03
    verification:
      - kind: unit
        ref: test/chimeway/delivery_target_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: Repository and generated migrations reject malformed tenant ownership and prior-attempt lineage.
    requirement: PUSH-02
    verification:
      - kind: integration
        ref: test/chimeway/migration_contract_test.exs
        status: pass
    human_judgment: false
  - id: D3
    description: Installer golden fixtures render migration 036 identically across supported static storage modes.
    requirement: RECOV-02
    verification:
      - kind: integration
        ref: test/chimeway/install/golden_diff_test.exs
        status: pass
    human_judgment: false
duration: 14min
completed: 2026-08-20
status: complete
---

# Phase 99 Plan 12: Delivery Tenant-Integrity Recovery Summary

**Target lifecycle mutation is now source-state locked, while migration 036 structurally prevents cross-tenant delivery history and cross-target predecessor links.**

## Performance

- **Duration:** 14 min
- **Tasks:** 3
- **Files modified:** 12

## Accomplishments

- Restricted ordinary retry to failed targets and expiry/invalidation to pending targets before the row mutation lock.
- Added named composite tenant/id indexes and ownership/lineage foreign keys with intentional referential delete behavior.
- Rendered and tested migration 036 in repository, legacy public, and dedicated Chimeway schema installer modes.

## Task Commits

1. **Task 1: Lock lifecycle authorization to operation-specific source states** - `fd26c5d`, `60b3757`
2. **Task 2: Add the forward composite tenant-integrity repair** - `063c39a`, `b1d3303`
3. **Task 3: Preserve installer and static-storage parity for migration 036** - `5c466f0`

## Decisions Made

- Ordinary public retry cannot reopen provider acceptance or ambiguous handoff evidence; linked policy-authorized redrive remains separate.
- Both ownership constraints cascade only when their owning parent is removed; same-target predecessor lineage keeps PostgreSQL's default non-cascading delete action.

## Verification

- PASS: focused lifecycle and target-worker tests (21 tests).
- PASS: serial repository and generated migration contract tests (14 tests).
- PASS: prefix contract test (7 tests) and golden fixtures refreshed using the installer acceptance command.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Critical parity] Updated installer idempotency expectations from 35 to 36 templates.**
- **Found during:** Task 3
- **Issue:** The existing installer idempotency proof still assumed the pre-migration-036 template count.
- **Fix:** Updated its deterministic counts with the installer catalog changes.
- **Files modified:** `test/chimeway/install/idempotency_test.exs`
- **Committed in:** `5c466f0`

**Total deviations:** 1 auto-fixed (Rule 2).

## Known Stubs

None.

## Self-Check: PASSED

- Migration 036 exists in repository, template, and both committed golden trees.
- All five task commits are present in git history.
- No tracked file deletions were introduced.
