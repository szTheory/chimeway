---
phase: 100-optional-apns-adapter
reviewed: 2026-08-22T12:02:00Z
depth: standard
files_reviewed: 32
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

**Reviewed:** 2026-08-22T12:02:00Z
**Depth:** standard
**Files Reviewed:** 32
**Status:** issues_found

## Summary

The APNs adapter, target lifecycle integration, migrations, consumer proof, and CI lane were reviewed. The durable routing-intent boundary does not actually require opaque identifiers: arbitrary sensitive values can be retained in the database and sent in the APNs payload. The same loose validation also permits control characters in a caller-supplied APNs collapse identifier.

## Critical Issues

### CR-01: “Opaque” open references can contain and disclose sensitive data

**File:** `lib/chimeway/apns/request_intent.ex:31`
**Issue:** `safe_opaque?/1` only rejects four substrings. It accepts values such as `"alice@example.com"`, `"user/123"`, or a signed URL as `open_ref`; `to_storage/1` then persists the value (`:63`) and `Payload.build/2` sends it to APNs as `chimeway_open_ref` (`lib/chimeway/apns/payload.ex:21-24`). This violates the project requirement not to leak sensitive payload fields and the module’s own durable *opaque* routing-intent contract. The payload-side `opaque_ref?/1` repeats the same insufficient validation at `lib/chimeway/apns/payload.ex:47`, so callers can bypass durable-intent construction as well.

**Fix:** Require a closed opaque-reference format at both boundaries, rather than attempting to blacklist secret words. For example:

```elixir
@opaque_ref ~r/^cw_[a-z0-9][a-z0-9_-]{3,159}$/

defp safe_opaque?(value),
  do: is_binary(value) and Regex.match?(@opaque_ref, value)

defp opaque_ref?(value),
  do: is_binary(value) and Regex.match?(@opaque_ref, value)
```

If host reference formats must vary, require the host to provide an opaque projection and persist/send only that projection. Add rejection tests for an email address, URL, raw user identifier, and a value containing newline characters.

## Warnings

### WR-01: Explicit collapse IDs accept invalid header characters

**File:** `lib/chimeway/apns/request_intent.ex:104`
**Issue:** A caller-supplied `collapse_id` is accepted whenever it is 1–64 bytes and lacks one of four secret-related words. Values containing `\r`, `\n`, or other control characters therefore become `Transport.Request.collapse_id` (`lib/chimeway/adapters/apns.ex:158`) and are passed to Pigeon as an APNs header field. Depending on the HTTP/2 client this becomes either a request failure after the target has been claimed or an unsafe header value. It should be rejected before any provider handoff.

**Fix:** Validate explicit collapse IDs against APNs’ header-safe character contract (or generate every collapse ID internally). At minimum reject control characters and constrain it to an ASCII allowlist, e.g. `~r/^[A-Za-z0-9._-]{1,64}$/`, and add boundary tests for CR/LF, tabs, and non-printable bytes.

---

_Reviewed: 2026-08-22T12:02:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
