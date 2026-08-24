---
phase: 101-crosswake-registration-protected-open
plan: "11"
subsystem: native-registration
tags: [swift, ios, apns, permission-loss, acknowledgement]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: exact scoped binding revision and permission-loss delegate seam from Plan 101-06
provides:
  - Host acknowledgement-driven permission-loss delivery marker
  - Retry-safe exact opaque revocation command after transient host rejection
affects: [phase-101, protected-notification-open, iOS-hosts]
tech-stack:
  added: []
  patterns:
    - Mark permission loss delivered only after a closed terminal host acknowledgement
    - Retain and retry the exact opaque binding command without token or host-payload retention
key-files:
  created: []
  modified:
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationRegistrationCoordinator.swift
    - ../crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/NotificationRegistrationTests.swift
decisions:
  - "[101-11]: Rejected permission-loss callbacks keep the exact retained command pending; only revoked and staleNoop acknowledge delivery terminally."
metrics:
  tasks_completed: 1
  commits: 2
  duration: 00:03:00
  completed_date: 2026-08-24
status: complete
---

# Phase 101 Plan 11: Acknowledged Permission-Loss Retry Summary

Native permission-loss revocation now retries the same opaque binding command after a transient host rejection, and becomes terminal only on a revoked or stale-no-op acknowledgement.

## Accomplishments

- Added XCTest coverage for rejected-then-revoked acknowledgement sequencing, byte-equal retry commands, terminal idempotency, and APNs-token sentinel absence from diagnostics.
- Updated the coordinator to leave delivery pending after `.rejected` or a missing delegate, retaining the exact opaque command for the next denied recheck.
- Preserved one-call terminal behavior for `.staleNoop` and no-op behavior after a terminal acknowledgement or missing retained binding.

## Verification

- `cd /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios && swift test --filter NotificationRegistrationTests` — passed (4 tests, 0 failures).

## TDD Gate Compliance

- RED: `7b9e98fc` added the failing rejected-then-revoked retry proof; the focused suite failed as expected before the coordinator change.
- GREEN: `b2e76605` marks delivery only after terminal acknowledgements; the focused suite passed.

## Decisions Made

- A native dispatch attempt is not a durable acknowledgement; `.rejected` leaves the exact opaque command pending for the next foreground/settings recheck.
- Only `.revoked` and `.staleNoop` close the permission-loss delivery marker.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- The coordinator, retry test, and summary files exist.
- Both TDD commits are present in Crosswake history.
