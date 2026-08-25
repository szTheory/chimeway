---
phase: 101-crosswake-registration-protected-open
reviewed: 2026-08-25T18:48:01Z
depth: standard
files_reviewed: 43
files_reviewed_list:
  - /Users/jon/projects/crosswake/examples/phoenix_host/README.md
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/metadata_sanitizer.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_registration_adapter.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260824210000_upgrade_chimeway_registration_authority.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260825180000_enforce_chimeway_binding_scope_consistency.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/notification_open_intent_test.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/notification_registration_adapter_test.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_notification_open_test.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs
  - /Users/jon/projects/crosswake/lib/crosswake/manifest/types.ex
  - /Users/jon/projects/crosswake/lib/crosswake/manifest/validator.ex
  - /Users/jon/projects/crosswake/lib/crosswake/policy/route.ex
  - /Users/jon/projects/crosswake/lib/crosswake/policy/schema.ex
  - /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/ActivationCoordinator.swift
  - /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/CrosswakeDelegates.swift
  - /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/CrosswakeShellConfig.swift
  - /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenDelegate.swift
  - /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift
  - /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationRegistrationCoordinator.swift
  - /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/NotificationOpenQueueTests.swift
  - /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/NotificationRegistrationTests.swift
  - /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/ProtectedNotificationActivationTests.swift
  - /Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex
  - /Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/denial_codes.ex
  - /Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/redaction.ex
  - /Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex
  - /Users/jon/projects/crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/telemetry.ex
  - /Users/jon/projects/crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/denial_codes_test.exs
  - /Users/jon/projects/crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/redaction_test.exs
  - /Users/jon/projects/crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/resolver_test.exs
  - /Users/jon/projects/crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/telemetry_test.exs
  - /Users/jon/projects/crosswake/packages/crosswake_chimeway/test/crosswake/proof/phase71_notification_workflow_proof_test.exs
  - /Users/jon/projects/crosswake/test/crosswake/manifest/builder_test.exs
  - /Users/jon/projects/crosswake/test/crosswake/manifest/validator_test.exs
  - /Users/jon/projects/crosswake/test/crosswake/policy/schema_test.exs
  - /Users/jon/projects/crosswake/test/crosswake/proof/phase60_chimeway_registry_test.exs
  - /Users/jon/projects/crosswake/test/fixtures/chimeway_notification_permission_loss_v1.json
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 101: Code Review Report

**Reviewed:** 2026-08-25T18:48:01Z
**Depth:** standard
**Files Reviewed:** 43
**Status:** issues_found

## Summary

Reviewed the registration lifecycle, protected-open resolver, iOS queue/coordinator, manifest policy validation, and the two latest closures. Exact-empty caller metadata persistence and the fail-closed matching predicate are correctly applied in the direct paths reviewed. The forward reconciliation nevertheless changes durable intent state without recording the required lifecycle evidence, making legacy denials unexplainable after the migration.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Reconciled intent revocations have no durable denial event

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260825190000_backfill_chimeway_notification_open_intent_scope.exs:63`
**Issue:** The second `UPDATE` changes every unreconcilable issued intent to `revoked`, but writes nothing to `chimeway_notification_open_intent_events`. Normal issuance and consumption use that append-only table (Registry lines 1302-1312 and 1372-1380). Consequently, an operator examining a legacy intent sees an issued event followed by a revoked current row with no timestamped reason or indication that the migration deliberately fail-closed it. This violates the project’s explainable notification lifecycle and prevents distinguishing a reconciliation denial from an ordinary revocation.
**Fix:** In the same migration transaction, insert one sanitized event for every row selected by the terminal predicate (for example `event_type: "reconciled_revoked"`, `occurred_at: CURRENT_TIMESTAMP`, and empty/static details), then perform the state update. Reuse the identical `NOT EXISTS` authority predicate in both statements, and add an upgrade assertion that each forced-revoked intent has exactly one reconciliation event.

---

_Reviewed: 2026-08-25T18:48:01Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
