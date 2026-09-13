---
phase: 106-idempotent-seen-lifecycle-workflow-proof
plan: "01"
subsystem: inbox-live
tags: [seen, liveview, idempotency, pagination, authorization]
provides:
  - Authorized visible-page seen lifecycle
  - Idempotent open/reopen and live-refresh behavior
  - Sender-excluded PubSub echoes preserving pagination
affects: [106-02, 107]
key-files:
  modified:
    - chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex
    - chimeway_inbox/lib/chimeway_inbox/change_stream.ex
    - chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs
requirements-completed: [INT-03]
duration: 9min
completed: 2026-09-12
status: complete
---

# Phase 106 Plan 01 Summary

**Opening the authorized bell now records only visible items seen, once.**

## Accomplishments

- Marked the first page seen only on closed-to-open transition after reauthorization.
- Marked newly loaded rows when pagination makes them visible and refreshed visible page-one rows while open.
- Kept closed refreshes non-engaging and authorization drift write-free.
- Excluded a publishing LiveView from its own PubSub echo so seen/read actions do not collapse a loaded second page.

## Task Commits

1. RED visible-seen contract — `3771089a`
2. Visible lifecycle implementation — `eb6c8630`

## Evidence

- Focused PubSub/LiveView suite: 23 tests, 0 failures.
- Aggregate `mix verify.inbox`: 24 optional-package tests plus 2 demo-host tests, 0 failures.
- Optional-package compile with warnings as errors: passed.

## Deviations from Plan

- Switched publication to `Phoenix.PubSub.broadcast_from/4` so the originating bell reconciles explicitly without consuming its own lossy hint; executable coverage proves other subscribers still receive the exact message.

## Self-Check: PASSED

- Implementation and RED/GREEN commits exist; changed files contain no conversational account identifiers.
