---
gsd_state_version: 1.0
milestone: v1.5
milestone_name: Adoption Surface
status: milestone_complete
last_updated: 2026-05-29T14:16:19.310Z
last_activity: 2026-05-29 -- Phase 42 planning complete
progress:
  total_phases: 8
  completed_phases: 7
  total_plans: 25
  completed_plans: 25
  percent: 88
stopped_at: Milestone complete (Phase 42 was final phase)
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-29)

**Core value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.
**Current focus:** Milestone complete

## Current Position

Milestone: v1.5 Adoption Surface — **SHIPPED** (2026-05-29)
Phases: 35–41 (7 phases, 22 plans)
Status: Milestone complete
Last activity: 2026-05-29

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent v1.5 decisions affecting shipped behavior:

- [Phase 41]: Trigger parity counts Chimeway.trigger( call sites only — Excludes Chimeway.trigger/3 arity prose references that would false-fail idempotency_key/tenant_id parity gate
- [Phase 41]: ci.verify_gates scoped to doc_contract_test.exs only — ci.docs and verify.example remain separate pre-ship mandates per D-14
- [Phase 41]: verify.example additive chain — demo host E2E first, chimeway_admin smoke second; dedicated verify_example CI job always-on without path-gating (D-08–D-11)
- [Phase 41]: verify.example requires mix cmd --shell on Elixir 1.19+ (Mix 1.19 cmd no longer expands shell operators without --shell)

### Pending Todos

None.

### Blockers/Concerns

None for v1.5 scope.

### Open Investigations

| ID | Question | When |
|----|----------|------|
| INV-001 | `chimeway_admin` in-tree vs sibling Hex package? | **Resolved** — in-tree package shipped Phase 40 |
| INV-002 | Fix journey guide vs implement `pending_signals` on wait? | **Resolved doc-truth** in 37-01; engine glue deferred READ milestone |
| INV-003 | Mailglass adapter as v1.5 proof vs v1.6 SEED-003 | v1.6 discuss-phase |

### Roadmap Evolution

- Milestone v1.5 formally closed 2026-05-29 after audit passed (12/12 requirements, 655 tests).
- Milestone v1.4 formally closed 2026-05-28 after re-audit passed (8/8 requirements, 549 tests).
- Phase 42 added: Close gap: DOCS-02/GATE-01 — align consumer docs to 1.0.0 and fix doc-contract drift patterns

### Deferred Items

Tech debt acknowledged at v1.5 close (see `milestones/v1.5-MILESTONE-AUDIT.md`):

| Category | Item | Status |
|----------|------|--------|
| docs | ex_doc relative-link warnings block `mix ci.docs` | deferred |
| nyquist | Phase 35/39 VALIDATION.md frontmatter incomplete | deferred |
| verify | verify.example Mix 1.19 --shell fix | **resolved** (4ca792f) |

### Session Continuity

Last session: 2026-05-29T13:58:13.320Z
Stopped at: Phase 42 context gathered (assumptions mode)
Resume file: .planning/phases/42-close-gap-docs-02-gate-01-align-consumer-docs-to-1-0-0-and-f/42-CONTEXT.md

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 41 P01 | 12min | 2 tasks | Doc-contract adoption gates |
| Phase 41 P02 | 18min | 3 tasks | ci.verify_gates + runbook |
| Phase 41 P03 | 12min | 3 tasks | verify.example + CI job |
| Phase 40 | 3 plans | — | chimeway_admin MVP |
| Phase 35–39 | 16 plans | — | Installer through demo trace |
