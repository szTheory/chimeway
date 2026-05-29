# Phase 49: Inbox Read → Signal - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 49-Inbox Read → Signal
**Mode:** assumptions
**Areas analyzed:** Implementation seam, Tenant resolution, Read vs seen semantics, Signal payload, Idempotent emission, Transaction coupling, READ-03 / route_signal behavior, Doc-truth

## Assumptions Presented

### Implementation seam
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Wire signal emission inside `Chimeway.Inbox` after successful lifecycle update, calling `Signal.track/4` | Likely | `lib/chimeway/inbox.ex`, `lib/chimeway/webhooks/process_feedback_worker.ex` `emit_signal/2`, `lib/chimeway.ex` facade |

### Tenant resolution
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Resolve `tenant_id` via notification → workflow_run join (preferred), fallback to first delivery row | Unclear | `Notification` has no `tenant_id`; `WorkflowRun` and `Delivery` store it from `trigger/3`; `route_signal/1` matches on `workflow_run.tenant_id` |

### Read vs seen semantics
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Emit distinct signals — no cross-emission between read and seen | Confident | `test/chimeway/inbox_state_transition_test.exs` (INBX-02/03), `guides/flows/multi-step-journeys.md` |

### Signal payload
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Payload `%{"notification_id" => notification_id}`; traces show event name only | Likely | `lib/chimeway/workflows.ex` `route_signal/1` transition context; webhook `delivery_id` payload pattern |

### Idempotent emission
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Emit only on first transition (nil → timestamp); no signal on re-mark | Likely | `update_lifecycle_timestamp` `{0,_}` no-op; `route_signal/1` idempotency |

### Transaction coupling
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Inbox update first, then `Signal.track/4` in separate transaction | Confident | `lib/chimeway/signal.ex` Multi pattern; feedback worker emit-after-primary-work |

### READ-03 / route_signal behavior
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No changes to `route_signal/1` — existing `signal_received` transition satisfies READ-03 | Confident | Phase 48 D-07; `workflow_progression_test.exs` injected signal proof |

### Doc-truth
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Update journey guide — remove READ-02 deferral; extend doc-contract tests | Likely | Phase 48-03 pattern; journey guide still defers READ-02 |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

None required — codebase provided sufficient evidence.
