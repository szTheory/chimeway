# Phase 18 Research: Scheduled Resume & Deferred Dispatch

**Phase:** 18 - Scheduled Resume & Deferred Dispatch
**Date:** 2026-04-28
**Requirement focus:** ORCH-03
**Status:** Ready for planning

## Objective

Determine how Chimeway should resume deferred deliveries automatically through durable async scheduling while preserving delivery-row identity, Oban-based execution, idempotency, and operator trace continuity.

## Current Baseline

### Durable data already exists

- `priv/repo/migrations/20260428093000_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` already added `orchestration_state`, `next_eligible_at`, `planning_reason`, and `planning_context`, plus an index on `[:orchestration_state, :next_eligible_at]`.
- `lib/chimeway/delivery.ex` exposes the orchestration fields on the canonical `chimeway_deliveries` row.
- `lib/chimeway/deliveries.ex` already persists planning-time decisions through `apply_planning_decision/2`.

### Dispatch path is already gated correctly

- `lib/chimeway/dispatch/oban.ex` only enqueues pending deliveries whose `orchestration_state == :ready`.
- `lib/chimeway/dispatch/oban_worker.ex` loads work by `delivery_id` only and short-circuits non-ready or terminal deliveries.
- `lib/chimeway/delivery_planning.ex` can already produce `:deferred` rows during planning without dispatching them.

### Phase 17 carry-forward boundary is explicit

- `.planning/phases/17-delivery-windows-deferral-semantics/17-03-SUMMARY.md` locked the rule that held deliveries stay `:pending` with zero attempts until a later resume phase exists.
- `.planning/phases/17-delivery-windows-deferral-semantics/17-VALIDATION.md` explicitly forbids dispatching deferred rows before resume scheduling is implemented.

## Research Findings

### 1. Delivery rows should remain the only durable scheduling source

The current schema and indexes already support a delivery-row-driven scheduler. Adding a second durable scheduling store would duplicate identity, complicate cancellation/supersession, and weaken the explainability model. The right durable lookup remains:

- `status == :pending`
- `orchestration_state == :deferred`
- `next_eligible_at <= now`

This aligns with the phase context decision that the canonical `chimeway_deliveries` row remains the source of truth.

### 2. Resume should be a state transition plus normal enqueue, not a new dispatch path

The safest execution shape is:

1. Find eligible deferred rows.
2. Atomically transition each row from `:deferred` to `:ready`.
3. Preserve `status == :pending`.
4. Enqueue the existing `Chimeway.Dispatch.ObanWorker` with `%{delivery_id: delivery.id}`.

This reuses the existing delivery lifecycle, adapter execution, retry semantics, and final-state convergence logic instead of creating a second performer.

### 3. Concurrency safety needs a durable claim step on the delivery row

The main risk in this phase is duplicate resume execution:

- multiple scheduler jobs may observe the same eligible delivery
- manual enqueue and scheduled resume may race
- cancellation or supersession may happen between eligibility lookup and enqueue

The resume path therefore needs an atomic claim/update step on the delivery row before enqueueing. Planning should favor an API in `Chimeway.Deliveries` that updates only rows that are still pending and deferred. If the update affects zero rows, resume should no-op.

Recommended invariants for the claim step:

- only resume when `status == :pending`
- only resume when `orchestration_state == :deferred`
- only resume when `next_eligible_at` is present and due
- clear or rewrite due-time fields in the same update so the row is no longer eligible for a second claim

### 4. Oban scheduling should stay identity-light

The existing worker uniqueness uses `delivery_id` in args and already keeps payloads out of job state. Phase 18 should preserve that rule:

- scheduled resume jobs should not carry notification identity beyond `delivery_id`
- any sweep/resume job should treat the delivery row as authoritative for trace and lifecycle facts

Two viable patterns fit the codebase:

- a sweep worker that periodically claims all eligible deferred deliveries and enqueues `ObanWorker`
- a direct scheduled-at-time resume job per deferred delivery that also claims the row before enqueue

Given the current code, a sweep worker is the lower-risk default because it avoids storing a second per-delivery scheduler identity while still leveraging the existing due-time index. A hybrid can still be acceptable if the row remains authoritative and duplicate claims are prevented.

### 5. Trace continuity must expose resume, cancellation, and supersession as delivery-row history

