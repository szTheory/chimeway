---
phase: 20-digest-emission-explainability
plan: 03
subsystem: explainability
tags: [traces, explainability, digests, tdd]
requires:
  - phase: 20-digest-emission-explainability
    provides: durable digest emission, membership resolution, and canonical dispatch handoff
provides:
  - source-row digest reasoning under Chimeway.Traces
  - emitted-digest explanation summaries for included and excluded members
  - digest-aware timeline events without payload leakage
affects: [traces, operators, phase-21, analytics]
tech-stack:
  added: []
  patterns: [row-centric operator reasoning, sanitized digest summaries, timeline-based explanations]
key-files:
  created:
    - test/chimeway/orchestration/digest_explainability_test.exs
  modified:
    - lib/chimeway/traces.ex
    - lib/chimeway/traces/explanation.ex
    - test/chimeway/integration/digest_delivery_lifecycle_test.exs
key-decisions:
  - "Digest explainability remains inside Chimeway.Traces instead of a separate debug surface."
  - "Source explanations read durable outcome facts and membership snapshots rather than queue state."
  - "Emitted digest explanations summarize included and excluded members without leaking raw payload or provider data."
patterns-established:
  - "Represent digest reasoning as a stable `digest` map on the explanation contract."
  - "Use timeline events for digest convergence while keeping the primary answer available in one explain_delivery call."
requirements-completed: [DIGEST-03, DIGEST-02]
duration: 14min
completed: 2026-04-28
---

# Phase 20 Plan 03: Digest Emission & Explainability Summary

**Digest-aware operator explanations for both source deliveries and emitted digest rows**

## Accomplishments
- Extended `Chimeway.Traces.Explanation` with digest-specific reasoning for source and emitted digest rows.
- Added digest-aware timeline events for included, skipped, immediate-release, and emitted-digest outcomes.
- Added tests proving sanitized explanations for included/skipped/immediate source rows and included/excluded emitted digest summaries.

## Verification
- `mix test test/chimeway/orchestration/digest_explainability_test.exs test/chimeway/traces_test.exs test/chimeway/integration/digest_delivery_lifecycle_test.exs --trace`

## Notes
- The explanation surface intentionally exposes rule identity, emitted digest linkage, and member outcome summaries while omitting raw payload and provider response blobs.
- This plan was executed inline on the current worktree, so there are no task-specific git commits to record in the summary.

## Self-Check: PASSED
- Verified digest explanation tests pass.
- Verified existing `test/chimeway/traces_test.exs` still passes with the expanded explanation contract.

---
*Phase: 20-digest-emission-explainability*
*Completed: 2026-04-28*
