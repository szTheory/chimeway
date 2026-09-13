---
phase: 101-crosswake-registration-protected-open
plan: "13"
subsystem: protected-notification-open
tags: [swift, ios, notification-open, idempotency, replay-protection]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: protected terminal notification outcomes and activation coordination from Plan 101-09
provides:
  - First-wins durable pending notification-open evidence keyed by open_ref
  - Production-drain proof that duplicate evidence cannot overwrite an allowed presentation
affects: [phase-101, offline-notification-open, protected-activation]
tech-stack:
  added: []
  patterns:
    - Normalize pending queue evidence through one prune-and-compaction path before enqueue inspection and every drain overload
    - Preserve the earliest stored item, FIFO order, and original enqueue age for each open_ref
key-files:
  created: []
  modified:
    - ../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/NotificationOpenQueue.swift
    - ../crosswake/packages/crosswake-shell-core-ios/Tests/CrosswakeShellCoreTests/NotificationOpenQueueTests.swift
decisions:
  - "[101-13]: A duplicate open_ref is repeated opaque evidence for one pending intent; retain the first item and compact legacy duplicates before host consumption."
metrics:
  tasks_completed: 1
  commits: 2
  duration: 00:03:00
  completed_date: 2026-08-25
status: complete
---

# Phase 101 Plan 13: Idempotent Notification-Open Queue Summary

The iOS notification-open queue now retains one first-wins opaque item per `open_ref`, so duplicate callbacks and legacy persisted duplicates reach host authority and protected activation exactly once.

## Accomplishments

- Added a production-drain regression that persists duplicate evidence, reloads it, and proves one host consume, terminal removal, and a stable allowed dashboard presentation.
- Centralized age pruning and first-wins `open_ref` compaction for enqueue, pending inspection, callback drain, and production activation-coordinator drain.
- Preserved the earliest stored evidence and enqueue age, FIFO ordering for distinct references, bounded queue behavior, retryable transport retention, opaque persistence schema, and terminal no-fallback activation semantics.

## Verification

- PASS: `cd /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios && swift test --filter NotificationOpenQueueTests` (4 tests, 0 failures).
- PASS: `cd /Users/jon/projects/crosswake/packages/crosswake-shell-core-ios && swift test --filter ProtectedNotificationActivationTests` (3 tests, 0 failures).

## TDD Gate Compliance

- RED: `247ee8c3` added the duplicate persisted-evidence production-drain contract; the focused queue suite failed as expected with two consumes and a replay-denial presentation overwrite.
- GREEN: `f11a67f0` implemented shared first-wins compaction; both required focused suites passed.

## Decisions Made

- Duplicate callbacks are not separate route identities: the queue keeps the first opaque `open_ref` item without refreshing its lifetime.
- Legacy queue records are compacted and persisted before either host drain can consume one-time authority.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. The plan-owned Swift source and test contain no placeholder, TODO, FIXME, or runtime/UI stub content.

## Self-Check: PASSED

- Both queue source and XCTest files exist in the Crosswake repository.
- TDD commits `247ee8c3` and `f11a67f0` exist in Crosswake history.
- No tracked file deletions were introduced by either task commit.
