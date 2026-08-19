---
phase: 99-multi-installation-delivery-recovery
plan: "02"
subsystem: installer
tags: [elixir, ecto, postgres, migrations, prefix, delivery-targets]
requires:
  - phase: 99-multi-installation-delivery-recovery
    provides: canonical delivery-target migration 035 and durable target schemas
provides:
  - Exact public and prefixed installer contracts for delivery target migration 035
  - Executable dual-mode PostgreSQL proof for target identity and ordered target attempts
  - Runtime-prefix fixture readiness for normal target planning writes
affects: [phase-99-recovery, phase-100-apns, installer]
tech-stack:
  added: []
  patterns:
    - Generated migration parity is locked through exact golden-source assertions and real dual-mode execution.
    - Runtime prefix fixtures include every target relation before testing ordinary Repo-default writes.
key-files:
  created:
    - .planning/phases/99-multi-installation-delivery-recovery/99-02-SUMMARY.md
  modified:
    - test/chimeway/install/golden_diff_test.exs
    - test/chimeway/install/prefix_contract_test.exs
    - test/chimeway/migration_contract_test.exs
    - test/chimeway/runtime_prefix_integration_test.exs
    - test/support/prefixed_runtime_case.ex
key-decisions:
  - "[99-02]: Target identity and attempt ordering are enforced at the generated PostgreSQL boundary in both static storage modes."
  - "[99-02]: Runtime target planning uses configured Repo storage only; the fixture never derives its schema from tenant or binding identity."
patterns-established:
  - "Installer exact-tree contracts assert migration-specific tables, helper-qualified references, and unique constraints in both public and prefixed output."
  - "Prefix fixture readiness must enumerate newly introduced Chimeway relations to prevent stale cloned schemas."
requirements-completed: [PUSH-02, PUSH-03]
coverage:
  - id: D1
    description: Deterministic installer generation preserves the target identity and target-attempt uniqueness contract in public and prefixed copies.
    requirement: PUSH-02
    verification:
      - kind: integration
        ref: mix verify.install_golden
        status: pass
    human_judgment: false
  - id: D2
    description: Generated public and prefixed schemas execute the target constraints and route ordinary planning through configured static storage.
    requirement: PUSH-03
    verification:
      - kind: integration
        ref: mix verify.runtime_prefix
        status: pass
      - kind: integration
        ref: test/chimeway/migration_contract_test.exs#generated target migration enforces identity and ordered attempts
        status: pass
    human_judgment: false
duration: 15 min
completed: 2026-08-19
status: complete
---

# Phase 99 Plan 02: Multi-Installation Delivery Recovery Summary

**Migration 035 now has exact public/prefixed installer parity plus real PostgreSQL uniqueness and static-routing proof for durable delivery targets.**

## Accomplishments

- Locked generated migration 035 output to helper-qualified target tables, references, unique target identity, and ordered target-attempt constraints in both supported static storage modes.
- Executed generated schemas in public and `chimeway` modes, proved duplicate target/attempt inserts fail, and proved rollback removes only target relations while retaining host-owned and earlier Chimeway relations.
- Updated the runtime-prefix fixture’s required relation list so ordinary target planning writes to the configured static schema with no tenant-derived prefix.

## Task Commits

1. **Task 1: Render and execute migration 035 in public and prefixed installs** — `0748cf4` (test).
2. **Task 2: Execute generated schemas and prove ordinary runtime storage routing** — `ac35545` (test).

## Verification

- `env MIX_ENV=test mix test test/chimeway/install/migrations_test.exs test/chimeway/install/golden_diff_test.exs test/chimeway/install/prefix_contract_test.exs --warnings-as-errors` — passed before final contract extensions; the installer alias was subsequently re-run as `mix verify.install_golden`.
- `env MIX_ENV=test mix test test/chimeway/migration_contract_test.exs test/chimeway/generated_prefixed_runtime_proof_test.exs test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors` — passed, 25 tests.
- `mix verify.runtime_prefix` — passed, 18 tests.
- `mix verify.install_golden` — passed after the final exact-source assertions.

## Decisions Made

- The database is the final concurrency boundary: target uniqueness is validated by real generated Postgres schemas instead of only source inspection.
- The prefixed runtime fixture treats target tables as mandatory Chimeway relations, preventing an old cloned schema from falsely passing route tests.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Prefixed runtime fixture readiness omitted the newly introduced target relations.**
- **Found during:** Task 2 verification.
- **Issue:** A stale prefixed clone could report ready without `chimeway_delivery_targets`, causing ordinary target planning to query a missing table.
- **Fix:** Added target and target-attempt tables to the fixture readiness contract.
- **Files modified:** `test/support/prefixed_runtime_case.ex`.
- **Verification:** `mix verify.runtime_prefix` passed.
- **Committed in:** `ac35545`.

**2. [Rule 1 - Bug] Initial target runtime proof supplied a push rendering declaration rather than the established direct planning seam.**
- **Found during:** Task 2 verification.
- **Issue:** Rendering normalization intentionally strips extra channel declaration fields, leaving a test-only invalid push payload before target planning could run.
- **Fix:** Proved the required ordinary planning write directly through `Chimeway.DeliveryTargets.plan_targets/3`, with a tenant-matched opaque binding revision.
- **Files modified:** `test/chimeway/runtime_prefix_integration_test.exs`.
- **Verification:** focused runtime-prefix suite passed.
- **Committed in:** `ac35545`.

### Baseline Integration Repair

Commit `630e881` had already regenerated migration-035 installer fixtures and corrected related count/trace expectations while resolving Wave 1 post-merge compatibility. This plan treated that committed work as its baseline, added missing exact-generation and execution proof, and did not duplicate or revert it.

## Known Stubs

None.

## Next Phase Readiness

Both supported installer storage modes now establish the durable target schema before runtime target work. Phase 99 recovery work can rely on equivalent target identity and ordered-attempt constraints in repository, public-generated, and prefixed-generated installations.

## Self-Check: PASSED

- Required installer, migration-contract, runtime-prefix, and fixture changes exist.
- Task commits `0748cf4` and `ac35545` are present in git history.
