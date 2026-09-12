# Roadmap: Chimeway

## Milestones

- 🚧 **v1.19 Adopter Hardening & Inbox Lifecycle** — Phases 104–107 (active)
- ✅ **v1.18 Adopter Alpha Mobile Delivery Readiness** — [Archived roadmap](milestones/v1.18-ROADMAP.md) · [Requirements](milestones/v1.18-REQUIREMENTS.md) · [Audit](milestones/v1.18-MILESTONE-AUDIT.md) (shipped 2026-09-12)
- ✅ **v1.17 Adopter Proof Paths** — [Archived roadmap](milestones/v1.17-ROADMAP.md) · [Audit](milestones/v1.17-MILESTONE-AUDIT.md) (shipped 2026-08-11)

Older shipped milestones remain indexed in `.planning/MILESTONES.md`.

## v1.19 Adopter Hardening & Inbox Lifecycle

**Goal:** Close the remaining copy-paste adoption seam from v1.18 and make inbox arrival, seen, and read state update in real time and appear honestly in operator explanations without weakening tenant or privacy boundaries.

**Boundary:** CrossWake documentation truth is tracked at a new docs revision and never rewrites the immutable v1.18 physical-proof authority. Core Chimeway remains Phoenix-free; optional packages and host adapters own PubSub. Real-time messages are reload hints, while durable host-owned state remains authoritative.

## Phases

- [x] **Phase 104: CrossWake Provider-Feedback Recipe Truth** — Repair the external copy-paste path and lock it to real authority APIs without moving v1.18 proof truth. (completed 2026-09-12)
- [x] **Phase 105: Tenant-Safe Inbox Change Stream** — Publish closed durable-change hints and refresh only the authorized connected bell. (completed 2026-09-12)
- [ ] **Phase 106: Idempotent Seen Lifecycle & Workflow Proof** — Wire panel visibility to first-seen state and prove safe workflow progression.
- [ ] **Phase 107: Operator Timeline, Guidance & Gate Parity** — Expose safe seen/read facts and require the completed adopter journey everywhere it matters.

## Phase Details

### Phase 104: CrossWake Provider-Feedback Recipe Truth

**Goal**: A CrossWake adopter can copy and verify a durable provider-feedback worker that uses the actual conversion and authenticated registry boundaries.
**Depends on**: Nothing
**Requirements**: DOCS-02, GATE-02
**Success Criteria** (what must be TRUE):

1. The CrossWake example-host README calls `Redaction.feedback_from_provider_attrs/1` and passes the exact authenticated binding, installation, application, and conditional session authority required by `Registry.apply_provider_feedback/2`.
2. Executable CrossWake examples cover accepted advisory feedback, exact invalidation, stale or mismatched denial, and recursively sanitized evidence without a vacuous or nonexistent API path.
3. A Chimeway contract verifies the separately selected CrossWake documentation revision from a fresh remote checkout and proves that the immutable v1.18 physical-proof revision did not move.

**Plans**: 2/2 complete

- [x] `104-01` — Publish a source-valid CrossWake provider-feedback recipe and exact documentation revision.
- [x] `104-02` — Enforce detached documentation truth across Chimeway CI and release gates.

### Phase 105: Tenant-Safe Inbox Change Stream

**Goal**: Connected inbox clients can refresh from durable state when their exact authorized stream changes, without making Phoenix a core dependency.
**Depends on**: Nothing
**Requirements**: INBX-03, INBX-04
**Success Criteria** (what must be TRUE):

1. A host can configure a replaceable publisher behaviour that emits one closed reload hint after durable notification creation and each first seen, read, or archive transition; repeated lifecycle calls emit no duplicate hint.
2. Publisher failure never rolls back or falsifies the already-durable notification lifecycle, and safe diagnostics expose only a stable classification.
3. `chimeway_inbox` subscribes only after host authorization to an opaque tenant-and-recipient topic, reloads authoritative state on relevant messages, and ignores unrelated tenant or recipient messages.
4. A non-Phoenix Chimeway consumer still compiles and runs without Phoenix PubSub or `chimeway_inbox` dependencies.

