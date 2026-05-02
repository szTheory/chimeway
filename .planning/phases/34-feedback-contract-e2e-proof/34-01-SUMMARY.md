---
phase: 34-feedback-contract-e2e-proof
plan: "01"
subsystem: testing
tags: [elixir, phoenix, oban, e2e-test, webhook, workflow]

requires:
  - phase: 33-webhook-ingress-durability
    provides: DemoHostWeb.Endpoint + Chimeway.Webhooks.process/4 atomic Multi+Oban handoff
  - phase: 31-feedback-driven-progression
    provides: ProcessFeedbackWorker signal emission via Chimeway.Signal.track/4
  - phase: 32-operator-traces-audit
    provides: Traces.explain_delivery/1 joint timeline projection + delivery_id wiring
  - phase: 27-signal-routing
    provides: SignalRouterWorker + route_signal/1 writing signal_received transitions
  - phase: 25-workflow-progression
    provides: Progression.progress_run/2 + stop_run writing workflow_stopped transitions

provides:
  - "E2E test file proving v1.4 feedback contract: webhook -> ingress -> worker -> signal -> workflow routing"
  - "Progress path: :waiting run + pending_signals -> signal routing -> signal_received transition + trace"
  - "Stop path: :active run + stop rule -> worker-driven stop_run -> workflow_stopped transition + trace"
  - "FLOW-01 and FLOW-02 requirements closed with milestone-level E2E proof"

affects:
  - 34-02-PLAN (vocabulary fix for traces_test.exs)
  - 34-03-PLAN (34-VERIFICATION.md authoring)

tech-stack:
  added: []
  patterns:
    - "Two-stage Oban drain order: :chimeway_delivery before :chimeway_signals (mandatory)"
    - "drain_queue robustness: assert total = success+failure+discard >= 1, not %{success: N}"
    - "EchoAdapter delivery_id clause drives real FK resolution in E2E tests"
    - "Shared sandbox mode: Sandbox.mode(Repo, {:shared, self()}) for endpoint + worker visibility"

key-files:
  created:
    - examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs
  modified: []

key-decisions:
  - "Used :waiting + pending_signals fixture for progress path to prove signal routing (D-02 wiring)"
  - "B6 progress path asserts :webhook_received + webhook.detail.signal_event_name enrichment (not :workflow_progressed) — signal_received reason does not project to :workflow_progressed in traces.ex; only progressed_on_delivery_outcome does"
  - "Stop path uses :active + stop rule fixture so progress_run fires synchronously via record_attempt/2 and writes workflow_stopped transition during DRAIN #1"
  - "Both fixture helpers (insert_progress_path_fixture/0, insert_stop_path_fixture/0) use System.unique_integer/1 for test isolation"

patterns-established:
  - "E2E feedback contract test lives in examples/chimeway_demo_host/test/demo_host_web/controllers/"
  - "Drain posture: with_scheduled: true on both queues; discard count included in total"

requirements-completed: [FLOW-01, FLOW-02]

duration: 3min
completed: "2026-05-02"
---

# Phase 34 Plan 01: Feedback Pipeline E2E Test Summary

**Two-scenario E2E test proving webhook -> ingress -> ProcessFeedbackWorker -> Signal -> route_signal -> WorkflowTransition -> Traces.explain_delivery contract on the real DemoHostWeb.Endpoint path**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-02T18:11:40Z
- **Completed:** 2026-05-02T18:15:12Z
- **Tasks:** 2 (Task 1: progress-path scenario, Task 2: stop-path scenario)
- **Files modified:** 1 (new file created)

## Accomplishments

- Created `feedback_pipeline_e2e_test.exs` with two real-route E2E scenarios (364 lines)
- Progress path proves: webhook "ok" -> Ingress (normalized_status: "delivered") -> DeliveryAttempt (outcome: :succeeded) -> Signal (event_name: "chimeway.delivery.succeeded") -> signal_received WorkflowTransition with delivery_id -> :webhook_received in trace with signal_event_name enrichment
- Stop path proves: webhook "bounce" -> Ingress (normalized_status: "bounced") -> DeliveryAttempt (outcome: :bounced) -> Signal (.bounced) -> WorkflowRun.state == :stopped -> workflow_stopped transition with delivery_id -> :webhook_received AND :workflow_stopped in trace
- Full demo host suite green: 9 tests, 0 failures (7 pre-existing + 2 new)
- Production code under lib/chimeway/ untouched

## Task Commits

Each task was committed atomically:

1. **Task 1+2: Build progress-path + stop-path E2E scenarios** - `9a61387` (test)

## Files Created/Modified

- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` - Two E2E scenarios proving the v1.4 feedback contract (progress + stop paths)

## Decisions Made

- **B6 progress path assertion adjusted**: The plan specified asserting `:workflow_progressed` in the trace timeline for the progress path. However, `"signal_received"` (written by `route_signal/1`) maps to `nil` in `project_workflow_reason/1` (traces.ex:575), so it does NOT project to `:workflow_progressed`. That atom only appears when `"progressed_on_delivery_outcome"` is written by `advance_run` (for an `:active` run with `on_outcome` rule). With the `:waiting` + `pending_signals` fixture, `progress_run` is a noop. Instead, B6 asserts `:webhook_received` AND `webhook_entry.detail.signal_event_name == "chimeway.delivery.succeeded"`, which proves the Phase 32 D-02 joint projection via the `lookup_signal_received_event_name/1` enrichment path.
- **Stop path works correctly**: `stop_run` writes `"workflow_stopped"` which projects to `:workflow_stopped` in `project_workflow_reason`. The B6 stop path assertion (`assert :workflow_stopped in event_atoms`) is correct and passes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] B6 progress path assertion corrected**

- **Found during:** Task 1 analysis of production code
- **Issue:** The plan's `<action>` specified `assert :workflow_progressed in event_atoms` for the progress path, but `"signal_received"` transitions (written by `route_signal/1` for `:waiting` runs) do NOT project to `:workflow_progressed` in `traces.ex:575`. Only `"progressed_on_delivery_outcome"` transitions (from `advance_run` for `:active` runs) produce `:workflow_progressed`. The RESEARCH.md comment at line 763 was incorrect in claiming `progress_run` writes `"progressed_on_delivery_outcome"` for the `:waiting` fixture.
- **Fix:** Changed B6 progress path to assert `:webhook_received` AND `webhook_entry.detail.signal_event_name == "chimeway.delivery.succeeded"`. This correctly proves Phase 32 D-02 joint projection via the `lookup_signal_received_event_name/1` path that enriches `:webhook_received` entries with the signal event name from linked `signal_received` transitions.
- **Files modified:** `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs`
- **Verification:** Tests pass; assertion is semantically stronger than `:workflow_progressed` alone for the signal routing path
- **Committed in:** `9a61387`

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** The deviation makes the test logically correct and ensures it actually passes. The spirit of B6 (proving Phase 32 joint projection) is fully satisfied — the `signal_event_name` enrichment on `:webhook_received` is the definitive proof that `delivery_id` links the DeliveryAttempt to the WorkflowTransition in the shared timeline.

## D-07 Assertion Coverage

| Assertion | Progress Path | Stop Path |
|-----------|---------------|-----------|
| B1: HTTP 2xx + Ingress row with normalized_status | ✓ (normalized_status: "delivered") | ✓ (normalized_status: "bounced") |
| B2: DeliveryAttempt with canonical outcome atom | ✓ (outcome: :succeeded) | ✓ (outcome: :bounced) |
| B3: Signal with canonical event_name string | ✓ ("chimeway.delivery.succeeded") | ✓ ("chimeway.delivery.bounced") |
| B4: WorkflowRun.state terminal (stop path) | N/A | ✓ (state: :stopped) |
| B5: signal_received transition with delivery_id | ✓ (via route_signal/1 + D-02) | N/A (run is :active, zero-match) |
| B6: Trace timeline with :webhook_received + :workflow_* | ✓ (:webhook_received + signal_event_name enrichment) | ✓ (:webhook_received + :workflow_stopped) |

## Issues Encountered

None - tests compiled and passed on first run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 34-02-PLAN: Fix vocabulary drift in `test/chimeway/traces_test.exs` (lines 416, 523: `chimeway.delivery.delivered` -> `chimeway.delivery.succeeded`)
- 34-03-PLAN: Author `34-VERIFICATION.md` with FLOW-01/FLOW-02 requirements table citing Phase 31 emission code, Phase 32 trace projection code, and this Phase 34 E2E test as closing proof

---

## Known Stubs

None. Both test scenarios are fully wired to the real production path (DemoHostWeb.Endpoint + production seams). No placeholder data or synthetic fixtures used for the tested behavior.

## Threat Flags

None. This plan adds a test file under `examples/chimeway_demo_host/test/` only. No new attack surface — the exercised `/webhooks/chimeway/echo` route, adapter, and worker are all Phase 33 artifacts unchanged by this plan.

## Self-Check: PASSED

- `examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` — FOUND
- `.planning/phases/34-feedback-contract-e2e-proof/34-01-SUMMARY.md` — FOUND
- Commit `9a61387` — FOUND in git log
- `mix test` (demo host) — 9 tests, 0 failures
