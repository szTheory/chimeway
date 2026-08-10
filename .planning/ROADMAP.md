# Roadmap: Chimeway

## Milestones

- 🚧 **v1.17 Adopter Proof Paths** — active (Phases 93–96 planned)
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
- ✅ **v1.10 Ecosystem Completions** — [Archived roadmap](.planning/milestones/v1.10-ROADMAP.md) · [Audit](.planning/milestones/v1.10-MILESTONE-AUDIT.md) (shipped 2026-06-04)
- ✅ **v1.11 Operator Console Polish & Hardening** — [Archived roadmap](.planning/milestones/v1.11-ROADMAP.md) · [Audit](.planning/milestones/v1.11-MILESTONE-AUDIT.md) (shipped 2026-06-04)
- ✅ **v1.13 Storage Isolation and Upgrade Path** — [Archived roadmap](.planning/milestones/v1.13-ROADMAP.md) · [Audit](.planning/milestones/v1.13-MILESTONE-AUDIT.md) (shipped 2026-07-02)
- ✅ **v1.14 Public Truth and Verification Architecture** — [Archived roadmap](.planning/milestones/v1.14-ROADMAP.md) (shipped 2026-07-03)
- ✅ **v1.15 Brand Identity & Brand Book** — [Archived roadmap](.planning/milestones/v1.15-ROADMAP.md) · [Audit](.planning/milestones/v1.15-MILESTONE-AUDIT.md) (shipped 2026-07-28, accepted-risk close)
- ✅ **v1.16 CI/CD Performance & Reliability** — [Archived roadmap](.planning/milestones/v1.16-ROADMAP.md) (shipped 2026-07-30, accepted-risk close — 25/26; CACHE-05 deferred)

## Phases

### v1.17 Adopter Proof Paths

**Goal:** Let a prospective Elixir/Phoenix adopter select a relevant Chimeway use case, run a clean and trustworthy proof from a packaged artifact, and understand the boundary between Chimeway and its integration partners.

- [x] **Phase 93: Hermetic Artifact Harness & Core Trace Proof** - A clean consumer proves the core durable notification lifecycle and public trace from an unpacked package artifact. (completed 2026-08-08)
- [x] **Phase 94: Mailglass Transactional-Email Proof** - A clean consumer proves deterministic Mailglass orchestration and explains exactly what fake transport covers. (completed 2026-08-09)
- [x] **Phase 95: Accrue Billing-Escalation Proof** - A clean consumer proves Accrue workflow outcomes with truthful released-package versus pinned-ref provenance. (completed 2026-08-09)
- [ ] **Phase 96: Adoption Front Door & Proof Gate** - Adopters can select, run, and trust the three proof paths through contract-checked guidance and one focused CI lane.

