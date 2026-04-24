# Roadmap: Chimeway

## Overview

Chimeway will be delivered in five coarse phases that prioritize durable data semantics and explainability before channel breadth. The roadmap starts with a stable key-based core and in-app lifecycle, then adds first outbound delivery, optional async execution with policy hardening, operator trace surfaces, and finally OSS release/verification hardening.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Durable Core Spine** - Establish stable notifier identity, durable records, and in-app lifecycle.
- [x] **Phase 2: First Outbound Delivery Slice** - Add one outbound adapter seam with full delivery/attempt tracking. (completed 2026-04-24)
- [x] **Phase 3: Async Dispatch and Policy Hardening** - Introduce optional Oban path and enforce late policy checks. (completed 2026-04-24)
- [x] **Phase 4: Explainability and Operator Surfaces** - Make operational tracing practical for support and debugging. (completed 2026-04-24)
- [x] **Phase 5: OSS Verification and Release Hardening** - Lock in quality gates, docs contracts, and release discipline. (completed 2026-04-24)
- [ ] **Phase 6: Delivery Planning and Policy Checkpoint Repair** - Restore per-channel planning fanout and planning-time policy enforcement.
- [ ] **Phase 7: Delayed Fallback Runtime Wiring** - Wire delayed fallback semantics through runtime delivery planning and suppression.
- [ ] **Phase 8: Trigger Dispatch Outcome Surfacing** - Surface dispatch/enqueue outcomes to trigger callers with durable trace links.
- [ ] **Phase 9: OSS Verification Evidence Refresh** - Regenerate stale verification artifacts and clear OPS-03 blocker status.
- [ ] **Phase 10: Telemetry Correlation Enrichment** - Increase lifecycle telemetry consistency for deep operator tracing.

## Phase Details

### Phase 1: Durable Core Spine
**Goal**: Deliver the foundational event/notification data model with stable key identity and in-app lifecycle semantics.  
**Depends on**: Nothing (first phase)  
**Requirements**: [CORE-01, CORE-02, CORE-03, CORE-04, INBX-01, INBX-02, INBX-03]  
**UI hint**: no  
**Success Criteria** (what must be TRUE):
  1. Developer can define a notifier with stable key/version and trigger it with idempotency input.
  2. Triggering a notifier persists durable event and per-recipient in-app notification records.
  3. Recipient inbox supports unread filtering and explicit `seen/read/archive` transitions.
  4. Duplicate trigger attempts with same idempotency key do not create duplicate canonical records.
**Plans**: 3 plans

Plans:
- [x] 01-01: Implement core notifier contract, key/version identity, and trigger pipeline.
- [x] 01-02: Add Ecto schemas/migrations for events and in-app notifications with idempotency constraints.
- [x] 01-03: Implement inbox query/state APIs and foundational tests.

### Phase 2: First Outbound Delivery Slice
**Goal**: Prove end-to-end outbound delivery from planned rows through attempt outcomes using one adapter seam.  
**Depends on**: Phase 1  
**Requirements**: [DLVR-01, DLVR-02, DLVR-03, INTG-01, INTG-02]  
**UI hint**: no  
**Success Criteria** (what must be TRUE):
  1. Trigger flow plans per-channel delivery rows for each recipient with explicit lifecycle states.
  2. Each outbound send attempt creates attempt metadata and final state transitions.
  3. One outbound adapter seam works in testable form (log/test or email wrapper) in addition to in-app.
  4. Integration contract ensures adapters remain replaceable and not core-coupled.
**Plans**: 3 plans

Plans:
- [x] 02-01: Add delivery and attempt persistence model plus lifecycle transitions.
- [x] 02-02: Implement first outbound adapter seam and classification of success/failure/suppression.
- [x] 02-03: Add adapter contract tests and fake provider harness.

### Phase 3: Async Dispatch and Policy Hardening
**Goal**: Add optional Oban-backed async execution and enforce policy correctness across delayed paths.  
**Depends on**: Phase 2  
**Requirements**: [DLVR-04, POLC-01, POLC-02, POLC-03, INTG-03]  
**UI hint**: no  
**Success Criteria** (what must be TRUE):
  1. System supports sync and optional Oban-backed dispatch through a documented integration seam.
  2. Preferences and policy are evaluated at both planning/enqueue and perform/send time.
  3. Delayed fallback can suppress outbound sends when in-app state indicates notification was read.
  4. Async retries/backoff preserve idempotency and trace correctness.
**Plans**: 3 plans

Plans:
- [x] 03-01: Build optional Oban worker path and transactional enqueue integration.
- [x] 03-02: Implement preference model and policy engine with dual evaluation checkpoints.
- [x] 03-03: Add delayed fallback behavior tests and async failure-mode verification.

### Phase 4: Explainability and Operator Surfaces
**Goal**: Deliver operator-grade observability and traceability over notification lifecycle data.  
**Depends on**: Phase 3  
**Requirements**: [OPS-01, OPS-02]  
**UI hint**: yes  
**Success Criteria** (what must be TRUE):
  1. Operators can query trace data to explain why a notification sent, failed, or was suppressed.
  2. Telemetry spans/events exist for key lifecycle transitions and avoid sensitive payload leakage.
  3. Support workflows can correlate event -> notification -> delivery -> attempt using durable identifiers.
**Plans**: 2 plans

Plans:
- [x] 04-01: Implement trace query surfaces and correlation helpers for operator debugging.
- [x] 04-02: Add structured telemetry instrumentation and redaction guarantees.

