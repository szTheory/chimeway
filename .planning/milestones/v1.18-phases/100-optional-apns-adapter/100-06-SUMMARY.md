---
phase: 100-optional-apns-adapter
plan: 06
subsystem: apns-transport-ci
tags: [elixir, pigeon, apns, ci]
provides:
  - Queue-correlated Pigeon 2.0.1 410 response projection
  - Required APNs verification on PR and non-PR gates
key-files:
  modified:
    - lib/chimeway/apns/transport.ex
    - test/chimeway/apns/result_test.exs
    - test/fixtures/apns_consumer/test/apns_consumer_test.exs
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "Pigeon 410 invalidation authority requires queue correlation and bounded complete facts."
metrics:
  duration: 18 min
status: complete
---

# Phase 100 Plan 06: APNs Response Bridge Summary

**The optional Pigeon bridge now projects only correlated, complete 410 APNs responses into the closed transport result, and the APNs lane is required by both aggregate gates.**

## Completed Work

- Added the optional Pigeon dispatcher adapter queue/end-stream bridge, preserving the original callback and returning a closed result only for bounded 410 ExpiredToken or Unregistered JSON bodies with a non-negative timestamp.
- Kept normalized, malformed, oversized, incomplete, and uncorrelated responses non-authoritative.
- Extended the packaged enabled-host test and root result matrix.
- Added `verify_apns` to `pr-gate`, with a contract asserting its single aggregate token.

## Verification

- PASS: `bash scripts/verify-apns.sh`
- PASS: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/result_test.exs --warnings-as-errors`
- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors`

## Task Commits

1. `8fff91b` — Pigeon 410 response bridge and fail-closed tests.
2. `84c454c` — required APNs PR gate aggregation contract.

## Deviations from Plan

None - plan executed as specified.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all five implementation and contract files exist.
- Confirmed task commits `8fff91b` and `84c454c` exist in history.
