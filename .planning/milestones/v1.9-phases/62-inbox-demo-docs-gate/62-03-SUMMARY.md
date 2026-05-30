---
phase: 62-inbox-demo-docs-gate
plan: 03
subsystem: infra
tags: [mix, ci, release-gate, inbox, chimeway_inbox]

requires:
  - phase: 62-inbox-demo-docs-gate
    provides: DEMO-08 :inbox proof test for verify.inbox demo lane
  - phase: 61-inbox-headless-package
    provides: chimeway_inbox package tests and path dep
provides:
  - mix verify.inbox alias (package + demo :inbox lane)
  - verify_inbox CI job with Postgres (no sibling checkout)
  - MAINTAINING eight-gate pre-ship checklist
  - release_gate_contract nine ci-gate lane parity
affects: [62-02-inbox-guide, GATE-05, ci-gate]

tech-stack:
  added: []
  patterns:
    - "In-repo path-dep verify gate mirroring verify_mailglass (no ACCRUE_PATH)"
    - "Eight-gate pre-ship octet with nine ci-gate aggregation lanes"

key-files:
  created: []
  modified:
    - mix.exs
    - .github/workflows/ci.yml
    - test/chimeway/release_gate_contract_test.exs
    - MAINTAINING.md

key-decisions:
  - "verify.inbox composes chimeway_inbox package tests + demo host --only inbox only — no root inbox lane or sibling checkout"
  - "ci-gate aggregates nine lanes; pre-ship checklist documents eight verify.* commands plus mix ci/ci.docs/ci.verify_gates"

patterns-established:
  - "GATE-05 Inbox: selective verify.inbox alias distinct from verify.example chimeway_inbox smoke lane"

requirements-completed: [GATE-05 (Inbox)]

duration: 3min
completed: 2026-05-30
---

# Phase 62 Plan 03: Inbox Release Gate Summary

**Formal `mix verify.inbox` alias, verify_inbox CI job, and eight-gate MAINTAINING octet with nine-lane ci-gate parity — in-repo path deps only**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-30T12:38:00Z
- **Completed:** 2026-05-30T12:41:09Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Added `mix verify.inbox` alias running `chimeway_inbox` package tests and demo host `:inbox` proof lane
- Added `verify_inbox` CI job mirroring `verify_mailglass` Postgres setup with no sibling checkout
- Extended release gate contract and MAINTAINING.md from seven-gate septet to eight-gate octet; ci-gate now aggregates nine lanes

## Task Commits

Each task was committed atomically:

1. **Task 1: Add verify.inbox alias to mix.exs (D-16)** - `d1a362c` (feat)
2. **Task 2: Add verify_inbox CI job and ci-gate aggregation (D-17)** - `29c7f7a` (feat)
3. **Task 3: Update release_gate_contract and MAINTAINING octet (D-18, D-19)** - `e9b1f10` (feat)

**Plan metadata:** pending (docs commit)

## Files Created/Modified

- `mix.exs` - Added `verify.inbox` alias after `verify.accrue`; removed Phase 62 deferral comment on verify.example inbox lane
- `.github/workflows/ci.yml` - Added `verify_inbox` job; extended ci-gate needs/env/loop with VERIFY_INBOX
- `test/chimeway/release_gate_contract_test.exs` - Eight-gate MAINTAINING assertion; nine ci-gate lanes; verify.inbox pre-ship tuple
- `MAINTAINING.md` - Pre-ship octet with `mix verify.inbox` command and GATE-05 Inbox description

## Decisions Made

- Followed verify_mailglass CI template exactly — Postgres 15, same action SHA pins, in-repo path deps only
- Pre-ship checklist counts eight verify gates; ci-gate counts nine lanes (includes lint/test/verify_gates/verify_docs)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Verification Results

| Command | Result |
|---------|--------|
| `mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | 29 tests, 0 failures |
| `mix verify.inbox --warnings-as-errors` | 6 package + 2 demo inbox tests, 0 failures |
| `mix ci.verify_gates --warnings-as-errors` | 239 tests, 0 failures |
| Task 1 grep acceptance | PASS |
| Task 2 grep acceptance (no ACCRUE_PATH in verify_inbox) | PASS |

## Self-Check: PASSED

- Key files exist on disk
- Three task commits with `62-03` grep match
- All acceptance criteria re-run and pass

## Next Phase Readiness

- 62-02 (inbox integration guide + doc-contract) unblocked on demo artifacts and `mix verify.inbox` gate
- Phase 62 Wave 1 complete (62-01 + 62-03); Wave 2 guide work ready

---
*Phase: 62-inbox-demo-docs-gate*
*Completed: 2026-05-30*
