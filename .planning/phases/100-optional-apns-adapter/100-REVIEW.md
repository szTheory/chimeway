---
phase: 100-optional-apns-adapter
reviewed: 2026-08-20T19:48:00Z
depth: standard
files_reviewed: 30
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
  - test/fixtures/apns_consumer/mix.exs
  - test/fixtures/apns_consumer/test/apns_consumer_test.exs
  - test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations/TIMESTAMP_add_apns_request_intent.exs
  - test/fixtures/installer_golden_public/tree/priv/repo/migrations/TIMESTAMP_add_apns_request_intent.exs
  - test/support/apns_fake_transport.ex
findings:
  critical: 3
  warning: 0
  info: 0
  total: 3
status: issues_found
---

# Phase 100: Code Review Report

**Reviewed:** 2026-08-20T19:48:00Z
**Depth:** standard
**Files Reviewed:** 30
**Status:** issues_found

## Summary

The phase’s persistence and target-lifecycle paths are scoped and tenant-qualified, but the optional Pigeon transport does not preserve important provider outcomes. In production this turns APNs invalidations and retryable failures into terminal delivery failures, and also treats a locally unavailable Pigeon dispatcher as a provider rejection.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: The 410 invalidation triple can never be reconstructed from a real APNs response

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/lib/chimeway/apns/transport.ex:186`

**Issue:** `closed_result/1` decodes the APNs error body and sends that map directly to `extract_response/1` at line 189. Apple’s JSON body contains `reason` and `timestamp`; the HTTP status is held separately in `stream.status`. Since `extract_response/1` requires a `"status" => 410` key, every real 410 falls through to Pigeon’s generic error handling. `classify_pigeon_response/1` then maps it to `{:error, :rejected}`, and `Chimeway.Adapters.APNS` persists a permanent failure rather than performing its intended binding invalidation.

**Fix:** Include the stream status when validating the decoded body, and retain the resulting closed `Transport.Result`.

```elixir
with {:ok, response} <- Pigeon.json_library().decode(body),
     {:ok, %{reason: reason, timestamp: timestamp}} <-
       extract_response(Map.put(response, "status", stream.status)) do
  {:ok, %Result{outcome: :rejected, code: normalize_code(reason),
                status: stream.status, reason: reason, timestamp: timestamp}}
end
```

Add an integration assertion using an APNs-shaped body without a `status` field, as supplied by `Pigeon.Http2.Stream`.

### CR-02: Retryable APNs provider responses are classified as permanent failures

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/lib/chimeway/apns/transport.ex:175-205`

**Issue:** The custom Pigeon adapter only attempts to produce a `Transport.Result` for status 410. For every other APNs error status, `close_response/3` delegates to Pigeon, which supplies an atom such as `:too_many_requests`, `:service_unavailable`, or `:shutdown` in `notification.response`. `classify_pigeon_response/1` treats every non-`Result` response as `{:error, :rejected}` (line 88). The APNS adapter consequently returns `:permanent` at line 21, bypassing its retry logic at lines 51-66 and dropping notifications during 429/5xx outages.

**Fix:** Translate all APNs error responses needed by the adapter contract into `Transport.Result` values before calling `Pigeon.Tasks.process_on_response/1`, preserving the HTTP status and normalized reason. At minimum, map 429 and the relevant 5xx/IdleTimeout reasons to `outcome: :rejected`; then `Chimeway.Adapters.APNS.classify_result/3` can select `:provider_retryable`.

```elixir
# In close_response/3, handle the closed vocabulary rather than only 410.
case closed_result(stream) do
  {:ok, result} -> {:closed, %{notification | response: result}}
  :error -> Pigeon.Configurable.handle_end_stream(config, stream, notification); :normalized
end
```

Extend `closed_result/1` to decode and validate the status/reason pair for 429 and transient 5xx responses, with tests asserting that they return `{:provider_retryable, ...}` rather than `{:permanent, ...}`.

### CR-03: A missing or stopped Pigeon dispatcher is recorded as a permanent provider rejection

**Classification:** BLOCKER

**File:** `/Users/jon/projects/chimeway/lib/chimeway/apns/transport.ex:83-89`

**Issue:** Pigeon returns `%Pigeon.APNS.Notification{response: :not_started}` when its registry has no worker for the requested dispatcher. No provider request has been emitted in that branch. The catch-all `%{response: _}` clause maps this to `{:error, :rejected}`, which `Chimeway.Adapters.APNS.deliver/2` maps to `{:permanent, ...}`. A temporary dispatcher outage therefore irreversibly fails a target instead of taking the pre-handoff retry path.

**Fix:** Classify `:not_started` as an unavailable local transport and preserve the pre-handoff distinction.

```elixir
defp classify_pigeon_response(%{response: :not_started}),
  do: {:error, :pigeon_unavailable}

defp classify_pigeon_response(%{response: :timeout}), do: {:error, :ambiguous}
```

Add a Pigeon-backed test that calls `Transport.pigeon_push/2` with a dispatcher key that has no registered worker and asserts `{:pre_handoff_retryable, %{provider_code: "pigeon_unavailable"}}` from the APNS adapter.

---

_Reviewed: 2026-08-20T19:48:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
