# Phase 74: Prefixed Migration Generator - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents. Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-06-30
**Phase:** 74-prefixed-migration-generator
**Mode:** assumptions with requested subagent research
**Areas analyzed:** Generator Interface, Generated Migration Shape, Verification Strategy

## Assumptions Presented

### Generator Interface

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `mix chimeway.gen.migrations` should default to prefixed `chimeway` output, while an explicit public/legacy CLI choice should generate unprefixed output. | Confident | `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/phases/73-storage-prefix-contract/73-CONTEXT.md`, `lib/mix/tasks/chimeway.gen.migrations.ex`, `lib/chimeway/install/migrations.ex` |

### Generated Migration Shape

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Prefixed generated migrations should embed the concrete `chimeway` prefix, create the schema in generated output, and explicitly qualify Chimeway table/index/reference/alter/drop/raw SQL operations instead of relying on `mix ecto.migrate --prefix`. | Confident | `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/research/v1.12-quality-readiness/PG-SCHEMA-ISOLATION-DECISION.md`, `priv/chimeway_migrations/001_create_chimeway_events.exs`, `priv/chimeway_migrations/003_create_chimeway_deliveries.exs`, `priv/chimeway_migrations/009_add_attempt_history_columns.exs`, `priv/chimeway_migrations/027_create_chimeway_signals_and_spine.exs`, `priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs` |

### Verification Strategy

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 74 tests should add separate default-prefixed and public-legacy lanes for golden fixture, idempotency, subprocess CLI, and migration contract coverage while preserving existing public assertions as legacy proof. | Confident | `test/chimeway/install/golden_diff_test.exs`, `test/chimeway/install/idempotency_test.exs`, `test/support/installer_fixture.ex`, `test/chimeway/migration_contract_test.exs`, `mix.exs`, `.github/workflows/ci.yml` |

## Corrections Made

No corrections reversed the assumptions. The user requested deeper one-shot
research across each area, including ecosystem norms, pros/cons/tradeoffs,
lessons from comparable libraries/frameworks, DX, architecture, CI/SRE, and
Chimeway prompt context. The final CONTEXT.md decisions incorporate that deeper
research.

## Research Synthesis

### Generator Interface and DX

Options considered:

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| Template-backed `--prefix chimeway|public`, default `chimeway` | Matches MIG-01/MIG-03, aligns with Phoenix generator conventions, keeps output deterministic, gives existing public users an explicit path | Requires careful docs so CLI `public` is not confused with runtime `prefix: false` | Chosen |
| No flags, default-only `chimeway` | Smallest CLI | Fails explicit public/legacy requirement and weakens upgrade story | Rejected |
| Derive output from runtime config | Fewer CLI choices | Hidden env/config-dependent generation; conflicts with Phase 73 missing-config behavior | Rejected |
| `--legacy-public` only | Very explicit compatibility wording | Less idiomatic than `--prefix`, awkward future extension | Alias only if useful |
| Post-copy transforms | Minimal template churn | Brittle around Ecto calls, heredocs, raw SQL, and future migrations | Rejected as primary strategy |

Decision: default to `chimeway`, accept strict `--prefix chimeway|public`, keep
runtime public config as `prefix: false`, and do not derive generated output from
runtime app env.

### Generated Migration Shape

Options considered:

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| One canonical template tree with helpers and generated `@chimeway_prefix` | Explicit, reviewable, Ecto-native, golden-friendly, avoids template drift | Touches all templates; raw SQL still needs manual care | Chosen |
| Generator text rewrite | Low template churn | Brittle and can silently miss raw SQL or future formatting | Rejected |
| AST transformation | Safer for Ecto calls than regex | More machinery; raw SQL still semantic string work | Not needed for static `chimeway`/public scope |
| Separate prefixed/public template trees | Literal output is easy to inspect | 62 templates and high drift risk | Rejected |
| `@schema_prefix` | First-class Ecto schema feature | Runtime schema metadata, not migration DDL, and does not qualify raw SQL | Rejected for Phase 74 |
| `mix ecto.migrate --prefix` | Official host operation | Requires special commands, affects migrator expectations, does not create schema or qualify raw SQL | Rejected for generated default |

Decision: hand-edit the 31 templates once, use local helpers for Ecto migration
objects and raw SQL qualification, create schema in the first generated prefixed
migration, and avoid destructive schema drops.

### Verification Strategy

Options considered:

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| Separate golden fixtures for prefixed and public modes | Clear, reviewable proof per user path | More fixture files and refresh work | Chosen |
| One golden tree with mode markers | Lower fixture volume | Can hide real generated output and prefix regressions | Rejected |
| Static generation contracts | Fast raw SQL/bare table guard | Does not prove full output or DB migration behavior | Companion guard |
| Real DB migration contract | Proves schema creation, references, indexes, raw SQL, and rollback in Postgres | Slower and needs cleanup discipline | Chosen, path-gated |
| CLI subprocess plus CI integration | Tests real Mix task and local/CI parity | Subprocess cost | Chosen as wrapper |

Decision: dual golden trees, dual idempotency, real CLI subprocess tests, static
bare-reference guards, real prefixed Postgres migration contract, retained
public legacy migration contract, and scoped CI entrypoints.

## External Research

- Ecto migration docs: table/index/reference helpers support prefixes; raw
  `execute` SQL must be authored as SQL.
  Source: https://hexdocs.pm/ecto_sql/Ecto.Migration.html
- Ecto migrate/migrator docs: migrator prefix support exists, but Phase 74 should
  avoid requiring special migrate commands for copied Chimeway migrations.
  Sources: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html,
  https://hexdocs.pm/ecto_sql/Ecto.Migrator.html
- Phoenix generator docs: generators commonly expose explicit flags for output
  shape, including prefix-oriented options.
  Source: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Schema.html
- Oban migration docs: Oban treats job-table prefix as an explicit migration
  option; Chimeway should keep that separate from Chimeway table prefix.
  Source: https://hexdocs.pm/oban/Oban.Migration.html
- PostgreSQL docs: schema creation/drop behavior should be explicit; avoid
  destructive `DROP SCHEMA ... CASCADE` for host apps.
  Sources: https://www.postgresql.org/docs/current/sql-createschema.html,
  https://www.postgresql.org/docs/current/sql-dropschema.html
- Rails engines and Laravel packages show that published/copied host migrations
  work best when generated artifacts are visible, timestamped, and reviewable.
  Sources: https://guides.rubyonrails.org/engines.html,
  https://laravel.com/docs/packages
- AshPostgres migration generation shows the value of generated artifacts plus
  checks/snapshots for schema evolution.
  Source: https://hexdocs.pm/ash_postgres/migrations-and-tasks.html

## Prompt/Lens Inputs Applied

- `prompts/chimeway-engineering-dna-from-prior-libs.md`: golden installer tests,
  explicit OSS library APIs, stable verification entrypoints, no opaque macros.
- `prompts/chimeway-testing-and-e2e-strategy.md`: golden installer plus
  idempotent second run, real Postgres integration when DB-heavy paths change.
- `prompts/chimeway-host-app-integration-seam.md`: host owns Repo and operational
  choices; Chimeway owns its migrations and storage conventions.
- `prompts/chimeway-release-engineering-and-ci.md`: local/CI parity and named
  entrypoints for non-trivial gates.
- `prompts/elixir_notifykit_research_brief.md`: embedded, local-first,
  explainable notification infrastructure; avoid hidden framework magic.
- Shared prior-art research: Ecto, OSS library DX, and CI/CD guidance from
  `/Users/jon/projects/rulestead/prompts/`.