<details>
<summary>✅ v1.16 CI/CD Performance & Reliability (Phases 87-92) — SHIPPED 2026-07-30 (accepted-risk close — 25/26; CACHE-05 deferred → backlog #4)</summary>

**Goal:** Make CI fast, deterministic, and trustworthy — collapse the ~6.5 min `main` wall-clock toward under ~3 min by fixing compiled-artifact caching, without lowering the quality signal. Doc/config/CI-only; no runtime library behavior changes.

- [x] Phase 87: CI Observability & Cache Diagnostics (3/3 plans) — completed 2026-07-29
- [x] Phase 88: Cache Correctness & Compile-Once (3/3 plans) — completed 2026-07-29 — accepted-risk: CACHE-01..04 shipped & proven (MIX_ENV collision fixed, caches HIT warm); **CACHE-05 deferred → backlog #4** (warm `ci-gate` regressed ~373s→~648s; compile-once relegated to a spike, owner decision 2026-07-29)
- [x] Phase 89: Test-Lane Concurrency (6/6 plans) — completed 2026-07-29 — ~20 pure-DB DataCase modules async, explicit pool, `--warnings-as-errors` parity, CONC-04 no-coupling proven (3 green CI runs + local `--seed 0`)
- [x] Phase 90: Pipeline Tiering (PR/main/nightly) (3/3 plans) — completed 2026-07-30 — `resolve_tiers` fromJSON OTP matrix (PR single-{27}, push/nightly {26,27}); `verify_admin`+cold-build+1.17-floor relocated to a `schedule`/dispatch nightly tier with `nightly-gate`; ci-gate 14→13 lanes
- [x] Phase 91: Quality & Supply-Chain Polish (3/3 plans) — completed 2026-07-30 — `.tool-versions` strict SSOT, Dependabot (mix+actions), least-privilege token, dual hex+deps audit, 1.17 floor gating on push; 5/5 by automated live-CI assertion
- [x] Phase 92: Reliability Triage & Determinism (3/3 plans) — completed 2026-07-30 — `reliability-report.sh` (rate=6%/streak=10), nightly-only `test_seed_zero`, `put_env_isolated/3` helper, backlog #2/#3 verified-fixed + issue #4 closed

Full detail: [milestones/v1.16-ROADMAP.md](.planning/milestones/v1.16-ROADMAP.md)

</details>

<details>
<summary>✅ v1.15 Brand Identity & Brand Book (Phases 81-86) — SHIPPED 2026-07-28 (accepted-risk close)</summary>

- [x] Phase 81: Design Tokens (Reconciliation & Documentation) (3/3 plans) — completed 2026-07-10
- [x] Phase 82: Logo Exploration & Shortlist (1/1 plan) — completed 2026-07-18
- [x] Phase 83: Direction Selection & Final Asset Family (User Checkpoint) (3/3 plans) — completed 2026-07-18
- [x] Phase 84: HTML Brandbook, Voice & Component States (4/4 plans) — completed 2026-07-27
- [x] Phase 85: Repo Integration (README + HexDocs + Favicon Wiring) (1/1 plan) — completed 2026-07-27
- [x] Phase 86: Accessibility Audit, Notes & Red-Team Close (4/4 plans) — completed 2026-07-28 — accepted-risk: A11Y-03 (focus-not-obscured) + A11Y-04 (CVD emulation) manual browser checks owner-waived

Full detail: [milestones/v1.15-ROADMAP.md](.planning/milestones/v1.15-ROADMAP.md)

</details>

<details>
<summary>✅ v1.14 Public Truth and Verification Architecture (Phases 77-80) — SHIPPED 2026-07-03</summary>

- [x] Phase 77: Truth Baseline and Package Model Decision (2/2 plans) — completed 2026-07-03
- [x] Phase 78: Release and Package Truth (3/3 plans) — completed 2026-07-03
- [x] Phase 79: Front Door and Docs IA (1/1 plan) — completed 2026-07-03
- [x] Phase 80: Verification Architecture and CI/DX (4/4 plans) — completed 2026-07-03

Full detail: [milestones/v1.14-ROADMAP.md](.planning/milestones/v1.14-ROADMAP.md)

</details>

<details>
<summary>✅ v1.13 Storage Isolation and Upgrade Path (Phases 73-76.1) — SHIPPED 2026-07-02</summary>

- [x] Phase 73: Storage Prefix Contract (3/3 plans) — completed 2026-06-30
- [x] Phase 74: Prefixed Migration Generator (10/10 plans) — completed 2026-06-30
- [x] Phase 75: Runtime Prefix Propagation (8/8 plans) — completed 2026-07-01
- [x] Phase 76: Prefix Docs, Demo, and Gates (3/3 plans) — completed 2026-07-02
- [x] Phase 76.1: Close gap: GATE-01 - generated prefixed migration runtime proof (1/1 plan) — completed 2026-07-02

Full detail: [milestones/v1.13-ROADMAP.md](.planning/milestones/v1.13-ROADMAP.md)

</details>

## Phase Details

### Phase 93: Hermetic Artifact Harness & Core Trace Proof

**Goal**: Prospective adopters can independently install an unpacked Chimeway artifact into a clean host and prove a core notification lifecycle through public explainability evidence.
**Depends on**: Nothing
**Requirements**: PROOF-01, PROOF-02, PROOF-03, CORE-01
**Success Criteria** (what must be TRUE):

  1. An adopter can run the Core proof from a temporary clean consumer whose Chimeway dependency resolves from an unpacked built package artifact, not the repository source tree.
  2. The clean consumer can boot, create and migrate its own supported PostgreSQL database, and execute the documented Core command reproducibly.
  3. The Core proof shows a notifier definition, public trigger, and durable delivery outcome with stable notification identity inputs visible in sanitized evidence.
  4. The proof obtains and asserts the lifecycle explanation through a public Chimeway explainability API rather than private test helpers or database-only inspection.

**Plans**: TBD

### Phase 94: Mailglass Transactional-Email Proof

**Goal**: Prospective adopters can evaluate the existing Mailglass transactional-email path in the clean consumer and see its public delivery evidence and exact boundary.
**Depends on**: Phase 93
**Requirements**: MAIL-01, MAIL-02
**Success Criteria** (what must be TRUE):

  1. An adopter can run the Mailglass proof in the clean consumer and observe configured host mailable/render-key orchestration reach a deterministic transactional-email outcome.
  2. The proof output includes sanitized public explainability evidence for the Mailglass adapter and delivery attempt.
  3. The path’s guidance states that its fake/test transport proves local composition and orchestration, while provider acceptance, sender verification, and live feedback remain outside the proof.

**Plans**: 3/3 plans executed

Plans:

- [x] 94-03-PLAN.md

**Wave 1**

- [x] 94-01-PLAN.md — Prove the unpacked-artifact Mailglass path and strict trace-only evidence boundary.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 94-02-PLAN.md — Lock canonical one-repo, Fake-transport, and live-provider boundary guidance.

### Phase 95: Accrue Billing-Escalation Proof

**Goal**: Prospective adopters can evaluate Accrue-driven billing escalation through its natural event and outcome-signal boundaries, with provenance that does not overstate release support.
**Depends on**: Phase 93
**Requirements**: ACCR-01, ACCR-02
**Success Criteria** (what must be TRUE):

  1. An adopter can run an Accrue proof in the clean consumer where a billing failure begins escalation and a payment outcome signal progresses or terminates the workflow without directly invoking a Chimeway notifier.
  2. The proof shows sanitized public trace evidence for the workflow progression and its resulting termination or outcome state.
  3. When the resolved Accrue release contains the integration, the proof identifies the released package versions and labels itself as an independent released-package adopter proof.
  4. If the integration is available only through an immutable pinned reference, the proof identifies the exact ref/SHA and labels itself solely as compatibility evidence, never as released-package installation guidance.

**Plans**: 5/5 plans executed

Plans:

- [x] 95-03-PLAN.md
- [x] 95-04-PLAN.md
- [x] 95-05-PLAN.md

**Wave 1**

- [x] 95-01-PLAN.md — Prove the unpacked-artifact Accrue event-to-outcome path and strict lifecycle/provenance evidence boundary.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 95-02-PLAN.md — Lock canonical non-terminal lifecycle and released-package-versus-SHA guidance.

### Phase 96: Adoption Front Door & Proof Gate

**Goal**: Prospective adopters can choose the right canonical path, understand ownership boundaries, and rely on CI-backed commands and documentation that remain truthful over time.
**Depends on**: Phase 94, Phase 95
**Requirements**: ADPT-01, ADPT-02, GATE-01, GATE-02, DOCS-01
**Success Criteria** (what must be TRUE):

  1. An adopter can choose Core, Mailglass, or Accrue from the desired outcome and see the respective host, Chimeway, and partner responsibilities.
  2. Each chosen path provides a copyable proof command, expected sanitized explainability evidence, and an explicit statement of what the proof does not cover.
  3. An adopter or maintainer can run `mix verify.adoption_paths` to execute the clean-room proof paths without re-running the repository’s detailed partner integration suites.
  4. CI runs that command in one dedicated PostgreSQL-backed adoption lane and surfaces enough per-path diagnostics to identify a failed proof.
  5. Contract checks prevent the selector, commands, artifact fixture guidance, and CI entrypoint from silently drifting apart.

**Plans**: 5/5 plans executed

- [x] 96-04-PLAN.md
- [x] 96-05-PLAN.md

**Wave 1**

- [x] 96-01-PLAN.md

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 96-02-PLAN.md

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 96-03-PLAN.md

## Progress

| Milestone | Phases | Plans | Requirements | Status | Shipped |
|-----------|--------|-------|--------------|--------|---------|
| v1.17 Adopter Proof Paths | 93-96 | 0/TBD | 0/13 | Planning | - |
| v1.16 CI/CD Performance & Reliability | 87-92 | 21/21 | 25/26 | Complete (accepted-risk: CACHE-05 deferred → backlog #4) | 2026-07-30 |
| v1.15 Brand Identity & Brand Book | 81-86 | 16/16 | 30/32 | Complete (accepted-risk: 2 A11Y manual checks owner-waived) | 2026-07-28 |
| v1.14 Public Truth and Verification Architecture | 77-80 | 10/10 | 14/14 | Complete | 2026-07-03 |
| v1.13 Storage Isolation and Upgrade Path | 73-76.1 | 25/25 | 20/20 | Complete | 2026-07-02 |
| v1.11 Operator Console Polish & Hardening | 68-72 | 12/12 | 18/18 | Complete | 2026-06-04 |
| v1.10 Ecosystem Completions | 63-67 | 13/13 | 8/8 | Complete | 2026-06-04 |

---
*Roadmap updated: 2026-08-08 — v1.17 Adopter Proof Paths defined: Phases 93–96. All 13 v1.17 requirements are mapped once; Phase 93 is next.*
