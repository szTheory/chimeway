# Requirements: Chimeway

**Defined:** 2026-04-25
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, or was suppressed.

## v1 Requirements

Requirements for the next production-trust milestone. Each maps to one roadmap phase.

### Policy & Preferences

- [x] **POL-01
**: Users can define notification preferences by channel or category.
- [x] **POL-02
**: Users can configure quiet hours and delivery caps.
- [x] **POL-03
**: The system suppresses delivery before enqueue and before perform when policy blocks it, and records the reason.

### Delivery Reliability

- [ ] **REL-01**: The system prevents duplicate events, notifications, and deliveries when creation or planning is retried.
- [ ] **REL-02**: Delivery attempt records preserve retry history, backoff behavior, and terminal failure outcomes.
- [ ] **REL-03**: Every delivery resolves to a durable final state that explains sent, failed, or suppressed outcomes.

### Observability & Supportability

- [ ] **OBS-01**: Operators can trace an event through notification, delivery, and attempt records using one durable identifier.
- [ ] **OBS-02**: Operators can inspect structured telemetry and logs for lifecycle events without leaking sensitive payload fields.
- [ ] **OBS-03**: Host-app correlation and tenancy context is available in operator surfaces and traces.

### Integration Hardening

- [x] **INT-01
**: Host apps can install and configure Chimeway through a documented integration path.
- [ ] **INT-02**: Adapter and job-dispatch seams remain contract-tested and safe for runtime configuration.

## v2 Requirements

Deferred to a later release after the trust baseline is proven in production.

### Product Expansion

- **EXP-01**: Users can schedule digest or summary deliveries.
- **EXP-02**: Users can group notifications into delivery windows.
- **EXP-03**: Operators can inspect higher-level adoption and delivery analytics.

### Workflow Expansion

- **WRK-01**: Teams can build multi-step notification journeys.
- **WRK-02**: Teams can preview and template richer notification content flows.

## Out of Scope

Explicitly excluded for this milestone.

| Feature | Reason |
|---------|--------|
| Hosted SaaS control plane | Chimeway stays embedded and local-first. |
| Campaign/journey automation | The product remains transactional notification infrastructure first. |
| Full analytics dashboard | The milestone focuses on trust and supportability before broader reporting. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| POL-01 | Phase 13 | Pending |
| POL-02 | Phase 13 | Pending |
| POL-03 | Phase 13 | Pending |
| REL-01 | Phase 14 | Pending |
| REL-02 | Phase 14 | Pending |
| REL-03 | Phase 14 | Pending |
| OBS-01 | Phase 15 | Pending |
| OBS-02 | Phase 15 | Pending |
| OBS-03 | Phase 15 | Pending |
| INT-01 | Phase 16 | Pending |
| INT-02 | Phase 16 | Pending |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-25*
*Last updated: 2026-04-25 after v1.1 milestone start*
