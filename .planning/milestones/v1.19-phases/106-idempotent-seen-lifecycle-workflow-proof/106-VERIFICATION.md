---
phase: 106-idempotent-seen-lifecycle-workflow-proof
verified: 2026-09-12T17:00:00Z
status: passed
score: 6/6 must-haves verified
behavior_unverified: 0
human_verification: []
---

# Phase 106 Verification Report

**Phase Goal:** Opening the authorized bell records exactly the visible first-seen facts and can progress an eligible workflow once.

| # | Observable truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Closed bells and disconnected render do not record seen. | VERIFIED | Closed-mount and closed-stream-refresh tests leave `seen_at` and signals absent. |
| 2 | Authorized open marks only the visible first page seen. | VERIFIED | First-page test records 20/21 rows; the non-visible row remains unchanged. |
| 3 | Load-more and open live refresh mark newly visible rows without collapsing pagination. | VERIFIED | Page-two and sender-excluded PubSub tests pass. |
| 4 | Reopen, reconnect semantics, and reload echoes cannot duplicate seen state or signals. | VERIFIED | Repeat-open and exact signal-count tests pass on the conditional core lifecycle. |
| 5 | Authorization and scope changes write nothing. | VERIFIED | Auth-drift, tenant, and recipient denial tests pass. |
| 6 | First seen progresses one eligible waiting workflow and replay cannot progress it twice. | VERIFIED | Mounted demo journey uses the real signal queue/router and records exactly one `signal_received` transition. |

## Behavioral Evidence

- Focused PubSub/LiveView suite: 23 tests, 0 failures.
- `mix verify.inbox`: 24 optional-package tests plus 4 demo-host tests, 0 failures.
- No conversational UAT required.

## Verdict

**PASSED.** INT-03 and INT-04 are machine-proven. Phase 107 may proceed.
