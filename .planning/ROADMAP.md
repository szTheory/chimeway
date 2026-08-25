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

- [x] **Phase 97: Tenant Identity & Compatible Upgrade** — Tenant-safe lifecycle identity and a non-guessing upgrade path. (completed 2026-08-12)
- [x] **Phase 98: Privacy-Safe Delivery Evidence** — Recursive redaction and bounded diagnostics across every observable Chimeway surface. (completed 2026-08-19)
- [x] **Phase 99: Multi-Installation Delivery & Recovery** — One logical delivery with independently explainable opaque installation targets. (completed 2026-08-20)
- [x] **Phase 100: Optional APNs Adapter** — Opt-in, reason-aware APNs dispatch under host token custody. (completed 2026-08-22)
- [x] **Phase 101: CrossWake Registration & Protected Open** — Authenticated registration and fail-closed offline notification activation. (completed 2026-08-25)
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

**Plans:** 14/14 plans complete

Plans:
**Wave 1**

- [x] 97-01-PLAN.md — Prove explicit tenant identity, composite idempotency, and scoped trace end to end.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 97-02-PLAN.md — Enforce tenant scope across core Inbox, Admin, and recovery operations.
- [x] 97-04-PLAN.md — Deliver callable non-guessing reconciliation and strict JSON automation.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 97-03-PLAN.md — Establish host-authorized tenant context in Inbox and Admin packages.
- [x] 97-06-PLAN.md — Prove deterministic copied migrations and reconciliation in both static storage modes.
- [x] 97-07-PLAN.md — Enforce tenant scope through core recovery claims, reloads, and replanning.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 97-05-PLAN.md — Propagate authorized tenant context through Admin list and aggregate LiveViews.
- [x] 97-08-PLAN.md — Propagate authorized tenant context through Admin trace and recovery LiveViews.

**Gap Closure Wave 1** *(97-09, 97-10, and 97-11 are independent)*

- [x] 97-09-PLAN.md — Canonicalize padded trigger tenant identity through persistence, dispatch, and scoped trace reads.
- [x] 97-10-PLAN.md — Make migration 032 rollback explicitly irreversible and prove lossless refusal in both static storage modes.
- [x] 97-11-PLAN.md — Restore the runtime-prefix recovery gate with explicit tenant scope on all three recovery operations.

**Gap Closure Wave 2** *(97-12, 97-13, and 97-14 are independent)*

- [x] 97-12-PLAN.md — Enforce lifecycle-wide tenant coherence in Admin DTOs and re-authorize Feed searches after mount.
- [x] 97-13-PLAN.md — Reconcile Delivery ownership atomically with Event and Notification ownership.
- [x] 97-14-PLAN.md — Fail closed when Inbox recipient or tenant identity changes after mount.

### Phase 98: Privacy-Safe Delivery Evidence

**Goal**: Operators can explain delivery behavior without Chimeway retaining or emitting sensitive endpoint, credential, identity, or content data.
**Depends on**: Phase 97
**Requirements**: PRIV-03, PRIV-04
**Success Criteria** (what must be TRUE):

  1. Nested map, list, and keyword-shaped diagnostics redact forbidden keys consistently regardless of casing before they are persisted or emitted.
  2. An operator can inspect a delivery trace, attempt result, telemetry projection, and proof artifact using opaque references, classifications, and allowlisted facts.
  3. Test fixtures containing raw tokens, credentials, recipient data, trusted deep links, and provider bodies cannot expose those values through Chimeway-owned storage or diagnostics.

**Plans:** 15/15 plans complete

Plans:

**Wave 1**

- [x] 98-01-PLAN.md — Prove recursive privacy and safe attempt-to-trace evidence end to end.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 98-02-PLAN.md — Close Trigger, delivery-planning, and Inbox write/query boundaries.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 98-03-PLAN.md — Bound adapter, telemetry, and log failure evidence.

**Wave 4** *(98-04 and 98-05 run independently after Wave 3)*

