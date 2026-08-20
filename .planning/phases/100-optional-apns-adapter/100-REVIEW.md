---
phase: 100-optional-apns-adapter
reviewed: 2026-08-20T21:22:48Z
depth: standard
files_reviewed: 29
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

**Reviewed:** 2026-08-20T21:22:48Z
**Depth:** standard
**Files Reviewed:** 29
**Status:** issues_found

## Summary

The durable request-intent, target lifecycle, migrations, and consumer proof were reviewed, with the APNs call path traced through the Pigeon bridge. The real Pigeon bridge discards the provider response needed for the advertised invalidation behavior, so an actual APNs `Unregistered`/`ExpiredToken` response cannot invalidate a stale binding. The focused Elixir tests passed, but they use a fake transport and therefore do not exercise that production path. The APNs gate is also not a required dependency of the pull-request aggregate gate.

## Critical Issues

### CR-01: Pigeon failures cannot produce the 410 invalidation result

**Classification:** BLOCKER

**File:** `lib/chimeway/apns/transport.ex:83`

**Issue:** `pigeon_push/2` sends through Pigeon and then `classify_pigeon_response/1` reduces every non-`:success` and non-`:timeout` response to `{:error, :rejected}`. Pigeon 2.0.1 represents APNs errors in `notification.response` as atoms such as `:unregistered` and `:expired_token`; this code never creates `Transport.Result{status: 410, reason: ..., timestamp: ...}`. Consequently `APNS.classify_result/3` at `lib/chimeway/adapters/apns.ex:36` can never take its invalidation clause on the real Pigeon path. It instead records a generic permanent rejection, leaving the no-longer-valid device binding active and repeatedly selected for future deliveries. `PigeonAdapter.extract_response/1` is only an isolated parser and is never called by the push path, so its tests do not cover this disconnect.

**Fix:** Either use a provider transport that exposes the full APNs HTTP error payload (including the 410 timestamp) and translate it into `Transport.Result`, or make the capability explicit that the Pigeon adapter cannot support CAS invalidation and do not claim/implement the 410 invalidation workflow there. Add an integration-level transport test that passes the actual Pigeon response shape and proves the intended durable outcome. For example, the classifier must deliberately map Pigeon's response before returning it:

```elixir
defp classify_pigeon_response(%{response: :success}),
  do: {:ok, %Result{outcome: :accepted, code: :accepted}}

# Only valid if the selected Pigeon integration supplies status and timestamp.
defp classify_pigeon_response(%{response: %{status: 410, reason: reason, timestamp: timestamp}})
     when reason in ["ExpiredToken", "Unregistered"] and is_integer(timestamp),
  do: {:ok, %Result{outcome: :rejected, code: :unregistered, status: 410,
                    reason: reason, timestamp: timestamp}}
```

## Warnings

### WR-01: Pull-request gate does not require the APNs verification job

**Classification:** WARNING

**File:** `.github/workflows/ci.yml:302`

**Issue:** `verify_apns` is defined and runs on pull requests, but `pr-gate`'s `needs` list and aggregate invocation omit it. `ci-gate` includes the job, but has `if: always() && github.event_name != 'pull_request'` at line 1389. A failing `mix verify.apns` result can therefore leave the PR's aggregate required check green, allowing the APNs package-consumer and contract checks to be bypassed before merge.

**Fix:** Add `verify_apns` to `pr-gate.needs`, export `VERIFY_APNS: ${{ needs.verify_apns.result }}`, and append `VERIFY_APNS` to `scripts/ci/aggregate-gate.sh`'s arguments. Keep the existing `ci-gate` dependency for non-PR events.

---

_Reviewed: 2026-08-20T21:22:48Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
