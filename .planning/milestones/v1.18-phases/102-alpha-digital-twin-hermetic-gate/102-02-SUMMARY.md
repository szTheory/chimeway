---
phase: 102-alpha-digital-twin-hermetic-gate
plan: "02"
subsystem: testing
tags: [elixir, clock, apns, deterministic, alpha-twin]
requires:
  - phase: 102-alpha-digital-twin-hermetic-gate
    provides: Immutable package and CrossWake provenance accepted tracer
provides:
  - System-default injectable Chimeway clock seam
  - Fixture-owned opaque binding and one-time intent authority
  - Redacted ordered APNs transport contract
affects: [alpha-twin-ci, phase-102-plan-03]
tech-stack:
  added: []
  patterns: [explicit clock injection, opaque host custody, scripted transport behaviour]
key-files:
  created:
    - lib/chimeway/clock.ex
    - test/fixtures/alpha_twin/lib/alpha_twin/clock.ex
    - test/fixtures/alpha_twin/lib/alpha_twin/registry.ex
    - test/fixtures/alpha_twin/lib/alpha_twin/scripted_apns_transport.ex
    - test/fixtures/alpha_twin/test/alpha_twin_test.exs
  modified:
    - lib/chimeway/delivery_targets.ex
    - lib/chimeway/adapters/apns.ex
key-decisions:
  - "Production time remains system UTC by default; explicit resolved timestamps override it only at exercised seam boundaries."
  - "The fixture registry alone retains raw device tokens and one-time intent state; Chimeway receives only bounded transient material and opaque references."
  - "The scripted transport consumes one outcome per real APNs request and observes only a redacted bounded projection."
patterns-established:
  - "Fixture transport implementations use the shipped Chimeway.APNS.Transport behaviour rather than emulating a provider protocol."
requirements-completed: [TWIN-01, TWIN-02]
coverage:
  - id: D1
    description: Deterministic system-default and injected clock behavior is available at target attempt and APNs acceptance/expiry seams.
    requirement: TWIN-01
    verification:
      - kind: integration
        ref: test/fixtures/alpha_twin/test/alpha_twin_test.exs#production-clock
        status: pass
    human_judgment: false
  - id: D2
    description: Host-owned registry and redacted scripted APNs outcomes remain deterministic and credential-free.
    requirement: TWIN-02
    verification:
      - kind: integration
        ref: test/fixtures/alpha_twin/test/alpha_twin_test.exs#scripted-transport
        status: pass
      - kind: integration
        ref: mix verify.alpha_twin
        status: pass
    human_judgment: false
duration: 14 min
completed: 2026-08-25
status: complete
---

# Phase 102 Plan 02: Deterministic Alpha Twin Seams Summary

**A system-default clock, host-private fixture registry, and ordered redacted APNs transport make the Alpha twin deterministic without Apple credentials or wall-clock sleeps.**

## Performance

- **Duration:** 14 min
- **Completed:** 2026-08-25T21:46:34Z
- **Tasks:** 1/1
- **Files modified:** 7

## Accomplishments

- Added `Chimeway.Clock` and passed explicit resolved time through target claiming, stale closeout, and APNs expiry/acceptance while leaving ordinary production callers on system UTC.
- Added fixture-owned opaque binding lifecycle, exact-revision invalidation, and atomic one-time intent consumption.
- Added a credential-free APNs transport behind the shipped behaviour that validates requests, emits redacted observations, and drives accepted, retryable, permanent, invalidating, and ambiguous classifications.

## Task Commits

1. **Task 1: Close deterministic clock, host-authority, and scripted-transport contracts** - `c7c7da8` (test RED), `440ea6b` (feat GREEN)

## Files Created/Modified

- `lib/chimeway/clock.ex` - System UTC default with optional fixture provider.
- `lib/chimeway/delivery_targets.ex` - Optional resolved timestamps for attempted and stale target transitions.
- `lib/chimeway/adapters/apns.ex` - Optional resolved APNs time and transport options.
- `test/fixtures/alpha_twin/lib/alpha_twin/registry.ex` - Private token custody, revision CAS, and intent replay protection.
- `test/fixtures/alpha_twin/lib/alpha_twin/scripted_apns_transport.ex` - Ordered redacted transport ledger.
- `test/fixtures/alpha_twin/test/alpha_twin_test.exs` - Executable seam contracts.

## Decisions Made

- Production defaults continue to use truncated `DateTime.utc_now/0`; fixture time is supplied only through explicit options.
- Rotating a binding creates a replacement opaque revision, so delayed invalidation of the old revision is harmless.
- Transport observations never retain device tokens or payload content.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The fixture seam test did not yet exist, so its RED step first failed on the intentionally absent fixture clock module before implementation.

## Known Stubs

None.

## Next Phase Readiness

Plan 03 can compose these deterministic seams into the complete ordered delivery and recovery ledger.

## Self-Check: PASSED

- Confirmed task commits `c7c7da8` and `440ea6b` exist.
- Confirmed all created fixture and production seam files exist.
