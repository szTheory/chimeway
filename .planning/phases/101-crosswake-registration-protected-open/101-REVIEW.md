---
phase: 101-crosswake-registration-protected-open
reviewed: 2026-08-24T20:41:28Z
depth: standard
files_reviewed: 36
files_reviewed_list:
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_registration_adapter.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/test/crosswake_example/chimeway/notification_registration_adapter_test.exs
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
  - /Users/jon/projects/crosswake/test/fixtures/chimeway_notification_permission_loss_v1.json
findings:
  critical: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 101: Code Review Report

**Reviewed:** 2026-08-24T20:41:28Z
**Depth:** standard
**Files Reviewed:** 36
**Status:** issues_found

## Summary

The protected-open resolver correctly treats server-resolved route/action data as authoritative, and the selected host, companion, and Swift test suites pass. However, the phase rewrites already-versioned database migrations rather than supplying an upgrade migration, and the iOS permission-loss state machine permanently suppresses retries after a rejected revoke. Both leave existing users in an unsafe or broken lifecycle state. The binding uniqueness predicates also still permit a transient concurrent duplicate authority scope when app-identity posture differs.

## Critical Issues

### CR-01: Previously applied migrations are rewritten without a forward upgrade

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs:17`

**Issue:** This phase adds the required `app_identity_ref` column and changes all three identity indexes by editing migration `20260602100000`; it likewise adds tenant/session authority columns by editing migration `20260603000000` at lines 9-12. Ecto records a migration version, not its current contents. Any host that ran these migrations before this phase will retain the old table/index definitions, then the new registry queries will fail on missing columns or retain the weaker uniqueness rules. Fresh test databases conceal the production upgrade failure.

**Fix:** Restore the historical migration files exactly as released and add a new, later migration that adds/backfills the authority columns, builds replacement indexes, and only then applies `NOT NULL` constraints. Include an upgrade-path integration test starting from the pre-phase schema.

### CR-02: A rejected permission-loss revoke is marked delivered and can never be retried

**File:** `/Users/jon/projects/crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationRegistrationCoordinator.swift:121-124`

**Issue:** `recheckPermissionState()` sets `permissionLossDelivered = true` before invoking the host delegate. If the host rejects the command because it is temporarily unavailable or fails its request, the method returns `.rejected` but all later denied-state checks return `.permissionDeniedNoop`. The active server binding is therefore never revoked after notification permission was withdrawn, which violates the required fail-closed permission-loss lifecycle.

**Fix:** Mark the command delivered only for terminal host acknowledgements (`.revoked` and `.staleNoop`); retain it and allow another call after `.rejected`. Add a test whose delegate returns `.rejected` once and `.revoked` on the next permission recheck.

## Warnings

### WR-01: Active-binding uniqueness can split one authority scope by posture during a concurrent bind

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs:54-105`

**Issue:** Every active uniqueness index includes `app_identity_posture`, while the registry's lookup at `registry.ex:205-219` deliberately does not. Two concurrent binds of the same token/subject/session/install/topic that observe different postures (for example `:unknown` and `:matched`) can both miss the row before either commits; the database permits both because the posture differs. Subsequent `repo.one(same_token_query)` then raises on the two active rows, and a permission-loss callback can affect only one exact `binding_ref`. Posture is mutable evidence, not part of the durable authority identity.

**Fix:** Remove `app_identity_posture` from the active identity/scope unique indexes and use a database-enforced upsert or row-lock/retry strategy keyed by the actual authority scope. Add a concurrent test with differing posture values that proves only one active binding survives.

---

_Reviewed: 2026-08-24T20:41:28Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
