# Phase 37: Doc Truth & Journey Guides - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-28
**Phase:** 37-doc-truth-journey-guides
**Mode:** assumptions
**Areas analyzed:** INV-002 resolution, Journey guide rewrite, Escalation example framing, Signal routing documentation, Doc-contract verification, Related doc fixes (Oban worker names)

## Assumptions Presented

### INV-002 resolution — doc-truth, not engine
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fix journey guide to match engine; do NOT implement `pending_signals` in `enter_waiting/6` | Confident | `.planning/REQUIREMENTS.md` deferral table; `lib/chimeway/workflows/progression.ex:251-273` |

### Journey guide full rewrite
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Rewrite using Notifier `workflow/2`, `config["progress"]` rules, `Chimeway.trigger/3`, correct `Signal.track/4`; remove fictional APIs | Confident | `test/chimeway/orchestration/workflow_progression_test.exs:40-74`; no `Chimeway.Workflow` module |

### Escalation example (time-based, not read-to-cancel)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Primary example: in_app → wait_until → email; read-to-cancel moved to Deferred callout | Confident | Assessment thread; `workflows_test.exs:190-195` (manual pending_signals in tests) |

### Signal routing documentation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Document delivery-feedback signals as working path; generic routing requires host wiring for pending_signals | Likely | `feedback_pipeline_e2e_test.exs`; `lib/chimeway/workflows.ex:373-391` |

### Doc-contract verification
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Lightweight contract test + manual VALIDATION checklist; full GATE-01 stays Phase 41 | Likely | ROADMAP success criterion #3; Phase 36 VALIDATION.md pattern |

### Related doc fixes (Oban worker names)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fix worker paths to `Chimeway.Dispatch.WorkflowProgressionWorker` and `SignalRouterWorker` | Confident | `lib/chimeway/dispatch/workflow_progression_worker.ex`; `guides/recipes/oban-integration.md:59` |

## Corrections Made

No corrections — all assumptions confirmed by user ("Yes, proceed").

## External Research

No external research performed — codebase evidence sufficient for all assumptions.
