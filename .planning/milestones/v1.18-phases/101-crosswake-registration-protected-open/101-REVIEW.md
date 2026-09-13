---
phase: 101-crosswake-registration-protected-open
reviewed: 2026-08-25T20:00:00Z
depth: standard
files_reviewed: 45
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
  - /Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260825200000_protect_chimeway_notification_open_intent_history.exs
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

**Reviewed:** 2026-08-25T20:00:00Z
**Depth:** standard
**Files Reviewed:** 45
**Status:** issues_found

## Summary

Reviewed the registration authority upgrade, one-time protected-open flow, redaction/telemetry boundaries, authority migrations, and iOS persistence queue. The scoped package tests and example-host tests pass, but the public provider-feedback worker recipe calls an API that does not exist and does not construct the registry's required authenticated option set.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Provider-feedback worker recipe cannot run

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/README.md:127-132`

**Issue:** The recommended Oban worker calls `Crosswake.Companions.Chimeway.Contracts.ProviderFeedback.from_attrs/1`, but `ProviderFeedback` is a contract struct and exposes no such function. The actual conversion boundary is `Crosswake.Companions.Chimeway.Redaction.feedback_from_provider_attrs/1`. Further, `Registry.apply_provider_feedback/2` requires a keyword option set including `:authenticated_context`, `:binding_ref`, `:installation_ref`, `:app_identity_ref`, and session authority when relevant; passing an unspecified `scope` map will either fail the function contract or return `:no_active_bindings` for invalidating feedback. A host copying the documented durable worker therefore crashes before processing provider feedback or silently fails to apply a valid revocation.

**Fix:** Build the feedback through the redaction boundary and have the host resolver return the exact registry options, for example:

```elixir
with {:ok, feedback} <- Crosswake.Companions.Chimeway.Redaction.feedback_from_provider_attrs(feedback_attrs) do
  opts = MyApp.Notifications.authenticated_provider_feedback_opts!(feedback)
  CrosswakeExample.Chimeway.Registry.apply_provider_feedback(feedback, opts)
end
```

Document that `opts` is a keyword list containing the authenticated context and exact binding/session scope required by `Registry.apply_provider_feedback/2`, and add a doctest or integration test that compiles and runs the recipe.

---

_Reviewed: 2026-08-25T20:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
