# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- ✅ **v1.1** — [Archived roadmap](.planning/milestones/v1.1-ROADMAP.md) (shipped 2026-04-27)
- 🚧 **v1.2 Delivery Orchestration** — active

## Current Milestone

**Version:** v1.2  
**Name:** Delivery Orchestration  
**Status:** Active  
**Goal:** Turn Chimeway from a durable notification engine into a product-grade notification layer that can decide not just whether to send, but when, how, and in what grouped form.

**Requirement coverage:** 11/11 mapped
**Phase range:** 17-22

## Phase Plan

### Phase 17: Delivery Windows & Deferral Semantics
**Goal**: Define the durable planning model for immediate sends, quiet-hours deferral, and recipient-timezone-aware delivery windows.
**Depends on**: Phase 16
**Requirements**: ORCH-01, ORCH-02

Success criteria:
1. Trigger planning can mark a delivery for immediate send, scheduled deferral, or digest eligibility using durable persisted state.
2. Window evaluation records the rule, timezone context, reason, and next eligible send time for each deferred delivery.
3. Explainability surfaces can show why a delivery was deferred instead of suppressed or sent immediately.

### Phase 18: Scheduled Resume & Deferred Dispatch
**Goal**: Resume deferred deliveries automatically through durable scheduling and lifecycle-safe async execution.
**Depends on**: Phase 17
**Requirements**: ORCH-03
**Plans:** 3/3 plans complete

Plans:
- [x] 18-01-PLAN.md — Lock the deferred-resume contract with targeted scheduling, promotion, and rollback tests.
- [x] 18-02-PLAN.md — Implement canonical deferred-to-ready promotion plus scheduled resume worker reuse of the normal Oban dispatch path.
- [x] 18-03-PLAN.md — Preserve resume trace continuity and prove race-safe lifecycle convergence.

Success criteria:
1. Deferred deliveries are resumed through Oban-backed scheduling without creating duplicate sends.
2. Scheduled resume preserves correlation, notification identity, and operator trace continuity.
3. Deferred deliveries converge to durable final states when resumed, cancelled, or superseded.

### Phase 19: Digest Data Model & Accumulation
**Goal**: Introduce first-class digest rules and durable accumulation records for repeated notification streams.
**Depends on**: Phase 18
**Requirements**: DIGEST-01
**Plans:** 3/3 plans complete

Plans:
- [x] 19-01-PLAN.md — Define durable digest rule and bucket storage contracts plus the public rule API.
- [x] 19-02-PLAN.md — Add explicit membership storage and transactional accumulation with DB-level idempotency.
- [x] 19-03-PLAN.md — Wire digest accumulation into the planning pipeline after policy-safe held outcomes.

Success criteria:
1. Teams can declare digest grouping rules by recipient and notification grouping key.
2. Repeated events accumulate into durable digest buckets instead of emitting redundant immediate deliveries when configured to batch.
3. Digest planning remains idempotent under retries and duplicate trigger conditions.

### Phase 20: Digest Emission & Explainability
**Goal**: Generate, dispatch, and explain digest deliveries from accumulated source notifications.
**Depends on**: Phase 19
**Requirements**: DIGEST-02, DIGEST-03

Success criteria:
1. Digest dispatch records exactly which source events and notifications were included in the emitted digest.
2. Operator trace surfaces can explain inclusion, exclusion, and immediate-send decisions for digestable notifications.
3. Digest emission remains safe under retries, duplicate job execution, and partial failure conditions.

### Phase 21: Template Versioning & Rendering Contracts
**Goal**: Make notification content versioned, channel-aware, and previewable without coupling durable history to notifier module changes.
**Depends on**: Phase 20
**Requirements**: TMPL-01, TMPL-02, TMPL-03

Success criteria:
1. Notification content versions are persisted as durable rendering identity separate from notifier module names.
2. Channel-specific rendering inputs and outputs are explicit, validated, and covered by contract tests.
3. Developers can preview or verify rendered notification content locally before provider delivery.

### Phase 22: Recovery & Outcome Analytics
**Goal**: Close the remaining operational trust gaps with reconciliation paths and aggregate outcome queries.
**Depends on**: Phase 21
**Requirements**: OPS-01, OPS-02

Success criteria:
1. Operators can detect events or deliveries that persisted but were not fully dispatched and re-drive them safely.
2. Reconciliation preserves idempotency and explainability instead of mutating history opaquely.
3. Aggregate query surfaces report sent, suppressed, delayed, digested, failed, and exhausted outcomes by key and channel.

## Summary Table

| Phase | Name | Goal | Requirements | Success Criteria |
|-------|------|------|--------------|------------------|
| 17 | Delivery Windows & Deferral Semantics | 3/3 | Complete    | 2026-04-28 |
| 18 | Scheduled Resume & Deferred Dispatch | 3/3 | Complete    | 2026-04-28 |
| 19 | Digest Data Model & Accumulation | 3/3 | Complete | 2026-04-28 |
| 20 | Digest Emission & Explainability | Dispatch digests and explain membership | DIGEST-02, DIGEST-03 | 3 |
| 21 | Template Versioning & Rendering Contracts | Version and preview content safely | TMPL-01, TMPL-02, TMPL-03 | 3 |
| 22 | Recovery & Outcome Analytics | Reconcile failures and expose aggregates | OPS-01, OPS-02 | 3 |

## Next Up

**Phase 20: Digest Emission & Explainability** — Generate, dispatch, and explain digest deliveries from accumulated source notifications.
