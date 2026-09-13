---
phase: 101-crosswake-registration-protected-open
plan: "07"
subsystem: protected-notification-open
tags: [swift, ios, notification-open, offline, authorization]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: current host notification-intent consumption and RouteGate allow outcomes
provides:
  - Bounded opaque-only durable notification-open evidence queue
  - Closed host consume outcomes with allow-only protected activation
affects: [101-08, protected-notification-open, iOS-hosts]
tech-stack:
  added: []
  patterns:
    - Versioned Codable evidence queue with atomic replacement
    - Host-owned reconnect consumption and no-fallback notification activation
key-files:
  created:
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenDelegate.swift
    - ../crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/NotificationOpenQueueTests.swift
    - ../crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/ProtectedNotificationActivationTests.swift
  modified:
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/ActivationCoordinator.swift
key-decisions:
  - "[101-07]: Offline notification evidence is versioned, age/count bounded, and contains only opaque open, binding, action, and correlation references."
  - "[101-07]: Reconnect removes terminal host outcomes, retains only explicit transport retries, and invokes native activation only for a host-provided allowed request."
metrics:
  tasks_completed: 1
  commits: 2
status: complete
---

# Phase 101 Plan 07: Protected Notification Open Queue Summary

**Offline notification taps now persist as bounded opaque evidence and can activate only after a fresh host allow outcome.**

## Completed Work

- Added a file-backed versioned queue with deterministic age/count eviction, restart reload, corrupt-file discard, and atomic replacement.
- Limited serialized evidence to opaque open, binding, action, and correlation references plus enqueue state/time; no route, URL, payload, token, tenant/session, identity, or authority flag enters storage.
- Added the closed asynchronous host consumer seam: allowed, terminal denial, and retryable transport failure.
- Added protected notification activation that accepts only a transient allowed request and removes retry/safe-fallback actions on denial.

## Verification

- `cd ../crosswake/packages/crosswake-shell-core-ios && swift test --filter NotificationOpenQueueTests` — passed (3 tests).
- `cd ../crosswake/packages/crosswake-shell-core-ios && swift test --filter ProtectedNotificationActivationTests` — passed (2 tests).
- `git diff --cached --check` — passed before the implementation commit.

## TDD Gate Compliance

- RED: `9ee9f27f` added the queue, reconnect-outcome, opaque-serialization, and no-fallback activation contract tests; the suite failed because the required types and activation entry did not exist.
- GREEN: `ef451fae` implemented the bounded queue, host delegate seam, and protected activation; both focused suites pass.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed. **Impact:** No scope expansion.

## Known Stubs

None. The queue has a concrete file-backed data source and all activation wiring is host-allow-only.

## Self-Check: PASSED

- Confirmed all five planned Crosswake artifacts exist.
- Confirmed RED commit `9ee9f27f` and GREEN commit `ef451fae` exist in Crosswake history.
- Confirmed both focused Swift test suites pass.
