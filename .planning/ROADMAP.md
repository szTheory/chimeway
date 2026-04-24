# Roadmap: Chimeway

## Overview

Chimeway will be delivered in five coarse phases that prioritize durable data semantics and explainability before channel breadth. The roadmap starts with a stable key-based core and in-app lifecycle, then adds first outbound delivery, optional async execution with policy hardening, operator trace surfaces, and finally OSS release/verification hardening.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Durable Core Spine** - Establish stable notifier identity, durable records, and in-app lifecycle.
- [ ] **Phase 2: First Outbound Delivery Slice** - Add one outbound adapter seam with full delivery/attempt tracking.
- [ ] **Phase 3: Async Dispatch and Policy Hardening** - Introduce optional Oban path and enforce late policy checks.
- [ ] **Phase 4: Explainability and Operator Surfaces** - Make operational tracing practical for support and debugging.
- [ ] **Phase 5: OSS Verification and Release Hardening** - Lock in quality gates, docs contracts, and release discipline.

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
- [ ] 02-01: Add delivery and attempt persistence model plus lifecycle transitions.
- [ ] 02-02: Implement first outbound adapter seam and classification of success/failure/suppression.
- [ ] 02-03: Add adapter contract tests and fake provider harness.

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
- [ ] 03-01: Build optional Oban worker path and transactional enqueue integration.
- [ ] 03-02: Implement preference model and policy engine with dual evaluation checkpoints.
- [ ] 03-03: Add delayed fallback behavior tests and async failure-mode verification.

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
- [ ] 04-01: Implement trace query surfaces and correlation helpers for operator debugging.
- [ ] 04-02: Add structured telemetry instrumentation and redaction guarantees.

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
- [ ] 05-01: Implement CI/verify entrypoints and pipeline parity checks.
- [ ] 05-02: Finalize release/checklist docs, doc-contract checks, and maintenance runbook baseline.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Durable Core Spine | 3/3 | Complete | 2026-04-24 |
| 2. First Outbound Delivery Slice | 0/3 | Not started | - |
| 3. Async Dispatch and Policy Hardening | 0/3 | Not started | - |
| 4. Explainability and Operator Surfaces | 0/2 | Not started | - |
| 5. OSS Verification and Release Hardening | 0/2 | Not started | - |
