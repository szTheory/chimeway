---
phase: 101-crosswake-registration-protected-open
plan: "10"
subsystem: crosswake-example-host-registration-authority
tags: [elixir, ecto, sqlite, migrations, concurrency, privacy]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: authenticated APNs binding and protected-open host contracts
provides:
  - Additive forward authority migration from released CrossWake host schemas
  - Fail-closed legacy intent and binding reconciliation with posture-independent active identity
  - Bounded named-constraint retry for concurrent binding observations
affects: [101-crosswake-registration-protected-open, 102-crosswake-digital-twin]
tech-stack:
  added: []
  patterns:
    - Released Ecto migrations remain immutable; forward migrations reconcile durable rows
    - Named active-identity conflicts retry the complete authoritative registry operation
key-files:
  created:
    - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260824210000_upgrade_chimeway_registration_authority.exs
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs
    - .planning/phases/101-crosswake-registration-protected-open/101-10-SUMMARY.md
  modified:
    - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs
    - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs
key-decisions:
  - "[101-10]: Historical migrations are restored byte-for-byte to their released definitions; all authority repair is additive in the 20260824210000 migration."
  - "[101-10]: app_identity_posture is mutable evidence only; app_identity_ref defines active token and authenticated authority identity."
  - "[101-10]: Only the three named active-identity constraints trigger a bounded whole-operation bind retry."
metrics:
  duration: 15 min
  completed: 2026-08-24
  tasks_completed: 2
  files_modified: 8
status: complete
---

# Phase 101 Plan 10: Forward Registration Authority Upgrade Summary

**Existing Phoenix hosts now migrate forward to fail-closed registration authority while concurrent posture observations converge on one active binding.**

## Completed Work

- Restored the two released migrations exactly and added a forward SQLite authority migration that backfills intent scope only from its exact binding, closes unmatched intents, invalidates untrusted legacy app identities, deterministically supersedes duplicate active rows, and installs posture-independent indexes.
- Added a throwaway-database upgrade proof from the released migration boundary, including legacy bad-deployment collision reconciliation and fresh full migration coverage.
- Aligned all `TokenBinding` named unique-constraint lists with the forward indexes and added a bounded retry/reload path exclusively for named active-identity conflicts.
- Added a barrier-synchronized differing-posture registry race proof that asserts both callers succeed with one binding reference and one active row.

## Verification

- `cd /Users/jon/projects/crosswake/examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs test/crosswake_example/chimeway/registry_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs --seed 0` — 16 tests, 0 failures.
- Exact released-blob comparisons for both historical migrations — passed.
- `git -C /Users/jon/projects/crosswake diff --check` — passed.

## TDD Gate Compliance

- RED: `cf7c52e4` added the upgrade proof, which failed against the rewritten historical binding migration.
- GREEN: `af356b80` restored released migrations and added the additive forward repair.
- Note: the initial differing-posture behavioral race already passed through the existing SQLite busy retry. `e80dc9bc` adds the distinct named-constraint retry required for non-SQLite conflict results and aligns changeset metadata with the repaired database identity.

## Deviations from Plan

None - plan executed as specified. The Task 2 behavioral proof exposed existing SQLite convergence before the registry metadata/retry hardening; the planned named-conflict path was still implemented for actual constraint races.

## Known Stubs

None.

## Self-Check: PASSED

- CrossWake task commits `cf7c52e4`, `af356b80`, and `e80dc9bc` exist.
- The forward migration, upgrade proof, and registry race proof exist at their documented paths.
