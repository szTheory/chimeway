---
phase: 103-physical-iphone-adoption-truth
plan: "01"
subsystem: cross-repository-proof
tags: [crosswake, notification, source-bound-evidence, git-publication, tdd]
requires:
  - phase: 102-alpha-digital-twin-hermetic-gate
    provides: physical-proof ownership boundary and stale-pin rejection
provides:
  - Published CrossWake notification-proof contract at immutable SHA 65dd9f42e218261015823e28045c507db1884cf3
  - Chimeway authority pin proven equal to the canonical CrossWake branch
affects:
  - 103-02 physical bundle tracer
tech-stack:
  added: []
  patterns:
    - Fixed ordered owner-qualified CrossWake assertion vocabulary
    - Canonical remote equality plus fresh detached-checkout proof before downstream pinning
key-files:
  created:
    - priv/mobile_proof/crosswake-selected-sha
  modified:
    - ../crosswake/lib/crosswake/proof_lane/chimeway_notification_physical_proof.ex
    - ../crosswake/test/fixtures/proof_lane/chimeway-notification-physical-proof.json
    - ../crosswake/test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs
decisions:
  - "Chimeway accepts only the published full SHA after canonical-ref equality and fresh detached source/API/test proof."
metrics:
  duration: 18 min
  completed: 2026-08-26
status: complete
coverage:
  - id: D1
    description: CrossWake owns a closed, ordered notification proof contract and source-bound verifier.
    requirement: TWIN-03
    verification:
      - kind: unit
        ref: ../crosswake/test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: The Chimeway authority file names the canonical, remotely reachable CrossWake commit.
    requirement: TWIN-03
    verification:
      - kind: integration
        ref: canonical git ls-remote equality plus fresh detached checkout and focused test
        status: pass
    human_judgment: false
---

# Phase 103 Plan 01: CrossWake Notification Authority Summary

**A source-bound, owner-qualified CrossWake notification contract is published at one immutable SHA, and Chimeway pins only that remotely reproducible revision.**

## Performance

- **Duration:** 18 min
- **Completed:** 2026-08-26
- **Tasks:** 1/1
- **Files modified:** 4

## Accomplishments

- Added `Crosswake.ProofLane.ChimewayNotificationPhysicalProof` v1 with fixed permission, authenticated-registration, and one-time protected-activation facts.
- Added its canonical sanitized fixture and focused API, ordering, owner, outcome, privacy, and source-bound tests in the same CrossWake commit.
- Published `65dd9f42e218261015823e28045c507db1884cf3` exactly to `refs/heads/phase-103-chimeway-notification-proof`, then verified it from a clean detached checkout before pinning it in Chimeway.

## Task Commits

1. **Task 1: Complete the CrossWake contract, test it, publish that exact commit, then record its SHA**
   - CrossWake authority: `65dd9f42` — `feat(103-01): add Chimeway notification proof contract`
   - Chimeway authority pin: `6896cf1` — `feat(103-01): pin published CrossWake notification authority`

## Files Created/Modified

- `../crosswake/lib/crosswake/proof_lane/chimeway_notification_physical_proof.ex` — CrossWake-owned contract and non-echoing source-bound verifier.
- `../crosswake/test/fixtures/proof_lane/chimeway-notification-physical-proof.json` — Canonical sanitized ordered report.
- `../crosswake/test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs` — Focused contract proof.
- `priv/mobile_proof/crosswake-selected-sha` — Sole 40-character selected CrossWake revision.

## Verification

- `mix test test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs --max-failures 1` — 4 tests, 0 failures locally and in a fresh detached checkout.
- Canonical `git ls-remote` equality matched `65dd9f42e218261015823e28045c507db1884cf3`.
- Fresh clone/fetch detached that exact SHA with clean status; module, fixture, all four public API declarations, `Evidence.check`, and focused source-bound coverage were present.
- The stale `f2c502cdb1ce572a4a57257d9e3c051665704b90` and unrelated `5f4265932ee781aa4cc75c6bd3d8e416488ca640` revisions were explicitly rejected before authority-file creation.

## Decisions Made

- CrossWake retains canonical evidence bytes internally for `validate_source_bound/2`; callers receive only stable validation rules.
- TWIN-03 remains pending: this plan establishes its authority prerequisite but does not claim the future signed-device or visible-alert proof.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Verified the Chimeway authority file exists and its recorded SHA is present on the canonical CrossWake remote.
- Verified both task commits exist: `65dd9f42` in CrossWake and `6896cf1` in Chimeway.

## Next Phase Readiness

Plan 103-02 can consume only `priv/mobile_proof/crosswake-selected-sha`; it must not modify the published CrossWake authority files.

---
*Phase: 103-physical-iphone-adoption-truth*
*Completed: 2026-08-26*
