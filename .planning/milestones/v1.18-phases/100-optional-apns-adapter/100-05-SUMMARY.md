---
phase: 100-optional-apns-adapter
plan: 05
subsystem: apns-packaging-ci
tags: [elixir, apns, pigeon, packaging, ci]
requires:
  - phase: 100-optional-apns-adapter
    provides: optional transport and closed APNs result contracts
provides:
  - Fresh packaged consumer proof for Pigeon-disabled and explicit Pigeon-enabled hosts
  - Local and CI APNs verification gate with external API coverage validation
affects: [release-gates, optional-adapters]
tech-stack:
  added: []
  patterns:
    - Build and unpack the published artifact before exercising a clean host fixture
    - Keep Pigeon 2.0.1 conditional in the host fixture rather than the library dependency graph
key-files:
  created:
    - scripts/verify-apns.sh
    - test/fixtures/apns_consumer/mix.exs
    - test/chimeway/apns/api_coverage_test.exs
  modified:
    - mix.exs
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
decisions:
  - "[100-05]: APNs optionality is proven by fresh packaged consumers; Pigeon 2.0.1 remains an explicit host-only dependency."
metrics:
  duration: 18 min
  completed: 2026-08-20
status: complete
---

# Phase 100 Plan 05: APNs Packaging and Gate Evidence Summary

**A freshly unpacked Chimeway package now proves zero-Pigeon default consumption and explicit host Pigeon 2.0.1 opt-in, backed by one local and one CI gate.**

## Completed Work

- Added a temporary-root package verifier that builds the production Hex artifact, exercises disabled and enabled consumer roots, checks dependency trees and locks, compiles with warnings-as-errors, and emits one fixed synthetic sandbox-only evidence line.
- Added the clean consumer fixture with an explicit conditional Pigeon dependency, no APNs credentials, and contract tests for safe evidence plus complete synthetic 410 invalidation facts.
- Added `mix verify.apns`, external capability table parsing, and a required `verify_apns` CI lane folded into `ci-gate` through `VERIFY_APNS`.
- Extended release-gate lane contracts so the aggregate must include the APNs job exactly once.

## Verification

- PASS: `bash scripts/verify-apns.sh`
- PASS: `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/apns/api_coverage_test.exs test/chimeway/release_gate_contract_test.exs --warnings-as-errors`
- PASS: `mix verify.apns` (28 tests plus packaged consumer proof)

## Task Commits

1. Task 1 RED — `3d870b0` consumer fixture contract.
2. Task 1 GREEN — `f900b64` packaged disabled/enabled proof.
3. Task 2 RED — `27e370e` API coverage gate contract.
4. Task 2 GREEN — `28467a3` local and CI APNs verification lane.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 3 - Blocking issue] Declared Oban in the clean host fixture.
- **Found during:** Task 1 packaged compilation.
- **Issue:** Published Chimeway source compiles Oban workers, while optional library dependencies are not automatically resolved for a path consumer.
- **Fix:** Added the host's normal Oban dependency only to the fixture; Pigeon remains conditionally host-owned.
- **Files modified:** `test/fixtures/apns_consumer/mix.exs`.
- **Commit:** `f900b64`.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed the package verifier, fixture, API coverage test, and CI lane files exist.
- Confirmed task commits `3d870b0`, `f900b64`, `27e370e`, and `28467a3` exist in git history.
