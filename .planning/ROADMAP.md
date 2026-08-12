# Roadmap: Chimeway

## Milestones

- ✅ **v1.17 Adopter Proof Paths** — [Archived roadmap](.planning/milestones/v1.17-ROADMAP.md) · [Audit](.planning/milestones/v1.17-MILESTONE-AUDIT.md) (shipped 2026-08-11)
- 🚧 **v1.18 Adopter Alpha Mobile Delivery Readiness** — Phases 97–103 (active)

Older shipped milestones remain indexed in `.planning/MILESTONES.md`.

## v1.18 Adopter Alpha Mobile Delivery Readiness

**Goal:** Make Chimeway production-ready for an iPhone-first, offline-capable CrossWake adopter through a tenant-safe, explainable APNs delivery path proven by a deterministic digital twin and a physical-iPhone sandbox run.

**Ownership boundaries:** The host owns raw tokens, binding persistence and authority, identity, eligibility, expiry, and one-time open intents. CrossWake owns native permission/token acquisition, offline open queueing, compiled manifests, and RouteGate activation. Chimeway owns the logical delivery, selected opaque `DeliveryTarget` revisions, attempts, recovery, and explanation.

**Proof rule:** Hermetic digital-twin gates must pass before physical promotion. Physical proof extends CrossWake Phase 162 and remains externally blocked until its Apple signing/provisioning gate is genuinely satisfied. APNs acceptance is provider handoff only; it never claims device display, open, inbox seen, or inbox read.

## Phases

- [ ] **Phase 97: Tenant Identity & Compatible Upgrade** — Tenant-safe lifecycle identity and a non-guessing upgrade path.
- [ ] **Phase 98: Privacy-Safe Delivery Evidence** — Recursive redaction and bounded diagnostics across every observable Chimeway surface.
- [ ] **Phase 99: Multi-Installation Delivery & Recovery** — One logical delivery with independently explainable opaque installation targets.
- [ ] **Phase 100: Optional APNs Adapter** — Opt-in, reason-aware APNs dispatch under host token custody.
- [ ] **Phase 101: CrossWake Registration & Protected Open** — Authenticated registration and fail-closed offline notification activation.
- [ ] **Phase 102: Alpha Digital Twin & Hermetic Gate** — Deterministic cross-repository production-path proof in CI.
- [ ] **Phase 103: Physical iPhone & Adoption Truth** — Redacted real-device sandbox evidence and operational adoption guidance.

## Phase Details

### Phase 97: Tenant Identity & Compatible Upgrade

**Goal**: Hosts can safely identify, query, and upgrade notification lifecycle state within an explicit tenant boundary.
**Depends on**: Nothing
**Requirements**: TENANT-01, TENANT-02, TENANT-03
**Success Criteria** (what must be TRUE):

  1. A host can create independent events with the same idempotency key in two tenants without collision, and each resulting notification retains its immutable tenant identity.
  2. A host cannot read or mutate inbox, trace, admin, or recovery state outside the tenant it explicitly supplies.
  3. A legacy single-tenant host continues only after it explicitly enables the compatibility configuration; otherwise formerly unscoped calls fail closed.
  4. An adopter can apply additive migrations, receive ambiguous-row reconciliation evidence, and assign ownership without Chimeway inferring a tenant or changing its static storage prefix.

**Plans:** 1/8 plans executed

Plans:
**Wave 1**

- [x] 97-01-PLAN.md — Prove explicit tenant identity, composite idempotency, and scoped trace end to end.

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 97-02-PLAN.md — Enforce tenant scope across core Inbox, Admin, and recovery operations.
- [ ] 97-04-PLAN.md — Deliver callable non-guessing reconciliation and strict JSON automation.

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 97-03-PLAN.md — Establish host-authorized tenant context in Inbox and Admin packages.
- [ ] 97-06-PLAN.md — Prove deterministic copied migrations and reconciliation in both static storage modes.
- [ ] 97-07-PLAN.md — Enforce tenant scope through core recovery claims, reloads, and replanning.

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 97-05-PLAN.md — Propagate authorized tenant context through Admin list and aggregate LiveViews.
- [ ] 97-08-PLAN.md — Propagate authorized tenant context through Admin trace and recovery LiveViews.

### Phase 98: Privacy-Safe Delivery Evidence

**Goal**: Operators can explain delivery behavior without Chimeway retaining or emitting sensitive endpoint, credential, identity, or content data.
**Depends on**: Phase 97
**Requirements**: PRIV-03, PRIV-04
**Success Criteria** (what must be TRUE):

  1. Nested map, list, and keyword-shaped diagnostics redact forbidden keys consistently regardless of casing before they are persisted or emitted.
  2. An operator can inspect a delivery trace, attempt result, telemetry projection, and proof artifact using opaque references, classifications, and allowlisted facts.
  3. Test fixtures containing raw tokens, credentials, recipient data, trusted deep links, and provider bodies cannot expose those values through Chimeway-owned storage or diagnostics.

**Plans**: TBD

### Phase 99: Multi-Installation Delivery & Recovery

