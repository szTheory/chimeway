# Phase 48: `wait_until` Pending Signals - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 48-`wait_until` Pending Signals
**Mode:** assumptions
**Areas analyzed:** Implementation seam, Progress-rule DSL, Canonical event names, Post-signal behavior, Doc-truth

## Assumptions Presented

### Implementation seam
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Populate `pending_signals` inside `enter_waiting/6` in same transaction as `:waiting` transition | Likely | `lib/chimeway/workflows/progression.ex` lines 251–287; `lib/chimeway/workflows/workflow_run.ex` |

### Progress-rule DSL extension
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add optional `cancel_signals` array to `wait_until` rules; omit → `[]` | Likely | `.planning/REQUIREMENTS.md` READ-01; `lib/chimeway/notifier.ex` `normalize_wait_until_rule/1` |

### Canonical event names
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Document `chimeway.notification.read` / `.seen`; emit in Phase 49 only | Likely | `chimeway.delivery.*` pattern in `process_feedback_worker.ex`; `lib/chimeway/inbox.ex` has no signal emission |

### Post-signal behavior
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 48 does not change `route_signal/1` post-match behavior; read-cancel halt is Phase 49+ | Confident | `lib/chimeway/workflows.ex` `route_signal/1`; ROADMAP Phase 48 vs 49 boundaries |

### Doc-truth deliverable
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Update `guides/flows/multi-step-journeys.md` in Phase 48; recipe rewrite deferred to Phase 50 | Likely | ROADMAP success criterion #3; DEMO-04 in Phase 50 |

## Corrections Made

No corrections — all assumptions confirmed by user ("Yes, proceed").

## Methodology Lenses Applied

- **Research-first decision ownership** — codebase analysis before user interaction
- **One-shot recommendation bias** — single coherent recommendation set per area
- **Durable explainability bias** — persist on run row inside existing transaction
- **Least-surprise DX default** — explicit `cancel_signals` opt-in, no silent auto-defaults