- [x] 98-04-PLAN.md — Make trace and core Admin projections independently safe.
- [x] 98-05-PLAN.md — Bind machine-readable proof to honest safe evidence.

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 98-06-PLAN.md — Purge legacy blobs and prove public/prefixed privacy gates.

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 98-07-PLAN.md — Close approved-key value validation and restore digested trace status.

**Gap Closure Wave 7** *(98-08 and 98-09 run independently after Wave 6)*

- [x] 98-08-PLAN.md — Separate private render dispatch context from safe public and durable evidence.
- [x] 98-09-PLAN.md — Fail closed on duplicate evidence fields and validate provider codes with the closed grammar.

**Gap Closure Wave 8** *(blocked on Gap Closure Wave 7 completion)*

- [x] 98-10-PLAN.md — Restore queued email delivery through host-owned transient context without expanding Chimeway custody.

**Gap Closure Wave 9** *(blocked on Gap Closure Wave 8 completion)*

- [x] 98-11-PLAN.md — Record bounded durable attempt evidence for queued hydration failures, retries, and exhaustion.

**Gap Closure Wave 10** *(blocked on Gap Closure Wave 9 completion)*

- [x] 98-12-PLAN.md — Require host-owned opaque recipient references and reject raw identity before Trigger or Workflow persistence.

**Gap Closure Wave 11** *(blocked on Gap Closure Wave 10 completion)*

- [x] 98-13-PLAN.md — Restore lifecycle regression evidence with explicit opaque recipient fixtures.

**Gap Closure Wave 12** *(blocked on Gap Closure Wave 11 completion)*

- [x] 98-14-PLAN.md — Close public Trace projections and restore opaque-recipient Core/Mailglass adoption proof.

**Gap Closure Wave 13** *(blocked on Gap Closure Wave 12 completion)*

- [x] 98-15-PLAN.md — Close arbitrary-struct redaction and nested trace evidence escape hatches.

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

**Plans**: 12/12 plans executed

Plans:

- [x] 99-12-PLAN.md

**Wave 1**

- [x] 99-01-PLAN.md — Prove one opaque target end to end beneath the canonical push delivery.

**Wave 2** *(after tracer verification)*

- [x] 99-02-PLAN.md — Lock copied migration parity across public and prefixed static storage.
- [x] 99-03-PLAN.md — Expand deterministic multi-target planning, aggregation, and traces.

**Wave 3** *(after multi-target contracts)*

- [x] 99-04-PLAN.md — Gate sync/Oban handoff on durable claims and preserve ambiguous crashes.

**Wave 4** *(after storage, aggregate, and handoff contracts)*

- [x] 99-05-PLAN.md — Recover bounded tenant-owned event and target work with safe evidence.

**Gap Closure Wave 5** *(blocked on Wave 4 completion)*

- [x] 99-06-PLAN.md — Close every adapter outcome with honest durable target and attempt evidence.

**Gap Closure Wave 6** *(blocked on Gap Closure Wave 5 completion)*

- [x] 99-07-PLAN.md — Make tenant recovery complete, independently pageable, bounded, and operationally evidenced.

**Gap Closure Wave 7** *(99-08, 99-09, and 99-10 run independently after Wave 6)*

- [x] 99-08-PLAN.md — Load independent target histories through every common operator trace and explanation path.
- [x] 99-09-PLAN.md — Execute every selected tenant-qualified target through synchronous push dispatch.
- [x] 99-10-PLAN.md — Gate target work on parent lifecycle, close retry exhaustion, and preserve ambiguous handoff races.

**Gap Closure Wave 8** *(blocked on Gap Closure Wave 7 completion)*

- [x] 99-11-PLAN.md — Recompute empty Oban fan-out and enforce parent-first stale recovery concurrency.

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

**Plans**: 11/11 plans executed

Plans:

**Wave 1**

