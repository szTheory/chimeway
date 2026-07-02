# Requirements: Chimeway v1.14 Public Truth and Verification Architecture

**Defined:** 2026-07-02
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.14 Requirements

Requirements for the active milestone. Each requirement maps to exactly one roadmap phase.

### Public Truth

- [ ] **TRUTH-01**: Root package version, release manifest, changelog, HexDocs source ref, README install guidance, and release automation agree on the real published package state.
- [ ] **TRUTH-02**: Repository identity, source URLs, README badges, package links, HexDocs links, changelog links, and workflow references point to the same canonical project surface.
- [ ] **TRUTH-03**: `chimeway_admin` and `chimeway_inbox` documentation states their real install status: in-repo preview/path packages until intentionally promoted.
- [ ] **TRUTH-04**: Planning milestone identifiers and package release tags are separated so planning version `v1.14` cannot be mistaken for a Hex package release.

### Front Door Documentation

- [ ] **DOCS-14**: README leads with Chimeway's local-first embedded notification value proposition and explainability promise.
- [ ] **DOCS-15**: README and first-hop docs clearly state use cases, non-goals, host-owned boundaries, and optional surface status.
- [ ] **DOCS-16**: Public snippets demonstrate required adoption invariants: stable notification key, `tenant_id`, `idempotency_key`, configured storage prefix, and trace/explainability lookup.
- [ ] **DOCS-17**: Stub or stale guides are either completed or removed from primary README/HexDocs learning paths.

### Verification Architecture

- [ ] **CI-01**: A fast, always-running `pr-gate` gives contributors trustworthy PR feedback without running the entire release matrix.
- [ ] **CI-02**: The full `ci-gate` remains the release, publish, automerge, and recovery source of truth and is at least as strict as the current release verification surface.
- [ ] **CI-03**: Required-check topology cannot leave required GitHub checks permanently pending after path-filtered skips.
- [ ] **CI-04**: Complex CI behavior is reproducible locally through scripts or Mix tasks instead of large inline workflow fragments.
- [ ] **CI-05**: Nested package, demo, npm, and Playwright caches reduce repeated CI setup cost without hiding failures.

### Adoption Proof

- [ ] **ADPT-01**: A fresh-host or unpacked-Hex smoke path proves the public install, docs, and package story from a clean consumer perspective.

## v1.15+ Candidates

Deferred ideas tracked for future milestone selection, not current execution.

### Product And Runtime

- **TENANT-01**: Re-evaluate broader tenant spine consistency across events, notifications, deliveries, inbox, admin, and public APIs.
- **PRIV-03**: Revisit recursive redaction and operator projection hardening if new sensitive payload gaps appear.
- **INBX-03**: Add real-time PubSub badge updates for `chimeway_inbox`.
- **INT-03**: Complete mark_seen progression E2E and BellDropdownLive mark_seen wiring.

### Package Expansion

- **PKG-01**: Promote `chimeway_admin` or `chimeway_inbox` to independently published Hex packages only after explicit package metadata, docs, SemVer, CI, and install smoke requirements are defined.

## Out of Scope

Explicitly excluded from v1.14 to keep the milestone coherent.

| Feature | Reason |
|---------|--------|
| Tenant spine redesign | Important future architecture topic, but this milestone is public truth and verification architecture. |
| Dynamic per-tenant database prefixes | Rejected in v1.13 because static storage prefix plus domain tenant identity avoids worker, Oban, uniqueness, and recovery complexity. |
| Automatic production data moves from public to `chimeway` schema | v1.13 deliberately documented manual move/rollback guidance instead of generated production data movement. |
| Oban optionality behavior changes | Could affect runtime semantics and belongs in a separate operational milestone. |
| Recursive redaction refactor | Worth revisiting if evidence shows gaps, but not needed for package/docs/CI truth. |
| Admin UI redesign | v1.11 shipped admin polish and hardening; v1.14 only updates public truth where admin is referenced. |
| New ecosystem integrations | v1.8-v1.10 completed the current ecosystem wedge; adding breadth would dilute release-readiness work. |
| Inbox PubSub polish | Deferred SEED-004 remainder; not required for public package/docs truth. |
| Publishing `chimeway_admin` or `chimeway_inbox` | v1.14 documents their true preview/path status. Publishing siblings is a separate package model milestone. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRUTH-04 | Phase 77 | Pending |
| TRUTH-01 | Phase 78 | Pending |
| TRUTH-02 | Phase 78 | Pending |
| TRUTH-03 | Phase 78 | Pending |
| DOCS-14 | Phase 79 | Pending |
| DOCS-15 | Phase 79 | Pending |
| DOCS-16 | Phase 79 | Pending |
| DOCS-17 | Phase 79 | Pending |
| ADPT-01 | Phase 79 | Pending |
| CI-01 | Phase 80 | Pending |
| CI-02 | Phase 80 | Pending |
| CI-03 | Phase 80 | Pending |
| CI-04 | Phase 80 | Pending |
| CI-05 | Phase 80 | Pending |

**Coverage:**
- v1.14 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0

---
*Requirements defined: 2026-07-02*
*Last updated: 2026-07-02 after v1.14 milestone initialization*
