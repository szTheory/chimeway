# Phase 08: trigger-dispatch-outcome-surfacing - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the assumptions analysis.

**Date:** 2026-04-24
**Phase:** 08-trigger-dispatch-outcome-surfacing
**Mode:** assumptions
**Areas analyzed:** Trigger API Contract Envelope, Dispatch Failure Propagation Boundary, Sync vs Oban Outcome Parity Semantics, Trace Correlation Fields in Caller Outcome, Duplicate Trigger Semantics vs Outcome Surfacing

## Assumptions Presented

### Trigger API Contract Envelope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep trigger top-level tuples (`{:ok, map} | {:duplicate, event} | {:error, reason}`) and enrich the `{:ok, map}` payload for dispatch/enqueue outcomes. | Likely | `lib/chimeway/trigger.ex`, `lib/chimeway.ex`, `test/chimeway/trigger_pipeline_test.exs`, `test/chimeway/integration/delivery_lifecycle_test.exs` |

### Dispatch Failure Propagation Boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Trigger should surface dispatch/enqueue failures as structured caller-visible outcomes instead of logging and swallowing them. | Confident | `lib/chimeway/trigger.ex`, `.planning/ROADMAP.md` (Phase 08 success criteria), `lib/chimeway/dispatch/sync.ex`, `lib/chimeway/dispatch/oban.ex` |

### Sync vs Oban Outcome Parity Semantics
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Parity should be stage-aware: sync reports immediate execution outcomes; Oban reports enqueue acceptance and durable references for later execution traces. | Likely | `lib/chimeway/dispatch/sync.ex`, `lib/chimeway/dispatch/oban.ex`, `lib/chimeway/dispatch/oban_worker.ex`, `test/chimeway/dispatch/oban_test.exs`, `test/chimeway/dispatch/oban_transactional_test.exs` |

### Trace Correlation Fields in Caller Outcome
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Caller-visible outcomes should include durable correlation pointers (`event_id`, `correlation_id`, delivery/job IDs when available). | Confident | `lib/chimeway/events/event.ex`, `lib/chimeway/traces.ex`, `test/chimeway/traces_test.exs` |

### Duplicate Trigger Semantics vs Outcome Surfacing
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Duplicate idempotency calls remain non-dispatching/non-enqueuing; any surfaced details should point to existing durable rows. | Likely | `lib/chimeway/trigger.ex`, `test/chimeway/integration/delivery_lifecycle_test.exs` (Scenario C) |

## Corrections Made

No corrections - all assumptions confirmed.

