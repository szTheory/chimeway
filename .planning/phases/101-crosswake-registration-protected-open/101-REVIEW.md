---
phase: 101-crosswake-registration-protected-open
reviewed: 2026-08-25T00:00:00Z
depth: standard
files_reviewed: 40
files_reviewed_list:
  - /Users/jon/projects/crosswake/examples/phoenix_host/README.md
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_registration_adapter.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/token_binding.ex
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260602100000_create_chimeway_token_bindings.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260603000000_create_chimeway_notification_open_intents.exs
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260824210000_upgrade_chimeway_registration_authority.exs
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
  critical: 1
  warning: 2
  info: 0
  total: 3
status: issues_found
---

# Phase 101: Code Review Report

**Reviewed:** 2026-08-25T00:00:00Z
**Depth:** standard
**Files Reviewed:** 40
**Status:** issues_found

## Summary

Reviewed the supplied Elixir/Phoenix, Swift, contracts, migrations, and focused tests. The current submission closes the prior queue-replay, feedback-authority, and migration-collision defects. However, the public intent-issuance boundary can durably retain raw token/payload data, and two lifecycle operations cannot operate on the valid `:subject_installation` binding scope that the schema explicitly supports.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Notification intent metadata accepts and persists sensitive token or payload fields

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex:42`

**Issue:** `changeset/2` casts `:metadata` without sanitizing or rejecting it. `Registry.issue_notification_open_intent/1` forwards caller-controlled attrs directly to this changeset at `registry.ex:1277-1284`. Consequently, a host call can persist raw APNs/FCM token material or notification payload fields in the durable open-intent table, bypassing the project’s raw-token and sensitive-payload boundary. This is especially risky because the generic public issuance API has no closed input contract.

**Fix:** Apply the same allowlist/redaction policy used for binding metadata, and reject forbidden raw-token keys before insertion. For example:

```elixir
|> validate_change(:metadata, fn :metadata, metadata ->
  if MetadataSanitizer.contains_forbidden_token_key?(metadata),
    do: [metadata: "contains forbidden token material"],
    else: []
end)
|> update_change(:metadata, &MetadataSanitizer.sanitize/1)
```

Add a test that attempts to issue an intent with `apns_token`, `raw_token`, notification body, and nested payload values, then asserts rejection (or that only explicitly safe metadata is stored).

## Warnings

### WR-01: Provider invalidation cannot revoke a valid installation-scoped binding

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex:1526-1548`

**Issue:** `provider_feedback_scope/1` unconditionally requires `session_ref` and `session_version`, then requires them to equal the authenticated context. `TokenBinding` explicitly permits `:subject_installation` bindings with neither field (`token_binding.ex:134-144`). Feedback for such a valid active binding therefore always becomes `{:error, :no_active_bindings}` and leaves an APNs-invalidated token active.

**Fix:** Build and query the feedback scope by `subject_scope`: require and predicate session revision only for `:subject_session`; for `:subject_installation`, require the exact binding reference, authenticated subject/org/installation, provider/platform/environment, and app identity while omitting session predicates. Add an integration test for invalidating feedback against an installation-scoped binding.

### WR-02: Notification open intents cannot be issued for a valid installation-scoped binding

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex:48-58`

**Issue:** Open intents always require `session_ref` and `session_version`. Issuance derives both directly from the selected active binding (`registry.ex:1278-1283`); for a supported `:subject_installation` binding they are `nil`, so the insert fails validation. The lifecycle API thus advertises and stores a valid binding scope that cannot receive a protected notification open.

**Fix:** Either deliberately restrict notification registration/open behavior to `:subject_session` and reject installation-scoped binding at bind time for this feature, or model intent authority by scope: store `subject_scope`, require session fields only for session scope, and have consume matching apply the corresponding exact scope predicate. Add a test proving the chosen contract.

---

_Reviewed: 2026-08-25T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
