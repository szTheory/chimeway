# Requirements: Chimeway

**Defined:** 2026-04-28
**Milestone:** v1.2 Delivery Orchestration
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.2 Requirements

### Orchestration

- [x] **ORCH-01**: Product teams can declare whether a notification delivery sends immediately, defers to the next allowed window, or participates in digesting.
- [x] **ORCH-02**: Delivery-window decisions respect recipient timezone and persist the reason, window rule, and next eligible send time.
- [x] **ORCH-03**: Deferred deliveries resume automatically through durable async scheduling without losing lifecycle traceability.

### Digests

- [x] **DIGEST-01**: Teams can define digest rules that group repeated notifications by recipient, notification key or category, and delivery window.
- [x] **DIGEST-02**: Digest generation is idempotent and records which source events and notifications were included in each digest delivery.
- [ ] **DIGEST-03**: Operators can explain why a notification was included in a digest, skipped from a digest, or emitted immediately instead.

### Templates & Rendering

- [x] **TMPL-01**: Notification content can be versioned independently from notifier module names so rendering changes remain durable and traceable.
- [x] **TMPL-02**: Channel-specific rendering contracts are explicit and testable, including structured assigns for in-app and outbound channels.
- [x] **TMPL-03**: Developers can preview or verify rendered notification content before provider delivery.

### Recovery & Analytics

- [x] **OPS-01**: Operators can detect and reconcile persisted events or deliveries that were never fully dispatched after trigger-time failures.
- [x] **OPS-02**: Operators can query aggregate outcomes by notification key, channel, and lifecycle result, including sent, suppressed, delayed, digested, failed, and exhausted flows.

## Future Requirements

### Workflow Journeys

- **WRK-01**: Teams can model multi-step notification journeys with branch logic across lifecycle events.
- **WRK-02**: Teams can coordinate escalations across channels when earlier steps remain unread or undelivered.

### Channel Expansion

- **CHAN-01**: Chimeway provides first-class production adapters beyond the initial outbound seam for SMS, push, and chat.
- **CHAN-02**: Transport-specific delivery receipts and webhook callbacks flow back into lifecycle traces uniformly.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Marketing campaigns and broadcast automation | Not aligned with Chimeway's transactional/product-notification focus |
| Hosted control plane or multi-tenant SaaS dashboard | Conflicts with local-first host ownership |
| Broad provider matrix in this milestone | Lower leverage than orchestration, batching, and recovery behavior |
| Visual journey builder UI | Workflow modeling is deferred until underlying orchestration semantics are proven |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ORCH-01 | Phase 17 | Complete |
| ORCH-02 | Phase 17 | Complete |
| ORCH-03 | Phase 18 | Complete |
| DIGEST-01 | Phase 19 | Complete |
| DIGEST-02 | Phase 23 | Complete |
| DIGEST-03 | Phase 23 | Pending |
| TMPL-01 | Phase 21 | Complete |
| TMPL-02 | Phase 21 | Complete |
| TMPL-03 | Phase 21 | Complete |
| OPS-01 | Phase 22 | Complete |
| OPS-02 | Phase 22 | Complete |

**Coverage:**
- v1.2 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-28*
*Last updated: 2026-04-28 after milestone v1.2 audit gap planning*
