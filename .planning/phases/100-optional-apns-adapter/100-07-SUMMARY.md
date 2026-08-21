---
phase: 100-optional-apns-adapter
plan: 07
subsystem: apns
tags: [elixir, pigeon, apns, optional-dependency, cas]
requires:
  - phase: 100-optional-apns-adapter
    provides: APNs request, classification, and optionality seams from plans 100-01 through 100-06
provides:
  - Packaged public APNS.deliver/2 to real Pigeon dispatcher to host CAS tracer
  - Pigeon-free compile-safe dispatcher callback surface for opt-in hosts
  - Fail-closed malformed and uncorrelated provider response handling
affects: [phase-100-verification, APNS-03]
tech-stack:
  added: []
  patterns:
    - Runtime-only Pigeon callback dispatch preserves the Pigeon-free package boundary.
    - Unrecognized provider streams become safe permanent outcomes instead of parser crashes.
key-files:
  created: [.planning/phases/100-optional-apns-adapter/100-07-SUMMARY.md]
  modified:
    - lib/chimeway/apns/transport.ex
    - lib/chimeway/apns/binding_lookup.ex
    - test/fixtures/apns_consumer/lib/apns_consumer.ex
    - test/fixtures/apns_consumer/test/apns_consumer_test.exs
    - scripts/verify-apns.sh
    - test/chimeway/apns/api_coverage_test.exs
key-decisions:
  - "[100-07] Treat a nil APNs transport setting as absent rather than as a configured atom adapter."
  - "[100-07] Close malformed/unrecognized Pigeon end streams into a safe rejected result so provider JSON parsing cannot terminate the dispatcher."
requirements-completed: [APNS-03]
duration: 24 min
completed: 2026-08-21
status: complete
---

# Phase 100 Plan 07: Optional APNs Bridge-to-CAS Summary

**The packaged APNs consumer now proves public adapter delivery through a real opt-in Pigeon dispatcher into the exact original host binding CAS, including its fail-closed raw-stream matrix.**

## Completed Work

- Added a tagged, no-network package-consumer tracer for both authoritative 410 reasons and every required non-authoritative case.
- Preserved runtime-only Pigeon callbacks when Chimeway is compiled without Pigeon, while allowing an opt-in consumer to supply Pigeon 2.0.1 later.
- Ensured PID dispatcher references are valid transient host bindings and an absent transport override enters the optional Pigeon path.
- Added focused `CHIMEWAY_APNS_FOCUS=bridge_to_cas` packaged verification mode.

## Verification

- `CHIMEWAY_APNS_FOCUS=bridge_to_cas bash scripts/verify-apns.sh` — passed through the freshly unpacked package fixture (3 tagged bridge-to-CAS tests).
- `mix verify.apns` — passed (30 focused root APNs tests plus the full packaged-consumer gate).
- `mix format --check-formatted` — passed for all touched Elixir files.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 1 - Bug] Corrected absent optional transport dispatch and Pigeon-free callback compilation.
   - **Found during:** Task 1 focused packaged tracer.
   - **Issue:** `nil` was treated as an atom adapter, causing `nil.push/3`; Pigeon callbacks were compiled away when the package compiled before the downstream Pigeon dependency.
   - **Fix:** Require a non-nil atom override and provide dynamic runtime-only Pigeon callback implementations that close recognized and unrecognized streams safely.
   - **Files modified:** `lib/chimeway/apns/transport.ex`, `lib/chimeway/apns/binding_lookup.ex`.
   - **Commit:** 11e909a.

2. [Rule 3 - Blocking verification] Repaired the pre-existing APNs coverage table parser/header contract.
   - **Found during:** `mix verify.apns`.
   - **Issue:** The parser accepted the Markdown separator and lower-case header as capability rows, failing the aggregate gate despite all 36 coverage rows being valid.
   - **Fix:** Restored the `disposition` header and excluded normalized headers/separators during parsing.
   - **Files modified:** `.planning/phases/100-optional-apns-adapter/COVERAGE.md`, `test/chimeway/apns/api_coverage_test.exs`.
   - **Commit:** 11e909a.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed the tracer fixture, focused script mode, dynamic transport callback surface, and coverage contract exist on disk.
- Confirmed RED commit `dcd628c` and GREEN commit `11e909a` exist in Git history.
