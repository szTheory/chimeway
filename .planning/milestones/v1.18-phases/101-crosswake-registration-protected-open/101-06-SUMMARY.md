---
phase: 101-crosswake-registration-protected-open
plan: "06"
subsystem: native-registration
tags: [swift, ios, elixir, phoenix, apns, registry-cas]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: exact scoped binding revision CAS from Plan 101-04
provides:
  - Explicit iOS permission, observation, binding, and permission-loss state transitions
  - A byte-identical v1 permission-loss callback transcript used by XCTest and ExUnit
  - Authenticated Phoenix adapter to real exact-revision registry revocation
affects: [phase-101, protected-notification-open, iOS-hosts]
tech-stack:
  added: []
  patterns:
    - Transient APNs Data crosses only a synchronous host delegate boundary
    - Permission-loss commands carry complete authenticated opaque scope and binding revision
key-files:
  created:
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationRegistrationCoordinator.swift
    - ../crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/NotificationRegistrationTests.swift
    - ../crosswake/test/fixtures/chimeway_notification_permission_loss_v1.json
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_registration_adapter.ex
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/notification_registration_adapter_test.exs
  modified:
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/CrosswakeDelegates.swift
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/CrosswakeShellConfig.swift
key-decisions:
  - "[101-06]: The iOS shell retains only the opaque binding revision and closed scope after synchronous APNs observation."
  - "[101-06]: Permission-loss callbacks require every authenticated scope field to match before the real registry exact-revision CAS runs."
patterns-established:
  - "Shared callback transcripts are copied byte-for-byte between canonical fixtures and Swift test resources."
requirements-completed: [OPEN-01]
metrics:
  tasks_completed: 2
  commits: 4
status: complete
---

# Phase 101 Plan 06: Native Registration and Authenticated Permission-Loss Summary

Native registration now keeps APNs bytes transient, retains only a scoped opaque revision, and routes permission loss through an authenticated Phoenix adapter to the existing exact-revision registry CAS.

## Accomplishments

- Added the explicit Swift registration state machine, optional host capability, and idempotent post-binding permission-loss callback.
- Added a canonical v1 callback transcript and byte-identical Swift resource; XCTest decodes it to drive the callback.
- Added the production adapter that rejects untrusted, incomplete, or scope-mismatched callbacks and maps valid stale revisions to a closed no-op result.
- Proved a stale revision cannot revoke the rotated replacement or unrelated installation binding.

## Verification

- `cd ../crosswake/packages/crosswake-shell-core-ios && swift test --filter NotificationRegistrationTests` — passed (3 tests).
- `cd ../crosswake/examples/phoenix_host && mix test test/crosswake_example/chimeway/notification_registration_adapter_test.exs --seed 0` — passed (2 tests).

## TDD Gate Compliance

- RED: `11139546` and `f9583fe0` added failing native and host-adapter tests.
- GREEN: `637930e9` and `dd021a53` implemented the pinned contracts.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made integration-test fingerprints unique per run**
- **Found during:** Task 2 verification
- **Issue:** Persistent example-host test data could collide with a fixed unrelated fingerprint.
- **Fix:** Generate unique fixture fingerprints while preserving the rotation and unrelated-scope assertions.
- **Files modified:** `../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/notification_registration_adapter_test.exs`
- **Commit:** `dd021a53`

## Self-Check: PASSED

- All six planned implementation and test artifacts exist.
- All four TDD commits are present in Crosswake history.
