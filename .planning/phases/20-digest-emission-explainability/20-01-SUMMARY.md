---
phase: 20-digest-emission-explainability
plan: 01
subsystem: database
tags: [ecto, postgres, digests, emissions, tdd]
requires:
  - phase: 19-digest-data-model-accumulation
    provides: durable digest rules, buckets, and memberships
provides:
  - durable digest emission claim state on buckets
  - membership-level resolution facts and emitted digest linkage
  - canonical source-row digest outcomes on deliveries
affects: [phase-20-plan-02, phase-20-plan-03, digests, traces, dispatch]
tech-stack:
  added: []
  patterns: [repo-transact claim boundary, explicit convergence helpers, persisted resolution fields]
key-files:
  created:
    - lib/chimeway/digests/emission.ex
    - priv/repo/migrations/20260428110000_alter_chimeway_digest_buckets_for_emission.exs
    - priv/repo/migrations/20260428110100_alter_chimeway_digest_memberships_for_resolution.exs
    - priv/repo/migrations/20260428110200_alter_chimeway_deliveries_for_digest_outcome.exs
    - test/chimeway/digests/emission_test.exs
  modified:
    - lib/chimeway/delivery.ex
    - lib/chimeway/deliveries.ex
    - lib/chimeway/digests.ex
    - lib/chimeway/digests/digest_bucket.ex
    - lib/chimeway/digests/digest_membership.ex
key-decisions:
  - "Digest buckets persist explicit flush claim state plus emitted digest delivery identity."
  - "Digest memberships persist immutable resolution facts instead of forcing later inference from bucket state."
  - "Source deliveries converge on explicit digest outcomes via named Deliveries helpers."
patterns-established:
  - "Use one transaction with FOR UPDATE bucket locking to collapse duplicate flush attempts onto one emitted digest identity."
  - "Keep digest outcome facts first-class on both memberships and canonical delivery rows."
requirements-completed: [DIGEST-02]
duration: 22min
completed: 2026-04-28
---

# Phase 20 Plan 01: Digest Emission & Explainability Summary

**Durable bucket claim, membership resolution, and canonical source-row convergence for digest emission**

## Accomplishments
- Added RED/GREEN tests for single-emission reuse, included membership resolution persistence, and explicit skipped/immediate source-row outcomes.
- Extended `DigestBucket`, `DigestMembership`, and `Delivery` with durable emission and resolution fields plus the supporting migrations.
- Implemented `Chimeway.Digests.Emission.emit_bucket/2` with bucket locking, emitted digest identity creation, and canonical source-row convergence helpers.

## Verification
- `mix test test/chimeway/digests/emission_test.exs --trace`

## Notes
- This plan was executed inline on the current worktree, so there are no task-specific git commits to record in the summary.

## Self-Check: PASSED
- Verified the new schema fields exist in code and migrations.
- Verified `test/chimeway/digests/emission_test.exs` passes.

---
*Phase: 20-digest-emission-explainability*
*Completed: 2026-04-28*
