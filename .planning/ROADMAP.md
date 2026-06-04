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
- ✅ **v1.10 Ecosystem Completions** — [Archived roadmap](.planning/milestones/v1.10-ROADMAP.md) · [Audit](.planning/milestones/v1.10-MILESTONE-AUDIT.md) (shipped 2026-06-04)
- ◆ **v1.11 Operator Console Polish & Hardening** — active

## Active Milestone

**v1.11 Operator Console Polish & Hardening**

**Goal:** Make Chimeway's embedded admin surface a coherent, branded, accessible, safe operator console for explainable notification debugging and recovery.

**Included seeds:** SEED-004 Personas/JTBD & DX Roadmap, SEED-002 Adoption Surface & Reference Flows

## Phases

### Phase 68: Admin Truth Alignment

**Goal:** Reconcile planning, docs, route map, and admin IA around the real multi-page operator console.

**Requirements:** ADMIN-01, ADMIN-02, ADMIN-03

**Success Criteria:**
1. Command center, traces, detail, feed, definitions, health, and recovery are represented consistently in planning/docs.
2. Default landing page makes the primary operator jobs obvious.
3. Demo/admin copy no longer describes shipped pages as out of scope.
4. Navigation labels and page hierarchy match the real route map.

### Phase 69: Console Design System

**Goal:** Raise the admin UI baseline with scoped Chimeway tokens, accessible themes, responsive layout, and restrained motion.

**Requirements:** DES-01, DES-02, DES-03, DES-04

**Plans:** 2 plans

Plans:
- [ ] 69-01-PLAN.md - Scoped token, theme-state, contrast, and reduced-motion contracts
- [ ] 69-02-PLAN.md - Responsive shared primitives, rendered LiveView contracts, and screenshot-ready evidence

**Success Criteria:**
1. Admin CSS exposes a reusable token scale for theme, spacing, status, focus, surfaces, and motion.
2. Light, dark, and system themes have accessible contrast and coherent hover/focus/active states.
3. Mobile and desktop screenshots show no text overlap, unstable controls, or broken hierarchy in core flows.
4. Motion is purposeful, interruptible, and reduced-motion-safe.

### Phase 70: Recovery, Auth, and Tenancy Hardening

**Goal:** Make action-bearing admin flows safe under host auth, tenant scope, stale candidates, and durable recovery evidence.

**Requirements:** SAFE-01, SAFE-02, SAFE-03, SAFE-04

**Success Criteria:**
1. Mutating LiveView events re-authorize with actor, action, and resource context.
2. Recovery handles stale or ineligible candidates without duplicate work.
3. Recovery confirmation and core API calls leave durable operator evidence.
4. Tenant-scoped reads and recovery candidates are proven through tests or documented host context.

### Phase 71: Redaction and Explainability Contracts

**Goal:** Prove rendered UI and DTO boundaries preserve privacy while improving operator explanation quality.

**Requirements:** PRIV-01, PRIV-02, EXPL-01, EXPL-02

**Success Criteria:**
1. Rendered LiveView HTML leak tests cover payloads, render data, provider bodies, secrets, tokens, auth codes, and full PII.
2. Admin DTO tests prove only stable explainability fields cross into UI.
3. Trace/detail/status labels distinguish sent, provider accepted, delivered, suppressed, retryable, and terminal failure states.
4. Definitions UI clearly communicates DB-inferred history and avoids unimplemented code-registry skew claims.

### Phase 72: Admin Docs and Verification Gate

**Goal:** Make the operator console shippable through integration docs, doc contracts, a named verify gate, CI parity, and browser smoke.

**Requirements:** DOCS-12, GATE-08, SMOKE-01

**Success Criteria:**
1. Admin integration guide covers mount, assets, auth, prefixing, recovery permissions, redaction, and fail-closed production setup.
2. Doc-contract tests lock route labels, auth snippets, asset setup, and redaction claims.
3. `mix verify.admin` runs core admin tests, `chimeway_admin` tests, and demo-host mounted admin coverage.
4. Browser smoke proves the mounted console is nonblank, styled, navigable, and usable across core pages.

## Progress

| Milestone | Phases | Plans | Requirements | Status | Shipped |
|-----------|--------|-------|--------------|--------|---------|
| v1.11 Operator Console Polish & Hardening | 68-72 | 0/0 | 0/18 | Active | — |
| v1.10 Ecosystem Completions | 63-67 | 13/13 | 8/8 | Complete | 2026-06-04 |

---
*Roadmap updated: 2026-06-04 — v1.11 initialized*
