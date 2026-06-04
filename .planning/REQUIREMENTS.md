# Requirements: Chimeway

**Defined:** 2026-05-30  
**Milestone:** v1.10 Ecosystem Completions  
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.10 Requirements

### Ecosystem — Threadline (ECOS)

- [x] **ECOS-08**: Optional Threadline telemetry reporter sinks Chimeway notification lifecycle outcomes (suppressed, deferred, dispatched, failed) into Threadline's immutable audit ledger — no host glue beyond config attach

### Ecosystem — Sigra Auth (ECOS)

- [x] **ECOS-09**: Sigra auth events (magic link, MFA token dispatch) trigger Chimeway notifiers with redacted trace payloads — sensitive tokens never persisted in Chimeway trace database
- [x] **ECOS-10**: Published Sigra auth notification reference blueprint with CI doc-contract coverage (Chimeway orchestrates when/why; Sigra owns auth state)

### Demo Proof (DEMO)

- [x] **DEMO-09**: Demo host proves Threadline audit correlation for at least one notification lifecycle event with operator inspectability at `/admin/chimeway`
- [x] **DEMO-10**: Demo host proves Sigra auth notification flow end-to-end (magic link or MFA token dispatch) with operator trace inspectability

### Integration Docs (DOCS)

- [x] **DOCS-10**: Golden-path integration guides cover Threadline telemetry bridge setup and Sigra auth notification mount (dependencies → config → trigger → proof)
- [x] **DOCS-11**: Doc-contract tests lock Threadline and Sigra integration guide truth and forbid regressions

### Release Gates (GATE)

- [x] **GATE-07**: Named verify entrypoints `mix verify.threadline` and `mix verify.sigra` run in CI and appear in MAINTAINING.md pre-ship checklist

## Future Requirements

Deferred to later milestones. Tracked but not in v1.10 roadmap.

### Optional polish (non-blocking)

- **INT-02**: Inbox-read signal projects onto delivery timeline UI in operator admin
- **INT-03**: `mark_seen` progression E2E in journey suite; wire `mark_seen` in BellDropdownLive
- **INBX-03**: Real-time PubSub bell badge updates
- **ADPT-01**: Greenfield `phx.new` + Hex dep install smoke in CI

## Out of Scope

| Feature | Reason |
|---------|--------|
| Broad channel matrix | Orchestration + ecosystem completeness remain higher leverage |
| Playwright admin smoke | Defer per INV-004 until ConnTest proves flaky |
| Full TeamPulse SaaS shell | Demo domain sufficient for integration proof |
| Re-milestone Accrue/Mailglass/INBX | v1.8–v1.9 slices satisfied |
| Re-milestone Consumer Journey Proof | v1.6–v1.7 adoption evidence satisfied |
| Full SEED-003 matrix beyond Threadline/Sigra | Mailglass + Accrue shipped; remainder complete in v1.10 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ECOS-08 | Phase 63 | Complete |
| ECOS-09 | Phase 64 | Complete |
| ECOS-10 | Phase 65 | Complete |
| DEMO-09 | Phase 65 | Complete |
| DEMO-10 | Phase 65 | Complete |
| DOCS-10 | Phase 66 | Complete |
| DOCS-11 | Phase 66 | Complete |
| GATE-07 | Phase 66 | Complete |

**Coverage:**
- v1.10 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-30*  
*Last updated: 2026-06-04 after Phase 67 ECOS-09 clean-CI proof*
