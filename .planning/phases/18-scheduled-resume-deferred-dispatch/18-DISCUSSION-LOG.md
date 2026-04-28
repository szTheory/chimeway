# Phase 18: Scheduled Resume & Deferred Dispatch - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-28T11:24:40Z
**Phase:** 18-Scheduled Resume & Deferred Dispatch
**Mode:** assumptions
**Areas analyzed:** Resume Source of Truth, Resume Execution Path, Identity and Trace Continuity, Duplicate Prevention and Final Convergence

## Assumptions Presented

### Resume Source of Truth
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 18 should schedule resumes directly from existing `chimeway_deliveries` rows using `orchestration_state == :deferred` plus `next_eligible_at`, rather than introducing a separate scheduling table as the primary source of truth. | Confident | `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md`, `.planning/phases/17-delivery-windows-deferral-semantics/17-VALIDATION.md`, `lib/chimeway/delivery.ex`, `priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` |

### Resume Execution Path
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Scheduled resume should transition the existing deferred delivery back to a dispatchable `:ready` state and then reuse the normal Oban worker execution path for that same delivery row. | Likely | `lib/chimeway/dispatch/sync.ex`, `lib/chimeway/dispatch/oban.ex`, `lib/chimeway/dispatch/oban_worker.ex`, `.planning/phases/17-delivery-windows-deferral-semantics/17-03-PLAN.md` |

### Identity and Trace Continuity
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Resume jobs should continue to identify work by `delivery_id` only and must not create replacement delivery rows or move correlation identity into ad hoc scheduler payloads. | Confident | `lib/chimeway/deliveries.ex`, `lib/chimeway/traces.ex`, `lib/chimeway/traces/explanation.ex`, `lib/chimeway/dispatch/oban_worker.ex`, `test/chimeway/integration/delivery_lifecycle_test.exs` |

### Duplicate Prevention and Final Convergence
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 18 needs resume idempotency on the existing delivery row, with durable state transitions preventing multiple resume jobs from producing duplicate sends and ensuring resumed or superseded rows land in one final durable outcome. | Likely | `lib/chimeway/deliveries.ex`, `test/chimeway/orchestration/delivery_planning_test.exs`, `lib/chimeway/dispatch/oban_worker.ex`, `test/chimeway/orchestration/dispatch_gating_test.exs`, `test/chimeway/integration/delivery_lifecycle_test.exs` |

## Corrections Made

No corrections — all assumptions confirmed.
