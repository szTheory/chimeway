# Requirements: Chimeway

**Defined:** 2026-08-08
**Milestone:** v1.17 Adopter Proof Paths
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.17 Requirements

### Adoption Clarity

- [ ] **ADPT-01**: A prospective adopter can choose the Core, Mailglass, or Accrue path from their intended outcome and understand the responsibility boundary between Chimeway and each integration partner.
- [ ] **ADPT-02**: Each supported path documents its proof command, observable outcome, and explicit coverage boundary.

### Hermetic Proof Foundation

- [ ] **PROOF-01**: A clean consumer fixture installs Chimeway from an unpacked built package artifact without a root source-path dependency.
- [ ] **PROOF-02**: The fixture can boot, migrate, and run the documented proof commands reproducibly with the project-supported PostgreSQL environment.
- [ ] **PROOF-03**: Every adoption proof asserts its lifecycle evidence through a public Chimeway explainability API.

### Core Trace Path

- [ ] **CORE-01**: The Core path proves notifier definition through trigger, durable delivery outcome, and an explainable trace in the clean consumer fixture.

### Transactional Email Path

- [ ] **MAIL-01**: The Mailglass path proves configured transactional-email orchestration and trace evidence in the clean consumer fixture.
- [ ] **MAIL-02**: Mailglass guidance and proof output accurately distinguish fake-transport behavior from live-provider delivery and feedback coverage.

### Billing Escalation Path

- [ ] **ACCR-01**: The Accrue path proves billing-event escalation, workflow progression, termination by outcome signal, and trace evidence.
- [ ] **ACCR-02**: Accrue documentation and verification accurately distinguish a released-package adopter proof from pinned-ref compatibility evidence.

### Verification and Documentation

- [ ] **GATE-01**: `mix verify.adoption_paths` runs the clean-room proofs without duplicating the detailed existing integration suites.
- [ ] **GATE-02**: CI executes the adopter-proof entrypoint in a dedicated PostgreSQL-backed lane with useful failure diagnostics.
- [ ] **DOCS-01**: The adoption front door, fixture commands, and CI entrypoint are contract-checked so copyable guidance cannot silently drift.

## Future Requirements

### Adoption Extensions

- **ADPT-03**: Add independently proven paths for Sigra authentication and Threadline audit telemetry after the three primary paths establish the reusable model.
- **INBX-03**: Add recipient-facing inbox PubSub badge updates and `mark_seen` progression proof when UI iteration is actively prioritized.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Browser-driven admin or recipient UI changes | UI iteration is explicitly deferred until it can receive focused human review. |
| Live third-party provider credentials or real webhook delivery | Baseline adopter proofs must be deterministic, credential-free, and safe to run in CI. |
| New integration adapters or broad channel expansion | This milestone validates the existing highest-value paths rather than growing the product surface. |
| Broad CI wall-clock optimization | CI changes are limited to the new proof lane; remaining general performance work is low-value. |
| A local Hex registry, Docker Compose, or new orchestration framework | The proof design should reuse the project’s package and PostgreSQL tooling with minimal new machinery. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ADPT-01 | TBD | Pending |
| ADPT-02 | TBD | Pending |
| PROOF-01 | TBD | Pending |
| PROOF-02 | TBD | Pending |
| PROOF-03 | TBD | Pending |
| CORE-01 | TBD | Pending |
| MAIL-01 | TBD | Pending |
| MAIL-02 | TBD | Pending |
| ACCR-01 | TBD | Pending |
| ACCR-02 | TBD | Pending |
| GATE-01 | TBD | Pending |
| GATE-02 | TBD | Pending |
| DOCS-01 | TBD | Pending |

**Coverage:**
- v1.17 requirements: 13 total
- Mapped to phases: 0
- Unmapped: 13 (roadmap pending)

---
*Requirements defined: 2026-08-08*
*Last updated: 2026-08-08 after v1.17 requirement confirmation*
