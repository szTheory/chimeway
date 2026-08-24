---
phase: 101-crosswake-registration-protected-open
reviewed: 2026-08-24T21:47:22Z
depth: standard
files_reviewed: 38
files_reviewed_list:
  - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex
  - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_registration_adapter.ex
  - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
  - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex
  - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs
  - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs
  - ../crosswake/examples/phoenix_host/priv/repo/migrations/20260824210000_upgrade_chimeway_registration_authority.exs
  - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/notification_registration_adapter_test.exs
  - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registration_authority_migration_upgrade_test.exs
  - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_notification_open_test.exs
  - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs
  - ../crosswake/lib/crosswake/manifest/types.ex
  - ../crosswake/lib/crosswake/manifest/validator.ex
  - ../crosswake/lib/crosswake/policy/route.ex
  - ../crosswake/lib/crosswake/policy/schema.ex
  - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/ActivationCoordinator.swift
  - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/CrosswakeDelegates.swift
  - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/CrosswakeShellConfig.swift
  - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenDelegate.swift
  - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift
  - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationRegistrationCoordinator.swift
  - ../crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/NotificationOpenQueueTests.swift
  - ../crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/NotificationRegistrationTests.swift
  - ../crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/ProtectedNotificationActivationTests.swift
  - ../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex
  - ../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/denial_codes.ex
  - ../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/redaction.ex
  - ../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex
  - ../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/telemetry.ex
  - ../crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/denial_codes_test.exs
  - ../crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/redaction_test.exs
  - ../crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/resolver_test.exs
  - ../crosswake/packages/crosswake_chimeway/test/crosswake/companions/chimeway/telemetry_test.exs
  - ../crosswake/packages/crosswake_chimeway/test/crosswake/proof/phase71_notification_workflow_proof_test.exs
  - ../crosswake/test/crosswake/manifest/builder_test.exs
  - ../crosswake/test/crosswake/manifest/validator_test.exs
  - ../crosswake/test/crosswake/policy/schema_test.exs
  - ../crosswake/test/fixtures/chimeway_notification_permission_loss_v1.json
findings:
  critical: 3
  warning: 0
  info: 0
  total: 3
status: issues_found
---

# Phase 101: Code Review Report

**Reviewed:** 2026-08-24T21:47:22Z
**Depth:** standard
**Files Reviewed:** 38
**Status:** issues_found

## Summary

The policy normalization and consume-first resolver paths are materially fail-closed, but three defects remain in lifecycle scope, migration compatibility, and replay handling. Each can violate a Phase 101 protected-open or binding-lifecycle requirement despite the focused test suites passing.

## Critical Issues

### CR-01: Provider invalidation can revoke bindings outside the feedback authority scope

**File:** `../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex:929-950`
**Issue:** Invalidating provider feedback selects every active row matching only token fingerprint (or token ref), provider, platform, and environment. It omits the durable app identity, tenant, subject, installation, session, and binding revision. The subsequent update only guards by the selected binding refs and `:active` state (lines 981-983), so one feedback event can disable another tenant/installation/session's active binding when token evidence is shared or collides across scopes. This directly violates exact-revision invalidation and can suppress delivery for an unrelated authority.
**Fix:** Make invalidating feedback carry and validate an opaque exact `binding_ref` plus the authenticated scope (at least app identity, tenant, installation, subject, and session/version), and include all of them in both the initial query and conditional update. Fail closed when that scope is unavailable; do not select by fingerprint alone.

### CR-02: The forward migration does not reconcile the new token-identity uniqueness domain

**File:** `../crosswake/examples/phoenix_host/priv/repo/migrations/20260824210000_upgrade_chimeway_registration_authority.exs:86-116`
**Issue:** `reconcile_active_collisions/0` only supersedes duplicate active rows in the subject/session/installation authority partition. It never reconciles rows that collide in the newly created `chimeway_token_bindings_active_token_identity_index` at lines 106-108. Pre-upgrade data can validly contain two active rows with the same fingerprint/provider/platform/environment/app identity but different old `app_identity_posture` values (the released index keyed on posture), or with different authority partitions. After dropping the old indexes, creating the new token-identity index fails, leaving production databases unable to migrate.
**Fix:** Before replacing indexes, deterministically reconcile *both* new uniqueness domains. Add a second ranked update partitioned by `token_fingerprint, provider, platform, environment, app_identity_ref`, retaining one current row and superseding the rest, then add an upgrade test that seeds this old-valid/new-conflicting posture case and asserts `Ecto.Migrator.run(..., all: true)` succeeds.

### CR-03: Duplicate queued evidence overwrites a successful protected open with replay denial

**File:** `../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift:100-108`
**Issue:** The queue permits multiple entries with the same `openRef` and drains each one. For a duplicate offline tap, the first item can be allowed and activate; the second is necessarily replayed. The production drain passes that replay outcome to `ActivationCoordinator.handleProtectedNotificationOutcome`, which sets a terminal denial presentation (ActivationCoordinator.swift:399-413). Consequently, a valid one-time open is immediately replaced by an error screen solely because the same opaque evidence was queued twice.
**Fix:** Deduplicate queue entries by `openRef` (preferably replace/update the pending item during `enqueue`) or suppress duplicate evidence during a drain. Add a test that enqueues the same evidence twice and asserts exactly one delegate consume/activation and that the final presentation remains the allowed route.

---

_Reviewed: 2026-08-24T21:47:22Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
