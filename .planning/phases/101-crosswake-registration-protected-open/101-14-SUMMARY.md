---
phase: 101-crosswake-registration-protected-open
plan: "14"
subsystem: crosswake-example-host
tags: [elixir, ecto, authorization, notification-open, metadata-sanitization]
requires:
  - phase: 101-crosswake-registration-protected-open
    provides: exact binding authority and atomic protected-open consumption
provides:
  - Subject-installation feedback invalidation and one-time intent consumption
  - Scope-consistent durable notification-open intent validation
  - Recursive sanitization at the notification intent persistence boundary
affects: [101-crosswake-registration-protected-open]
tech-stack:
  added: []
  patterns:
    - Subject-scope-specific Ecto predicates shared by feedback selection and mutation
    - Atomic issued-to-consumed updates with current binding authority rechecks
    - Recursive metadata sanitization without atomizing string keys
key-files:
  created:
    - .planning/phases/101-crosswake-registration-protected-open/101-14-SUMMARY.md
  modified:
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex
    - ../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/metadata_sanitizer.ex
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_test.exs
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/registry_notification_open_test.exs
    - ../crosswake/examples/phoenix_host/test/crosswake_example/chimeway/notification_open_intent_test.exs
key-decisions:
  - "[101-14]: Subject-installation authority requires exact tenant, subject, installation, binding, scope, and active-state predicates while session fields remain nil."
  - "[101-14]: Notification intent metadata is recursively sanitized immediately after cast, with non-map inputs projected to an empty map."
requirements-completed: [OPEN-01, OPEN-03]
metrics:
  tasks_completed: 2
  files_modified: 6
  completed: 2026-08-25
status: complete
---

# Phase 101 Plan 14: Installation Authority and Intent Privacy Summary

**Installation-scoped bindings now support exact provider invalidation and one-time protected opens, while intent metadata is recursively stripped of tokens, notification content, and provider payloads.**

## Completed Work

- Added scope-aware feedback predicates so an installation binding can be invalidated without session fields, while unrelated bindings remain active.
- Issued intents derive authoritative scope and session fields from the active binding; consume CAS checks tenant, subject, installation, scope, and active exact binding.
- Enforced session-vs-installation consistency in the intent changeset.
- Recursively sanitized maps, lists, and keyword-shaped metadata before durable intent insertion.

## Verification

- PASS: `cd /Users/jon/projects/crosswake/examples/phoenix_host && MIX_ENV=test mix test test/crosswake_example/chimeway/registry_test.exs test/crosswake_example/chimeway/notification_open_intent_test.exs test/crosswake_example/chimeway/registry_notification_open_test.exs --seed 0` — 24 tests, 0 failures.
- PASS: `git diff --check`.

## TDD Gate Compliance

- Task 1 RED: `b570ea2a` — installation authority regressions failed against the prior session-only implementation.
- Task 1 GREEN: `8ad35362` — scope-aware feedback and consume logic passed the focused suite.
- Task 2 RED: `1c89ff4d` — recursive metadata and durable sentinel regressions failed against shallow/no intent sanitization.
- Task 2 GREEN: `20e98197` — recursive sanitizer and changeset boundary passed the focused suite.

## Decisions Made

- Installation-scoped authority never manufactures session fields; session-scoped paths retain their exact session reference and version checks.
- Intent metadata uses the existing host-owned forbidden-key vocabulary and keeps only safe nested siblings.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Query bug] Removed nil session comparisons from installation-scope predicates**
- **Found during:** Task 1 GREEN verification
- **Issue:** Ecto rejects comparisons against pinned nil values, preventing installation bindings from traversing session-only query predicates.
- **Fix:** Added explicit session and installation predicate branches using `is_nil/1` for the installation variant.
- **Files modified:** `../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/registry.ex`
- **Verification:** Focused deterministic suite passed.
- **Commit:** `8ad35362`

**2. [Rule 2 - Persistence boundary] Projected non-map metadata before Ecto map casting**
- **Found during:** Task 2 GREEN verification
- **Issue:** Ecto rejects a non-map before an after-cast sanitizer can project it to the required empty map.
- **Fix:** Normalized non-map atom- and string-keyed metadata attributes to `%{}` before cast, then applied shared sanitization after cast.
- **Files modified:** `../crosswake/examples/phoenix_host/lib/crosswake_example/chimeway/notification_open_intent.ex`
- **Verification:** Focused deterministic suite passed.
- **Commit:** `20e98197`

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 2). **Impact:** Both changes preserve the planned authority and privacy boundaries.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all six plan-owned Crosswake files and this summary exist.
- Confirmed RED and GREEN commits `b570ea2a`, `8ad35362`, `1c89ff4d`, and `20e98197` exist.
