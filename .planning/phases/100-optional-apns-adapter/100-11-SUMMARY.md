---
phase: 100-optional-apns-adapter
plan: 11
subsystem: packaged-apns-verification
tags: [elixir, mix, apns, package-consumer, warnings-as-errors]
requires:
  - phase: 100-optional-apns-adapter
    provides: enabled APNs consumer fixture and package verifier
provides:
  - Chimeway-only warning-strict compilation after normal dependency preparation
  - Mutation-proofed warning-gate command ordering and visible diagnostics
affects:
  - phase-100-final-apns-verification
tech-stack:
  added: []
  patterns:
    - Compile resolved dependencies normally before forcing only Chimeway's Elixir compiler
    - Keep warning-gate mutation evidence in the packaged verifier and release contract
key-files:
  created:
    - .planning/phases/100-optional-apns-adapter/100-11-SUMMARY.md
  modified:
    - scripts/verify-apns.sh
    - test/chimeway/release_gate_contract_test.exs
key-decisions:
  - "[100-11]: The enabled consumer prepares its resolved graph normally, then invokes `mix cmd --cd deps/chimeway mix compile --force-elixir --no-deps-check --warnings-as-errors` so strict diagnostics apply to Chimeway rather than unrelated dependencies."
  - "[100-11]: A focused temporary unpacked-source mutation proves Chimeway warnings make the strict compiler command fail while diagnostics remain visible."
metrics:
  duration: 14 min
  completed: 2026-08-22
status: complete
---

# Phase 100 Plan 11: APNs Warning Gate Scope Summary

The enabled packaged-consumer verifier now compiles dependencies normally and warning-strictly recompiles only unpacked Chimeway source before compiling its consumer.

## Accomplishments

- Added normal enabled-graph `mix deps.compile` preparation after the locked dependency resolution.
- Replaced whole-project forcing with the exact Chimeway-only strict command using `--force-elixir` and `--no-deps-check`.
- Added a bounded temporary Chimeway-source warning probe and visible compiler output through `tee`.
- Tagged release-contract ordering and mutation checks for focused execution.

## Task Commits

1. Task 1 RED — `0401d2b`: add APNs warning-gate contract.
2. Task 1 GREEN — `aad7a9e`: scope APNs warning gate to Chimeway.

## Verification

- PASS: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only apns_warning_gate_contract --warnings-as-errors` — 2 tests, 0 failures.
- PASS: `bash -n scripts/verify-apns.sh`.
- PASS: Post-wave focused contract rerun after the strict compile environment repair — 2 tests, 0 failures.
- Not run by design: the full `bash scripts/verify-apns.sh` and `mix verify.apns` gates remain owned by Plan 100-10.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Bug] Restored enabled-consumer environment propagation for normal dependency compilation.
- **Found during:** Task 1 focused mutation execution.
- **Issue:** Bare `mix deps.compile` could not load the copied fixture because `CHIMEWAY_PACKAGE_PATH` was not set.
- **Fix:** Ran dependency preparation with the same enabled fixture environment used for locked resolution and consumer compilation.
- **Files modified:** `scripts/verify-apns.sh`
- **Commit:** `aad7a9e`

2. [Rule 1 - Bug] Passed the enabled fixture environment into the Chimeway-only strict compile.
- **Found during:** Plan 100-10's post-wave full package gate.
- **Issue:** The strict `mix cmd --cd deps/chimeway` process did not inherit `CHIMEWAY_PACKAGE_PATH`, so the fixture project could not load.
- **Fix:** Prefixed both strict compile paths with `CHIMEWAY_PACKAGE_PATH`, `CHIMEWAY_APNS_ENABLED=1`, and `MIX_ENV=test`; added mutation contracts for all three variables.
- **Files modified:** `scripts/verify-apns.sh`, `test/chimeway/release_gate_contract_test.exs`
- **Commit:** `678de21`

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed `scripts/verify-apns.sh`, `test/chimeway/release_gate_contract_test.exs`, and this summary exist.
- Confirmed commits `0401d2b` and `aad7a9e` exist.
