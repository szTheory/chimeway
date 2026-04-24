# Phase 11: channel-adapter-safety-and-explainability-hardening - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-24  
**Phase:** 11-channel-adapter-safety-and-explainability-hardening  
**Mode:** assumptions  
**Areas analyzed:** Adapter Config Lookup Safety, Explainability Channel Representation, Oban Dynamic Atom Scope Boundary, Regression Coverage Shape

## Assumptions Presented

### Adapter Config Lookup Safety
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Executor should stop deriving adapter config keys via runtime atom creation and use a non-dynamic channel config resolver. | Likely | `lib/chimeway/dispatch/executor.ex`, `lib/chimeway/delivery.ex`, `lib/chimeway/delivery_planning.ex`, `.planning/ROADMAP.md`, `.planning/v1.0-MILESTONE-AUDIT.md` |

### Explainability Channel Representation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Explainability should avoid runtime channel atom conversion and support valid custom channels safely. | Likely | `lib/chimeway/traces.ex`, `lib/chimeway/traces/explanation.ex`, `lib/chimeway/delivery_planning.ex`, `lib/chimeway/delivery.ex`, `.planning/v1.0-MILESTONE-AUDIT.md`, `.planning/phases/07-delayed-fallback-runtime-wiring/07-REVIEW.md` |

### Oban Dynamic Atom Scope Boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Oban dynamic atom usage is adjacent hardening debt and requires an explicit in-scope vs deferred decision. | Unclear | `lib/chimeway/dispatch/oban.ex`, `.planning/phases/07-delayed-fallback-runtime-wiring/07-REVIEW.md`, `.planning/v1.0-MILESTONE-AUDIT.md`, `.planning/ROADMAP.md` |

### Regression Coverage Shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Regression tests should explicitly cover custom string channels across adapter lookup and explainability, with sync/Oban parity through shared executor behavior. | Confident | `lib/chimeway/dispatch/sync.ex`, `lib/chimeway/dispatch/oban_worker.ex`, `lib/chimeway/dispatch/executor.ex`, `test/chimeway/dispatch/sync_test.exs`, `test/chimeway/dispatch/oban_test.exs`, `test/chimeway/traces_test.exs` |

## Corrections Made

No corrections — all assumptions confirmed.
