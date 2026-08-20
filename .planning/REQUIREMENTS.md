# Requirements: Chimeway

**Defined:** 2026-08-11
**Milestone:** v1.18 Adopter Alpha Mobile Delivery Readiness
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.18 Requirements

### Tenant Safety and Compatibility

- [x] **TENANT-01**: A host can persist every new event and notification under an immutable `tenant_id`, with event idempotency scoped to `{tenant_id, idempotency_key}`.
- [x] **TENANT-02**: A host can query or mutate inbox, trace, admin, and recovery state only within an explicit tenant scope; existing single-tenant signatures work only when explicit compatibility mode is configured.
- [x] **TENANT-03**: An adopter can migrate existing rows additively, receive a report for ambiguous legacy rows, and reconcile them without Chimeway guessing tenant ownership or changing static storage-prefix behavior.

### Privacy and Diagnostic Safety

- [x] **PRIV-03**: Nested maps, lists, and keyword-shaped values are recursively redacted with case-normalized forbidden-key handling before persistence, telemetry, logs, traces, DTOs, and proof output.
- [x] **PRIV-04**: Raw device tokens, credentials, recipient or adopter data, trusted deep links, and provider bodies never enter Chimeway-owned storage or diagnostics; only opaque references, fingerprints, stable classifications, and allowlisted provider facts are retained.

### Mobile Target Model

- [x] **PUSH-01**: A host can implement a public target-resolution behaviour that returns every active eligible installation as an opaque, tenant-scoped binding revision without exposing raw tokens.
- [x] **PUSH-02**: One logical push delivery durably records one target child per selected installation, and each target has independent claim, attempt, retry, invalidation, expiry, and trace history.
- [x] **PUSH-03**: Duplicate planning, job execution, or recovery cannot create a duplicate target or an unexplained additional provider request.
- [x] **PUSH-04**: A logical push with no eligible targets is suppressed with a stable explainable reason; after all targets terminate, it succeeds when at least one was APNs-accepted and exposes partial failures without claiming all-device delivery.

### APNs Dispatch

- [ ] **APNS-01**: An APNs-enabled host can opt into a Pigeon-backed adapter without adding Pigeon or APNs configuration to non-push Chimeway installations.
- [ ] **APNS-02**: Each request uses host-resolved token custody, the correct environment and topic, a stable `apns-id`, a bounded allowlisted payload, and an opaque one-time open reference.
- [ ] **APNS-03**: APNs outcomes are classified by reason into accepted handoff, retryable, permanent configuration or payload failure, or exact-binding invalidation; invalidation never affects a rotated replacement or another tenant or environment.
- [ ] **APNS-04**: The host supplies an absolute expiry; Chimeway checks it before send and retry, maps it to `apns-expiration`, and records explicit expiry suppression instead of delivering stale reminders.
- [ ] **APNS-05**: A host may opt a replaceable reminder occurrence into an opaque, installation-safe collapse key; distinct notifications omit collapse and are never silently coalesced.
- [ ] **APNS-06**: Operators can distinguish local dispatch intent, APNs acceptance or rejection, retry exhaustion, target invalidation, protected app open, and inbox seen or read without conflating these states.

### Recovery

- [ ] **RECOV-01**: A tenant-scoped recovery worker can claim and replan events stranded after trigger commit, with bounded concurrency and explainable recovery evidence.
- [ ] **RECOV-02**: Chimeway persists target claim and attempt-start evidence before provider I/O and represents a crash after possible APNs acceptance as an explicit ambiguous handoff rather than silently promising exactly-once delivery or blindly resending.

### CrossWake Registration and Opens

- [ ] **OPEN-01**: CrossWake supports explicit permission to APNs registration to authenticated host binding, including idempotent token observation, rotation, logout or session revocation, and provider-driven invalidation.
- [ ] **OPEN-02**: CrossWake's notification action allowlist is normalized consistently with compiled manifests and fails closed for malformed, absent, or unknown route or action configuration.
- [ ] **OPEN-03**: A notification tap carries only opaque evidence; when offline it enters a safe queued state and, after reconnect, atomically consumes the one-time intent and rechecks tenant, binding revision, expiry, session, manifest, and RouteGate authorization.
- [ ] **OPEN-04**: Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or route-removed opens activate no fallback route and produce sanitized explainable denial evidence.

