---
phase: 50-natural-escalation-demo
plan: 01
subsystem: demo
tags: [elixir, workflow, read-signals, journey-tests]

requires:
  - phase: 48-wait-until-pending-signals
    provides: cancel_signals → pending_signals at enter_waiting/6
  - phase: 49-inbox-read-signal
    provides: Chimeway.mark_read/3 inbox signal emission
provides:
  - READ-driven PaymentReminder workflow with wait_until + cancel_signals
  - Trigger-only escalation seed without webhook choreography
  - JOUR-03 proof of mark_read → signal → resume
affects: [50-02, mention-escalation-recipe]

tech-stack:
  added: []
  patterns:
    - "Demo seeds use Chimeway.trigger/3 only — no manual Workflows.update_run/3 for pending_signals"
    - "Journey tests call Chimeway.mark_read/3 public API — no host Signal.track glue"

key-files:
  created: []
  modified:
    - examples/chimeway_demo_host/lib/demo_host/notifiers/payment_reminder.ex
    - examples/chimeway_demo_host/lib/demo_host/seeds.ex
    - examples/chimeway_demo_host/test/demo_host_web/journey_test.exs
  deleted:
    - examples/chimeway_demo_host/lib/demo_host/adapters/pending_webhook_adapter.ex

key-decisions:
  - "PaymentReminder uses 7200s wait_until with chimeway.notification.read cancel signal"
  - "Deleted PendingWebhookAdapter without deprecation shim per D-05"

patterns-established:
  - "TeamPulse escalation demo proves READ-driven progression in CI via JOUR-03"

requirements-completed: [DEMO-03]

duration: 15min
completed: 2026-05-29
---

# Phase 50 Plan 01 Summary

**TeamPulse payment escalation demo now proves READ-driven workflow progression — no staged webhook choreography.**

## Performance

- **Duration:** ~15 min
- **Tasks:** 4/4
- **Files modified:** 4 (1 deleted)

## Accomplishments

- Reshaped `PaymentReminder.workflow/2` with `wait_until` + `cancel_signals: ["chimeway.notification.read"]` and `email_escalation` step
- Simplified `seed_escalation_waiting/0` to trigger-only — removed `stage_escalation_webhook/1` and adapter swap
- Deleted `PendingWebhookAdapter` seed fixture
- Rewrote JOUR-03 to assert natural `:waiting` state, `mark_read`, signal emission, and `signal_received` transition

## Task Commits

1. **Task 1: PaymentReminder workflow** - `6fb05ec` (feat)
2. **Task 2: Seeds trigger-only** - `a1e072a` (feat)
3. **Task 3: Delete PendingWebhookAdapter** - `e708774` (feat)
4. **Task 4: Rewrite JOUR-03** - `7845309` (test)

## Files Created/Modified

- `examples/chimeway_demo_host/lib/demo_host/notifiers/payment_reminder.ex` — READ-driven wait_until workflow
- `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — trigger-only escalation seed
- `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` — JOUR-03 mark_read proof
- `examples/chimeway_demo_host/lib/demo_host/adapters/pending_webhook_adapter.ex` — deleted

## Self-Check: PASSED

- `mix verify.journeys` — green (5 tests)
- `mix test test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — green (webhook regression unchanged)
- `rg "stage_escalation_webhook|PendingWebhookAdapter" examples/chimeway_demo_host/` — no matches

## Deviations

None.
