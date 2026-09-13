---
phase: 107-operator-timeline-guidance-gate-parity
plan: "01"
subsystem: operator-timeline
tags: [elixir, ecto, phoenix-liveview, safe-evidence, inbox-lifecycle]
requires:
  - phase: 105-tenant-safe-inbox-change-stream
    provides: durable post-commit inbox change publication and authorized reload
  - phase: 106-idempotent-seen-lifecycle-workflow-proof
    provides: idempotent visible-seen transitions and once-only workflow progression
provides:
  - Timestamp-first notification seen/read facts in tenant-authorized delivery explanations
  - Stable optional-admin lifecycle labels and per-event structural hooks
  - Mounted demo proof from durable arrival through seen/read to Trace Detail
affects: [107-02-guidance-gate-parity, verify-inbox, operator-explainability]
actuals:
  tokens: 3979
  tasks: 3
  commits: 5
plan_head_before: 147e6792b8e96bb12f1c173edf2ba48839911f18
tech-stack:
  added: []
  patterns:
    - Parent notification timestamps are the sole seen/read timeline authority
    - Timeline ordering uses exact timestamp first and closed event rank only for ties
    - Optional admin rendering consumes closed SafeEvidence and re-redacts detail
key-files:
  created:
    - chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs
  modified:
    - lib/chimeway/traces.ex
    - lib/chimeway/safe_evidence.ex
    - test/chimeway/traces_test.exs
    - test/chimeway/safe_evidence_test.exs
    - chimeway_admin/lib/chimeway_admin/components/timeline_event.ex
    - examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs
key-decisions:
  - "Use DateTime Unix microseconds before the closed event rank so chronology is global and rank resolves exact ties only."
  - "Project seen and read independently from the preloaded parent notification with exact empty detail maps."
  - "Expose one extensible data-cw-timeline-event hook while retaining explicit lifecycle labels and generic event rendering."
patterns-established:
  - "Lifecycle projection: sibling delivery explanations derive identical seen/read facts from their parent notification."
  - "Dual redaction: lifecycle details remain empty in core and are still passed through the admin allowlist."
requirements-completed: [INT-02, GATE-03]
coverage:
  - id: D1
    description: "Tenant-authorized delivery explanations expose independent notification seen/read facts with exact timestamps, empty detail, sibling consistency, and timestamp-first ordering."
    requirement: INT-02
    verification:
      - kind: integration
        ref: "test/chimeway/traces_test.exs#projects independent parent notification seen and read facts onto sibling deliveries"
        status: pass
      - kind: unit
        ref: "test/chimeway/safe_evidence_test.exs#trace admits only the closed notification lifecycle events with empty detail"
        status: pass
    human_judgment: false
  - id: D2
    description: "The optional admin timeline renders exact lifecycle labels and stable event hooks without weakening timestamps, generic event behavior, or redaction."
    requirement: INT-02
    verification:
      - kind: automated_ui
        ref: "chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs"
        status: pass
    human_judgment: false
  - id: D3
    description: "The demo host proves durable arrival, visible first-seen, once-only workflow progression, explicit read, replay idempotency, and authorized Trace Detail rendering."
    requirement: GATE-03
    verification:
      - kind: e2e
        ref: "examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs#DEMO-08 arrival through seen and read renders the authorized operator timeline"
        status: pass
      - kind: integration
        ref: "mix verify.inbox"
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-09-13
status: complete
---

# Phase 107 Plan 01: Safe Operator Timeline Vertical Slice Summary

**Durable notification seen/read facts now flow chronologically through closed core evidence, explicit admin rendering, and the real mounted inbox-to-Trace-Detail journey.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-13T00:44:25Z
- **Completed:** 2026-09-13T00:52:41Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added independent `:notification_seen` and `:notification_read` entries sourced only from persisted parent notification timestamps, with exact empty detail and sibling-delivery agreement.
- Corrected global timeline ordering to timestamp-first with closed event rank as the deterministic tie-breaker and seen-before-read for equal timestamps.
- Added exact admin labels and `data-cw-timeline-event` hooks while retaining ISO timestamps, detail markup, generic events, and defense-in-depth redaction.
- Extended the demo-host journey through mounted arrival, visible seen, once-only workflow progression, explicit read, replay/reload idempotency, and authorized Trace Detail privacy checks.

## Task Commits

1. **Task 1 RED: core lifecycle contracts** — `aade5ef6` (`test`)
2. **Task 1 GREEN: durable lifecycle projection** — `ca21b90a` (`feat`)
3. **Task 2 RED: admin component contracts** — `6c436e6b` (`test`)
4. **Task 2 GREEN: explicit labels and stable hooks** — `aba15740` (`feat`)
5. **Task 3: mounted demo integration proof** — `2ed76678` (`test`)

