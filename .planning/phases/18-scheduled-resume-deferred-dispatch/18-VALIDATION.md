---
phase: 18
slug: scheduled-resume-deferred-dispatch
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-28
---

# Phase 18 — Validation Strategy

## Validation Intent

Phase 18 must prove that deferred deliveries resume automatically through durable async scheduling without creating duplicate sends, losing correlation/trace continuity, or leaving resumed work in ambiguous lifecycle states.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/chimeway/orchestration` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~20 seconds |

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/orchestration`
- **After every plan wave:** Run targeted phase commands plus `mix test` when lifecycle behavior changes
- **Before `$gsd-verify-work`:** `mix test` must be green
- **Max feedback latency:** 20 seconds

## Requirement Coverage

| Requirement | Validation focus |
|-------------|------------------|
| ORCH-03 | Deferred rows resume through durable async scheduling, remain idempotent under repeated scheduling, and preserve operator-visible lifecycle continuity. |

## Required Automated Checks

### Resume claim and scheduling

- `mix test test/chimeway/orchestration`

Expected proof:

- due deferred rows are selected from the delivery row, not external scheduler state
- repeated resume attempts do not create duplicate sends
- non-due, terminal, cancelled, or already-ready rows no-op safely

### Lifecycle and trace continuity

- `mix test test/chimeway/integration/delivery_lifecycle_test.exs`

Expected proof:

- resumed deliveries preserve delivery identity and correlation chain
- resumed deliveries converge through normal worker retry/final-state semantics
- trace explanations expose deferred-then-resumed lifecycle history durably

### Phase gate

- `mix test`

## Mandatory Assertions

- Deferred deliveries resume by mutating the canonical `chimeway_deliveries` row instead of creating replacement rows.
- Async scheduling and worker execution continue to identify work by `delivery_id` only.
- Duplicate scheduler runs cannot cause more than one actual send attempt for the same deferred delivery.
- Resume logic respects terminal, cancelled, and superseded rows as no-op or converged outcomes.
- `Chimeway.Traces.explain_delivery/2` remains able to explain deferral and subsequent resume/cancellation outcomes from durable state.

## Risks To Watch

- Non-atomic claim/update logic causing duplicate enqueue or duplicate send.
- Oban job uniqueness masking row-level race bugs instead of preventing them durably.
- Resume semantics clearing or mutating planning fields in a way that breaks explainability.
- Tests proving enqueue behavior only, while missing final-state convergence after resumed execution.