### Proof, Documentation, and Gates

- [ ] **TWIN-01**: A sanitized Adopter Alpha host exercises real Chimeway persistence and CrossWake contracts with deterministic time, a host token registry, and a scripted fake APNs transport.
- [ ] **TWIN-02**: The hermetic twin proves two-installation fan-out, no-target suppression, rotation or revocation races, reason-classified retry, expiry and collapse, trigger crash recovery, recursive leak prevention, and offline, replayed, or denied opens.
- [ ] **TWIN-03**: A physical-iPhone APNs sandbox run proves permission, token registration, APNs acceptance, visible alert, and one-time protected activation while emitting only redacted machine-readable evidence; subjective display confirmation is isolated from executable assertions.
- [ ] **GATE-01**: Named `mix verify.*` entrypoints run the hermetic cross-repository proof in CI and validate the physical-proof evidence contract without requiring Apple credentials in CI.
- [ ] **DOCS-01**: Integration and operator guidance accurately documents ownership boundaries, setup, compatibility migration, outcome vocabulary, offline-open behavior, proof commands, and explicit non-goals.

## Future Requirements

### Mobile Expansion

- **FCM-01**: Add an FCM transport and Android production proof after the APNs-first contract is proven.
- **INBX-03**: Add recipient-facing inbox PubSub badge updates when inbox UI iteration is actively prioritized.
- **INT-02**: Project inbox lifecycle signals onto the operator delivery timeline.
- **INT-03**: Complete `mark_seen` progression E2E and BellDropdownLive wiring.

## Out of Scope

| Feature | Reason |
|---------|--------|
| FCM or Android transport | Adopter Alpha's active production path is iPhone-first; provider-neutral contracts remain extensible. |
| Generic offline or background sync | CrossWake's offline contract remains route-scoped and server-authoritative; push does not expand it. |
| Push delivered, read, opened, or engagement analytics | APNs acceptance proves provider handoff only; protected open and inbox lifecycle remain distinct facts. |
| Raw-token storage or device management in Chimeway | The host owns raw tokens, identity, eligibility, binding authority, and credentials. |
| Campaign builder, rich media, or arbitrary notification actions | The milestone proves one bounded protected-open path, not a general push-marketing surface. |
| Inbox PubSub and `mark_seen` polish | SEED-004 remainder was explicitly excluded to keep the production push milestone coherent. |
| Dynamic tenant database prefixes | Domain tenant identity must not reopen the rejected prefix-per-request design. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TENANT-01 | Phase 97 | Complete |
| TENANT-02 | Phase 97 | Complete |
| TENANT-03 | Phase 97 | Complete |
| PRIV-03 | Phase 98 | Gaps Found |
| PRIV-04 | Phase 98 | Gaps Found |
| PUSH-01 | Phase 99 | Gaps Found |
| PUSH-02 | Phase 99 | Gaps Found |
| PUSH-03 | Phase 99 | Gaps Found |
| PUSH-04 | Phase 99 | Gaps Found |
| RECOV-01 | Phase 99 | Gaps Found |
| RECOV-02 | Phase 99 | Gaps Found |
| APNS-01 | Phase 100 | Pending |
| APNS-02 | Phase 100 | Pending |
| APNS-03 | Phase 100 | Pending |
| APNS-04 | Phase 100 | Pending |
| APNS-05 | Phase 100 | Pending |
| APNS-06 | Phase 100 | Pending |
| OPEN-01 | Phase 101 | Pending |
| OPEN-02 | Phase 101 | Pending |
| OPEN-03 | Phase 101 | Pending |
| OPEN-04 | Phase 101 | Pending |
| TWIN-01 | Phase 102 | Pending |
| TWIN-02 | Phase 102 | Pending |
| GATE-01 | Phase 102 | Pending |
| TWIN-03 | Phase 103 | Pending |
| DOCS-01 | Phase 103 | Pending |

**Coverage:**

- v1.18 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0

---
*Requirements defined: 2026-08-11*
*Last updated: 2026-08-11 after v1.18 roadmap mapping*
