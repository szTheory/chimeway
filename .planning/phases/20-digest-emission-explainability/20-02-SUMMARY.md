---
phase: 20-digest-emission-explainability
plan: 02
subsystem: runtime
tags: [digests, dispatch, oban, sync, tdd]
requires:
  - phase: 20-digest-emission-explainability
    provides: durable digest emission claim and source-row outcome fields
provides:
  - canonical dispatch handoff for emitted digest deliveries
  - sync and oban execution support for emitted digests and immediate-release rows
  - thin digest flush worker with durable bucket-id args
affects: [phase-20-plan-03, digests, dispatch, integration-tests]
tech-stack:
  added: []
  patterns: [pre-planned delivery dispatch, transactional oban enqueue, thin worker delegation]
key-files:
  created:
    - lib/chimeway/dispatch/digest_flush_worker.ex
    - test/chimeway/integration/digest_delivery_lifecycle_test.exs
  modified:
    - lib/chimeway/digests/emission.ex
    - lib/chimeway/dispatch.ex
    - lib/chimeway/dispatch/oban.ex
    - lib/chimeway/dispatch/sync.ex
key-decisions:
  - "Emitted digests reuse the normal delivery lifecycle through dispatch_delivery by delivery_id."
  - "Oban enqueue stays delivery-id based and can happen inside the emission transaction."
  - "Digest flush workers carry only bucket_id and delegate all correctness to the emission service."
patterns-established:
  - "Expose a public pre-planned delivery handoff seam instead of re-entering notification planning."
  - "Treat emitted digests and immediate-release rows as the same dispatch primitive: a ready delivery row."
requirements-completed: [DIGEST-02]
duration: 18min
completed: 2026-04-28
---

# Phase 20 Plan 02: Digest Emission & Explainability Summary

**Canonical digest dispatch handoff through sync and Oban delivery_id paths**

## Accomplishments
- Extended the dispatcher contract with `dispatch_delivery/2` so pre-planned digest deliveries can run without re-entering planning.
- Added sync and Oban lifecycle coverage proving emitted digests dispatch through the normal path and duplicate flush execution reuses one emitted digest identity.
- Added `DigestFlushWorker` as a thin bucket-id worker that delegates to the durable emission service.

## Verification
- `mix test test/chimeway/digests/emission_test.exs test/chimeway/integration/digest_delivery_lifecycle_test.exs --trace`

## Notes
- The emitted digest row now carries adapter-ready `subject`, `body`, `summary`, `items`, and digest identity metadata before dispatch.
- This plan was executed inline on the current worktree, so there are no task-specific git commits to record in the summary.

## Self-Check: PASSED
- Verified sync dispatch reaches the test adapter with the emitted digest row.
- Verified Oban enqueue happens by `delivery_id` and duplicate digest flush worker runs reuse the same emitted digest identity.

---
*Phase: 20-digest-emission-explainability*
*Completed: 2026-04-28*
