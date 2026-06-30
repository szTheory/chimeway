# Postgres Schema Isolation Decision

**Date:** 2026-06-30  
**Decision status:** recommended follow-on milestone, not implemented in this audit  
**Scope:** static Chimeway storage prefix/schema support for Chimeway-owned tables

## Decision

Implement a dedicated Postgres schema/prefix for Chimeway-owned tables. The preferred new-install default should be schema `chimeway`. Existing public-schema installs must remain supported through an explicit legacy/public mode and must not be silently migrated.

Do **not** build dynamic per-tenant prefixes in the same milestone. Chimeway already has tenant IDs in the domain model; dynamic DB prefixes would require job args, Oban prefix propagation, uniqueness changes, and many new failure modes.

## Current Support State

Chimeway is effectively public-schema only today:

- Docs teach `mix chimeway.gen.migrations` followed by `mix ecto.migrate`, with no prefix guidance.
- `priv/chimeway_migrations` contains 31 migration templates.
- `test/chimeway/migration_contract_test.exs` checks `public`.
- Runtime prefix awareness exists only in limited read surfaces, such as top-level trace/admin queries.
- Write paths use many bare `Repo.*` calls and some string-source `insert_all` calls.
- Raw SQL in migrations references unqualified table names.
- Oban integration docs omit prefix guidance, and Oban has a separate prefix configuration.

## Why This Is Worth Doing

Pros:
- Keeps host app schema clean.
- Makes Chimeway tables easier to inspect, grant, dump, back up, and reason about.
- Matches the library's local-first/host-respect philosophy.
- Reduces collision risk with host tables and future ecosystem packages.
- Improves DDD cleanliness: Chimeway's durable lifecycle spine is visibly separate from host domain tables.

Cons:
- Significant migration/generator/test/doc blast radius.
- Existing users on public need compatibility and an opt-in move guide.
- Raw SQL migrations need careful qualification.
- Oban prefix is separate and can be misconfigured.
- Ecto prefix semantics can confuse users if docs mix `mix ecto.migrate --prefix` with generated host migrations.

Tradeoff decision:
- For copied host migrations, prefer **generated explicit table/index/reference prefixes** over requiring users to run `mix ecto.migrate --prefix chimeway`.
- Keep the host app's normal `schema_migrations` flow unless there is a specific reason to move migration tracking. This is simpler for copied migrations and easier for existing Phoenix apps.

## External/Ecosystem Evidence

- Ecto supports query/schema/repo operation prefixes and migration table/index prefixes.
- Ecto SQL migration tasks support prefixes, but copied library migrations can also explicitly set `prefix:` on `table`, `index`, and `references`.
- Oban explicitly supports a `:prefix` option and requires `oban_jobs` to exist in that prefix. Oban testing also defaults to public unless a prefix is supplied.

Relevant official docs:
- Ecto schema/query prefixes: https://hexdocs.pm/ecto/
- Ecto SQL migrations: https://hexdocs.pm/ecto_sql/
- Oban migration prefix support: https://hexdocs.pm/oban/Oban.Migrations.html

## Recommended Public Interface

Configuration:

```elixir
config :chimeway,
  repo: MyApp.Repo,
  prefix: "chimeway"
```

Legacy/public mode:

```elixir
config :chimeway,
  repo: MyApp.Repo,
  prefix: false
```

Rules:
- `prefix: "chimeway"` is the new generated-install default.
- `prefix: false` means unprefixed/public legacy behavior.
- Do not accept runtime functions or per-request prefixes in this milestone.
- Runtime APIs may still accept explicit `prefix:` only for test/admin/debug surfaces, but the default path must come from one validated config source.

Installer:

```bash
mix chimeway.gen.migrations
mix chimeway.gen.migrations --prefix public
mix chimeway.gen.migrations --prefix chimeway
```

Generator behavior:
- Default prefix: `chimeway`.
- `--prefix public` or `--prefix false` generates legacy unprefixed migrations.
- Generated migrations embed a concrete `@chimeway_prefix` value so host migrations are deterministic.
- First generated migration creates schema when prefix is not false:

```elixir
execute("CREATE SCHEMA IF NOT EXISTS chimeway")
```

