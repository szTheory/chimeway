# Phase 39: Demo Host Trace Path - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-28
**Phase:** 39-demo-host-trace-path
**Mode:** assumptions
**Areas analyzed:** Primary surface, Trigger mechanism, Scenario, Golden-path integration, Automation/CI boundaries, Runtime configuration

## Assumptions Presented

### Primary surface: IEx walkthrough in demo host
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `examples/chimeway_demo_host/README.md` with step-by-step IEx session; no new Phoenix route/LiveView | Confident | No demo README; Phase 40 owns operator UI; `lib/chimeway/traces.ex` IEx moduledoc; golden-path §6 |

### Trigger mechanism: minimal demo notifier + real trigger API
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add demo host notifier + document `Chimeway.trigger/3`; sync dispatcher | Likely | Zero notifiers in demo host; `Chimeway.Test.SupportNotifier`; `config/test.exs` uses `Chimeway.Dispatch.Sync` |

### Scenario: simple delivery trace (not workflow/webhook)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Mirror password-reset support trace; contrast with webhook E2E | Confident | Phase 38 deferred non-webhook path; `guides/recipes/password-reset-support-trace.md` |

### Golden-path integration
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New golden-path subsection linking demo host README as lowest-friction validation | Confident | ROADMAP success criterion 3; Phase 36–38 cross-link pattern |

### Optional script, not CI gate
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Optional `priv/scripts` or Mix alias; do not expand `mix verify.example` | Likely | `mix.exs` verify.example; Phase 41 GATE-01 |

### Dev/runtime config for IEx
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `config/dev.exs` for demo host (non-sandbox Repo) | Likely | Only `config/test.exs` exists today |

## Corrections Made

No corrections — all assumptions confirmed ("Yes, proceed").

## Auto-Resolved

Not applicable (interactive assumptions mode, not `--auto`).

## External Research

Not performed — codebase provided sufficient evidence for all areas.
