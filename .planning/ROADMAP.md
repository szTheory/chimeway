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

## Active Milestone

**v1.9 Adopter Complete** — Accrue dunning blueprint (SEED-003 slice) plus end-user inbox UI via optional `chimeway_inbox` package (SEED-004 INBX). Threadline/Sigra deferred to v1.10.

---

## Overview

Close the last adopter-facing gaps so Chimeway is adoptable off the lot for all three personas. Accrue dunning proves the workflow + Signal spine composes with billing state (Chimeway orchestrates when/why; Accrue owns subscription state). INBX closes the Feature Developer JTBD with headless API polish and an unstyled bell-dropdown LiveView package modeled on `chimeway_admin`.

## Phases

- [x] **Phase 58: Accrue Dunning Core** — Optional `accrue` dep; billing events start/stop Chimeway dunning workflows via Signal engine (completed 2026-05-30)
- [x] **Phase 59: Accrue Blueprint & Demo** — Reference recipe plus demo host Accrue dunning proof with operator traces (completed 2026-05-30)
- [ ] **Phase 60: Accrue Docs & Release Gate** — Golden-path guide, doc-contract tests, and `mix verify.accrue` CI gate
- [ ] **Phase 61: Inbox Headless + Package** — Core API polish and bootstrap `chimeway_inbox` optional package
- [ ] **Phase 62: Inbox Demo, Docs & Gate** — Demo mount, inbox guide, doc-contract, and `mix verify.inbox` release gate

## Phase Details

### Phase 58: Accrue Dunning Core

**Goal:** Accrue billing events drive Chimeway dunning workflow lifecycle without host glue — payment failure starts escalation; payment success terminates via Outcome Signal.

**Depends on:** v1.8 (workflow spine, Signal engine, Mailglass adapter optional for email steps)

**Requirements:** ECOS-06

**Success Criteria** (what must be TRUE):

1. Host with optional `accrue` dep configured can receive `invoice.payment_failed` and observe a new Chimeway dunning workflow run start with explainable trace
2. Subsequent `invoice.paid` emits an Outcome Signal that terminates the active dunning run — no manual host callback wiring
3. Integration tests prove event → workflow start and event → signal termination paths with `@moduletag :accrue` selective CI

**Plans:** 3/3 plans complete

**Wave 1 *(no dependencies)*:** 58-01 — Optional accrue dep + test harness + event subscription stub  
**Wave 2 *(blocked on Wave 1)*:** 58-02 — Dunning workflow wiring (`payment_failed` → trigger/start run)  
**Wave 3 *(blocked on Wave 2)*:** 58-03 — `invoice.paid` → Outcome Signal termination proof

**Cross-cutting constraints:**

- Workflow + Signal integration — not a `Chimeway.Adapter` delivery seam (58-01..03)
- Runtime config only — no compile-time secrets (58-01..03)
- Reuse existing `Chimeway.Signal.track/4` and workflow progression from v1.3–v1.4 (58-02..03)

### Phase 59: Accrue Blueprint & Demo

**Goal:** Adopters can copy a published Accrue + Chimeway dunning reference recipe and see the same behaviour proven on the demo host with operator trace inspectability.

**Depends on:** Phase 58

**Requirements:** ECOS-07, DEMO-07

**Success Criteria** (what must be TRUE):

1. Reference recipe documents notifier authoring, Accrue event subscription, and Chimeway orchestration vs Accrue billing-state split with CI doc-contract coverage
2. Demo host proves Accrue-driven dunning end-to-end — failed payment triggers escalation emails; paid invoice terminates workflow
3. Operator traces at `/admin/chimeway` show dunning workflow progression and explainable suppression/delivery decisions

**Plans:** 2/2 plans complete

**Wave 1 *(no dependencies)*:** 59-01 — Demo host Accrue dunning proof (DEMO-07: escalation + admin trace, journey CI isolated)  
**Wave 2 *(blocked on Wave 1 completion)*:** 59-02 — Accrue dunning blueprint recipe + ECOS-07 doc-contract

Plans:
- [x] 59-01-PLAN.md — Demo host Accrue dunning proof (`@moduletag :accrue`, `seed_accrue_dunning/0`, admin trace, `verify.accrue` + demo host)
- [x] 59-02-PLAN.md — `accrue-dunning-blueprint.md` + ECOS-07 doc-contract

### Phase 60: Accrue Docs & Release Gate

**Goal:** Accrue dunning integration is documented, contract-tested, and gated in the release checklist alongside existing verify entrypoints.

**Depends on:** Phase 59

**Requirements:** DOCS-08 (Accrue), DOCS-09 (Accrue), GATE-05 (Accrue)

