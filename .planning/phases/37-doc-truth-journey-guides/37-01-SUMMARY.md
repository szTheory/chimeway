---
phase: 37-doc-truth-journey-guides
plan: "01"
subsystem: docs
tags: [workflow, wait_until, notifier, signals, oban, doc-truth]

requires:
  - phase: 36-golden-path-version-alignment
    provides: Chimeway.trigger/3 golden-path pattern and webhook appendix cross-link
provides:
  - Engine-accurate multi-step journey guide with Notifier workflow/2 authoring surface
  - wait_until/on_outcome/stop progress rule documentation
  - Delivery-feedback signal routing path with demo E2E cross-links
  - Explicit READ milestone deferral for read-to-cancel (INV-002 doc-truth resolution)
affects: [37-02, 37-03, 38-reference-recipes]

tech-stack:
  added: []
  patterns:
    - "Doc-truth: forbid aspirational API strings even in negation prose (grep gates)"
    - "Primary journey story is wait_until time escalation, not inbox-read cancellation"

key-files:
  created: []
  modified:
    - guides/flows/multi-step-journeys.md

key-decisions:
  - "Negative mentions of forbidden APIs rephrased to pass grep gates (e.g. 'standalone workflow behaviour module' instead of naming Chimeway.Workflow)"
  - "INV-002 resolved via doc-truth in guide Deferred section; pending_signals engine gap documented honestly"

patterns-established:
  - "Journey guide anchored on workflow_progression_test.exs fixture with 7200s wait_until delay"
  - "Signal.track/4 documented tenant-first argument order with chimeway.delivery.* event names"

requirements-completed: [DOCS-03]

duration: 15min
completed: 2026-05-29
---

# Phase 37 Plan 01: Journey Guide Rewrite Summary

**Full rewrite of multi-step-journeys.md to Notifier workflow/2 with wait_until escalation, correct trigger/signal APIs, and explicit READ milestone deferral**

## Performance

- **Duration:** 15 min
- **Started:** 2026-05-29T00:10:00Z
- **Completed:** 2026-05-29T00:24:43Z
- **Tasks:** 3 completed
- **Files modified:** 1

## Accomplishments

- Replaced fictional `Chimeway.Workflow` / `stop_conditions` / wait-step DSL with Notifier `workflow/2` and `config["progress"]` rule kinds
- Primary scenario documents time-based in_app → email escalation via `wait_until` (`prior_delivery_terminal_at`, `delay_seconds: 7200`)
- Added trigger, waiting state, inspection (`explain/2`, `list_traces/2`), delivery-feedback signal routing, and Deferred READ-01/READ-02 callout
- `mix ci.docs` passes; all plan grep acceptance criteria green

## Task Commits

Each task was committed atomically:

1. **Task 37-01-01: Rewrite guide scaffold and workflow definition (sections 1–2)** - `5f10902` (docs)
2. **Task 37-01-02: Trigger, waiting state, and operator inspection (sections 3–5)** - `38aa12e` (docs)
3. **Task 37-01-03: Signal routing, delivery feedback, and Deferred callout (sections 6–8)** - `708c757` (docs)

**Plan metadata:** `0286666` (docs: complete plan)

## Files Created/Modified

- `guides/flows/multi-step-journeys.md` — Full engine-accurate journey guide (~198 lines); DOCS-03 #1 and #2 satisfied for guide content

## Decisions Made

- Rephrased negation prose to avoid forbidden grep strings (`Chimeway.Workflow`, `stop_conditions`, `PT2H`, `type: :wait`) while preserving honest "these don't exist" messaging
- Kept `notification_read` out of guide entirely rather than mentioning only in Deferred — cleaner INV-002 resolution

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Verification

| Check | Result |
|-------|--------|
| Task 1 grep gates (forbid Workflow/stop_conditions/PT2H) | PASS |
| Task 2 grep gates (Chimeway.trigger, no Trigger.trigger) | PASS |
| Task 3 grep gates (Signal.track, SignalRouterWorker, Deferred) | PASS |
| `mix ci.docs` | PASS (exit 0) |

## Self-Check: PASSED

## Next Phase Readiness

- Ready for **37-02** — fix `guides/recipes/oban-integration.md` worker paths and queue/cron guidance (D-13, D-14)
- **37-03** follows — doc-contract test extension and validation checklist status update
- DOCS-03 #3 (automated doc-contract test) remains for plan 37-03

---
*Phase: 37-doc-truth-journey-guides*
*Completed: 2026-05-29*
