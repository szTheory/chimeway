---
gsd_state_version: 1.0
milestone: v1.5
milestone_name: Adoption Surface
status: defining_requirements
stopped_at: null
last_updated: "2026-05-28T20:00:00.000Z"
last_activity: 2026-05-28 — Milestone v1.5 Adoption Surface started
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-28)

**Core value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.
**Current focus:** v1.5 Adoption Surface — installer, golden path, reference flows, operator trace MVP

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-05-28 — Milestone v1.5 started

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent v1.4 decisions affecting shipped behavior:

- [v1.4]: Generic outbound channel behaviour with per-channel render contracts and adapter resolution (Phase 29).
- [v1.4]: Webhook ingress via atomic `Multi+Oban` handoff and ingress schema (Phase 33).
- [v1.4]: Canonical `chimeway.delivery.{succeeded,bounced,failed}` vocabulary across normalization, signals, and traces (Phase 34).
- [33-06]: `CacheBodyReader` must handle `:ok`, `:more`, and `:error` from `Plug.Conn.read_body/2` for chunked bodies.

### Pending Todos

None.

### Blockers/Concerns

None for engine work. Adoption gaps drive v1.5 scope (assessment 2026-05-28).

### Open Investigations

| ID | Question | When |
|----|----------|------|
| INV-001 | `chimeway_admin` in-tree vs sibling Hex package? | v1.5 plan-phase |
| INV-002 | Fix journey guide vs implement `pending_signals` on wait? | v1.5 early phase or v1.5.1 READ |
| INV-003 | Mailglass adapter as v1.5 proof vs v1.6 SEED-003 | v1.5 discuss-phase |

### Roadmap Evolution

- Milestone v1.4 formally closed 2026-05-28 after re-audit passed (8/8 requirements, 549 tests).
- Milestone v1.5 initialized 2026-05-28; phases continue from 35.

### Deferred Items

Carried from v1.4 close — see PROJECT.md Out of Scope and assessment thread.

### Session Continuity

Last session: v1.5 milestone initialization
Resume file: `.planning/threads/2026-05-28-v1.5-milestone-assessment.md`

**Planned Phase:** None (requirements in progress)
