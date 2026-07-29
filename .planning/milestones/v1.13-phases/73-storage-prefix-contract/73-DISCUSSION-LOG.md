# Phase 73: Storage Prefix Contract - Discussion Log (Assumptions + Advisor Research)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-06-30
**Phase:** 73-storage-prefix-contract
**Mode:** assumptions + advisor research
**Areas analyzed:** Prefix Value Semantics, Early Validation, Internal Repo Option Contract, Phase Boundary and Upgrade Contract

## Assumptions Presented

### Prefix Value Semantics

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The runtime contract should accept `prefix: "chimeway"` and `prefix: false`; public-schema compatibility is represented only by `false`, not by missing config or runtime `"public"`. | Likely | `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/research/v1.12-quality-readiness/PG-SCHEMA-ISOLATION-DECISION.md` |

### Early Validation

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Prefix validation should follow the existing boot-time validation pattern with actionable Chimeway config errors. | Likely | `lib/chimeway/application.ex`, `test/chimeway/application_validation_test.exs`, `config/config.exs` |

### Repo Option Contract

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 73 should add one core internal helper or equivalent contract mapping validated storage config to Ecto repo options. | Likely | `.planning/research/v1.12-quality-readiness/PG-SCHEMA-ISOLATION-DECISION.md`, `lib/chimeway/traces.ex`, `lib/chimeway/admin.ex` |

### Phase Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 73 should prove the contract with focused config/helper tests and narrow docs/test representation of public legacy mode, without migration template rewrite or broad runtime threading. | Confident | `.planning/ROADMAP.md`, `lib/chimeway/install/migrations.ex`, `lib/mix/tasks/chimeway.gen.migrations.ex`, `lib/chimeway/trigger.ex`, `lib/chimeway/inbox.ex` |

## Corrections Made

No direct corrections were requested. The user requested deeper advisor-style research using subagents, with pros/cons/tradeoffs, ecosystem lessons, DX focus, and a one-shot coherent recommendation set.

## Advisor Research Summary

### Prefix Value Semantics

Recommended strict static runtime config:

- `prefix: "chimeway"` for schema-isolated storage.
- `prefix: false` for explicit public-schema legacy mode.
- Reject missing config, `nil`, `"public"`, dynamic/function prefixes, and per-tenant database prefixes.
- Allow later generator CLI sugar such as `--prefix public` only as a migration-generation convenience normalized to runtime `false`.

Tradeoff accepted: existing public users must opt into legacy mode explicitly, but this avoids silent public writes and migration/runtime split-brain.

### Early Validation

Recommended combined runtime contract:

- One normalizer/validator.
- Boot validation in `Chimeway.Application.start/2`.
- Shared helper validation through the storage repo-option contract.
- Later Mix-task validation through the same normalizer.
- No boot-time database schema existence checks.

Tradeoff accepted: slightly more validation surface, but one shared normalizer prevents divergent behavior.

### Internal Repo Option Contract

Recommended internal storage namespace:

- Add `Chimeway.Storage.repo_opts/1` and validated prefix helpers.
- Use `Keyword.put_new/3` so explicit caller overrides remain possible for tests/admin/debug surfaces.
- Do not advertise per-call prefixes as tenancy.
- Keep context-private option filtering, but delegate prefix construction to `Chimeway.Storage`.

Tradeoff accepted: Phase 75 still has broad call-site work, but Phase 73 establishes the contract that prevents duplicated prefix logic.

### Phase Boundary, Tests, Docs, Upgrade Contract

Recommended contract-only Phase 73:

- Add validation/helper/config/doc-contract proof.
- Reframe current public migration contract as legacy compatibility.
- Defer CLI flags, migration output, raw SQL qualification, golden fixtures, runtime propagation, demo proof, Oban docs, manual move guide, and release gates.

Tradeoff accepted: prefixed installs are not runnable at the end of Phase 73, but scope remains clean and later phases have a stable contract.

## External Research

- Ecto repo/query/schema prefix semantics: `https://hexdocs.pm/ecto/Ecto.Repo.html`, `https://hexdocs.pm/ecto/Ecto.Query.html`, `https://hexdocs.pm/ecto/Ecto.Schema.html`, `https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html`
- Ecto migration prefix behavior: `https://hexdocs.pm/ecto_sql/Ecto.Migration.html`
- Oban prefix and testing behavior: `https://hexdocs.pm/oban/Oban.Migration.html`, `https://hexdocs.pm/oban/testing.html`
- Elixir/Phoenix-style configuration and application startup references: `https://hexdocs.pm/elixir/Application.html`, `https://hexdocs.pm/elixir/Config.html`, `https://hexdocs.pm/mix/Mix.html`
- Notification ecosystem lessons: Noticed (`https://github.com/excid3/noticed`), Laravel Notifications (`https://laravel.com/docs/notifications`), Symfony Notifier (`https://symfony.com/doc/current/notifier.html`)
- Migration/upgrade lessons cited by advisor research: Rails engines (`https://guides.rubyonrails.org/engines.html`), Django migrations (`https://docs.djangoproject.com/en/stable/topics/migrations/`), Alembic autogenerate (`https://alembic.sqlalchemy.org/en/latest/autogenerate.html`)

## Methodology Applied

- Cohesive Recommendation Default: collapsed competing options into one coherent architecture.
- High-Impact Escalation Gate: escalated only public contract decisions; implementation-local choices were recommended directly.
- Research-First Decision Ownership: used local planning docs, prompts, code scouting, and ecosystem references before finalizing.
- Durable Explainability Bias: favored explicit storage modes and durable upgrade semantics over silent fallback behavior.
- Least-Surprise DX Default: chose copy-paste config, branded errors, and honest legacy-mode wording.

## Auto-Resolved

Not applicable.