`lib/chimeway/traces.ex` already explains deferred rows from delivery-row fields. Phase 18 must extend that model rather than shifting operator answers into Oban metadata.

Planning should ensure trace surfaces can answer:

- why this delivery stayed deferred
- when it became eligible
- when and why it resumed
- whether it was resumed, cancelled, or superseded before send

Likely trace changes:

- add a timeline entry for resume transition
- preserve `planning_reason`, `planning_context`, and correlation continuity after resume
- ensure cancelled or superseded deferred rows still converge on one durable explanation path

### 6. Testing must target races and lifecycle convergence, not only the happy path

Existing tests already prove deferred rows do not run early. Phase 18 needs complementary proof that they do run exactly once when resumed and that losing paths no-op safely.

High-value test shapes:

- due deferred row becomes ready and is enqueued once
- already-resumed row is ignored by a second resume attempt
- terminal or cancelled row is ignored by resume
- resumed row preserves correlation and notification identity through `Traces.explain_delivery/2`
- resumed transient failure still converges through the existing Oban retry/exhaustion path
- superseded or cancelled deferred row reaches a durable final explanation without duplicate attempts

## Recommended Plan Boundaries

### Plan slice 1: Resume transition and due-row query API

Likely files:

- `lib/chimeway/deliveries.ex`
- `lib/chimeway/delivery.ex`
- `test/chimeway/orchestration/...`

Responsibilities:

- query/select due deferred rows
- atomically claim or resume one row
- define status/orchestration-state transition contract
- cover duplicate-claim and no-op behavior

### Plan slice 2: Oban scheduler integration

Likely files:

- `lib/chimeway/dispatch/oban.ex`
- `lib/chimeway/dispatch/oban_worker.ex`
- new scheduler worker module under `lib/chimeway/dispatch/`
- Oban-focused tests

Responsibilities:

- schedule or sweep eligible rows
- enqueue canonical `ObanWorker` jobs
- prevent duplicate sends under repeated scheduler execution

### Plan slice 3: Explainability and lifecycle integration

Likely files:

- `lib/chimeway/traces.ex`
- `lib/chimeway/traces/explanation.ex`
- integration and trace tests

Responsibilities:

- surface resume/cancel/supersede history
- prove correlation and delivery identity continuity
- verify durable final states under resumed execution

## Files Most Likely To Change

- `lib/chimeway/deliveries.ex`
- `lib/chimeway/dispatch/oban.ex`
- `lib/chimeway/dispatch/oban_worker.ex`
- `lib/chimeway/traces.ex`
- `lib/chimeway/traces/explanation.ex`
- `test/chimeway/orchestration/dispatch_gating_test.exs`
- `test/chimeway/integration/delivery_lifecycle_test.exs`
- one or more new orchestration/dispatch tests for due-row resume behavior
- possibly a new worker module for deferred-resume sweeping

## Risks And Pitfalls

- Enqueueing without an atomic row claim can produce duplicate sends.
- Introducing separate scheduler identity or payload state weakens explainability and cancellation semantics.
- Reusing `status` alone for hold/resume logic will blur planning state with lifecycle state; `orchestration_state` must remain the primary planning gate.
- Trace surfaces may become misleading if resume state lives only in Oban jobs or logs instead of delivery-row-derived history.
- A per-delivery scheduled job approach can still be correct, but only if duplicate resume claims collapse safely on the row itself.

## Recommendation

Plan around a delivery-row-driven resume API plus Oban-backed async scheduling that reuses `Chimeway.Dispatch.ObanWorker` unchanged for actual sending. The row claim/update contract is the core correctness boundary for this phase; scheduler shape is secondary as long as the row remains the source of truth and repeated resume attempts no-op safely.

## Validation Architecture

Phase 18 validation should prove three properties:

1. due deferred deliveries become dispatchable exactly once
2. resumed work preserves delivery identity, correlation, and trace continuity
3. resumed, cancelled, and superseded rows converge to durable final states without duplicate attempts

Recommended automated checks:

- focused orchestration tests for due-row claim/resume behavior
- Oban tests for repeated scheduler execution and duplicate enqueue prevention
- integration tests proving resumed rows go through the normal lifecycle and trace APIs
- full `mix test` phase gate before completion