**Success Criteria** (what must be TRUE):

1. Golden-path Accrue integration guide walks a fresh host from dependency → config → dunning trigger → operator trace
2. Doc-contract tests fail if guide text regresses or omits required Accrue setup steps
3. `mix verify.accrue` runs in CI and appears in MAINTAINING.md pre-ship checklist without breaking existing journey/mailglass gate sextet

**Plans:** 2/3 plans executed

**Wave 1 *(parallel)*:** 60-01 — Golden-path Accrue dunning integration guide (DOCS-08); 60-03 — `mix verify.accrue` + CI job + MAINTAINING update (GATE-05)  
**Wave 2 *(blocked on Wave 1 guide — 60-01)*:** 60-02 — Accrue guide doc-contract tests (DOCS-09)

Plans:
- [x] 60-01-PLAN.md — Golden-path `accrue-dunning-integration.md` + README/blueprint cross-links (DOCS-08)
- [ ] 60-02-PLAN.md — Guide doc-contract describe in `doc_contract_test.exs` (DOCS-09)
- [x] 60-03-PLAN.md — `verify_accrue` CI job + MAINTAINING septet (GATE-05 Accrue)

**Cross-cutting constraints:**

- Documentation + release gate only — no new ECOS-06/DEMO-07 proof tests (60-01..03)
- Guide vs blueprint separation — introduction owns path, recipe owns copy-paste sections (60-01)
- Sibling Accrue checkout required for CI and local `mix verify.accrue` (60-03)

### Phase 61: Inbox Headless + Package

**Goal:** Headless inbox API is UI-ready and an optional `chimeway_inbox` package provides mountable bell-dropdown LiveView components for end-user JTBD.

**Depends on:** v1.7 (inbox lifecycle + read/seen signal emission); parallel with Phases 58–60 after Phase 58 Wave 1 or sequentially after Phase 60

**Requirements:** INBX-01, INBX-02

**Success Criteria** (what must be TRUE):

1. `Chimeway.unread_count/1`, paginated `list_for_recipient/2` with `exclude_archived`, and stable serializable item maps are available on the public API
2. `chimeway_inbox` optional package exposes router macro, recipient auth behaviour, and unstyled bell-dropdown LiveView (modeled on `chimeway_admin`)
3. Package tests prove list → mark_read/seen from LiveView handlers without host glue beyond auth behaviour

**Plans:** TBD

**Wave 1 *(no dependencies)*:** 61-01 — Headless inbox API polish (INBX-01: unread_count, pagination, DTO maps)  
**Wave 2 *(blocked on Wave 1)*:** 61-02 — Bootstrap `chimeway_inbox` package (router, auth behaviour, bell LiveView)  
**Wave 3 *(blocked on Wave 2)*:** 61-03 — Package LiveViewTest coverage (INBX-02)

**Cross-cutting constraints:**

- Optional Phoenix package — core `lib/chimeway` stays Phoenix-free
- Recipient auth behaviour pluggable like `ChimewayAdmin.Auth` — host resolves identity from session
- No real-time PubSub bell updates in v1.9 (deferred)

### Phase 62: Inbox Demo, Docs & Gate

**Goal:** Inbox UI integration is documented, demo-proven, contract-tested, and gated in the release checklist.

**Depends on:** Phase 61

**Requirements:** DEMO-08, DOCS-08 (Inbox), DOCS-09 (Inbox), GATE-05 (Inbox)

**Success Criteria** (what must be TRUE):

1. Demo host mounts end-user inbox; journey test proves list → mark_read/seen → badge count update
2. Golden-path inbox integration guide covers dependency → router mount → auth behaviour → bell UI
3. Doc-contract tests lock inbox guide truth; `mix verify.inbox` runs in CI and completes MAINTAINING.md pre-ship octet

**Plans:** TBD

**Wave 1 *(parallel)*:** 62-01 — Demo host inbox mount + journey proof (DEMO-08); 62-03 — `mix verify.inbox` + CI job + MAINTAINING octet (GATE-05)  
**Wave 2 *(blocked on 62-01)*:** 62-02 — Inbox integration guide + doc-contract tests (DOCS-08/09)

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 58. Accrue Dunning Core | 3/3 | Complete    | 2026-05-30 |
| 59. Accrue Blueprint & Demo | 2/2 | Complete    | 2026-05-30 |
| 60. Accrue Docs & Release Gate | 2/3 | In Progress|  |
| 61. Inbox Headless + Package | 0/TBD | Not started | — |
| 62. Inbox Demo, Docs & Gate | 0/TBD | Not started | — |

---
*Roadmap updated: 2026-05-30 — milestone v1.9 Adopter Complete*
