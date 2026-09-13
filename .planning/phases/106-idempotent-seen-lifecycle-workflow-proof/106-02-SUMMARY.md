---
phase: 106-idempotent-seen-lifecycle-workflow-proof
plan: "02"
subsystem: demo-workflow
tags: [seen, workflow, oban, tenant-isolation, end-to-end]
provides:
  - Mounted bell-to-seen-signal-to-workflow proof
  - Replay and exact scope denial evidence
affects: [107]
key-files:
  modified:
    - examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs
requirements-completed: [INT-04]
duration: 5min
completed: 2026-09-12
status: complete
---

# Phase 106 Plan 02 Summary

**The reference host now proves an authorized bell-open progresses one eligible seen workflow exactly once.**

## Accomplishments

- Mounted the real inbox route against a waiting `chimeway.notification.seen` workflow.
- Opened the real bell, drained the real signal router queue, and asserted one activation transition.
- Proved reopen/replay cannot duplicate progression and wrong tenant/recipient signals leave the run waiting.

## Task Commits

1. Mounted workflow and denial proof — `2a84f500`

## Evidence

- Focused demo inbox journey: 4 tests, 0 failures.
- Aggregate `mix verify.inbox`: 24 optional-package tests plus 4 demo-host tests, 0 failures.

## Deviations from Plan

None.

## Self-Check: PASSED

- The executable journey uses the real mounted LiveView, durable signal, Oban queue, and workflow router.
