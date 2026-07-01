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
- ✅ **v1.11 Operator Console Polish & Hardening** — [Archived roadmap](.planning/milestones/v1.11-ROADMAP.md) · [Audit](.planning/milestones/v1.11-MILESTONE-AUDIT.md) (shipped 2026-06-04)
- ◆ **v1.13 Storage Isolation and Upgrade Path** — active

## Active Milestone

**v1.13 Storage Isolation and Upgrade Path**

**Goal:** Make Chimeway a respectful guest in host databases by defaulting new installs to a dedicated `chimeway` Postgres schema while preserving explicit public-schema compatibility for existing installs.

**Source context:** `.planning/research/v1.12-quality-readiness/PG-SCHEMA-ISOLATION-DECISION.md`, `.planning/research/v1.12-quality-readiness/SYNTHESIS-ROADMAP.md`

**Included seeds:** None. This milestone is audit-driven storage cleanup, not a new product wedge.

## Phases

### Phase 73: Storage Prefix Contract

**Goal:** Establish the public and internal contract for static Chimeway storage prefixes before changing migrations or runtime paths.

**Requirements:** PFX-01, PFX-02, PFX-03, PFX-04, UPG-01

**Success Criteria:**

1. Host apps can configure `config :chimeway, prefix: "chimeway"` for default schema-isolated installs and `prefix: false` for public-schema legacy mode.
2. Invalid prefix config fails early with actionable errors.
3. Core code has one internal repo-option/prefix helper or equivalent contract that later phases can use consistently.
4. Public-schema compatibility is explicitly represented in tests and docs as legacy mode, not an accidental default.
5. No dynamic per-tenant prefix API is introduced.

### Phase 74: Prefixed Migration Generator

**Goal:** Make copied host migrations deterministic and schema-respectful, with `chimeway` as the generated default and public as an explicit compatibility choice.

**Requirements:** MIG-01, MIG-02, MIG-03, MIG-04

**Depends on:** Phase 73

**Plans:** 10/10 plans complete

Plans:
**Wave 1**

- [x] 74-01-PLAN.md — CLI/core generation-mode contract

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 74-02-PLAN.md — templates 001-005 helper conversion
- [x] 74-03-PLAN.md — templates 006-010 helper/raw SQL conversion
- [x] 74-04-PLAN.md — templates 011-015 helper conversion
- [x] 74-05-PLAN.md — templates 016-020 helper conversion
- [x] 74-06-PLAN.md — templates 021-025 helper conversion
- [x] 74-07-PLAN.md — templates 026-030 helper/raw SQL conversion
- [x] 74-08-PLAN.md — template 031 helper conversion

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 74-09-PLAN.md — dual fixture and idempotency proof

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 74-10-PLAN.md — static, DB, verify, and CI parity proof

**Cross-cutting constraints:**

- Public generated output remains legacy unprefixed migration code.

**Success Criteria:**

1. `mix chimeway.gen.migrations` emits default migrations that create/use the `chimeway` schema.
2. Tables, indexes, references, alters, drops, and raw SQL in generated migrations are explicitly qualified for the selected prefix.
3. Public/legacy generation remains available and produces unprefixed migrations.
4. Golden fixture, idempotency, and migration contract tests cover both prefixed and public generation.
5. Generated migrations do not require users to run `mix ecto.migrate --prefix chimeway`.

### Phase 75: Runtime Prefix Propagation

**Goal:** Thread the storage-prefix contract through Chimeway runtime behavior so real notification flows read and write in the configured schema.

**Requirements:** RUN-01, RUN-02, RUN-03, RUN-04

**Depends on:** Phases 73-74

**Plans:** 2/7 plans executed

Plans:
**Wave 0**

- [x] 75-01-PLAN.md — Prefixed runtime test harness and guardrails

**Wave 1** *(blocked on Wave 0 completion)*

- [x] 75-02-PLAN.md — Repo defaults and trigger fanout propagation

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 75-03-PLAN.md — Operator, inbox, trace, and recovery surfaces
- [ ] 75-04-PLAN.md — Workflow, signal, worker, and Oban boundary
- [ ] 75-06-PLAN.md — Policy and preference propagation

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 75-05-PLAN.md — Digest and webhook propagation

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 75-07-PLAN.md — Focused runtime-prefix gate and final verification

**Success Criteria:**

1. Trigger fanout persists events, notifications, deliveries, and attempts into the configured prefix.
2. Idempotency, duplicate detection, traces, explainability, inbox, admin, and recovery queries do not accidentally read from `public` when prefix mode is enabled.
3. Workflow progression, signal routing, digests, policy/preferences, webhook ingress, dispatch workers, and string-source `insert_all` calls propagate prefix options.
4. Prefixed integration tests prove trigger-to-trace, duplicate idempotency, inbox read/seen, workflow progression, digest, webhook, and recovery paths.
5. Legacy public mode remains green.

### Phase 76: Prefix Docs, Demo, and Gates

**Goal:** Make storage isolation adoptable and supportable through docs, demo proof, upgrade guidance, Oban caveats, and named verification gates.

**Requirements:** UPG-02, UPG-03, DOCS-01, DOCS-02, DEMO-01, GATE-01

**Depends on:** Phase 75

**Success Criteria:**

1. README, install docs, golden path, troubleshooting, and Oban guide explain the default `chimeway` schema and explicit public mode.
2. Docs clearly state that Oban's prefix is separate from Chimeway's table prefix.
3. Upgrade docs provide a no-silent-migration public compatibility path plus an optional manual move guide and rollback/failure notes.
4. Demo host or equivalent example runs against the default `chimeway` schema and proves trigger-to-trace.
5. Named verify/CI gates cover prefixed install/runtime behavior, public legacy compatibility, and storage docs contracts.

## Progress

| Milestone | Phases | Plans | Requirements | Status | Shipped |
|-----------|--------|-------|--------------|--------|---------|
| v1.13 Storage Isolation and Upgrade Path | 73-76 | 3/3 | 5/19 | Active | — |
| v1.11 Operator Console Polish & Hardening | 68-72 | 12/12 | 18/18 | Complete | 2026-06-04 |
| v1.10 Ecosystem Completions | 63-67 | 13/13 | 8/8 | Complete | 2026-06-04 |

---
*Roadmap updated: 2026-06-30 — Phase 73 complete*
