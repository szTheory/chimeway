---
phase: 101-crosswake-registration-protected-open
reviewed: 2026-08-25T19:23:45Z
depth: standard
files_reviewed: 44
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
  critical: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 101: Code Review Report

**Reviewed:** 2026-08-25T19:23:45Z
**Depth:** standard
**Files Reviewed:** 44
**Status:** issues_found

## Summary

The protected-open CAS path, closed action-policy validation, metadata stripping, and focused Phoenix/iOS tests were reviewed. Two lifecycle failures remain: a delayed logout can revoke a newer session-version binding, and notification-open audit history is cascade-deleted. The focused Phoenix migration/open suite and iOS notification suites pass, but neither exercises those failure modes.

## Critical Issues

### CR-01: Logout revocation ignores the authenticated session version

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex:539-545`
**Issue:** `validate_context/1` requires a non-negative `session_version` for `:subject_session`, but the logout selector uses only `subject_ref`, `org_ref`, and `session_ref`. A delayed logout for session version 1 therefore selects and revokes an active replacement binding for version 2 with the same session reference. This violates the version-guarded authority contract and suppresses notifications for the current session.
**Fix:** Include the exact authenticated version in both the initial read and conditional update predicates, and add a regression where a stale logout leaves a newer-version binding active.

```elixir
where:
  b.subject_ref == ^ctx.subject_ref and
    b.org_ref == ^ctx.org_ref and
    b.session_ref == ^session_ref and
    b.session_version == ^ctx.session_version and
    b.subject_scope == :subject_session and
    b.state == :active
```

### CR-02: Notification-open lifecycle evidence can be destroyed by parent deletion

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs:23`
**Issue:** The append-only `chimeway_notification_open_intent_events` foreign key specifies `on_delete: :delete_all`. Deleting an intent destroys issued, consumed, and `reconciliation_revoked` evidence, defeating the phase's explainability guarantee and creating a durable audit-data-loss path.
**Fix:** Do not cascade-delete lifecycle events. Prefer no foreign key for this append-only audit relation (matching the token-binding event posture), or use a restrictive foreign key and prohibit intent deletion. Add a migration-level assertion that deleting an intent cannot erase its events.

```elixir
add :open_intent_id, :binary_id, null: false
# Keep the opaque relation without an on-delete cascade.
```

## Warnings

### WR-01: Terminal-denial coverage omits one declared denial case

**File:** `/Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/ProtectedNotificationActivationTests.swift:8-19`
**Issue:** The test claims every protected denial is terminal but excludes `NotificationOpenDenial.routeActionRemoved`. A future implementation can accidentally give that case fallback/activation behavior while the exhaustive-contract test still passes.
**Fix:** Include `.routeActionRemoved` in `denials` (or derive the test cases from an explicit complete-case list) and assert empty actions for it.

---

_Reviewed: 2026-08-25T19:23:45Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
