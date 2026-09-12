# Requirements: Chimeway

**Defined:** 2026-09-12
**Milestone:** v1.19 Adopter Hardening & Inbox Lifecycle
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.19 Requirements

### Adopter Recipe Truth

- [x] **DOCS-02**: A CrossWake host can copy a durable provider-feedback worker recipe that uses the real provider-attribute conversion boundary and supplies every authenticated binding-authority option required by the registry.
- [x] **GATE-02**: A maintainer can run an executable contract against a separately selected CrossWake documentation revision that rejects nonexistent APIs, incomplete authority scope, and vacuous examples without changing the immutable v1.18 physical-proof revision.

### Tenant-Safe Inbox Changes

- [ ] **INBX-03**: A host can opt into a replaceable inbox-change publisher that emits a closed event only after durable notification creation or a first seen, read, or archive transition, without adding Phoenix or PubSub as a core dependency.
- [ ] **INBX-04**: A connected `chimeway_inbox` bell subscribes only to its currently authorized tenant and opaque recipient stream and refreshes its badge and visible items on relevant arrival and lifecycle events without polling or cross-tenant disclosure.

### Seen, Read, and Explanation

- [ ] **INT-02**: An operator can distinguish notification-seen and notification-read facts on each correlated delivery timeline using stable event names, timestamps, and allowlisted detail without recipient identity or caller metadata.
- [ ] **INT-03**: Opening the bell panel marks only the currently visible, re-authorized inbox items seen, and repeated panel opens produce neither duplicate state transitions nor duplicate seen signals.
- [ ] **INT-04**: A deterministic end-to-end journey proves that the first `chimeway.notification.seen` signal can progress an eligible waiting workflow while replay, wrong-tenant, and wrong-recipient paths do not progress it.

### Guidance and Gates

- [ ] **DOCS-03**: Host guidance explains publisher configuration, topic ownership, tenant and recipient isolation, arrival/seen/read/archive semantics, reconnect behavior, and the distinction between inbox state, protected open, provider handoff, and engagement.
- [ ] **GATE-03**: Named inbox and aggregate verification entrypoints prove the packaged LiveView, demo-host arrival-to-seen-to-read journey, workflow progression, operator timeline, documentation contract, and Phoenix-optional core boundary.

## Future Requirements

### CI Performance

- **CACHE-05**: A proven compile-once design materially reduces warm `ci-gate` wall-clock without weakening cache correctness, isolation, or gate coverage.

### Mobile Expansion

- **FCM-01**: An Android-enabled host can use a provider-neutral FCM transport and present bounded physical-device proof under the same custody and explainability rules as APNs.

### Deferred Quality

- **A11Y-03**: Complete the previously waived browser focus-not-obscured check for the brandbook.
- **A11Y-04**: Complete the previously waived color-vision-deficiency emulation check for the brandbook.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Moving or rewriting the v1.18 selected physical-proof revision | v1.18 support truth is immutable; v1.19 tracks any CrossWake documentation revision separately. |
| Phoenix or PubSub dependency in core Chimeway | Core exposes a replaceable host-owned publication seam; the optional LiveView package owns Phoenix subscription behavior. |
| Raw tenant, recipient, token, route, or notification content in change events or topics | Real-time updates must preserve the opaque evidence and host-custody boundaries established in v1.18. |
| Generic offline inbox synchronization | v1.19 refreshes connected LiveViews and reloads durable host state after reconnect; it does not create a client sync protocol. |
| Inbox visual redesign or styled component system | This milestone completes lifecycle behavior and accessibility-preserving structural hooks, not a new visual language. |
| Engagement analytics or delivered/opened inference | Provider handoff, protected activation, inbox seen/read, and engagement remain separate facts. |
| New push providers or Android/FCM | Mobile breadth follows adopter hardening, inbox lifecycle completion, and the CI performance investigation. |

## Traceability

Which phases cover which requirements. Filled during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOCS-02 | Phase 104 | Complete |
| GATE-02 | Phase 104 | Complete |
| INBX-03 | Phase 105 | Pending |
| INBX-04 | Phase 105 | Pending |
| INT-03 | Phase 106 | Pending |
| INT-04 | Phase 106 | Pending |
| INT-02 | Phase 107 | Pending |
| DOCS-03 | Phase 107 | Pending |
| GATE-03 | Phase 107 | Pending |

**Coverage:**

- v1.19 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-12*
*Last updated: 2026-09-12 after v1.19 roadmap mapping*
