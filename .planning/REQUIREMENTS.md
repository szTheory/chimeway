# Requirements: Chimeway

**Defined:** 2026-04-23  
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, or was suppressed.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Core Event Model

- [ ] **CORE-01**: Developer can define a notification type with a stable persisted `notification_key` and version.
- [ ] **CORE-02**: Developer can trigger a notification event with an explicit idempotency key.
- [ ] **CORE-03**: System persists each event as a durable row before external delivery is attempted.
- [ ] **CORE-04**: System resolves one event to multiple recipients deterministically.

### In-App Lifecycle

- [ ] **INBX-01**: System creates per-recipient in-app notification rows for resolved recipients.
- [ ] **INBX-02**: User can transition in-app notification state through explicit `seen`, `read`, and archive semantics.
- [ ] **INBX-03**: Application can query recipient inbox records with unread filtering and newest-first ordering.

### Delivery and Attempt Tracking

- [ ] **DLVR-01**: System plans per-channel delivery rows from the event and recipient set.
- [ ] **DLVR-02**: System records every provider/send attempt with outcome metadata and timestamps.
- [ ] **DLVR-03**: System classifies delivery outcomes into explicit states including succeeded, failed, suppressed, cancelled, and expired where applicable.
- [ ] **DLVR-04**: System supports sync dispatch for v1 and a documented seam for optional job-backed dispatch.

### Policy and Preferences

- [ ] **POLC-01**: Application can express recipient preferences that enable/disable notification channels by key/topic.
- [ ] **POLC-02**: Policy evaluation runs at planning/enqueue time and again at perform/send time for delayed deliveries.
- [ ] **POLC-03**: Delayed fallback behavior can suppress outbound delivery when in-app state shows the notification was already read.

### Integrations and Composability

- [ ] **INTG-01**: Developers can implement outbound channel integrations via explicit adapter behaviours instead of core vendor lock-in.
- [ ] **INTG-02**: v1 includes at least one outbound adapter seam (test/log adapter or email adapter wrapper) in addition to in-app delivery.
- [ ] **INTG-03**: Optional Oban integration path is documented and compatible with transactional persistence.

### Operability and OSS Quality

- [ ] **OPS-01**: Operators can trace a notification from trigger through policy, delivery planning, and attempt outcomes using durable data.
- [ ] **OPS-02**: System emits structured telemetry for core lifecycle events without leaking sensitive payload fields by default.
- [ ] **OPS-03**: Repository provides stable `mix verify.*` / `mix ci.*` entrypoints covering lint, test, and documentation/release checks.

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Admin and UX

- **ADMN-01**: Operator can use a mountable Phoenix/LiveView admin trace UI to inspect lifecycle timelines.
- **ADMN-02**: Support user can filter and inspect notification traces by recipient, key, channel, and correlation identifier.

### Channel Expansion

- **CHAN-01**: Application can deliver via additional adapters (Slack, webhook, push, SMS) with shared contract tests.
- **CHAN-02**: Push channels support token lifecycle management and invalidation handling.

### Advanced Orchestration

- **ORCH-01**: Application can define quiet hours and frequency caps for non-critical notifications.
- **ORCH-02**: Application can batch notifications into digest windows.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Hosted notification SaaS control plane | Project is intentionally embedded and local-first. |
| Marketing campaign/journey automation | Outside transactional/product notification scope. |
| Replacing Swoosh/Oban core responsibilities | Chimeway integrates existing ecosystem primitives. |
| Hardcoding one SMS or push provider as mandatory | Adapter seams must remain replaceable. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | TBD | Pending |
| CORE-02 | TBD | Pending |
| CORE-03 | TBD | Pending |
| CORE-04 | TBD | Pending |
| INBX-01 | TBD | Pending |
| INBX-02 | TBD | Pending |
| INBX-03 | TBD | Pending |
| DLVR-01 | TBD | Pending |
| DLVR-02 | TBD | Pending |
| DLVR-03 | TBD | Pending |
| DLVR-04 | TBD | Pending |
| POLC-01 | TBD | Pending |
| POLC-02 | TBD | Pending |
| POLC-03 | TBD | Pending |
| INTG-01 | TBD | Pending |
| INTG-02 | TBD | Pending |
| INTG-03 | TBD | Pending |
| OPS-01 | TBD | Pending |
| OPS-02 | TBD | Pending |
| OPS-03 | TBD | Pending |

**Coverage:**
- v1 requirements: 20 total
- Mapped to phases: 0
- Unmapped: 20 ⚠

---
*Requirements defined: 2026-04-23*
*Last updated: 2026-04-23 after initial definition*
