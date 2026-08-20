---
phase: 100
slug: optional-apns-adapter
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-20
updated: 2026-08-20
---

# Phase 100 — Validation Strategy

Plan-time executable contract for Phase 100. `status: draft` and pending rows mean implementation has not run; `nyquist_compliant: true` means every planned behavior has an automated command and no manual-only acceptance gap.

## Test Infrastructure

| Property | Value |
|---|---|
| **Framework** | ExUnit on Elixir 1.17+ / OTP 26+; PostgreSQL through `scripts/test-db`; shell clean-consumer verifier |
| **Config file** | `test/test_helper.exs`, `config/test.exs`, `mix.exs`, `.github/workflows/ci.yml` |
| **Quick run command** | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns --warnings-as-errors` |
| **Phase gate** | `mix verify.apns` |
| **Cross-phase gate** | `mix ci && mix ci.verify_gates` |
| **Estimated focused runtime** | 10–60 seconds after compilation |
| **Estimated phase-gate runtime** | Up to 5 minutes because it builds a package and two clean consumers |

## Sampling Rate

- **After every task commit:** run the exact focused command in that task's `<verify><automated>` block.
- **After every plan wave:** run `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors`; after Wave 2 also run `mix verify.install_golden`.
- **After Wave 5:** run `mix verify.apns`, `mix ci`, and `mix ci.verify_gates`.
- **Maximum focused feedback latency:** 60 seconds after dependencies are compiled; the package/clean-consumer gate is intentionally sampled only at Wave 5.
- **Completion evidence:** verifier reads executable results and returns `passed` or `gaps_found`; no conversational UAT.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Threat refs | Secure behavior | Test type | Automated command | File exists at planning | Status |
|---|---:|---:|---|---|---|---|---|---|---|
| 100-01-01 | 01 | 1 | APNS-02, APNS-04, APNS-05 | T-100-01..06 | Persisted intent, transient token, bounds, expiry, one handoff | DB tracer | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix ecto.migrate && scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/tracer_test.exs --warnings-as-errors` | ❌ Wave 0 | ⬜ pending |
| 100-02-01 | 02 | 2 | APNS-02, APNS-04 | T-100-07..10 | No secret columns; public/prefixed template parity | installer contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs test/chimeway/install/golden_diff_test.exs --warnings-as-errors` | ✅ extend | ⬜ pending |
| 100-02-02 | 02 | 2 | APNS-02, APNS-04 | T-100-07..10 | up/down/up preserves Phase 99 rows/constraints | isolated DB migration | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs test/chimeway/generated_prefixed_runtime_proof_test.exs --warnings-as-errors` | ✅ extend | ⬜ pending |
| 100-03-01 | 03 | 3 | APNS-02, APNS-04, APNS-05 | T-100-12..13 | Closed payload, byte/expiry/collapse boundaries | unit | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/request_test.exs --warnings-as-errors` | ❌ Wave 0 | ⬜ pending |
| 100-03-02 | 03 | 3 | APNS-01, APNS-02 | T-100-11, T-100-14..15, T-100-SC | Exact lookup, dynamic Pigeon raw-end-stream adapter, ambiguity, no secret evidence | adapter contract | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/adapters/apns_test.exs test/chimeway/apns/request_test.exs --warnings-as-errors` | ❌ Wave 0 | ⬜ pending |
| 100-04-01 | 04 | 4 | APNS-03, APNS-04 | T-100-16..18, T-100-21 | Exhaustive result matrix and exact status/reason/timestamp-bound CAS invalidation | DB integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/result_test.exs test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors` | ❌/✅ extend | ⬜ pending |
| 100-04-02 | 04 | 4 | APNS-03, APNS-06 | T-100-18..20 | Retry exhaustion and distinct redacted operator states | DB integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/safe_evidence_test.exs test/chimeway/traces_test.exs test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors` | ✅ extend | ⬜ pending |
| 100-05-01 | 05 | 5 | APNS-01, APNS-02 | T-100-22..24, T-100-26, T-100-SC | Package consumer proves Pigeon absent/default and explicit 2.0.1 opt-in | clean consumer | `bash scripts/verify-apns.sh` | ❌ Wave 0 | ⬜ pending |
| 100-05-02 | 05 | 5 | APNS-01..06 | T-100-23..25, T-100-SC | Full API disposition and local/CI parity | contract + aggregate | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/api_coverage_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors && mix verify.apns` | ❌/✅ extend | ⬜ pending |

Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky.

## Requirement and Edge-Probe Closure

| Probe item | Planned explicit evidence |
|---|---|
| APNS-01 unclassified | `scripts/verify-apns.sh` proves both package modes; flagged assumption remains until green. |
| APNS-02 adjacency | `request_test.exs`: encoded 4096 accepted / 4097 rejected; collapse 64 accepted / 65 rejected. |
| APNS-02 empty | nil intent valid for provider-neutral target; APNS delivery with nil/incomplete intent fails before lookup; one target succeeds. |
| APNS-02 ordering | duplicate normalized binding revisions retain one original target/intent; payload key ordering is not an observable contract. |
| APNS-02 concurrency | tracer/result tests permit one claim/provider call under duplicate execution. |
| APNS-03 unclassified | exhaustive Pigeon 2.0.1 matrix plus unknown-conclusive permanent fallback; flagged until matrix test is green. |
| APNS-04 idempotency | repeated expiry execution adds no second terminal attempt/provider call. |
| APNS-04 concurrency | duplicate workers yield one expiry winner and no lookup/provider call. |
| APNS-05 unclassified | host-declared replaceability only; no inference; flagged until request contract is green. |
| APNS-06 idempotency | repeated trace reads are byte-equivalent and non-mutating. |
| APNS-06 concurrency | completion race yields one terminal started-attempt mutation and one trace outcome. |

## Wave 0 Requirements

- [ ] `test/chimeway/apns/tracer_test.exs` — accepted vertical slice, expiry/bounds, idempotency, concurrency, and leak sentinel.
- [ ] `test/chimeway/apns/request_test.exs` — intent/payload/collapse edge matrix.
- [ ] `test/chimeway/adapters/apns_test.exs` — lookup and dynamic transport contract.
- [ ] `test/chimeway/apns/result_test.exs` — pinned provider result and exact invalidation matrix.
- [ ] `test/chimeway/apns/api_coverage_test.exs` — full COVERAGE.md disposition/parser gate.
- [ ] `test/support/apns_fake_transport.ex` — no-network request/result capture.
- [ ] `scripts/verify-apns.sh` and `test/fixtures/apns_consumer/` — disabled/enabled clean package consumer.
- [ ] Migration 037 repository/template/golden files — executable public/prefixed up/down/up evidence.

Existing ExUnit, DataCase, PostgreSQL wrapper, installer fixture, release-gate contract, SafeEvidence tests, target worker tests, and CI aggregate infrastructure cover all other prerequisites; no new test framework or root Pigeon dependency is required.

## Manual-Only Verifications

All Phase 100 behaviors have automated verification. Live Apple credentials, a physical device, CrossWake registration, and protected-open authorization are explicitly Phase 101–103 scope and are not Phase 100 manual acceptance gaps.

## Validation Sign-Off

- [x] Every task has an executable automated command.
- [x] Sampling continuity has no three consecutive tasks without focused automation.
- [x] Wave 0 names every not-yet-existing test/fixture/script/migration.
- [x] No watch-mode flags or conversational UAT.
- [x] All six requirement IDs and all 11 edge-probe candidates map to explicit or flagged evidence.
- [x] `nyquist_compliant: true` records complete plan-time coverage.
- [ ] Implementation commands executed green.
- [ ] `status: validated` and `wave_0_complete: true` set by validation after implementation.

**Approval:** pending implementation evidence
