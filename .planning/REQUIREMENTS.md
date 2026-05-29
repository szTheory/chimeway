# Requirements: Chimeway

**Defined:** 2026-05-29  
**Milestone:** v1.8 Ecosystem Integration Blueprints (Mailglass-only)  
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.8 Requirements

### Ecosystem Adapter (ECOS)

- [x] **ECOS-01**: Host can configure `Chimeway.Adapter.Mailglass` as the email delivery adapter and dispatch notifications through Mailglass rendering and Swoosh delivery
- [x] **ECOS-02**: `Chimeway.Adapter.Mailglass` passes shared `Chimeway.Adapter` contract tests for `deliver/2`, including redacted provider metadata on success and classified errors on failure
- [x] **ECOS-03**: Mailglass inbound webhook payloads verify, resolve delivery identity, and normalize into canonical Chimeway delivery outcomes via the existing webhook pipeline
- [x] **ECOS-04**: Normalized Mailglass feedback drives workflow progression through the existing Signal engine with explainable operator traces

### Blueprint & Demo (ECOS / DEMO)

- [ ] **ECOS-05**: Published reference recipe documents the Chimeway orchestration vs Mailglass templating split of responsibilities with copy-pasteable notifier and adapter config
- [ ] **DEMO-06**: Demo host proves Mailglass adapter on at least one TeamPulse notifier end-to-end with operator trace inspectability

### Integration Docs (DOCS)

- [ ] **DOCS-06**: Golden-path integration guide covers Chimeway + Mailglass dependency setup, adapter registration, delivery config, and inbound feedback wiring
- [ ] **DOCS-07**: Doc-contract tests lock Mailglass integration guide truth and forbid regressions to pre-integration assumptions

### Release Gates (GATE)

- [ ] **GATE-04**: Named verify entrypoint (`mix verify.mailglass` or equivalent) exercises Mailglass integration in CI and is documented in MAINTAINING.md pre-ship checklist

## Future Requirements

Deferred to later milestones. Tracked but not in v1.8 roadmap.

### Ecosystem (v1.9+ — SEED-003 remainder)

- **ECOS-06**: Accrue dunning workflow blueprint
- **ECOS-07**: Threadline telemetry bridge (`Chimeway.Telemetry.ThreadlineReporter` or equivalent)
- **ECOS-08**: Sigra auth notification flows (magic link, MFA token dispatch)

### Inbox UI (v1.9 — INBX)

- **INBX-01**: Headless inbox API or unstyled bell-dropdown LiveView components

### Adoption (post-v1.8)

- **ADPT-01**: Greenfield `phx.new` + Hex dep install smoke in CI

### Optional polish (non-blocking)

- **INT-02**: Inbox-read signal projects onto delivery timeline UI in operator admin
- **INT-03**: `mark_seen` progression E2E in journey suite

## Out of Scope

| Feature | Reason |
|---------|--------|
| Accrue / Threadline / Sigra blueprints | Mailglass-only v1.8 scope (user confirmed 1+A); remainder deferred to v1.9+ |
| INBX bell / notification center UI | v1.9; ecosystem proof before end-user UI productization |
| Broad channel matrix | Orchestration + ecosystem composition remain higher leverage |
| Playwright admin smoke | Defer per INV-004 until ConnTest proves flaky |
| Full TeamPulse SaaS shell | Demo domain sufficient for integration proof |
| Re-milestone Consumer Journey Proof | v1.6–v1.7 adoption evidence satisfied |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ECOS-01 | Phase 54 | Complete |
| ECOS-02 | Phase 54 | Complete |
| ECOS-03 | Phase 55 | Complete |
| ECOS-04 | Phase 55 | Complete |
| ECOS-05 | Phase 56 | Pending |
| DEMO-06 | Phase 56 | Pending |
| DOCS-06 | Phase 57 | Pending |
| DOCS-07 | Phase 57 | Pending |
| GATE-04 | Phase 57 | Pending |

**Coverage:**
- v1.8 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-29*  
*Last updated: 2026-05-29 after milestone v1.8 roadmap creation*