- [x] 100-01-PLAN.md — Prove the persisted accepted-handoff APNs tracer across planning, target attempt, host custody, bounds, and provider evidence.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 100-02-PLAN.md — Publish and rollback safe APNs intent storage across repository, public, and prefixed migration modes.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 100-03-PLAN.md — Complete closed request construction, exact host lookup, and the optional pinned Pigeon transport seam.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 100-04-PLAN.md — Classify every provider outcome into exact target lifecycle, retry, invalidation, and operator evidence paths.

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 100-05-PLAN.md — Prove no-Pigeon clean consumption, explicit host opt-in, full API coverage, and local/CI gate parity.

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 100-06-PLAN.md — Carry represented Pigeon 2.0.1 APNs 410 responses through the production callback bridge to exact-binding invalidation, and require that proof in both hosted aggregate gates.

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 100-07-PLAN.md — Prove the public `APNS.deliver/2` → real Pigeon response bridge → classifier → exact host CAS path, including fail-closed variants.

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 100-08-PLAN.md — Restore packaged ordinary APNs success handling and enforce a deterministic advisory-free enabled-consumer dependency graph.

**Wave 9** *(blocked on Wave 8 completion)*

- [x] 100-09-PLAN.md — Preserve honest pre-provider failure evidence and enforce warning-strict enabled-consumer compilation.

**Wave 10** *(blocked on Wave 9 completion)*

- [x] 100-11-PLAN.md — Restore a passing enabled packaged-consumer gate while preserving warning-strict evidence for Chimeway-owned compilation.

**Wave 11** *(blocked on Wave 10 completion)*

- [x] 100-10-PLAN.md — Reject unsafe open references and collapse-header bytes consistently before persistence or APNs handoff.

### Phase 101: CrossWake Registration & Protected Open

**Goal**: A CrossWake host can bind APNs registrations and activate notification routes only when current host authority permits it.
**Depends on**: Phase 99
**Requirements**: OPEN-01, OPEN-02, OPEN-03, OPEN-04
**Success Criteria** (what must be TRUE):

  1. A signed-in user can complete permission, APNs registration, and authenticated host binding; repeated observations, rotation, logout, revocation, and provider invalidation leave only the current binding usable.
  2. Malformed, absent, or unknown action and route configuration is rejected by a manifest-consistent default-deny policy.
  3. A notification tap contains only opaque evidence; offline taps queue safely and reconnect only activates a one-time intent after tenant, revision, expiry, session, manifest, and RouteGate reauthorization.
  4. Replayed, expired, revoked, mismatched, logged-out, tenant-switched, or removed-route opens activate no fallback route and produce sanitized denial evidence.

**Plans**: 20/20 plans executed

Plans:

**Wave 1**

- [x] 101-01-PLAN.md — Prove one host-consumed, current-policy-authorized notification tap and replay denial end to end.

**Wave 2** *(after tracer verification)*

- [x] 101-02-PLAN.md — Normalize notification-open authoring and compiled manifest policy.
- [x] 101-04-PLAN.md — Enforce authenticated current binding revision under lifecycle races.
- [x] 101-06-PLAN.md — Add explicit iOS permission, APNs observation, and host-binding states.

**Wave 3** *(after normalized policy and binding authority)*

- [x] 101-03-PLAN.md — Reject malformed compiled policy and require exact current action membership.
- [x] 101-05-PLAN.md — Atomically consume one-time intents with current tenant/session/binding authority.

**Wave 4** *(after host and policy authorization)*

- [x] 101-07-PLAN.md — Queue opaque taps offline and consume them safely on reconnect.
- [x] 101-08-PLAN.md — Close protected-open denial, redaction, and telemetry vocabularies.

**Wave 5** *(phase acceptance)*

- [x] 101-09-PLAN.md — Prove the complete stale-authority no-fallback denial matrix.

**Wave 6** *(gap closure after phase acceptance)*

