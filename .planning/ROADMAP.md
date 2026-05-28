# Roadmap: Chimeway

## Milestones

- ✅ **v1.0** — [Archived roadmap](.planning/milestones/v1.0-ROADMAP.md) (shipped 2026-04-25)
- ✅ **v1.1** — [Archived roadmap](.planning/milestones/v1.1-ROADMAP.md) (shipped 2026-04-27)
- ✅ **v1.2** — [Archived roadmap](.planning/milestones/v1.2-ROADMAP.md) (shipped 2026-04-29)
- ✅ **v1.3** — [Archived roadmap](.planning/milestones/v1.3-ROADMAP.md) (shipped 2026-04-30)
- ✅ **v1.4** — [Archived roadmap](.planning/milestones/v1.4-ROADMAP.md) · [Audit](.planning/milestones/v1.4-MILESTONE-AUDIT.md) (shipped 2026-05-08, closed 2026-05-28)

## Active Milestone: v1.5 Adoption Surface

**Status:** Planning complete — ready for Phase 35
**Phases:** 35–40
**Requirements:** 12/12 mapped

### Overview

Make Chimeway adoptable off the lot: installer truth, golden-path docs, reference recipes, demo trace path, optional operator trace MVP, and release doc-contract gates. Engine scope stays fixed; adoption friction is the bottleneck.

---

## Phase 35: Installer Task

**Goal:** Host developers can bootstrap Chimeway schema via a documented, idempotent Mix task.
**Depends on:** Phase 34 (v1.4 complete)
**Requirements:** INST-01, INST-02
**Plans:** 3/3 complete (35-01 ✅, 35-02 ✅, 35-03 ✅)

**Success criteria:**

1. `mix chimeway.gen.migrations` (or equivalent install task) exists and is documented in installation guide.
2. Running the task on a fresh host generates expected migration files without manual schema copying.
3. Re-running the task is idempotent and covered by golden-diff or contract test in CI.

---

## Phase 36: Golden Path & Version Alignment

**Goal:** A fresh Phoenix host can follow one credible path from dependency to first explainable trace, with consistent version strings everywhere.
**Depends on:** Phase 35
**Requirements:** DOCS-01, DOCS-02

**Success criteria:**

1. Golden-path guide covers dependency add → migrations → config → first `Chimeway.trigger/3` → trace query.
2. Guide optionally extends to webhook feedback loop using demo host patterns.
3. README, installation guide, and package version strings agree on semver (no `0.1` vs `1.0.0` drift).

---

## Phase 37: Doc Truth & Journey Guides

**Goal:** Workflow/journey documentation matches engine capabilities so adopters are not misled by aspirational APIs.
**Depends on:** Phase 36
**Requirements:** DOCS-03

**Success criteria:**

1. Multi-step journey guide accurately describes `wait_until`, outcome progression, and signal routing as implemented.
2. Any unsupported `stop_conditions` / `notification_read` patterns are removed, deferred with explicit callouts, or marked experimental with engine gap noted (INV-002 resolution).
3. Doc-contract test or checklist flags journey guide sections against implemented APIs.

---

## Phase 38: Reference Recipes

**Goal:** Adopters get copy-adaptable recipes for the two highest-leverage SaaS notification JTBDs (SEED-002, SEED-004).
**Depends on:** Phase 37
**Requirements:** RECP-01, RECP-02

**Success criteria:**

1. Password-reset support trace recipe walks Feature Developer trigger setup and Support Operator trace inspection for "why no email?"
2. Feedback escalation recipe walks Product Manager flow: send → webhook → workflow progression visible in trace.
3. Recipes are self-contained under `guides/` or `examples/` with runnable snippets or demo host cross-links.

---

## Phase 39: Demo Host Trace Path

**Goal:** Demo host proves explainability without requiring provider webhook setup.
**Depends on:** Phase 38
**Requirements:** DEMO-01

**Success criteria:**

1. Demo host documents a trace inspection path (IEx, script, or minimal route) separate from webhook E2E.
2. A maintainer or adopter can follow the doc and query delivery/trace outcomes on a triggered notification.
3. Path is referenced from golden-path guide as the lowest-friction validation step.

---

## Phase 40: Operator Trace MVP

**Goal:** Optional `chimeway_admin` package gives support staff redacted trace lookup without building custom tooling.
**Depends on:** Phase 39
**Requirements:** OPER-01, OPER-02

**Success criteria:**

1. Trace lookup by user ID or correlation ID works behind host-provided auth behaviour (no hard-coded host auth).
2. Timeline view shows delivery attempts, suppressions, webhook events, and workflow transitions in one redacted surface.
3. Scope explicitly excludes bell inbox, campaign UI, and marketing tooling (MVP trace-only).

**Open investigation:** INV-001 — in-tree vs sibling Hex package resolved during discuss-phase.

---

## Phase 41: Release Verification Gates

**Goal:** Doc drift and example breakage are caught before release, not by adopters in production.
**Depends on:** Phase 40
**Requirements:** GATE-01

**Success criteria:**

1. `mix verify.example` (or equivalent) runs demo host / reference flow smoke checks in CI.
2. Doc-contract checks validate installer task name, version strings, and golden-path steps against repo reality.
3. Release checklist documents these gates as mandatory pre-ship steps.

---

## Requirement Coverage

| Requirement | Phase | Status |
|-------------|-------|--------|
| INST-01 | Phase 35 | Complete |
| INST-02 | Phase 35 | Complete |
| DOCS-01 | Phase 36 | Pending |
| DOCS-02 | Phase 36 | Pending |
| DOCS-03 | Phase 37 | Pending |
| RECP-01 | Phase 38 | Pending |
| RECP-02 | Phase 38 | Pending |
| DEMO-01 | Phase 39 | Pending |
| OPER-01 | Phase 40 | Pending |
| OPER-02 | Phase 40 | Pending |
| GATE-01 | Phase 41 | Pending |

**Coverage:** 12/12 requirements mapped ✓

---
*Roadmap created: 2026-05-28 for milestone v1.5 Adoption Surface*
