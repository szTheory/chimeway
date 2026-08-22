---
phase: 100-optional-apns-adapter
reviewed: 2026-08-22T00:38:03Z
depth: standard
files_reviewed: 33
files_reviewed_list:
  - .github/workflows/ci.yml
  - lib/chimeway/adapters/apns.ex
  - lib/chimeway/apns/binding_lookup.ex
  - lib/chimeway/apns/payload.ex
  - lib/chimeway/apns/request_intent.ex
  - lib/chimeway/apns/transport.ex
  - lib/chimeway/delivery_target.ex
  - lib/chimeway/delivery_targets.ex
  - lib/chimeway/dispatch/executor.ex
  - lib/chimeway/dispatch/oban_worker.ex
  - lib/chimeway/safe_evidence.ex
  - lib/chimeway/target_adapter.ex
  - lib/chimeway/target_resolver.ex
  - priv/chimeway_migrations/037_add_apns_request_intent.exs
  - priv/repo/migrations/20260820000001_add_apns_request_intent.exs
  - scripts/verify-apns.sh
  - test/chimeway/adapters/apns_test.exs
  - test/chimeway/apns/api_coverage_test.exs
  - test/chimeway/apns/request_test.exs
  - test/chimeway/apns/result_test.exs
  - test/chimeway/apns/tracer_test.exs
  - test/chimeway/generated_prefixed_runtime_proof_test.exs
  - test/chimeway/migration_contract_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - test/chimeway/safe_evidence_test.exs
  - test/fixtures/apns_consumer/apns-enabled.lock
  - test/fixtures/apns_consumer/lib/apns_consumer.ex
  - test/fixtures/apns_consumer/mix.exs
  - test/fixtures/apns_consumer/test/apns_consumer_test.exs
  - test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations/TIMESTAMP_add_apns_request_intent.exs
  - test/fixtures/installer_golden_public/tree/priv/repo/migrations/TIMESTAMP_add_apns_request_intent.exs
  - test/support/apns_fake_transport.ex
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 100: Code Review Report

**Reviewed:** 2026-08-22T00:38:03Z
**Depth:** standard
**Files Reviewed:** 33
**Status:** issues_found

## Summary

The APNs request/response path, durable intent storage, target lifecycle integration, consumer proof, migration templates, and CI hook were reviewed. Provider response facts are bounded before persistence and the 410 invalidation path is correctly gated on the complete response tuple. Two defects remain: pre-handoff failures can be recorded as an ambiguous provider handoff, and the Pigeon-enabled compilation path contains unreachable duplicate callbacks and an undefined Pigeon API call.

## Critical Issues

### CR-01: Pre-handoff exceptions are falsely recorded as possible provider handoffs

**File:** `lib/chimeway/adapters/apns.ex:9-30`
**Issue:** The rescue/catch surrounds intent decoding, host binding lookup, payload construction, and the actual `Transport.push/2` call. Consequently, an exception from `BindingLookup.resolve/1` (including a host lookup callback crash) or `Payload.build/2` is converted to `{:error, :possible_handoff, :ambiguous_handoff}` even though no provider request was attempted. `Executor` then durably closes the target as `:ambiguous_handoff`, preventing the normal safe pre-handoff retry. This violates the lifecycle evidence contract and can strand otherwise deliverable notifications after a local/transient host error.

**Fix:** Keep the pre-handoff operations outside the transport uncertainty rescue and map their failures to `:pre_handoff_retryable` (or a safe permanent validation result). Only wrap the provider-emission call in the ambiguity guard. For example:

```elixir
with {:ok, intent} <- RequestIntent.from_storage(target.apns_request_intent),
     false <- RequestIntent.expired?(intent, DateTime.utc_now()),
     {:ok, transient} <- BindingLookup.resolve(binding_request(target, intent)),
     {:ok, payload} <- Payload.build(delivery.render_data || %{}, intent.open_ref) do
  push_and_classify(transient, intent, payload, target)
else
  {:error, :binding_not_found} -> {:pre_handoff_retryable, %{provider_code: "binding_not_found"}}
  # other validated pre-handoff cases
end

defp push_and_classify(transient, intent, payload, target) do
  result =
    try do
      Transport.push(transient.dispatcher_ref, request(transient, intent, payload))
    rescue
      _ -> {:error, :ambiguous}
    catch
      _, _ -> {:error, :ambiguous}
    end

  case result do
    {:ok, response} -> classify_result(response, target, intent)
    {:error, :pigeon_unavailable} -> {:pre_handoff_retryable, %{provider_code: "pigeon_unavailable"}}
    _ -> {:error, :possible_handoff, :ambiguous_handoff}
  end
end
```

Add a regression test where `resolve_binding/1` raises and assert no transport call, a pending/retryable target, and a pre-handoff evidence code.

## Warnings

### WR-01: Pigeon-enabled build has unreachable duplicate adapter callbacks

**File:** `lib/chimeway/apns/transport.ex:115-175,266-379`
**Issue:** The generic `init/1`, `handle_push/2`, `handle_info/2`, and `process_end_stream/2` clauses are defined before the `if Code.ensure_loaded?(Pigeon.Adapter)` block and match every invocation. When Pigeon is installed, the later callback implementations are therefore unreachable. The Pigeon-enabled consumer compile emits warnings for every duplicate/unreachable clause; it also reports `Pigeon.json_library/0` as undefined at lines 332 and 353. This defeats the claimed warnings-as-errors quality gate for the optional path and leaves two divergent response implementations, one of which is dead.

**Fix:** Retain one callback implementation. Prefer the dependency-neutral dynamic implementation, remove the conditional duplicate block, and use the dynamically resolved Pigeon JSON module there. Alternatively, put the Pigeon-specific callbacks in a separate module compiled only in the enabled consumer, with no overlapping function heads. Add a consumer compile assertion that fails on warnings originating from Chimeway (not just the fixture application).

---

_Reviewed: 2026-08-22T00:38:03Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
