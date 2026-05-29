# Requirements: Chimeway

**Defined:** 2026-05-29  
**Milestone:** v1.7 READ + Adoption Polish  
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.7 Requirements

### Read/Unread Workflow Glue (READ)

- [x] **READ-01**: Workflow runs entering `wait_until` persist canonical `pending_signals` derived from progress rules (no host glue required)
- [x] **READ-02**: `Chimeway.mark_read/3` and `mark_seen/3` emit durable signals that route workflow progression through the existing signal router without host glue
- [x] **READ-03**: Inbox-read signal early-resume from `:waiting` records an explainable `signal_received` transition in operator traces

### Demo Alignment (DEMO)

- [x] **DEMO-03**: TeamPulse payment escalation demo uses READ-driven progression (no `stage_escalation_webhook/1` or staged webhook choreography)
- [x] **DEMO-04**: Mention-escalation reference recipe documents read-cancel plus time-based `wait_until` fallback as the primary PM JTBD path

### Journey Proof (JOUR)

- [ ] **JOUR-06**: Journey test proves inbox `mark_read` cancels a scheduled escalation step before `wait_until` due_at
- [ ] **JOUR-07**: Admin journey test covers Sam password-reset suppression trace (Support Operator persona)
- [ ] **JOUR-08**: Admin journey test covers Morgan payment-escalation trace (Product Manager persona)

### Adoption Docs (DOCS)

- [ ] **DOCS-04**: Demo host README resolves webhook-path contradiction and unifies TeamPulse vs TraceDemo narrative
- [ ] **DOCS-05**: `mix demo.up --check` moduledoc accurately describes migrate + seed + app.start behavior

### Release Gates (GATE)

- [ ] **GATE-03**: `mix verify.journeys` covers JOUR-06..08; MAINTAINING.md pre-ship quintet documents READ journey proof

## Future Requirements

Deferred to later milestones. Tracked but not in v1.7 roadmap.

### Ecosystem (v1.8 — SEED-003)

- **ECOS-01**: Mailglass adapter blueprint
- **ECOS-02**: Accrue dunning workflow blueprint
- **ECOS-03**: Threadline telemetry bridge
- **ECOS-04**: Sigra auth notification flows

### Inbox UI (v1.9 — INBX)

- **INBX-01**: Headless inbox API or unstyled bell-dropdown LiveView components

### Adoption (post-v1.7)

- **ADPT-01**: Greenfield `phx.new` + Hex dep install smoke in CI

## Out of Scope

| Feature | Reason |
|---------|--------|
| SEED-003 ecosystem plugins | v1.8 milestone; READ glue is higher leverage |
| Bell inbox UI (INBX) | v1.9; engine glue before UI productization |
| Broad channel matrix | Orchestration and explainability remain higher leverage |
| Playwright admin smoke | Defer per INV-004 until ConnTest proves flaky |
| Full TeamPulse SaaS shell | Demo domain sufficient for adoption evidence |
| Retroactive GSD phase dirs 43–47 | Audit-trail polish only; not blocking v1.7 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| READ-01 | Phase 48 | Complete |
| READ-02 | Phase 49 | Complete |
| READ-03 | Phase 49 | Complete |
| DEMO-03 | Phase 50 | Complete |
| DEMO-04 | Phase 50 | Complete |
| JOUR-06 | Phase 51 | Pending |
| JOUR-07 | Phase 51 | Pending |
| JOUR-08 | Phase 51 | Pending |
| DOCS-04 | Phase 52 | Pending |
| DOCS-05 | Phase 52 | Pending |
| GATE-03 | Phase 52 | Pending |

**Coverage:**
- v1.7 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-29*  
*Last updated: 2026-05-29 after milestone v1.7 roadmap creation*
