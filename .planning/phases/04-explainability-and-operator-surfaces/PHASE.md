# Phase 4: Explainability and Operator Surfaces

**Status**: not_started
**Depends on**: Phase 3 (Async Dispatch and Policy Hardening)
**Requirements**: [OPS-01, OPS-02]

## Goal

Deliver operator-grade observability and traceability over notification lifecycle data.

## Plans

| Plan | Title | Status | Depends On |
|------|-------|--------|------------|
| [04-01](plans/04-01-trace-query-surfaces.md) | Implement Trace Query Surfaces and Correlation Helpers for Operator Debugging | not_started | — |
| [04-02](plans/04-02-structured-telemetry.md) | Add Structured Telemetry Instrumentation and Redaction Guarantees | not_started | 04-01 |

## Execution Waves

- **Wave 1**: 04-01 — query context, `explain_delivery/1`, correlation ID persistence
- **Wave 2**: 04-02 — telemetry spans, `safe_meta/1` redaction, integration test

## Success Criteria

1. Operators can query trace data to explain why a notification sent, failed, or was suppressed (OPS-01).
2. Telemetry spans/events exist for key lifecycle transitions and avoid sensitive payload leakage (OPS-02).
3. Support workflows can correlate event → notification → delivery → attempt using durable identifiers (OPS-01).

## Key Modules Added This Phase

- `lib/chimeway/traces.ex` — public query context with `get_trace/1`, `find_traces_for_recipient/2`, `find_traces_by_correlation_id/1`, `explain_delivery/1`
- `lib/chimeway/traces/explanation.ex` — `Chimeway.Traces.Explanation` struct
- `lib/chimeway/telemetry.ex` — span wrapper, `safe_meta/1`, `attach_default_handlers/0`

## Key DB Changes This Phase

- `correlation_id` nullable string column on `chimeway_events` (alter; add index)