### Phase 5: OSS Verification and Release Hardening
**Goal**: Ensure the project can ship and evolve safely with repeatable quality and release workflows.  
**Depends on**: Phase 4  
**Requirements**: [OPS-03]  
**UI hint**: no  
**Success Criteria** (what must be TRUE):
  1. Repository provides documented and reliable `mix verify.*` / `mix ci.*` entrypoints.
  2. CI lanes cover lint, tests, docs checks, and release discipline consistent with project DNA.
  3. Baseline contributor and release docs are aligned with actual workflow behavior.
**Plans**: 2 plans

Plans:
- [x] 05-01: Implement CI/verify entrypoints and pipeline parity checks.
- [x] 05-02: Finalize release/checklist docs, doc-contract checks, and maintenance runbook baseline.

### Phase 6: Delivery Planning and Policy Checkpoint Repair
**Goal**: Repair delivery planning fanout and planning-time policy checkpoints so sync and Oban paths enforce the same contracts.  
**Depends on**: Phase 5  
**Requirements**: [DLVR-01, INTG-02, POLC-01, POLC-02]  
**UI hint**: no  
**Gap Closure**: Closes v1.0 audit integration/flow gaps for trigger fanout and Oban planning policy evaluation.  
**Success Criteria** (what must be TRUE):
  1. Trigger planning creates per-recipient, per-channel delivery rows instead of hardcoding `:in_app`.
  2. Policy checks run during planning/enqueue in both sync and Oban paths, not only worker perform time.
  3. Automated tests cover standard outbound success flow with fanout and planning-time policy enforcement.
**Plans**: 3 plans

Plans:
- [x] 06-01: Introduce shared delivery planner and planning-time policy fanout contract.
- [x] 06-02: Unify sync/Oban execution semantics and suppression checkpoint metadata.
- [ ] 06-03: Add parity and integration coverage for fanout and planning checkpoint enforcement.

### Phase 7: Delayed Fallback Runtime Wiring
**Goal**: Make delayed fallback suppression a first-class runtime behavior in normal trigger planning.  
**Depends on**: Phase 6  
**Requirements**: [POLC-03]  
**UI hint**: no  
**Gap Closure**: Closes v1.0 blocker gap for delayed fallback suppression in runtime planning.  
**Success Criteria** (what must be TRUE):
  1. Runtime planning marks delayed fallback semantics (`delay_fallback`) where required by policy.
  2. Dispatch suppresses outbound sends when in-app state indicates notification was already read.
  3. End-to-end tests verify delayed fallback behavior beyond fixture-only setups.
**Plans**: 0 plans

### Phase 8: Trigger Dispatch Outcome Surfacing
**Goal**: Ensure trigger callers receive explicit dispatch/enqueue outcomes with trace correlation context.  
**Depends on**: Phase 6  
**Requirements**: [DLVR-04, OPS-01]  
**UI hint**: no  
**Gap Closure**: Closes v1.0 gaps for trigger API error visibility and standard outbound flow robustness.  
**Success Criteria** (what must be TRUE):
  1. Trigger returns structured results for dispatch/enqueue failures instead of swallowing errors.
  2. Sync and async paths expose caller-visible outcome metadata suitable for retries and support workflows.
  3. Trace data links caller-visible outcomes to durable event/delivery identifiers.
**Plans**: 0 plans

### Phase 9: OSS Verification Evidence Refresh
**Goal**: Regenerate verification artifacts so OSS release hardening reflects current repository state.  
**Depends on**: Phase 5  
**Requirements**: [OPS-03]  
**UI hint**: no  
**Gap Closure**: Closes v1.0 unsatisfied requirement gap caused by stale Phase 5 verification evidence.  
**Success Criteria** (what must be TRUE):
  1. Phase 5 verification is rerun and updated with current docs/contracts evidence.
  2. Verification status for OPS-03 is `passed` with no stale blockers.
  3. Audit traceability artifacts align with refreshed verification outputs.
**Plans**: 0 plans

### Phase 10: Telemetry Correlation Enrichment
**Goal**: Improve telemetry metadata consistency to strengthen operator lifecycle correlation.  
**Depends on**: Phase 8  
**Requirements**: [OPS-02]  
**UI hint**: no  
**Gap Closure**: Closes optional low-severity v1.0 flow gap for operator traceability richness.  
**Success Criteria** (what must be TRUE):
  1. Lifecycle spans emit consistent correlation metadata across event, delivery, and attempt transitions.
  2. Operators can reconstruct deep lifecycle paths from telemetry without payload leakage.
  3. Tests assert metadata presence and redaction behavior on enriched telemetry paths.
**Plans**: 0 plans

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Durable Core Spine | 3/3 | Complete | 2026-04-24 |
| 2. First Outbound Delivery Slice | 3/3 | Complete    | 2026-04-24 |
| 3. Async Dispatch and Policy Hardening | 3/3 | Complete    | 2026-04-24 |
| 4. Explainability and Operator Surfaces | 2/2 | Complete    | 2026-04-24 |
| 5. OSS Verification and Release Hardening | 1/2 | Complete    | 2026-04-24 |
| 6. Delivery Planning and Policy Checkpoint Repair | 2/3 | In Progress | — |
| 7. Delayed Fallback Runtime Wiring | 0/0 | Planned | — |
| 8. Trigger Dispatch Outcome Surfacing | 0/0 | Planned | — |
| 9. OSS Verification Evidence Refresh | 0/0 | Planned | — |
| 10. Telemetry Correlation Enrichment | 0/0 | Planned | — |
