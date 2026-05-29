# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- ✅ **v1.1** — [Archived roadmap](.planning/milestones/v1.1-ROADMAP.md) (shipped 2026-04-27)
- ✅ **v1.2** — [Archived roadmap](.planning/milestones/v1.2-ROADMAP.md) (shipped 2026-04-29)
- ✅ **v1.3** — [Archived roadmap](.planning/milestones/v1.3-ROADMAP.md) (shipped 2026-04-30)
- ✅ **v1.4** — [Archived roadmap](.planning/milestones/v1.4-ROADMAP.md) · [Audit](.planning/milestones/v1.4-MILESTONE-AUDIT.md) (shipped 2026-05-08, closed 2026-05-28)
- ✅ **v1.5** — [Archived roadmap](.planning/milestones/v1.5-ROADMAP.md) · [Audit](.planning/milestones/v1.5-MILESTONE-AUDIT.md) (shipped 2026-05-29)

## Active Milestone

**v1.5 gap closure** — Phase 42 inserted after re-audit found DOCS-02/GATE-01 regressions.

---

## Progress

<details>
<summary>✅ v1.5 Adoption Surface (Phases 35–41) — SHIPPED 2026-05-29</summary>

| Phase | Name | Plans | Status |
|-------|------|-------|--------|
| 35 | Installer Task | 3/3 | Complete |
| 36 | Golden Path & Version Alignment | 3/3 | Complete |
| 37 | Doc Truth & Journey Guides | 4/4 | Complete |
| 38 | Reference Recipes | 3/3 | Complete |
| 39 | Demo Host Trace Path | 3/3 | Complete |
| 40 | Operator Trace MVP | 3/3 | Complete |
| 41 | Release Verification Gates | 3/3 | Complete |

**Requirements:** INST-01/02, DOCS-01/02/03, RECP-01/02, DEMO-01, OPER-01/02, GATE-01 — all satisfied.

</details>

### Phase 42: Close gap: DOCS-02/GATE-01 — align consumer docs to 1.0.0 and fix doc-contract drift patterns

**Goal:** Close v1.5 re-audit regressions — align consumer docs to `{:chimeway, "~> 1.0"}`, reconcile major-aware drift patterns, fix ex_doc cross-package links, and get the MAINTAINING.md pre-ship quartet green.
**Requirements**: DOCS-02, GATE-01
**Depends on:** Phase 41
**Plans:** 3/3 plans complete

**Wave 1** *(no dependencies)*
Plans:
- [x] 42-01-PLAN.md — DOCS-02 consumer version alignment + `stale_drift_patterns/2`

**Wave 2** *(blocked on Wave 1 completion)*
Plans:
- [x] 42-02-PLAN.md — ex_doc cross-package link fixes (4 guides)

**Wave 3** *(blocked on Wave 2 completion)*
Plans:
- [x] 42-03-PLAN.md — Demo README hygiene, audit update, pre-ship quartet sign-off

**Cross-cutting constraints:**
- Phase succeeds only when all four MAINTAINING.md pre-ship commands exit 0 (`mix ci`, `mix ci.docs`, `mix ci.verify_gates`, `mix verify.example`)
- Do not add `examples/` or `chimeway_admin/` to Hex `:files` — use GitHub absolute URLs for out-of-package links

---
*Roadmap updated: 2026-05-29 — Phase 42 planned (3 plans, 3 waves)*
