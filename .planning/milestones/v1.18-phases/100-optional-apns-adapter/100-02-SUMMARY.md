---
phase: 100-optional-apns-adapter
plan: 02
subsystem: installer-migrations
tags: [elixir, ecto, postgres, migrations, apns]
requires:
  - phase: 100-optional-apns-adapter
    provides: safe APNs request-intent delivery target field and repository migration
provides:
  - Prefix-aware copied migration 037 for nullable APNs request intent
  - Public and prefixed golden migration parity
  - Three-mode migration rollback and generated-runtime persistence proof
affects: [100-03, installer, delivery-targets]
tech-stack:
  added: []
  patterns:
    - Prefix-aware additive copied migration with a column-only down path
    - Repository and generated-fixture migration parity exercised through up/down/up
key-files:
  created:
    - priv/chimeway_migrations/037_add_apns_request_intent.exs
    - test/fixtures/installer_golden_public/tree/priv/repo/migrations/TIMESTAMP_add_apns_request_intent.exs
    - test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations/TIMESTAMP_add_apns_request_intent.exs
  modified:
    - test/chimeway/migration_contract_test.exs
    - test/chimeway/generated_prefixed_runtime_proof_test.exs
decisions:
  - "[100-02]: APNs intent is a nullable map added only to existing delivery targets; copied migration rollback removes only that column."
metrics:
  duration: 18 min
  completed: 2026-08-20
status: complete
---

# Phase 100 Plan 02: APNs Copied Migration Parity Summary

**Migration 037 now adds one nullable, prefix-aware APNs request-intent map across repository, public, and prefixed installation paths, with executable rollback preservation proof.**

## Accomplishments

- Published canonical migration 037 and structurally equivalent public/prefixed golden copies; all installer modes now render 37 migrations.
- Added explicit installer and golden contracts rejecting token, credential, payload, and provider-body migration storage.
- Proved repository, generated public, and generated prefixed `036 → 037 → 036 → 037` paths retain target/attempt history and tenant constraints.
- Added generated-prefixed runtime evidence that `Chimeway.Repo` persists and reloads safe APNs intent only in the configured schema.

## Verification

- PASS: `scripts/test-db env CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs test/chimeway/install/golden_diff_test.exs --warnings-as-errors`
- PASS: `scripts/test-db env CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs test/chimeway/generated_prefixed_runtime_proof_test.exs --warnings-as-errors` (26 tests)
- PASS: `scripts/test-db env CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix verify.install_golden`

## Task Commits

1. Task 1 — `3630020` test RED, `df95a78` migration implementation.
2. Task 2 — `85c7954` migration and generated-runtime proof.
3. Directly related verification fix — `fd81619` installer idempotency count.

## Decisions Made

- The copied migration alters only `:chimeway_delivery_targets` and removes only `:apns_request_intent` on rollback.
- Safe intent remains a map/jsonb field; no APNs token, credential, payload, or response-body column is introduced.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Bug] Updated generated target migration rollback expectations after migration 037 became the latest generated migration.
- Found during: Task 2 verification.
- Fix: Roll back 037 before asserting the existing 036 rollback behavior.
- Files modified: `test/chimeway/migration_contract_test.exs`.
- Commit: `85c7954`.

2. [Rule 2 - Missing critical functionality] Updated installer idempotency counts for the new migration.
- Found during: `mix verify.install_golden`.
- Fix: Assert the 37-file installer tree and unchanged output count.
- Files modified: `test/chimeway/install/idempotency_test.exs`.
- Commit: `fd81619`.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed migration 037 exists in canonical, public golden, and prefixed golden paths.
- Confirmed task commits `3630020`, `df95a78`, `85c7954`, and `fd81619` exist.

