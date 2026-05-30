---
phase: 58-accrue-dunning-core
plan: 03
subsystem: integrations
tags: [accrue, chimeway, dunning, outcome-signal, invoice.paid, ecos-06]

requires:
  - phase: 58-accrue-dunning-core
    plan: 02
    provides: DunningNotifier workflow with cancel_signals + start-path integration tests
provides:
  - cancel_campaign/3 emits canonical invoice.paid Outcome Signal (customer email actor)
  - DefaultHandler invoice.paid recovery finalizes dunning via cancel_campaign/3
  - Accrue-side signal shape unit test + Chimeway terminate-path E2E
affects: [59-accrue-blueprint-demo, 60-accrue-docs-release-gates]

tech-stack:
  added: []
  patterns:
    - "Accrue.ChimewayTestSupport bootstraps Chimeway.Repo in Accrue test suite"
    - "Terminate proof via Accrue.Test.trigger_event(:invoice_paid) + Oban.drain_queue(:chimeway_signals)"

key-files:
  created:
    - ../accrue/accrue/test/support/chimeway_test_support.ex
  modified:
    - ../accrue/accrue/lib/accrue/integrations/chimeway.ex
    - ../accrue/accrue/lib/accrue/webhook/default_handler.ex
    - ../accrue/accrue/test/accrue/integrations/chimeway_test.exs
    - ../accrue/accrue/config/test.exs
    - test/chimeway/integrations/accrue_dunning_lifecycle_test.exs
    - test/support/accrue/fixtures.ex

key-decisions:
  - "cancel_campaign/3 actor_id = customer.email matches DunningNotifier recipient_identity (D-09)"
  - "DefaultHandler maybe_recover_dunning_on_invoice_paid backstops anchor clear + cancel stash"
  - "ChimewayTestSupport stops stale Repo before reconfiguring — prevents missing :database flakes"

patterns-established:
  - "Pattern: start_dunning_and_wait!/0 + trigger_invoice_paid_event! for terminate describe setup"
  - "Pattern: accrue config/test.exs pre-seeds Chimeway.Repo database before :chimeway auto-start"

requirements-completed: [ECOS-06]

duration: 35min
completed: 2026-05-30
---

# Phase 58 Plan 03: Accrue Dunning Termination Summary

**Fixed v1.40 silent cancel no-op by emitting `invoice.paid` with customer email actor; integration tests prove payment recovery terminates waiting dunning runs, blocks escalation, and records explainable `signal_received` transitions.**

## Performance

- **Duration:** 35 min (includes interrupted session resume)
- **Started:** 2026-05-30T22:30:00Z
- **Completed:** 2026-05-30T09:12:00Z
- **Tasks:** 3
- **Files modified:** 7 (2 repos)

## Accomplishments

- Replaced `cancel_campaign/3` `payment_recovered` / `accrue.dunning` actor with canonical `Chimeway.Signal.track/4` using `invoice.paid` and customer email.
- Wired `DefaultHandler` invoice.paid recovery to finalize dunning campaigns and invoke `cancel_campaign/3` post-commit.
- Added Accrue unit test locking signal shape plus Chimeway terminate describe (4 tests) via webhook synthetic path and Oban signal drain.

## Task Commits

1. **Task 1–2: cancel_campaign fix + Accrue tests + test support** — `0e95e5f5` (Accrue feat)
2. **Task 3: Terminate-path integration tests** — `7aac06c` (Chimeway test)

**Plan metadata:** this commit

## Files Created/Modified

- `../accrue/accrue/lib/accrue/integrations/chimeway.ex` — D-09 cancel_campaign Outcome Signal
- `../accrue/accrue/lib/accrue/webhook/default_handler.ex` — invoice.paid dunning recovery
- `../accrue/accrue/test/support/chimeway_test_support.ex` — Chimeway.Repo bootstrap for Accrue tests
- `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs` — terminate describe (4 tests)

## Deviations from Plan

- **DefaultHandler recovery hook** — Added `maybe_recover_dunning_on_invoice_paid/2` so `Accrue.Test.trigger_event(:invoice_paid)` reaches `cancel_campaign/3` through the webhook path (required for D-12 primary proof).
- **Accrue config/test.exs Chimeway.Repo** — Pre-configures database before `:chimeway` auto-start to avoid missing `:database` connection errors in Accrue-side tests.
- **ChimewayTest module async: false** — Required for shared SQL sandbox across Accrue + Chimeway repos in cancel_campaign describe.

## Self-Check: PASSED

- [x] `mix verify.accrue --warnings-as-errors` — 11 tests, 0 failures
- [x] `mix ci.test` — 743 tests, 0 failures
- [x] `CHIMEWAY_PATH=... mix test test/accrue/integrations/chimeway_test.exs` — 4 tests, 0 failures
- [x] `mix test test/chimeway/workflows_test.exs` — 13 tests, 0 failures (T-27-03 regression)
- [x] No `payment_recovered` in cancel_campaign/3

## Next Phase

Phase 58 library-level ECOS-06 complete. Ready for Phase 59 (Accrue blueprint demo) or Phase 60 (docs/release gates).
