---
phase: 101-crosswake-registration-protected-open
reviewed: 2026-08-25T18:07:39Z
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

**Reviewed:** 2026-08-25T18:07:39Z
**Depth:** standard
**Files Reviewed:** 43
**Status:** issues_found

## Summary

The protected-open flow generally re-resolves server authority and terminates denied native outcomes correctly. However, the forward authority migration leaves pre-upgrade intents unusable, and the purported metadata sanitizer still durably retains raw token material and PII under non-enumerated keys. The public intent-issuance API also crashes on malformed input instead of returning a normal error.

## Critical Issues

### CR-01: Authority upgrade leaves existing issued intents without a scope

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/priv/repo/migrations/20260824210000_upgrade_chimeway_registration_authority.exs:19-25`
**Issue:** The upgrade copies tenant, subject, and session columns from the binding but never sets `chimeway_notification_open_intents.scope`. Every intent created before this migration retains `NULL` scope. `Registry.consume_current_intent/3` requires `i.scope == scope.scope` (`registry.ex:1358-1362`), so an otherwise valid legacy intent can never be consumed after upgrade. This silently turns still-valid notification opens into failures.
**Fix:** Backfill scope from the bound row in the same update, and add a migration test that consumes a pre-upgrade, unexpired intent after migration.

```elixir
UPDATE chimeway_notification_open_intents
SET tenant_ref = (SELECT org_ref FROM chimeway_token_bindings WHERE binding_ref = chimeway_notification_open_intents.binding_ref),
    subject_ref = (SELECT subject_ref FROM chimeway_token_bindings WHERE binding_ref = chimeway_notification_open_intents.binding_ref),
    scope = (SELECT subject_scope FROM chimeway_token_bindings WHERE binding_ref = chimeway_notification_open_intents.binding_ref),
    session_ref = (SELECT session_ref FROM chimeway_token_bindings WHERE binding_ref = chimeway_notification_open_intents.binding_ref),
    session_version = (SELECT session_version FROM chimeway_token_bindings WHERE binding_ref = chimeway_notification_open_intents.binding_ref)
...
```

### CR-02: Metadata “sanitization” persists sensitive payloads under arbitrary keys

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/metadata_sanitizer.ex:35-39`
**Issue:** `sanitize/1` is a denylist, despite its allowlist contract. It copies every key not exactly equal to one of the small forbidden spellings. For example, `%{"deviceToken" => raw_token}`, `%{"provider_response" => payload}`, or `%{"diagnostics" => %{...PII...}}` survive and are written to token-binding and audit metadata (`token_binding.ex:176-183`; `registry.ex:1721,1785,1815`). This violates the project’s no-raw-token/no-provider-payload durable-data boundary and lets casing or a new provider field bypass the filter.
**Fix:** Make durable metadata a strict, recursively checked allowlist with bounded scalar values (or persist `%{}` when no explicitly approved fields are needed); do not attempt to recognize sensitive data by forbidden names.

```elixir
@allowed_keys [:safe_detail]

def sanitize(metadata) when is_map(metadata) do
  Enum.reduce(metadata, %{}, fn {key, value}, acc ->
    if key in @allowed_keys and safe_scalar?(value), do: Map.put(acc, key, value), else: acc
  end)
end
```

## Warnings

### WR-01: Malformed notification-open issuance input raises a process exception

**File:** `/Users/jon/projects/crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex:1279-1286`
**Issue:** The public `issue_notification_open_intent/1` accesses `attrs.binding_ref` before validating that `attrs` is a map with that key. A missing key or a non-map therefore raises `KeyError`/`BadMapError`, producing a 500-style failure rather than the documented `{:error, reason}` result. This is especially brittle at the host API boundary.
**Fix:** Guard the function and use a required-field helper before constructing the transaction; return `{:error, :invalid_notification_open_intent}` for malformed inputs.

```elixir
def issue_notification_open_intent(attrs) when is_map(attrs) do
  with {:ok, binding_ref} <- required_string(attrs, :binding_ref) do
    do_issue_notification_open_intent(Map.put(attrs, :binding_ref, binding_ref))
  end
end

def issue_notification_open_intent(_), do: {:error, :invalid_notification_open_intent}
```

---

_Reviewed: 2026-08-25T18:07:39Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