- [x] 101-10-PLAN.md — Restore forward-only host upgrades and posture-independent, conflict-safe binding uniqueness.
- [x] 101-11-PLAN.md — Make native permission-loss revocation acknowledgement-driven and retry-safe.

**Wave 7** *(verification gap closure)*

- [x] 101-12-PLAN.md — Enforce exact provider-feedback scope and reconcile both active-binding uniqueness domains.
- [x] 101-13-PLAN.md — Compact duplicate opaque open evidence before production reconnect drain.

**Wave 8** *(remaining verification gap closure)*

- [x] 101-14-PLAN.md — Support exact installation-scoped invalidation and protected-open consumption with recursively sanitized intent metadata.

**Wave 9** *(final verification gap closure; after Wave 8)*

- [x] 101-15-PLAN.md — Enforce installation/session authority separation and isolate logout/session revocation selection.
- [x] 101-16-PLAN.md — Drop all caller-controlled metadata at the durable notification-open boundary.

**Wave 10** *(remaining verifier gap closure; plans run independently)*

- [x] 101-17-PLAN.md — Drop caller metadata across registration binding and append-only audit persistence.
- [x] 101-18-PLAN.md — Backfill exact binding-derived legacy intent scope and prove current-authority consumption.

**Wave 11** *(blocked on Wave 10 completion)*

- [x] 101-19-PLAN.md — Append exactly one sanitized reconciliation event for every migration-forced intent revocation.

**Wave 12** *(blocked on Wave 11 completion)*

- [x] 101-20-PLAN.md — Bind logout to the exact authenticated session version and protect append-only notification-open history from parent deletion.

### Phase 102: Alpha Digital Twin & Hermetic Gate

**Goal**: The full host, Chimeway, and CrossWake mobile path is reproducible in CI without Apple credentials and rejects regressions in safety-critical behavior.
**Depends on**: Phase 100, Phase 101
**Requirements**: TWIN-01, TWIN-02, GATE-01
**Success Criteria** (what must be TRUE):

  1. A sanitized Adopter Alpha reference host runs real Chimeway persistence with deterministic time, a host token registry, and a scripted fake APNs transport.
  2. The hermetic proof demonstrates two-installation fan-out, zero-target suppression, rotation/revocation races, classified retry, expiry, collapse, crash recovery, recursive leak prevention, and denied or replayed offline opens.
  3. Named `mix verify.*` entrypoints run the cross-repository proof in CI without Apple credentials and reject malformed physical-proof evidence.

**Plans**: 2/4 plans executed

Plans:

**Wave 1**

- [x] 102-01-PLAN.md — Publish and machine-verify the exact locked CrossWake commit, then prove one immutable-package host-to-Chimeway-to-CrossWake accepted tracer.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 102-02-PLAN.md — Add deterministic clock, host-authority registry, and ordered scripted-transport seams.

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 102-03-PLAN.md — Execute the complete ordered delivery, recovery, privacy, and protected-open safety ledger through the resolved crash seam.

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 102-04-PLAN.md — Consume Plan 01's exact-SHA reachability evidence, bind provenance, validate the future physical-proof contract, and require the Alpha lane in both aggregate gates.

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
| 97. Tenant Identity & Compatible Upgrade | 14/14 | Complete    | 2026-08-12 |
| 98. Privacy-Safe Delivery Evidence | 15/15 | Complete    | 2026-08-19 |
| 99. Multi-Installation Delivery & Recovery | 12/12 | Complete    | 2026-08-20 |
| 100. Optional APNs Adapter | 11/11 | Complete    | 2026-08-22 |
| 101. CrossWake Registration & Protected Open | 20/20 | Complete    | 2026-08-25 |
| 102. Alpha Digital Twin & Hermetic Gate | 2/4 | In Progress|  |
| 103. Physical iPhone & Adoption Truth | 0/TBD | Blocked by external Apple signing gate until Phase 162 evidence | - |

---
*Roadmap updated: 2026-08-11 — v1.18 created with Phases 97–103.*
