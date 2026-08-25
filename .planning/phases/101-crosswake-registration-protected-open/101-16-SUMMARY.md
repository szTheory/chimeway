---
phase: 101-crosswake-registration-protected-open
plan: "16"
subsystem: crosswake-example-host
tags: [elixir, ecto, notification-open, metadata-sanitization, privacy]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: scope-consistent one-time notification-open intent lifecycle
provides:
  - Drop-all caller metadata projection for notification-open intents
  - Exact-empty changeset and persistence privacy regressions
affects: [OPEN-03, crosswake-example-host]
tech-stack:
  added: []
  patterns:
    - Notification-open caller metadata has a dedicated constant projection instead of sharing a finite forbidden-key filter
key-files:
  created:
    - .planning/phases/101-crosswake-registration-protected-open/101-16-SUMMARY.md
  modified:
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/metadata_sanitizer.ex
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/notification_open_intent_test.exs
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_notification_open_test.exs
key-decisions:
  - "[101-16]: Notification-open caller metadata is always projected to %{}; durable intents retain only explicit schema and host-authoritative fields."
  - "[101-16]: The shared MetadataSanitizer.sanitize/1 contract remains unchanged for token-binding and audit consumers."
requirements-completed: [OPEN-03]
coverage:
  - id: D1
    description: Caller metadata is absent from notification-open changesets and persisted intent/event evidence.
    requirement: OPEN-03
    verification:
      - kind: integration
        ref: "examples/phoenix_host: MIX_ENV=test mix test notification_open_intent_test.exs registry_notification_open_test.exs --seed 0"
        status: pass
    human_judgment: false
metrics:
  tasks_completed: 1
  files_modified: 4
  completed: 2026-08-25
status: complete
---

# Phase 101 Plan 16: Drop-All Notification-Open Metadata Summary

**Notification-open intents now discard all caller metadata before persistence, preserving only explicit opaque and host-authoritative lifecycle fields.**

## Completed Work

- Added `MetadataSanitizer.sanitize_notification_open/1`, a documented constant `%{}` projection for every caller input.
- Routed intent changesets through that boundary after cast while leaving the shared metadata sanitizer available to its unrelated consumers.
- Replaced safe-sibling expectations with adversarial exact-empty regressions covering camelCase token, authorization/PII, provider body, unknown nested data, non-scalar values, and oversized strings for atom and string attrs.
- Proved persisted rows and issued event inspection do not retain adversarial sentinels.

## Verification

- PASS: `cd /Users/jon/projects/crosswake/examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/notification_open_intent_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs --seed 0` — 17 tests, 0 failures.
- PASS: `git -C /Users/jon/projects/crosswake diff --check`.
- PASS: `COVERAGE.md` remains unchanged and limited to local Ecto/ExUnit scope.

## TDD Gate Compliance

- Task 1 RED: `b6bb3b2d` — exact-empty changeset/persistence assertions failed against the finite blocklist, including a non-scalar persistence failure.
- Task 1 GREEN: `8efb1b12` — dedicated drop-all projection and both atom/string attr coverage passed the focused suite.

## Decisions Made

- Caller notification-open metadata has no durable contract and is always `%{}`.
- Existing token-binding and audit metadata consumers retain their scoped shared sanitizer behavior.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all four Crosswake implementation/test artifacts exist.
- Confirmed RED and GREEN commits `b6bb3b2d` and `8efb1b12` exist.
- Stub-pattern scan found no plan-blocking placeholder or empty-data stubs.
