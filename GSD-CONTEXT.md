# Chimeway — start here for GSD

**Goal:** Embedded Elixir/Phoenix **notification** layer with durable records, multi-channel dispatch, and explainable traces—plus optional admin UI. Not a hosted SaaS.

## One-shot for a cleared AI session

### A) Fast path (`--auto`)

1. Open **`prompts/CHIMEWAY-GSD-IDEA.md`** (authoritative vision, v0.1 spine, reading list).
2. From repo root, run:

   ```text
   /gsd-new-project --auto @prompts/CHIMEWAY-GSD-IDEA.md
   ```

3. Then:

   ```text
   /gsd-plan-phase 1
   ```

   Use `--text` on your CLI if menus are unavailable.

### B) Interactive path (questions + four researchers + synthesizer)

Follow **`prompts/INTERACTIVE-GSD-NEW-PROJECT.md`** — same repo; includes the exact `@` list for the first message, Step 3/5/6 guidance, and `/gsd-plan-phase 1` after init.

## Context map (`prompts/`)

| File | Role |
|------|------|
| `CHIMEWAY-GSD-IDEA.md` | GSD bootstrap + milestone seed |
| `INTERACTIVE-GSD-NEW-PROJECT.md` | Interactive `/gsd-new-project` + research subagents paste block |
| `chimeway-brand-book.md` | Brand and voice |
| `elixir_notifykit_research_brief.md` | Domain / ecosystem research (Chimeway is the product name) |
| `chimeway-engineering-dna-from-prior-libs.md` | OSS engineering defaults + Chimeway translation |
| `chimeway-admin-ui-and-operator-ia.md` | Operator UX |
| `chimeway-testing-and-e2e-strategy.md` | Tests, installer golden path, CI |
| `chimeway-release-engineering-and-ci.md` | Release/CI pointers |
| `chimeway-host-app-integration-seam.md` | Host vs library boundaries |
| `prior-art/SOURCE-CANONICAL.md` | Seven shared `*-deep-research.md` files — read from **`rulestead`** checkout or run `prior-art/sync-from-canonical.sh` |

## Seeds map (`.planning/seeds/`)

| File | Role |
|------|------|
| `SEED-001-channel-feedback-loops.md` | v1.4 milestone seeds |
| `SEED-002-adoption-surface-reference-flows.md` | Reference flow planning |
| `SEED-003-ecosystem-integrations.md` | Integrations with sztheory libraries (Mailglass, Accrue, Threadline, Sigra) |
| `SEED-004-personas-and-dx-roadmap.md` | Personas, JTBD, and v1.5+ DX Roadmap |

## Git

This repo is initialized with **`git`** so GSD’s `init.new-project` check passes (`has_git: true`). If you clone fresh elsewhere, run **`git init`** before the first `/gsd-new-project`.

## Machine paths

Default sibling canonical research: **`/Users/jon/projects/rulestead/prompts/`** (see `prior-art/SOURCE-CANONICAL.md`).
