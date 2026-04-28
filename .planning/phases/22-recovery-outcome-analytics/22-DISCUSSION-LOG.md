# Phase 22: Recovery & Outcome Analytics - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-28
**Phase:** 22-recovery-outcome-analytics
**Mode:** assumptions
**Areas analyzed:** Reconciliation Mechanism, Stuck Delivery Detection, Aggregate Outcomes API, Outcome Aggregation Data Source

## Assumptions Presented

### Reconciliation Mechanism
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Reconciliation will recover "stuck" deliveries by re-enqueuing them to the dispatcher and mutating the canonical delivery rows in place, without deleting or replacing them. | Confident | lib/chimeway/deliveries.ex |

### Stuck Delivery Detection
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Detection of undispatched persisted deliveries will rely on querying Chimeway's schema state (e.g., status == :pending and orchestration_state == :ready past a safe time threshold) without interrogating the Oban queue. | Likely | .planning/phases/20-digest-emission-explainability/20-CONTEXT.md, lib/chimeway/deliveries.ex |

### Aggregate Outcomes API
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Aggregate query capabilities will be implemented as new functions within Chimeway.Traces rather than introducing a separate top-level module (like Chimeway.Analytics). | Confident | lib/chimeway/traces.ex |

### Outcome Aggregation Data Source
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Outcome analytics will aggregate directly over chimeway_deliveries.status, chimeway_deliveries.orchestration_state, and chimeway_deliveries.suppression_reason rather than traversing the chimeway_delivery_attempts history. | Confident | lib/chimeway/deliveries.ex |

## Corrections Made

No corrections — all assumptions confirmed.
