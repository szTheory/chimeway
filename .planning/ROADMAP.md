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

## Active Milestone

**v1.8 Ecosystem Integration Blueprints** — Mailglass-first adapter, inbound feedback bridge, reference blueprint, demo proof, and release gates. Accrue/Threadline/Sigra deferred to v1.9+.

---

## Overview

Prove Chimeway composes with the szTheory ecosystem by shipping a first-class Mailglass adapter: Chimeway owns orchestration (workflows, escalations, deduplication, explainability); Mailglass owns templating, MJML rendering, and Swoosh delivery. Inbound feedback closes the loop into workflow progression. A reference recipe, demo host proof, integration guide, and named verify gate make the composition adoptable off the lot.

## Phases

- [x] **Phase 54: Mailglass Adapter Core** — Outbound delivery through Mailglass with contract-tested adapter behaviour (complete 2026-05-29)
- [x] **Phase 55: Inbound Feedback Bridge** — Mailglass webhooks normalize into Chimeway outcomes and drive workflow progression (completed 2026-05-29)
- [ ] **Phase 56: Blueprint & Demo Proof** — Reference recipe plus TeamPulse demo host end-to-end proof
- [ ] **Phase 57: Docs & Release Gates** — Integration guide, doc-contract tests, and `mix verify.mailglass` CI gate

## Phase Details

### Phase 54: Mailglass Adapter Core

**Goal:** Host applications can deliver Chimeway email notifications through Mailglass rendering without bypassing Chimeway's durable delivery lifecycle.

**Depends on:** v1.7 (durable spine, adapter behaviour, webhook foundation)

**Requirements:** ECOS-01, ECOS-02

**Success Criteria** (what must be TRUE):

1. A host configuring `:mailglass` (or equivalent) as the Chimeway email adapter can trigger a notifier and observe a successful delivery attempt with Mailglass-rendered content
2. `Chimeway.Adapter.Mailglass` passes shared adapter contract tests for deliver success, temporary/permanent/bounced error classification, and redacted provider metadata
3. Adapter config is read at call time via `Application.get_env/3` — no compile-time secrets

**Plans:** 3/3 plans complete

**Wave 1 *(no dependencies)*:** 54-01 — Optional mailglass dep + test harness + adapter stub  
**Wave 2 *(blocked on Wave 1)*:** 54-02 — `deliver/2` implementation (message build, tenancy, error mapping)  
**Wave 3 *(blocked on Wave 2)*:** 54-03 — Contract tests + executor routing + recipe doc

**Cross-cutting constraints:**
- Outbound `deliver/2` only — no webhook callbacks (Phase 55)
- Runtime config only — no compile-time secrets in adapter
- Dual lifecycle: Chimeway attempts + Mailglass delivery ledger (intentional)

### Phase 55: Inbound Feedback Bridge

**Goal:** Mailglass inbound webhook events feed Chimeway's existing feedback pipeline and resume or terminate workflows with explainable traces.

**Depends on:** Phase 54

**Requirements:** ECOS-03, ECOS-04

**Success Criteria** (what must be TRUE):

1. A signed Mailglass inbound webhook payload verifies, resolves delivery identity, and records a canonical delivery outcome (delivered, bounced, or failed)
2. Normalized feedback from Mailglass triggers workflow progression via the existing Signal engine without host glue
3. Operator traces show webhook-received and outcome-linked transitions for Mailglass feedback events

**Plans:** 3/3 plans complete

**Wave 1 *(no dependencies)*:** 55-01 — Spine extensions (`provider_message_id` + webhook parse seam)  
**Wave 2 *(blocked on Wave 1)*:** 55-02 — Mailglass adapter webhook callbacks (verify/resolve/normalize/dedup)  
**Wave 3 *(blocked on Wave 2)*:** 55-03 — Webhook contract tests + ECOS-04 feedback pipeline integration proof

### Phase 56: Blueprint & Demo Proof

**Goal:** Adopters can copy a published Mailglass + Chimeway reference recipe and see the same behaviour proven on the demo host.

**Depends on:** Phase 55

**Requirements:** ECOS-05, DEMO-06

**Success Criteria** (what must be TRUE):

1. A reference recipe documents notifier authoring, adapter config, and the orchestration vs templating responsibility split with CI doc-contract coverage
2. Demo host TeamPulse notifiers deliver at least one email through `Chimeway.Adapter.Mailglass` with inspectable traces via `/admin/chimeway`
3. Recipe and demo align on stable notification keys and Mailglass template identifiers — no module-name coupling in durable identity

**Plans:** 1/2 plans complete

**Wave 1 *(no dependencies)*:** 56-01 — Demo host Mailglass proof (DEMO-06: invite delivery + admin trace, journey CI isolated)  
**Wave 2 *(blocked on Wave 1)*:** 56-02 — Mailglass integration blueprint recipe + ECOS-05 doc-contract

### Phase 57: Docs & Release Gates

**Goal:** Mailglass integration is documented, contract-tested, and gated in the release checklist alongside existing verify entrypoints.

**Depends on:** Phase 56

**Requirements:** DOCS-06, DOCS-07, GATE-04

**Success Criteria** (what must be TRUE):

1. Golden-path integration guide walks a fresh host from dependency → config → trigger → Mailglass delivery → optional inbound feedback
2. Doc-contract tests fail if guide text regresses to pre-Mailglass assumptions or omits required setup steps
3. `mix verify.mailglass` (or equivalent named entrypoint) runs in CI and appears in MAINTAINING.md pre-ship checklist without breaking the existing journey/doc gate quintet

**Plans:** TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 54. Mailglass Adapter Core | 3/3 | Complete    | 2026-05-29 |
| 55. Inbound Feedback Bridge | 3/3 | Complete    | 2026-05-29 |
| 56. Blueprint & Demo Proof | 1/2 | In Progress | — |
| 57. Docs & Release Gates | 0/? | Not started | — |

---
*Roadmap updated: 2026-05-29 — milestone v1.8 Ecosystem Integration Blueprints*
