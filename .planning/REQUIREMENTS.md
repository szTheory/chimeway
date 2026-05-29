# Requirements: Chimeway v1.5 Adoption Surface

**Defined:** 2026-05-28
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.5 Requirements

Requirements for the Adoption Surface milestone. Each maps to roadmap phases (starting at Phase 35).

### Installer & Onboarding (INST)

- [x] **INST-01**: Host developer can run a documented Mix task (`mix chimeway.gen.migrations` or equivalent install task) to generate Chimeway migrations without hand-copying schema files
- [x] **INST-02**: Installer output is idempotent and verified by golden-diff or contract test so re-running does not corrupt host repos

### Integration Docs & Doc Truth (DOCS)

- [x] **DOCS-01**: Golden-path guide walks a fresh Phoenix host from dependency add → migrations → first trigger → trace query → optional webhook feedback loop
- [x] **DOCS-02**: README, installation guide, and `mix.exs` version strings are aligned so adopters see one credible semver story
- [x] **DOCS-03**: Journey/workflow guides match engine capabilities (doc-truth fix for `stop_conditions` / `pending_signals` drift, or explicit deferral callouts)

### Reference Recipes (RECP)

- [x] **RECP-01**: Password-reset support trace recipe shows Support Operator JTBD — trigger → policy/delivery outcomes → explainable trace for "why didn't user get email?"
- [x] **RECP-02**: Feedback escalation recipe shows Product Manager JTBD — outbound send → webhook feedback → workflow progression step visible in trace

### Demo Host (DEMO)

- [ ] **DEMO-01**: Demo host documents and demonstrates a non-webhook trace inspection path (IEx, script, or minimal UI) so adopters can validate explainability without standing up provider webhooks

### Operator Trace Surface (OPER)

- [ ] **OPER-01**: Optional `chimeway_admin` MVP exposes redacted trace lookup by user ID or correlation ID with host-provided auth behaviour
- [ ] **OPER-02**: Operator trace view links delivery attempts, suppressions, webhook events, and workflow transitions on one timeline (no bell inbox or marketing campaign UI)

### Release & Verification Gates (GATE)

- [ ] **GATE-01**: Doc-contract checks and `mix verify.example` are part of the release checklist so doc drift is caught before ship

## Future Requirements (v1.6+)

Deferred to post-v1.5. Tracked but not in current roadmap.

### Read/Unread Workflow Glue (READ)

- **READ-01**: `pending_signals` populated when journeys enter `wait_until` gates
- **READ-02**: Inbox read/seen events can drive workflow branching without host glue code

### Ecosystem Integrations (ECOS)

- **ECOS-01**: Mailglass adapter blueprint (Chimeway orchestrates when/why; Mailglass handles render/delivery)
- **ECOS-02**: Accrue dunning workflow blueprint
- **ECOS-03**: Threadline telemetry bridge for unified audit
- **ECOS-04**: Sigra auth notification blueprints

### In-App Inbox UI (INBX)

- **INBX-01**: Headless or LiveView bell-icon inbox components for read/seen state

## Out of Scope

Explicitly excluded for v1.5. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Read/unread auto-branching as primary workflow driver | Engine glue deferred; belongs in READ milestone after doc truth |
| Full SEED-003 ecosystem integration matrix | Follow v1.5; Mailglass proof slice only via INV-003 if scoped in |
| Vendor-specific SMS/push/chat adapters in core | Host-owned adapter seam; no channel matrix expansion |
| Marketing campaign or drip-campaign UI | Chimeway is transactional/product notification focused |
| Bell-icon notification center | INBX deferred to v1.6+ |
| `pending_signals` engine implementation (unless INV-002 resolves to code fix) | Assessment ranks READ milestone separately; doc-truth preferred for v1.5 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INST-01 | Phase 35 | Complete (35-02) |
| INST-02 | Phase 35 | Complete (35-03) |
| DOCS-01 | Phase 36 | Complete |
| DOCS-02 | Phase 36 | Complete |
| DOCS-03 | Phase 37 | Complete |
| RECP-01 | Phase 38 | Complete |
| RECP-02 | Phase 38 | Complete |
| DEMO-01 | Phase 39 | Pending |
| OPER-01 | Phase 40 | Pending |
| OPER-02 | Phase 40 | Pending |
| GATE-01 | Phase 41 | Pending |

**Coverage:**

- v1.5 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-28*
*Last updated: 2026-05-28 after roadmap creation*
