# Requirements: Chimeway

**Defined:** 2026-05-30  
**Milestone:** v1.9 Adopter Complete  
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.9 Requirements

### Ecosystem — Accrue Dunning (ECOS)

- [x] **ECOS-06**: Accrue `invoice.payment_failed` starts a Chimeway dunning workflow; `invoice.paid` terminates it via Outcome Signal — no host glue
- [x] **ECOS-07**: Published Accrue dunning reference recipe with CI doc-contract coverage (Chimeway orchestrates when/why; Accrue owns billing state)

### Demo Proof (DEMO)

- [x] **DEMO-07**: Demo host proves Accrue-driven dunning end-to-end with operator trace inspectability at `/admin/chimeway`
- [x] **DEMO-08**: Demo host mounts end-user inbox; journey test proves list → mark_read/seen → badge count

### Inbox UI (INBX)

- [x] **INBX-01**: Headless inbox API exposes UI-ready queries: `unread_count/1`, paginated `list_for_recipient/2` with `exclude_archived`, stable serializable item maps
- [x] **INBX-02**: Optional `chimeway_inbox` package provides mountable router macro, recipient auth behaviour, and unstyled bell-dropdown LiveView

### Integration Docs (DOCS)

- [x] **DOCS-08**: Golden-path integration guides cover Accrue dunning setup and inbox UI mount (dependencies → config → proof)
- [x] **DOCS-09**: Doc-contract tests lock Accrue and inbox integration guide truth and forbid regressions

### Release Gates (GATE)

- [x] **GATE-05**: Named verify entrypoints `mix verify.accrue` and `mix verify.inbox` run in CI and appear in MAINTAINING.md pre-ship checklist
- [x] **GATE-06**: Automated Hex publish on release tag, gated on ci-gate green; Release Please owns version/changelog SSOT

## Future Requirements

Deferred to later milestones. Tracked but not in v1.9 roadmap.

### Ecosystem (v1.10 — SEED-003 remainder)

- **ECOS-08**: Threadline telemetry bridge (`Chimeway.Telemetry.ThreadlineReporter` or equivalent)
- **ECOS-09**: Sigra auth notification flows (magic link, MFA token dispatch)

### Adoption (post-v1.9)

- **ADPT-01**: Greenfield `phx.new` + Hex dep install smoke in CI

### Optional polish (non-blocking)

- **INT-02**: Inbox-read signal projects onto delivery timeline UI in operator admin
- **INT-03**: `mark_seen` progression E2E in journey suite
- **INBX-03**: Real-time PubSub bell badge updates

## Out of Scope

| Feature | Reason |
|---------|--------|
| Threadline / Sigra blueprints | v1.10; v1.9 Accrue-only SEED-003 slice |
| Real-time PubSub bell updates | No PubSub infra in core; stretch for v1.10+ |
| Broad channel matrix | Orchestration + adopter completeness remain higher leverage |
| Playwright admin smoke | Defer per INV-004 until ConnTest proves flaky |
| Full TeamPulse SaaS shell | Demo domain sufficient for integration proof |
| Re-milestone Consumer Journey Proof | v1.6–v1.7 adoption evidence satisfied |
| Re-milestone Mailglass integration | v1.8 ECOS-01..05 satisfied |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ECOS-06 | Phase 58 | Complete |
| ECOS-07 | Phase 59 | Complete |
| DEMO-07 | Phase 59 | Complete |
| DOCS-08 (Accrue) | Phase 60 | Pending |
| DOCS-09 (Accrue) | Phase 60 | Pending |
| GATE-05 (Accrue) | Phase 60 | Complete |
| GATE-06 | Phase 60.1 | Complete |
| INBX-01 | Phase 61 | Complete |
| INBX-02 | Phase 61 | Complete |
| DEMO-08 | Phase 62 | Complete |
| DOCS-08 (Inbox) | Phase 62 | Complete |
| DOCS-09 (Inbox) | Phase 62 | Complete |
| GATE-05 (Inbox) | Phase 62 | Complete |

**Coverage:**
- v1.9 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-30*  
*Last updated: 2026-05-30 after milestone v1.9 roadmap creation*
