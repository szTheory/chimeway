# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- ✅ **v1.1** — [Archived roadmap](.planning/milestones/v1.1-ROADMAP.md) (shipped 2026-04-27)
- ✅ **v1.2** — [Archived roadmap](.planning/milestones/v1.2-ROADMAP.md) (shipped 2026-04-29)
- ✅ **v1.3** — [Archived roadmap](.planning/milestones/v1.3-ROADMAP.md) (shipped 2026-04-30)
- ✅ **v1.4** — [Archived roadmap](.planning/milestones/v1.4-ROADMAP.md) · [Audit](.planning/milestones/v1.4-MILESTONE-AUDIT.md) (shipped 2026-05-08, closed 2026-05-28)
- ✅ **v1.5** — [Archived roadmap](.planning/milestones/v1.5-ROADMAP.md) · [Audit](.planning/milestones/v1.5-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.6** — [Archived roadmap](.planning/milestones/v1.6-ROADMAP.md) · [Audit](.planning/milestones/v1.6-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.7** — [Archived roadmap](.planning/milestones/v1.7-ROADMAP.md) · [Audit](.planning/milestones/v1.7-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.8** — [Archived roadmap](.planning/milestones/v1.8-ROADMAP.md) · [Audit](.planning/milestones/v1.8-MILESTONE-AUDIT.md) (shipped 2026-05-30)
- ✅ **v1.9** — [Archived roadmap](.planning/milestones/v1.9-ROADMAP.md) · [Audit](.planning/milestones/v1.9-MILESTONE-AUDIT.md) (shipped 2026-05-30)

## Active Milestone

**v1.10 Ecosystem Completions** — SEED-003 remainder: Threadline telemetry bridge and Sigra auth notification flows with blueprint, demo proof, integration docs, and verify gates.

---

## Overview

Complete the SEED-003 ecosystem integration matrix by shipping Threadline and Sigra vertical slices using the proven Mailglass/Accrue pattern: optional dep, core integration module, reference blueprint, demo host proof, golden-path guide, doc-contract truth lock, and named verify gate. Chimeway owns orchestration explainability; Threadline owns audit ledger; Sigra owns auth state.

## Phases

- [x] **Phase 63: Threadline Telemetry Bridge** — Optional `threadline` dep; telemetry reporter sinks notification outcomes into Threadline audit ledger (2026-05-30)
- [ ] **Phase 64: Sigra Auth Flows Core** — Sigra auth events trigger Chimeway notifiers with redacted trace payloads
- [ ] **Phase 65: Ecosystem Blueprints & Demo** — Sigra auth reference blueprint plus demo host proofs for Threadline and Sigra
- [ ] **Phase 66: Docs & Release Gates** — Golden-path guides, doc-contract tests, and `mix verify.threadline` / `mix verify.sigra` CI gates

## Phase Details

### Phase 63: Threadline Telemetry Bridge

**Goal:** Chimeway notification lifecycle outcomes automatically appear in Threadline's immutable audit ledger without host glue beyond reporter attach.

**Depends on:** v1.9 (durable spine, telemetry correlation, explainable traces)

**Requirements:** ECOS-08

**Success Criteria** (what must be TRUE):

1. Host with optional `threadline` dep configured can attach `Chimeway.Telemetry.ThreadlineReporter` (or equivalent) and observe notification suppressed/deferred/dispatched/failed outcomes in Threadline audit entries
2. Reporter redacts sensitive payload fields — only deterministic outcome metadata crosses the bridge
3. Integration tests prove at least one notification lifecycle event → Threadline audit row correlation with `@moduletag :threadline` selective CI

**Plans:** 2 plans

**Wave 1** *(harness + telemetry enrichment — blocks Wave 2)*

Plans:
- [x] 63-01-PLAN.md — Optional threadline dep, selective CI, test harness, `planning_reason` + `correlation_id` span enrichment (2026-05-30)

**Wave 2** *(blocked on Wave 1 completion)*

Plans:
- [x] 63-02-PLAN.md — `Chimeway.Telemetry.ThreadlineReporter` + lifecycle → audit row integration proof (2026-05-30)

### Phase 64: Sigra Auth Flows Core

**Goal:** Sigra auth events drive Chimeway notification delivery for magic link and MFA token flows with security-first trace redaction.

**Depends on:** Phase 63 (parallel-safe — no hard dependency; both depend on v1.9 spine)

**Requirements:** ECOS-09

**Success Criteria** (what must be TRUE):

1. Sigra magic link or MFA token dispatch event triggers a Chimeway notifier and creates a durable delivery attempt with explainable trace
2. Sensitive token values never appear in Chimeway trace database, telemetry, or operator surfaces — redaction is enforced at the integration boundary
3. Integration tests prove event → notification → delivery path with `@moduletag :sigra` selective CI

**Plans:** 0 plans

### Phase 65: Ecosystem Blueprints & Demo

**Goal:** Adopters can copy published Threadline and Sigra reference recipes and see the same behaviour proven on the demo host.

**Depends on:** Phases 63, 64

**Requirements:** ECOS-10, DEMO-09, DEMO-10

**Success Criteria** (what must be TRUE):

1. Sigra auth notification reference blueprint documents notifier authoring, Sigra event wiring, and orchestration vs auth-state responsibility split with CI doc-contract coverage
2. Demo host proves Threadline audit correlation for at least one notification lifecycle event with inspectable traces at `/admin/chimeway`
3. Demo host proves Sigra auth notification flow end-to-end (magic link or MFA token) with operator trace inspectability — journey CI isolated via `@moduletag`

**Plans:** 0 plans

### Phase 66: Docs & Release Gates

**Goal:** Threadline and Sigra integrations are documented, contract-tested, and gated in the release checklist alongside existing verify entrypoints.

**Depends on:** Phase 65

**Requirements:** DOCS-10, DOCS-11, GATE-07

**Success Criteria** (what must be TRUE):

1. Golden-path integration guides walk a fresh host from dependency → config → trigger → proof for both Threadline bridge and Sigra auth flows
2. Doc-contract tests fail if guide text regresses to pre-integration assumptions or omits required setup steps
3. `mix verify.threadline` and `mix verify.sigra` run in CI and appear in MAINTAINING.md pre-ship checklist without breaking the existing verify octet

**Plans:** 0 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 63 Threadline Telemetry Bridge | 2/2 | Complete | 2026-05-30 |
| 64 Sigra Auth Flows Core | 0/? | Not started | — |
| 65 Ecosystem Blueprints & Demo | 0/? | Not started | — |
| 66 Docs & Release Gates | 0/? | Not started | — |

## Requirement Coverage

| Requirement | Phase | Description |
|-------------|-------|-------------|
| ECOS-08 | 63 | Threadline telemetry reporter |
| ECOS-09 | 64 | Sigra auth notification flows |
| ECOS-10 | 65 | Sigra auth reference blueprint |
| DEMO-09 | 65 | Threadline demo proof |
| DEMO-10 | 65 | Sigra auth demo proof |
| DOCS-10 | 66 | Threadline + Sigra integration guides |
| DOCS-11 | 66 | Doc-contract tests |
| GATE-07 | 66 | verify.threadline + verify.sigra gates |

**Coverage:** 8/8 requirements mapped ✓

---
*Roadmap updated: 2026-05-30 — milestone v1.10 Ecosystem Completions started*