**Goal**: A host can deliver one notification decision to all eligible opaque installations while preserving independent, tenant-safe target truth and recovery.
**Depends on**: Phase 98
**Requirements**: PUSH-01, PUSH-02, PUSH-03, PUSH-04, RECOV-01, RECOV-02
**Success Criteria** (what must be TRUE):

  1. A host resolver can return every active eligible installation as an opaque tenant-scoped binding revision, and Chimeway records one durable target for each selected revision.
  2. Operators can see each target's independent claim, attempt, retry, expiry, invalidation, and trace history beneath one logical delivery.
  3. Repeated planning, execution, or recovery produces neither a duplicate target nor an unexplained additional provider request; a bounded tenant-scoped worker recovers stranded work with evidence.
  4. A delivery with no eligible target is suppressed with a stable reason, while mixed terminal target results succeed only when at least one target receives APNs acceptance and retain partial failures.
  5. A crash after possible provider handoff records an explicit ambiguous outcome from pre-I/O claim and attempt-start evidence rather than silently resending or promising exactly-once delivery.

**Plans**: TBD

### Phase 100: Optional APNs Adapter

**Goal**: An APNs-enabled host can dispatch safe, bounded push requests and receive honest target-specific provider outcomes without adding push dependencies to other hosts.
**Depends on**: Phase 99
**Requirements**: APNS-01, APNS-02, APNS-03, APNS-04, APNS-05, APNS-06
**Success Criteria** (what must be TRUE):

  1. A non-push Chimeway host runs without Pigeon or APNs configuration, while an opting-in host can use the Pigeon-backed adapter through host-controlled token lookup.
  2. Each APNs request uses the selected target's correct topic and environment, stable `apns-id`, bounded allowlisted payload, host-supplied expiry, and opaque one-time open reference.
  3. Operators can distinguish accepted handoff, retryable failure, permanent payload/configuration failure, retry exhaustion, exact-binding invalidation, protected open, inbox seen, and inbox read.
  4. Expired reminders are suppressed before initial send or retry, and only host-opted replaceable occurrences use an installation-safe collapse key; distinct notifications remain uncoalesced.
  5. A provider invalidation affects only its exact tenant, environment, and binding revision, never a rotated replacement or another installation.

**Plans**: TBD

### Phase 101: CrossWake Registration & Protected Open

**Goal**: A CrossWake host can bind APNs registrations and activate notification routes only when current host authority permits it.
**Depends on**: Phase 99
**Requirements**: OPEN-01, OPEN-02, OPEN-03, OPEN-04
**Success Criteria** (what must be TRUE):

  1. A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable.
  2. Malformed, absent, or unknown action and route configuration is rejected by a manifest-consistent default-deny policy.
  3. A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization.
  4. Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized denial evidence.

**Plans**: TBD

### Phase 102: Alpha Digital Twin & Hermetic Gate

**Goal**: The full host, Chimeway, and CrossWake mobile path is reproducible in CI without Apple credentials and rejects regressions in safety-critical behavior.
**Depends on**: Phase 100, Phase 101
**Requirements**: TWIN-01, TWIN-02, GATE-01
**Success Criteria** (what must be TRUE):

  1. A sanitized Adopter Alpha reference host runs real Chimeway persistence with deterministic time, a host token registry, and a scripted fake APNs transport.
  2. The hermetic proof demonstrates two-installation fan-out, zero-target suppression, rotation/revocation races, classified retry, expiry, collapse, crash recovery, recursive leak prevention, and denied or replayed offline opens.
  3. Named `mix verify.*` entrypoints run the cross-repository proof in CI without Apple credentials and reject malformed physical-proof evidence.

**Plans**: TBD

### Phase 103: Physical iPhone & Adoption Truth

**Goal**: Adopter Alpha can present bounded, redacted real-iPhone evidence of the production path and understand its operational limits.
**Depends on**: Phase 102
**Requirements**: TWIN-03, DOCS-01
**Success Criteria** (what must be TRUE):

  1. Once CrossWake Phase 162's external Apple signing gate is satisfied, a physical-iPhone sandbox run records permission, token registration, APNs acceptance, visible alert confirmation, and one-time protected activation in dated redacted evidence.
  2. The proof record is machine-validatable and separates the subjective visible-alert observation from executable provider and protected-open assertions.
  3. Host and operator guidance explains setup, ownership boundaries, compatibility migration, outcome vocabulary, offline-open behavior, proof commands, and explicit non-goals.

**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 97. Tenant Identity & Compatible Upgrade | 1/8 | In Progress|  |
| 98. Privacy-Safe Delivery Evidence | 0/TBD | Not started | - |
| 99. Multi-Installation Delivery & Recovery | 0/TBD | Not started | - |
| 100. Optional APNs Adapter | 0/TBD | Not started | - |
| 101. CrossWake Registration & Protected Open | 0/TBD | Not started | - |
| 102. Alpha Digital Twin & Hermetic Gate | 0/TBD | Not started | - |
| 103. Physical iPhone & Adoption Truth | 0/TBD | Blocked by external Apple signing gate until Phase 162 evidence | - |

---
*Roadmap updated: 2026-08-11 — v1.18 created with Phases 97–103.*