Migration template behavior:
- Every Chimeway `create table`, `alter table`, `create index`, `drop index`, and `references` call must include the generated prefix helper.
- Raw SQL must qualify Chimeway table/index names with the generated prefix.
- Oban migrations are still not bundled; Oban prefix is documented separately.

Runtime helper:

```elixir
Chimeway.Config.repo_opts(opts)
# returns [prefix: "chimeway"] unless caller/config selected legacy false
```

All internal `Repo.*` and `Oban.Testing` calls should use this helper or a context-specific equivalent rather than manually threading keyword options everywhere.

## Implementation Blast Radius

Core write/read paths:
- Trigger
- Deliveries
- DeliveryPlanning
- Workflows
- Digests
- Policy/settings/preferences
- Inbox
- Signal
- Webhooks
- Dispatch/Oban workers
- Admin and trace read models

Migration/install paths:
- 31 files under `priv/chimeway_migrations`.
- Timestamped dev migrations under `priv/repo/migrations`.
- Installer generator and Mix task.
- Golden fixture tree.
- Migration contract tests.

Docs:
- README.
- Installation.
- Golden Path.
- Oban integration.
- Admin/inbox integration docs.
- Troubleshooting/upgrade docs.

CI/tests:
- Root migration contract.
- Installer golden/idempotency.
- New prefixed integration suite.
- Demo host configured to use `prefix: "chimeway"`.
- Optional legacy/public test lane for backward compatibility.

## Migration / Upgrade Strategy

New installs:
1. Generate migrations with default prefix `chimeway`.
2. Host runs normal `mix ecto.migrate`.
3. Host config includes `config :chimeway, prefix: "chimeway"`.
4. If using Oban with Chimeway jobs, host separately decides whether Oban jobs live in `public`, `oban`, or `chimeway`; docs must be explicit.

Existing public installs:
1. No silent migration.
2. Existing installs keep `prefix: false`.
3. Provide optional manual move guide:
   - stop Chimeway writes/workers
   - create `chimeway` schema
   - move all `public.chimeway_*` tables and indexes
   - update runtime config
   - verify with read-only trace/inbox/admin checks
   - restart workers
4. Do not auto-move `schema_migrations`; copied host migrations remain host migration history.

Rollback:
- If a new install has no production data, drop schema and regenerate public migrations.
- If production data was moved, rollback is manual and should be treated as a DB operation, not a Mix task.

## Required Tests

Prefix install tests:
- Generator default emits prefixed migrations.
- Generator explicit public emits legacy migrations.
- Golden fixture for prefixed output.
- Raw SQL migrations qualify Chimeway objects.

Runtime integration tests:
- prefixed trigger -> event -> notification -> delivery -> attempt
- prefixed duplicate idempotency
- prefixed trace lookup/explain
- prefixed inbox list/read/seen
- prefixed workflow progression
- prefixed digest bucket/flush
- prefixed webhook ingress/worker
- prefixed recovery event/delivery
- prefixed admin read models

Compatibility tests:
- public/legacy mode still works.
- prefix config missing or invalid fails early with actionable error.
- Oban.Testing prefix is set in prefixed tests.

Docs/contracts:
- README and install docs require prefix section.
- Oban guide explicitly states Oban prefix is separate.
- Golden Path shows default schema `chimeway`.
- Upgrade guide explains public legacy mode.

## Top Footguns

1. Raw SQL does not automatically inherit Ecto table prefixes.
2. Oban prefix is separate from Chimeway table prefix.
3. Top-level prefix-aware queries can still leak to public through helper queries.
4. `insert_all` with string table names needs explicit prefix coverage.
5. Using `@schema_prefix` alone can make public opt-out surprising.
6. Running `mix ecto.migrate --prefix chimeway` changes migration tracking expectations; generated explicit prefixes are simpler for copied host migrations.
7. Dynamic prefixes would require worker/job prefix state and should not be included.
8. Existing users need a compatibility story before the default flips.

## Recommendation for GSD Sequencing

Make this its own milestone after the audit:

1. Prefix config and repo option infrastructure.
2. Migration generator/templates/golden fixtures.
3. Runtime write/read path propagation.
4. Prefixed integration suite and demo host.
5. Docs/upgrade guide/Oban guidance.

Do not bundle CI optimization or README rewrite into the same implementation milestone unless they directly protect this storage change.

