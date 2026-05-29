---
gsd_state_version: 1.0
milestone: v1.8
milestone_name: Ecosystem Integration Blueprints
status: planning
last_updated: "2026-05-29T21:29:33.855Z"
last_activity: 2026-05-29
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 8
  completed_plans: 8
  percent: 75
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-29)

**Core value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.
**Current focus:** Phase 57 — docs & release gates

## Current Position

Phase: 57
Plan: Not started
Status: Ready to plan
Last activity: 2026-05-29

## Accumulated Context

### Decisions

- [v1.6]: Adoption surface (v1.5) and adoption evidence (v1.6) are distinct milestones — journey CI is not optional polish
- [v1.6]: TeamPulse minimal B2B SaaS domain maps SEED-004 personas (Feature Developer, Support Operator, Product Manager)
- [v1.6]: `DemoHost.Seeds` is adopter-copyable public API — not internal test fixture inserts
- [v1.6]: Defer Playwright; host-mount ConnTest + LiveViewTest sufficient for JOUR-04 (INV-004)
- [v1.6]: `verify.journeys` separate CI job; not bundled into default `mix ci`
- [v1.7-assessment]: v1.6 satisfied adoption-evidence foundation — do not re-milestone Consumer Journey Proof
- [v1.7-assessment]: Staged seed choreography (`stage_escalation_webhook/1`) masks READ engine gap — fix in v1.7 READ + demo polish tail
- [48-01]: Omit `cancel_signals` from normalized wait_until output when absent or empty (D-06)
- [48-01]: Validate cancel_signals at notifier declaration time, not runtime in progression
- [48-02]: Do not mirror cancel_signals into status_context — pending_signals column is sole durable source
- [48-02]: route_signal/1 unchanged in Phase 48 — population only at enter_waiting/6
- [48-03]: Journey guide documents cancel_signals with canonical chimeway.notification.read/.seen; READ-02 deferral retained
- [48-03]: Doc contract forbids "Engine gap today" to prevent READ-01 gap regression
- [49-03]: READ-02 deferral removed from journey guide; inbox emission documented (D-09)
- [49-03]: Doc contract requires mark_read/mark_seen strings; forbids deferral phrases via @forbidden_phrases
- [49-01]: Inbox emits signals on first read/seen transition only; skip emission when tenant unresolved
- [49-01]: Lifecycle :ok independent of Signal.track/4 result — separate transactions per D-07
- [49-02]: E2E mark_read path uses public Chimeway.mark_read/3 — no host Signal.track glue (READ-02)
- [49-02]: signal_received transition context is event_name only — no payload/notification_id in trace (READ-03)
- [v1.8-assessment]: Adoption evidence prompt re-run confirms v1.6–v1.7 closed the demo/seeds/journey gap — do not re-milestone Consumer Journey Proof
- [v1.8-assessment]: Next wedge is v1.8 SEED-003 (ecosystem plugins), then v1.9 INBX — operator demo ≠ end-user bell UI
- [v1.8]: Mailglass-only v1.8 scope — Accrue/Threadline/Sigra deferred to v1.9+ (INV-003 resolved)
- [54-01]: Mailglass test config unconditional in config/test.exs — config loads before dep compile
- [54-01]: Shim Mailglass.TestRepo/DataCase in Chimeway test/support — not published on hex
- [54-02]: Recipient email precedence render_data to/email then user: actor_id prefix
- [54-02]: Hex mailglass needs test/support migration shim — priv wrappers not on hex artifact
- [54-02]: simulate_error supports :bounced/:suppressed for SuppressedError classifier tests
- [54-03]: ContractTest error shape passes simulate_error: true config when simulate_error?/0
- [54-03]: Permanent Mailglass errors tested via classify_error_for_test/1 on TemplateError
- [56-01]: Mailglass adapter registered only in :mailglass test setup — journey suite keeps Logger (D-10)
- [56-01]: adapter_module whitelisted in admin timeline redaction for operator inspectability

### Pending Todos

None.

### Blockers/Concerns

None.

### Open Investigations

| ID | Question | When |
|----|----------|------|
| INV-003 | Mailglass-first vs full SEED-003 matrix in v1.8 scope | **Resolved** — Mailglass-only v1.8 |
| INV-004 | Playwright vs LiveView ConnTest for admin smoke | Defer until ConnTest flaky |

### Roadmap Evolution

- Phase 53 added: Milestone close-out — Nyquist validation + journey test hygiene (post-audit)
- v1.8 Ecosystem Integration Blueprints started 2026-05-29 — Phases 54–57, 9 requirements (Mailglass-only)
- v1.7 READ + Adoption Polish shipped 2026-05-29 (Phases 48–53, 11 requirements)
- v1.6 Consumer Journey Proof shipped 2026-05-29 (Phases 43–47)
- v1.5 formally closed 2026-05-29 (Phases 35–42)

### Deferred Items

Items acknowledged and deferred at v1.7 milestone close on 2026-05-29:

| Category | Item | Status |
|----------|------|--------|
| seed | SEED-003 Mailglass slice | v1.8 active |
| seed | SEED-003 remainder (Accrue, Threadline, Sigra) | v1.9+ |
| seed | SEED-004 inbox / bell UI remainder (INBX) | v1.9+ |
| planning | Phases 43–47 GSD artifacts (SUMMARY/VERIFICATION) | optional retroactive |
| integration | Inbox-read signal may not project onto delivery timeline UI (INT-02) | v1.8 optional |
| integration | `mark_seen` progression E2E not covered (INT-03) | v1.8 optional |

### Session Continuity

Last session: 2026-05-29T21:29:33.851Z
Stopped at: Phase 57 context gathered (assumptions mode)
Resume file: .planning/phases/57-docs-release-gates/57-CONTEXT.md

## Operator Next Steps

- Execute plan 56-02 — Mailglass integration blueprint recipe + ECOS-05 doc-contract
- Review: `.planning/phases/56-blueprint-demo-proof/56-01-SUMMARY.md`
- Pre-ship baseline unchanged: `mix verify.journeys` (10 tests) + existing gate quintet

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 53 P01 | 12min | 4 tasks | 4 files |
| Phase 53 P02 | 8 min | 3 tasks | 3 files |
| Phase 54-mailglass-adapter-core P01 | 15min | 3 tasks | 8 files |
| Phase 54-mailglass-adapter-core P02 | 25min | 3 tasks | 8 files |
| Phase 54-mailglass-adapter-core P03 | 12min | 3 tasks | 5 files |
| Phase 55-inbound-feedback-bridge P02 | 8 | 2 tasks | 3 files |
| Phase 55-inbound-feedback-bridge P03 | 12min | 2 tasks | 4 files |
| Phase 56-blueprint-demo-proof P01 | 20min | 3 tasks | 8 files |
| Phase 56-blueprint-demo-proof P02 | 12min | 2 tasks | 3 files |