**Plans**: 2/2 complete

- [x] `105-01` — Add the Phoenix-free durable inbox change publisher and lifecycle hooks.
- [x] `105-02` — Add opaque PubSub routing and authorized LiveView refresh.

### Phase 106: Idempotent Seen Lifecycle & Workflow Proof

**Goal**: Opening the authorized bell records exactly the visible first-seen facts and can progress an eligible workflow once.
**Depends on**: Phase 105
**Requirements**: INT-03, INT-04
**Success Criteria** (what must be TRUE):

1. Opening the bell panel reauthorizes the mounted tenant and recipient before marking only the currently visible page of items seen.
2. Reopening, reconnecting, or receiving duplicate reload hints creates neither duplicate seen timestamps nor duplicate `chimeway.notification.seen` signals.
3. A deterministic demo journey proves that the first seen signal progresses an eligible waiting workflow exactly once, while replay, wrong-tenant, wrong-recipient, and authorization-change paths do not progress it.
4. The bell reloads durable state after reconnect or publication gaps instead of treating ephemeral messages as lifecycle truth.

**Plans**: 2 plans

- [ ] `106-01` — Mark authorized visible inbox items seen idempotently.
- [ ] `106-02` — Prove mounted seen-to-workflow progression and scope denials.

### Phase 107: Operator Timeline, Guidance & Gate Parity

**Goal**: Adopters and operators can understand and continuously verify the complete arrival-to-seen-to-read path.
**Depends on**: Phase 104, Phase 105, Phase 106
**Requirements**: INT-02, DOCS-03, GATE-03
**Success Criteria** (what must be TRUE):

1. Every correlated delivery explanation can include stable notification-seen and notification-read timeline entries with authoritative timestamps and closed detail, without recipient identity or caller metadata.
2. The optional admin timeline renders the new event types distinctly while preserving existing redaction and outcome semantics.
3. Host guidance documents publisher and topic ownership, tenant/recipient isolation, reconnect behavior, and the difference between arrival, provider handoff, protected activation, inbox seen/read, and engagement.
4. `mix verify.inbox` and both aggregate CI gates require packaged LiveView, demo journey, workflow progression, operator timeline, docs-contract, and Phoenix-optional boundary evidence.

**Plans**: TBD

<details>
<summary>✅ v1.18 Adopter Alpha Mobile Delivery Readiness (Phases 97–103) — SHIPPED 2026-09-12</summary>

- [x] Phase 97: Tenant Identity & Compatible Upgrade (14/14 plans) — completed 2026-08-12
- [x] Phase 98: Privacy-Safe Delivery Evidence (15/15 plans) — completed 2026-08-19
- [x] Phase 99: Multi-Installation Delivery & Recovery (12/12 plans) — completed 2026-08-20
- [x] Phase 100: Optional APNs Adapter (11/11 plans) — completed 2026-08-22
- [x] Phase 101: CrossWake Registration & Protected Open (20/20 plans) — completed 2026-08-25
- [x] Phase 102: Alpha Digital Twin & Hermetic Gate (4/4 plans) — completed 2026-08-26
- [x] Phase 103: Physical iPhone & Adoption Truth (4/4 plans) — completed 2026-09-12

</details>

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 104. CrossWake Provider-Feedback Recipe Truth | 2/2 | Complete    | 2026-09-12 |
| 105. Tenant-Safe Inbox Change Stream | 2/2 | Complete    | 2026-09-12 |
| 106. Idempotent Seen Lifecycle & Workflow Proof | 1/2 | In Progress|  |
| 107. Operator Timeline, Guidance & Gate Parity | 0/TBD | Not started | — |

---
*Roadmap updated: 2026-09-12 when creating the v1.19 roadmap.*
