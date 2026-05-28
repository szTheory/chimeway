---
gsd_state_version: 1.0
milestone: v1.5
milestone_name: Adoption Surface
status: executing
last_updated: "2026-05-28T21:23:28.879Z"
last_activity: 2026-05-28
progress:
  total_phases: 7
  completed_phases: 2
  total_plans: 6
  completed_plans: 6
  percent: 29
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-28)

**Core value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.
**Current focus:** Phase 36 — golden-path-version-alignment

## Current Position

Phase: 37
Plan: Not started
Status: Executing Phase 36
Last activity: 2026-05-28

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent v1.4/v1.5 decisions affecting shipped behavior:

- [v1.4]: Generic outbound channel behaviour with per-channel render contracts and adapter resolution (Phase 29).
- [v1.4]: Webhook ingress via atomic `Multi+Oban` handoff and ingress schema (Phase 33).
- [v1.4]: Canonical `chimeway.delivery.{succeeded,bounced,failed}` vocabulary across normalization, signals, and traces (Phase 34).
- [33-06]: `CacheBodyReader` must handle `:ok`, `:more`, and `:error` from `Plug.Conn.read_body/2` for chunked bodies.
- [35-01]: D-05 Option A — infer `{App}.Repo` from host `mix.exs` when `config :chimeway, :repo` unset; 31 templates shipped excluding Oban (D-10).
- [35-02]: Tmp host subprocess tests include Oban dep for path-dep compile; moduledoc includes shortdoc for mix help verify.
- [35-03]: Golden fixture at `test/fixtures/installer_golden/`; `MIX_INSTALLER_ACCEPT_GOLDEN=1` refresh; path-gated `install_golden_contract` CI job.

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
- Phase 35 complete 2026-05-28 — INST-01 and INST-02 satisfied.

### Deferred Items

Carried from v1.4 close — see PROJECT.md Out of Scope and assessment thread.

### Session Continuity

Last session: 2026-05-28T21:00:06.303Z
Resume file: .planning/phases/36-golden-path-version-alignment/36-CONTEXT.md

**Planned Phase:** 36 — Golden Path & Version Alignment

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 35 P01 | 12min | 3 tasks | 33 files |
| Phase 35 P02 | 10min | 3 tasks | Mix task + integration tests |
| Phase 35 P03 | 45min | 5 tasks | Golden fixture + CI contracts |