## Files Created/Modified

- `lib/chimeway/traces.ex` — Projects parent notification lifecycle facts and sorts timelines by exact timestamp before event rank.
- `lib/chimeway/safe_evidence.ex` — Admits exactly the two new closed event atoms without adding detail fields.
- `test/chimeway/traces_test.exs` — Covers all persisted state combinations, sibling equality, chronology, ties, exact shape, and hostile sentinels.
- `test/chimeway/safe_evidence_test.exs` — Covers positive lifecycle admission and unknown-event rejection.
- `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex` — Adds exact lifecycle labels and the stable per-event data hook.
- `chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs` — Proves labels, hooks, timestamps, detail markup, generic behavior, and re-redaction.
- `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` — Proves the complete mounted lifecycle-to-operator path and replay stability.

## Decisions Made

- Used `DateTime.to_unix(at, :microsecond)` as the primary sort coordinate so exact persisted chronology cannot be overridden by event kind.
- Kept seen/read independent and emitted no detail fields, preventing UI intuition, signals, publisher data, or delivery state from becoming lifecycle authority.
- Applied one stable hook to every timeline item, preserving extensibility and existing generic event rendering.
- Assumption delta: core remains Phoenix-free, `chimeway_admin` remains optional and host-mounted, and notification/tenant/recipient identity anchors are unchanged.

## TDD Gate Compliance

- Task 1 preserved verified RED evidence (52 tests, 3 intended lifecycle assertion failures) before the RED and GREEN commits; final focused result was 52 tests, 0 failures.
- Task 2 preserved verified RED evidence (9 tests, 2 intended missing-hook assertion failures) before the RED and GREEN commits; final focused result was 9 tests, 0 failures.
- Task 3 is a test-only integration-evidence task. Its first behavioral run exposed an incorrect closed-panel visibility expectation; after aligning the test with the public UI contract (unread arrival count while closed, item visibility after opening), the full journey passed. No production implementation was permitted or required after Tasks 1 and 2 completed the exercised path.

## Verification

- `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/traces_test.exs test/chimeway/safe_evidence_test.exs --warnings-as-errors` — 52 tests, 0 failures.
- `cd chimeway_admin && mix test test/chimeway_admin/components/timeline_event_test.exs test/chimeway_admin/redaction_test.exs --warnings-as-errors` — 9 tests, 0 failures.
- `cd chimeway_inbox && mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs --warnings-as-errors` — 19 tests, 0 failures.
- `cd examples/chimeway_demo_host && mix test test/demo_host_web/inbox_bell_proof_test.exs --include inbox --warnings-as-errors` — 5 tests, 0 failures.
- `mix verify.inbox` — 24 optional-package tests and 5 demo-host tests, 0 failures.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test Bug] Corrected closed-panel arrival visibility assertion**
- **Found during:** Task 3
- **Issue:** The first journey draft expected hidden notification item markup before the bell panel was opened, contradicting the existing public component contract.
- **Fix:** Asserted the durable arrival through the closed bell's unread count, then asserted the seeded item became visible after opening the panel.
- **Files modified:** `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs`
- **Verification:** Focused demo journey passed 5 tests with 0 failures.
- **Committed in:** `2ed76678`

**Total deviations:** 1 auto-fixed (1 Rule 1 test bug).
**Impact on plan:** No production scope change; the correction made the journey reflect the shipped accessible disclosure behavior.

## Issues Encountered

- `mix deps.get` reported an expired optional Hex authentication session and current security advisories for already-locked dependencies; dependency resolution remained unchanged.
- Demo-host test startup printed the existing notices for configured-but-optional `:ex_cldr`, `:ex_money`, and `:accrue` applications. The focused suite compiled without warnings under `--warnings-as-errors` and passed. These pre-existing notices are outside Plan 107-01's owned files.

## Known Stubs

None. The plan-owned files contain no new TODO/FIXME/placeholder or unwired runtime/UI data path.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for `107-02` to publish canonical guidance, harden release-contract cleanup, and expand the named inbox/release gates.
- The unsafe broad release-gate contract was intentionally not run; Plan 107-02 owns its cleanup prerequisite.

## Self-Check: PASSED

- Found all seven plan-owned production, test, and demo files.
- Found task commits `aade5ef6`, `ca21b90a`, `6c436e6b`, `aba15740`, and `2ed76678`.
- All five plan-level verification commands exited successfully.
- Stub and threat-surface scans found no unplanned blocking surface; the only new security-relevant rendering surface is covered by T-107-01 through closed evidence and dual redaction.
- No tracked file deletions or Plan 107-02 file changes were introduced.

---
*Phase: 107-operator-timeline-guidance-gate-parity*
*Completed: 2026-09-13*
