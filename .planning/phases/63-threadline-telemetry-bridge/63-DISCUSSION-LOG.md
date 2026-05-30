# Phase 63: Threadline Telemetry Bridge - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-30
**Phase:** 63-threadline-telemetry-bridge
**Mode:** assumptions
**Areas analyzed:** Integration seam, Host wiring, Outcome mapping, Phase scope boundary, Test harness & CI, Cross-repo ownership

## Assumptions Presented

### Integration seam (telemetry bridge, not adapter)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ship `Chimeway.Telemetry.ThreadlineReporter` as `:telemetry` handler behind `Code.ensure_loaded?(Threadline)` | Confident | `lib/chimeway/telemetry.ex`, ROADMAP Phase 63, SEED-003 |

### Host wiring (attach-only)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Optional `threadline ~> 0.7` dep + `ThreadlineReporter.attach/0` in Application.start; config for repo/actor | Likely | `Chimeway.Telemetry` moduledoc, `Threadline.record_action/2`, Accrue `mix.exs` pattern |

### Outcome mapping (telemetry → audit actions)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Map policy/dispatch/attempt spans to four Threadline actions; forward correlation_id; add planning_reason to safe_meta allowlist | Likely | `lib/chimeway/policy.ex`, `lib/chimeway/deliveries.ex`, `../threadline/lib/threadline.ex` |

### Phase 63 scope boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Core reporter + root integration test only; demo/docs/verify gate in Phases 65–66 | Confident | ROADMAP waves, Phase 58 CONTEXT scope split |

### Test harness & CI
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `@moduletag :threadline`, exclude from ci.test, THREADLINE_PATH harness; verify.threadline deferred Phase 66 | Likely | `config/test.exs`, `mix.exs`, `test/test_helper.exs` |

### Cross-repo ownership
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Chimeway-only; public Threadline.record_action/2 sufficient | Confident | `../threadline/lib/threadline.ex`, no existing Chimeway integration in Threadline repo |

## Corrections Made

No corrections — all assumptions confirmed ("Yes, proceed").

## External Research

None performed — Threadline 0.7.0 API and Chimeway telemetry catalog sufficient from local codebase.
