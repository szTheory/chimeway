---
phase: 100-optional-apns-adapter
reviewed: 2026-08-21T18:23:45Z
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
  - mix.exs
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
  - test/fixtures/apns_consumer/lib/apns_consumer.ex
  - test/fixtures/apns_consumer/mix.exs
  - test/fixtures/apns_consumer/test/apns_consumer_test.exs
  - test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations/TIMESTAMP_add_apns_request_intent.exs
  - test/fixtures/installer_golden_public/tree/priv/repo/migrations/TIMESTAMP_add_apns_request_intent.exs
  - test/support/apns_fake_transport.ex
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 100: Code Review Report

**Reviewed:** 2026-08-21T18:23:45Z
**Depth:** standard
**Files Reviewed:** 32
**Status:** issues_found

## Summary

The optional APNs path contains a provider-result handling defect that turns ordinary APNs successes into terminal rejections in the package's normal Pigeon-neutral compilation mode. The supported opt-in consumer fixture also forces a Pigeon release whose resolved HTTP dependency tree reports known security advisories, so the prescribed production integration imports vulnerable code.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Runtime Pigeon adapter rejects successful APNs streams

**File:** `lib/chimeway/apns/transport.ex:153-168`
**Classification:** BLOCKER

**Issue:** The always-compiled Pigeon-neutral `process_end_stream/2` removes every correlated stream from the queue and passes `runtime_closed_result(stream)` to `Pigeon.Tasks.process_on_response/1`. `runtime_closed_result/1` only recognizes selected error statuses; its catch-all at lines 222-230 produces `%Result{outcome: :rejected, code: :unrecognized_provider_response}`. Consequently, a normal APNs 200 response is completed as a rejection. The Pigeon-specific implementation below has the required fallback to `Pigeon.Configurable.handle_end_stream/3`, but it is not available when Chimeway is compiled without Pigeon (the intended optional-dependency case). No consumer test sends a successful end stream.

**Fix:** Preserve Pigeon's normal response handling in the dynamic implementation: make `runtime_closed_result/1` return `:error` for unrecognized/success streams, then invoke `Pigeon.Configurable.handle_end_stream(config, stream, notification)` for that case; only call `process_on_response/1` for the validated closed APNs error results. Add an enabled-consumer test that delivers a correlated 200 stream and asserts `{:provider_accepted, ...}`.

### CR-02: The required APNs opt-in pins a dependency tree with published HTTP security advisories

**File:** `test/fixtures/apns_consumer/mix.exs:19-20`
**Classification:** BLOCKER

**Issue:** The supported APNs consumer path hard-pins `pigeon` to `2.0.1`. Resolving the fixture in the supplied `verify.apns` workflow currently selects `hackney 1.17.1`; Hex reports the Hackney SSRF advisory `GHSA-vq52-99r9-h5pw` plus multiple 2026 advisories (including host allowlist bypass and CR/LF injection) during that resolution. This is not merely a test-only dependency: the fixture documents and proves the exact host opt-in dependency consumers are directed to add, so production APNs users inherit the vulnerable HTTP client chain.

**Fix:** Upgrade or replace the Pigeon integration with a release whose dependency constraints resolve to patched HTTP-client versions, and lock/contract-test the resulting graph. If no secure compatible Pigeon release exists, remove `pigeon 2.0.1` as the supported adapter dependency and document a secure alternative before shipping the adapter.

---

_Reviewed: 2026-08-21T18:23:45Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
