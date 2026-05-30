---
phase: 58-accrue-dunning-core
plan: 02
subsystem: integrations
tags: [accrue, chimeway, dunning, workflow, cancel_signals, ecos-06]

requires:
  - phase: 58-accrue-dunning-core
    plan: 01
    provides: Accrue selective CI harness, fixtures, trigger_event path
provides:
  - DunningNotifier workflow/2 (48h escalation) + rendering/2 in Accrue sibling repo
  - Accrue-side behaviour tests for workflow contract normalization
  - Chimeway start-path integration tests (payment_failed → WorkflowRun + pending_signals)
affects: [58-03, 59-accrue-blueprint-demo, 60-accrue-docs-release-gates]

tech-stack:
  added: []
  patterns:
    - "Cross-repo CHIMEWAY_PATH override for Accrue integration tests against local spine"
    - "trigger_event primary proof path — no direct Chimeway.trigger in ECOS-06 start describe"

key-files:
  created:
    - test/chimeway/integrations/accrue_dunning_lifecycle_test.exs
  modified:
    - ../accrue/accrue/lib/accrue/integrations/chimeway.ex
    - ../accrue/accrue/test/accrue/integrations/chimeway_test.exs
    - ../accrue/accrue/mix.exs
    - test/support/accrue/fixtures.ex

key-decisions:
  - "Keep orchestration/2 as {:ok, :immediate} — workflow runs created independently via workflow/2 (OQ-2)"
  - "CHIMEWAY_PATH env override in Accrue mix.exs for cross-repo dev against cancel_signals spine"
  - "cancel_campaign/3 unchanged — invoice.paid signal fix deferred to 58-03 (D-09)"

patterns-established:
  - "Pattern: drain_initial_email_delivery! + progress_to_waiting! helpers for workflow progression tests"
  - "Pattern: list_dunning_runs! query joins WorkflowRun + WorkflowDefinition by accrue.dunning key"

requirements-completed: [ECOS-06]

duration: 25min
completed: 2026-05-30
---

# Phase 58 Plan 02: Accrue Dunning Start Path Summary

**Multi-step `accrue.dunning` workflow with 48h escalation and `invoice.paid` cancel_signals; integration tests prove `invoice.payment_failed` → WorkflowRun start with explainable trace and `:waiting` pending_signals after first email delivery.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-05-30T22:04:00Z
- **Completed:** 2026-05-30T22:29:00Z
- **Tasks:** 3
- **Files modified:** 5 (2 repos)

## Accomplishments

- Upgraded Accrue `DunningNotifier` from v1.40 email-only to two-step workflow (initial_email → 48h wait_until → escalation_email) with `rendering/2` for trigger path.
- Added Accrue-side contract tests asserting `workflow/2`/`rendering/2` export and `cancel_signals: ["invoice.paid"]` normalization.
- Delivered Chimeway `@moduletag :accrue` lifecycle tests proving ECOS-06 start path via `Accrue.Test.trigger_event/2` — WorkflowRun creation, idempotency, and pending_signals after progression.

## Task Commits

Each task was committed atomically:

1. **Task 1: Accrue DunningNotifier workflow/2 + rendering/2** — `ad9ff10b` (Accrue feat)
2. **Task 2: Accrue-side behaviour tests** — `d71bb485` (Accrue test)
3. **Task 3: Start-path integration tests** — `30e67d5` (Chimeway test)

**Plan metadata:** pending (this commit)

## Files Created/Modified

- `../accrue/accrue/lib/accrue/integrations/chimeway.ex` — workflow/2, rendering/2; Phase 58 moduledoc
- `../accrue/accrue/test/accrue/integrations/chimeway_test.exs` — workflow contract describe
- `../accrue/accrue/mix.exs` — CHIMEWAY_PATH path dep override
- `test/support/accrue/fixtures.ex` — trigger/drain/progress helpers
- `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs` — 3 start-path integration tests

## Decisions Made

- Kept `orchestration/2` → `{:ok, :immediate}` per RESEARCH OQ-2 — workflow runs created via `workflow/2` independently.
- Added `CHIMEWAY_PATH` override in Accrue mix.exs so integration tests use local Chimeway with `cancel_signals` normalization (hex ~> 1.0 lacks spine).
- Left `cancel_campaign/3` unchanged — Wave 58-03 owns `invoice.paid` signal emission fix.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] CHIMEWAY_PATH override required for Accrue repo tests**
- **Found during:** Task 2 verification (`mix test chimeway_test.exs`)
- **Issue:** Hex `chimeway ~> 1.0` rejects `cancel_signals` in wait_until rules (`{:mixed_rule_shape, ["cancel_signals"]}`)
- **Fix:** Added `chimeWAY_dep/0` helper with `CHIMEWAY_PATH` path override; tests run with local Chimeway sibling
- **Files modified:** `accrue/mix.exs`
- **Verification:** `CHIMEWAY_PATH=/Users/jon/projects/chimeway mix test ...` — 3 tests, 0 failures
- **Committed in:** `ad9ff10b`

---

**Total deviations:** 1 auto-fixed (missing critical)
**Impact:** Required for Accrue-side workflow normalization tests against v1.7+ cancel_signals spine. No scope creep.

## Issues Encountered

None blocking. Accrue repo has unrelated `.planning/` deletions in working tree — not staged for 58-02 commits.

## User Setup Required

Cross-repo dev requires path deps on both sides:
- Chimeway: `ACCRUE_PATH=/path/to/accrue/accrue mix deps.get`
- Accrue: `CHIMEWAY_PATH=/path/to/chimeway mix deps.get`

## Verification Results

| Check | Result |
|-------|--------|
| `CHIMEWAY_PATH=... mix test test/accrue/integrations/chimeway_test.exs --warnings-as-errors` (Accrue) | PASS (3 tests, 0 failures) |
| `ACCRUE_PATH=... mix verify.accrue` (Chimeway) | PASS (7 tests, 0 failures) |
| `mix ci.test` (Chimeway, excludes :accrue) | PASS (743 tests, 0 failures) |
| `grep workflow/2 accrue chimeway.ex` | PASS |
| `grep 172_800 accrue chimeway.ex` | PASS |
| No `Chimeway.Adapter` added | PASS |
| `cancel_campaign/3` unchanged | PASS |

## Self-Check: PASSED

## Next Phase Readiness

- Ready for 58-03: fix `cancel_campaign/3` to emit `invoice.paid` with `actor_id = customer.email`; add terminate describe to lifecycle test.
- Start-path ROADMAP SC #1 satisfied; termination proof (SC #2) remains Wave 58-03.

---
*Phase: 58-accrue-dunning-core*
*Completed: 2026-05-30*
