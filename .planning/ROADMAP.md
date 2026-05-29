# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- ✅ **v1.1** — [Archived roadmap](.planning/milestones/v1.1-ROADMAP.md) (shipped 2026-04-27)
- ✅ **v1.2** — [Archived roadmap](.planning/milestones/v1.2-ROADMAP.md) (shipped 2026-04-29)
- ✅ **v1.3** — [Archived roadmap](.planning/milestones/v1.3-ROADMAP.md) (shipped 2026-04-30)
- ✅ **v1.4** — [Archived roadmap](.planning/milestones/v1.4-ROADMAP.md) · [Audit](.planning/milestones/v1.4-MILESTONE-AUDIT.md) (shipped 2026-05-08, closed 2026-05-28)
- ✅ **v1.5** — [Archived roadmap](.planning/milestones/v1.5-ROADMAP.md) · [Audit](.planning/milestones/v1.5-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- ✅ **v1.6** — [Archived roadmap](.planning/milestones/v1.6-ROADMAP.md) · [Audit](.planning/milestones/v1.6-MILESTONE-AUDIT.md) (shipped 2026-05-29)
- 🚧 **v1.7** — READ + Adoption Polish (Phases 48–52, in progress)

## Active Milestone

**v1.7 READ + Adoption Polish** — Connect inbox read/unread state to workflow progression and close adoption-evidence gaps in demo, docs, and journeys.

---

## Phases

### 🚧 v1.7 READ + Adoption Polish (Phases 48–52)

- [ ] **Phase 48: `wait_until` Pending Signals** — Auto-populate `pending_signals` when runs enter time-based waits
- [ ] **Phase 49: Inbox Read → Signal** — `mark_read` / `mark_seen` emit durable signals with explainable early resume
- [ ] **Phase 50: Natural Escalation Demo** — TeamPulse seeds and mention-escalation recipe use READ paths
- [ ] **Phase 51: Journey & Admin Proof** — READ journey plus all-persona admin traces in CI
- [ ] **Phase 52: Doc Truth & Gates** — README/moduledoc fixes and `verify.journeys` expansion

## Phase Details

### Phase 48: `wait_until` Pending Signals

**Goal:** Close READ-01 — workflow runs entering `wait_until` automatically persist canonical `pending_signals` so signal routing works without host glue.

**Depends on:** v1.6 (workflow engine + journey foundation)

**Requirements:** READ-01

**Success Criteria** (what must be TRUE):

1. A workflow run entering `:waiting` via `wait_until` has `pending_signals` populated from progress-rule configuration
2. `SignalRouterWorker` can match an injected signal against a waiting run without manual `pending_signals` assignment by the host
3. Multi-step journey guide no longer documents READ-01 as an engine gap (deferred callout removed or marked shipped)

**Plans:** 3 plans (3 waves)

| Wave | Plans | What it builds |
|------|-------|----------------|
| 1 | 48-01 | `cancel_signals` DSL validation in `normalize_wait_until_rule/1` + notifier contract tests |
| 2 *(blocked on Wave 1)* | 48-02 | `enter_waiting/6` auto-populates `pending_signals` + progression tests + SignalRouterWorker proof |
| 3 *(blocked on Wave 2)* | 48-03 | Journey guide doc-truth (`cancel_signals` authoring, READ-01 gap removed) + doc contract tests |

---

### Phase 49: Inbox Read → Signal

**Goal:** Close READ-02 and READ-03 — inbox lifecycle actions emit durable signals that resume waiting workflows with explainable traces.

**Depends on:** Phase 48

**Requirements:** READ-02, READ-03

**Success Criteria** (what must be TRUE):

1. Calling `Chimeway.mark_read/3` on a notification emits a durable signal routed through `SignalRouterWorker`
2. Calling `Chimeway.mark_seen/3` emits a durable signal with documented semantics distinct from or aligned with read
3. A `:waiting` run whose `pending_signals` includes the inbox-read event resumes to `:active` with a `signal_received` transition visible in operator traces (event name only, no raw payload)

**Plans:** TBD

---

### Phase 50: Natural Escalation Demo

**Goal:** Replace staged webhook choreography with READ-driven TeamPulse escalation and update the mention-escalation recipe.

**Depends on:** Phase 49

**Requirements:** DEMO-03, DEMO-04

**Success Criteria** (what must be TRUE):

1. `DemoHost.Seeds` payment-escalation path no longer requires `stage_escalation_webhook/1` or `PendingWebhookAdapter` choreography for the primary demo story
2. PM JTBD ("if they don't open in 2 hours, send push/email") is demonstrable via seeds using READ-driven progression
3. Mention-escalation reference recipe documents read-cancel plus time-based `wait_until` fallback as the canonical pattern

**Plans:** TBD

---

### Phase 51: Journey & Admin Proof

**Goal:** Extend journey CI to prove READ behavior and cover all three SEED-004 personas in admin traces.

**Depends on:** Phase 50

**Requirements:** JOUR-06, JOUR-07, JOUR-08

**Success Criteria** (what must be TRUE):

1. JOUR-06: seed → delivery → `mark_read` → escalation step does not fire before `wait_until` due_at
2. JOUR-07: admin search/detail shows Sam password-reset suppression with explainable reason (Support Operator)
3. JOUR-08: admin search/detail shows Morgan payment-escalation workflow trace (Product Manager)

**Plans:** TBD

---

### Phase 52: Doc Truth & Gates

**Goal:** Close adoption-evidence doc drift and extend release gates for READ journeys.

**Depends on:** Phase 51

**Requirements:** DOCS-04, DOCS-05, GATE-03

**Success Criteria** (what must be TRUE):

1. Demo host README no longer contradicts webhook progression vs TeamPulse escalation; TraceDemo vs TeamPulse narrative is unified
2. `mix demo.up --check` moduledoc matches actual migrate + seed + app.start behavior
3. `mix verify.journeys` runs JOUR-06..08; MAINTAINING.md pre-ship quintet documents the expanded journey suite

**Plans:** TBD

---

## Progress

<details>
<summary>✅ v1.6 Consumer Journey Proof (Phases 43–47) — SHIPPED 2026-05-29</summary>

| Phase | Name | Status |
|-------|------|--------|
| 43 | TeamPulse domain + seeds | Complete |
| 44 | Demo commands | Complete |
| 45 | Journey tests (engine paths) | Complete |
| 46 | Host-mount admin integration | Complete |
| 47 | CI gates + verify.journeys | Complete |

**Requirements:** DEMO-02, SEED-01, CMD-01, JOUR-01..05, GATE-02 — all satisfied (9 requirements).

</details>

<details>
<summary>✅ v1.5 Adoption Surface (Phases 35–42) — SHIPPED 2026-05-29</summary>

| Phase | Name | Plans | Status |
|-------|------|-------|--------|
| 35 | Installer Task | 3/3 | Complete |
| 36 | Golden Path & Version Alignment | 3/3 | Complete |
| 37 | Doc Truth & Journey Guides | 4/4 | Complete |
| 38 | Reference Recipes | 3/3 | Complete |
| 39 | Demo Host Trace Path | 3/3 | Complete |
| 40 | Operator Trace MVP | 3/3 | Complete |
| 41 | Release Verification Gates | 3/3 | Complete |
| 42 | DOCS-02/GATE-01 gap closure (INSERTED) | 3/3 | Complete |

</details>

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 48. `wait_until` Pending Signals | v1.7 | 1/3 | In Progress | — |
| 49. Inbox Read → Signal | v1.7 | 0/TBD | Not started | — |
| 50. Natural Escalation Demo | v1.7 | 0/TBD | Not started | — |
| 51. Journey & Admin Proof | v1.7 | 0/TBD | Not started | — |
| 52. Doc Truth & Gates | v1.7 | 0/TBD | Not started | — |

---
*Roadmap updated: 2026-05-29 — milestone v1.7 READ + Adoption Polish started (Phases 48–52)*
