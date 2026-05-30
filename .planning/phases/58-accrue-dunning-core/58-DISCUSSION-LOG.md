# Phase 58: Accrue Dunning Core - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `58-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 58-accrue-dunning-core
**Mode:** assumptions
**Areas analyzed:** Integration seam, Cross-repo ownership, Start path, Termination, Test harness & CI

## Assumptions Presented

### Integration seam (not `Chimeway.Adapter`)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Workflow + Signal bridge only; Accrue owns `Accrue.Integrations.Chimeway` engine | Confident | ROADMAP constraints; `lib/chimeway/adapters/mailglass.ex`; `accrue/lib/accrue/integrations/chimeway.ex` |

### Cross-repo ownership
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 58 spans Accrue + Chimeway; upgrade DunningNotifier + Chimeway test lane | Likely | Accrue v1.40 `:immediate` omits `workflow/2`; zero accrue files in chimeway repo |

### Start path (`payment_failed` → workflow run)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `start_campaign` → `trigger` with new `workflow/2` multi-step dunning | Likely | `payment_reminder.ex`; Accrue moduledoc "creates no WorkflowRun" |

### Termination (`invoice.paid` / Outcome Signal)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `cancel_signals: ["invoice.paid"]` + `Signal.track` with customer email actor_id | Likely | `workflows.ex` route_signal; Accrue uses `payment_recovered`/`accrue.dunning` today |

### Test harness & CI (58-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Mailglass pattern: optional dep, `@moduletag :accrue`, `verify.accrue` | Confident | `mix.exs`; STATE.md v1.9 |

## Corrections Made

No corrections — all assumptions confirmed ("Yes, proceed").

## External Research

Topics flagged for plan-phase (not blocking context capture):

- Accrue hex API naming (`Accrue.Integrations.Chimeway` vs `Accrue.Chimeway`)
- Whether ECOS-06 "terminate" requires explicit `:stopped`/`:completed` vs read-cancel resume semantics
- Accrue event helper atoms vs string `invoice.payment_failed` in tests
