---
phase: 100-optional-apns-adapter
plan: 09
subsystem: apns-adapter
tags: [elixir, apns, pigeon, package-verification]
requires:
  - phase: 100-optional-apns-adapter
    provides: APNs optional transport and packaged consumer proof
provides:
  - Stage-scoped pre-handoff APNs exception classification
  - One runtime Pigeon callback bridge with configured JSON decoding
  - Warning-strict unpacked dependency compilation gate
affects: [phase-100-release-verification, optional-adapter-consumers]
tech-stack:
  added: []
  patterns:
    - Pre-provider failures are normalized before Transport.push/2.
    - Optional Pigeon callbacks use runtime module dispatch and runtime JSON configuration.
key-files:
  created: [.planning/phases/100-optional-apns-adapter/100-09-SUMMARY.md]
  modified:
    - lib/chimeway/adapters/apns.ex
    - test/chimeway/adapters/apns_test.exs
    - lib/chimeway/apns/transport.ex
    - scripts/verify-apns.sh
    - test/chimeway/release_gate_contract_test.exs
key-decisions:
  - "[100-09]: APNS ambiguity begins only at Transport.push/2; lookup and payload-builder exceptions are bounded pre-handoff outcomes."
  - "[100-09]: Enabled package verification force-compiles unpacked Chimeway under warnings-as-errors before consumer compilation."
metrics:
  duration: 18 min
  completed: 2026-08-22
status: complete
---

# Phase 100 Plan 09: APNs Boundary and Warning Gate Summary

APNs now distinguishes local pre-provider failures from possible provider handoff, and the enabled package verifier warning-strictly compiles the unpacked Chimeway dependency before its consumer.

## Accomplishments

- Added a private configurable payload-builder seam and bounded lookup/payload exception classification before `Transport.push/2`.
- Retained ambiguity only around the provider transport handoff; adapter regressions prove zero transport messages for the new local failure paths.
- Removed duplicate compile-time Pigeon callbacks, retained the dynamic bridge, and resolve JSON decoding from Pigeon's runtime configuration.
- Strengthened the package script and release contract with a forced `deps/chimeway` warnings-as-errors compile before consumer compilation.

## Task Commits

1. Task 1 — `2ac605f`: bound APNS pre-handoff failures.
2. Task 2 — `f6edbbd`: enforce APNS dependency warning gate.

## Verification

- PASS: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/adapters/apns_test.exs test/chimeway/dispatch/target_worker_test.exs --warnings-as-errors` (15 tests).
- BLOCKED: `bash scripts/verify-apns.sh` reaches the new strict dependency gate and fails on an existing Oban dependency warning (`Oban.Repo.expected_error?/1` unreachable clause).
- BLOCKED: focused release-gate test could not initialize its test dependency repositories due PostgreSQL `53300 too_many_connections` contention.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Bug] Replaced unavailable `String.index/2` in the release contract with `:binary.match/2`.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed plan-owned source, test, script, and summary files exist.
- Confirmed commits `2ac605f` and `f6edbbd` exist.
