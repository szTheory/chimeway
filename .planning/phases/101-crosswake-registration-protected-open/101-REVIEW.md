---
phase: 101-crosswake-registration-protected-open
reviewed: 2026-08-25T00:00:00Z
depth: standard
files_reviewed: 42
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

**Reviewed:** 2026-08-25T00:00:00Z
**Depth:** standard
**Files Reviewed:** 42
**Status:** issues_found

## Summary

The protected-open CAS itself is appropriately scoped, but the durable metadata boundary is fail-open and the binding model permits an installation-scoped row to acquire session authority. Both defects contradict the phase's privacy and narrow-revocation guarantees.

## Critical Issues

### CR-01: Metadata sanitization persists unrecognised sensitive fields

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/metadata_sanitizer.ex:10-59`
**Issue:** The sanitizer is a small exact-name blocklist, not an allowlist. It persists every unknown key and recursively preserves unknown nested keys. Common alternate forms such as `deviceToken`, `apnsToken`, `authorization`, `phone_number`, `user_email`, or an opaque provider payload key are therefore written into `TokenBinding` and notification-intent metadata. This violates the stated raw-token/PII persistence boundary and is particularly unsafe because input maps can originate at bridge/provider seams.
**Fix:** Replace the blocklist with a narrow, documented allowlist of scalar diagnostic fields (as `Redaction.safe_metadata/1` does), reject all other keys and non-scalar/nested values, and add regression cases for camelCase token fields and arbitrary PII-shaped keys.

### CR-02: Installation-scoped bindings can be revoked by a session logout

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex:153-167`
**Issue:** `:subject_installation` has no invariant that `session_ref` and `session_version` are nil. `Registry.bind_or_rotate/3` forwards both fields from its otherwise permissive context, so it can create an installation-scoped binding with a session ref. `revoke_for_logout/2` then filters only `subject_ref`, `org_ref`, `session_ref`, and `state` ([registry.ex](/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex:550)), and revokes that installation binding. A session-only logout can consequently revoke a longer-lived installation authority.
**Fix:** Reject any session fields for `:subject_installation` in the changeset and enforce the same rule with a database check constraint. Also add `b.subject_scope == :subject_session` to the logout query as defense in depth, plus a regression test that attempts to bind an installation scope with a session ref.

## Warnings

### WR-01: Permission-loss state is unsynchronised across callback queues

**File:** `/Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationRegistrationCoordinator.swift:85-133`
**Issue:** This mutable coordinator is neither `@MainActor` nor an actor, yet APNs/permission callbacks can arrive on different queues. Concurrent `recheckPermissionState()` calls can both observe `permissionLossDelivered == false` and send duplicate revocation commands; concurrent token observations can also overwrite `retainedBinding` and state out of order. The backend makes the duplicate safe, but the shell's claimed one-shot lifecycle and diagnostics are not reliable.
**Fix:** Isolate the coordinator to `@MainActor` (and ensure delegate calls are made from that actor), or make it an actor with an explicit serialized delegate boundary. Add a concurrent recheck/observe test that proves only the latest command is sent once.

---

_Reviewed: 2026-08-25T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
