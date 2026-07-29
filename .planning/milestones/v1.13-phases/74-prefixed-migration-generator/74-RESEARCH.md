# Phase 74: Prefixed Migration Generator - Research

**Researched:** 2026-06-30  
**Domain:** Elixir/Ecto copied migration generation with PostgreSQL schema prefixes  
**Confidence:** HIGH

## User Constraints (from CONTEXT.md)

The phase boundary, locked decisions, discretion note, and deferred ideas in this section are copied from `74-CONTEXT.md`. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

### Phase Boundary

Phase 74 changes only Chimeway's copied host migration generator and its
generation-time proof. It covers MIG-01, MIG-02, MIG-03, and MIG-04: default
generation for the dedicated `chimeway` Postgres schema, explicit public legacy
generation, deterministic copied host migrations, schema creation, qualified
Ecto migration operations, qualified raw SQL, golden/idempotency proof, and
migration contract proof. It should not thread runtime prefix options through
trigger, delivery, workflow, inbox, admin, webhook, worker, or trace paths; that
is Phase 75. It should not add a production data move task, dynamic per-tenant
database prefixes, Oban prefix coupling, demo-host proof, or full upgrade docs;
those are Phase 76 or future scope.

### Locked Decisions

#### Generator Interface and DX

- **D-01:** `mix chimeway.gen.migrations` defaults to deterministic generated
  migrations for the `chimeway` schema.
- **D-02:** The canonical explicit CLI is `mix chimeway.gen.migrations --prefix
  chimeway` or `mix chimeway.gen.migrations --prefix public`.
- **D-03:** `--prefix public` is generator-only compatibility sugar. It means
  "generate legacy unprefixed/public-schema migrations"; runtime docs and config
  must still teach `config :chimeway, prefix: false`.
- **D-04:** Do not derive generated output from runtime application config.
  Generation should be reproducible from the command arguments, not from
  environment-specific `config :chimeway` values.
- **D-05:** Option parsing should be strict and fail with actionable errors for
  unsupported flags or unsupported prefix values. If planners add
  `--legacy-public`, treat it only as an alias for `--prefix public`, not as a
  second conceptual mode.

#### Generated Migration Shape

- **D-06:** Keep one canonical migration template tree under
  `priv/chimeway_migrations/`. Do not maintain separate prefixed and public
  template trees, because duplicated templates would drift.
- **D-07:** Hand-edit the canonical templates to use small local migration
  helpers for Chimeway-owned `table`, `index`, `unique_index`, `references`,
  `alter`, `drop`, and raw SQL relation references. Avoid broad ad hoc string
  rewrites as the main prefixing strategy.
- **D-08:** Generated default migrations should make the selected prefix visible
  in each host migration, for example with a concrete `@chimeway_prefix
  "chimeway"` and helper functions. Public generation must not pass
  `prefix: false` to Ecto; its helpers should emit unprefixed Ecto operations.
- **D-09:** The first generated prefixed migration must create the schema with
  `CREATE SCHEMA IF NOT EXISTS chimeway` before creating Chimeway tables.
- **D-10:** Generated migrations must explicitly qualify Chimeway table,
  reference, index, alter, drop, and raw SQL operations. Do not require adopters
  to run `mix ecto.migrate --prefix chimeway`.
- **D-11:** Raw SQL in migrations such as attempt-history backfills, workflow
  signal-spine updates, and tenant/actor backfills must qualify Chimeway table
  names through a small helper or literal safe qualified names. Public
  generation keeps bare relation names.
- **D-12:** Rollback should reverse Chimeway tables, indexes, references, and
  columns where practical, but avoid destructive `DROP SCHEMA ... CASCADE`.
  Schema cleanup should be manual or `RESTRICT`-only if implementation proves it
  cannot remove host-owned objects.
- **D-13:** Do not use `@schema_prefix`, runtime schema metadata, process state,
  or `mix ecto.migrate --prefix` as the primary Phase 74 mechanism. Those are
  runtime or host-operation concerns and do not qualify raw SQL.

#### Verification Strategy

- **D-14:** Add separate committed golden fixture trees for the two user-visible
  generation modes: default prefixed and explicit public legacy.
- **D-15:** Shared installer fixture helpers should run the real
  `mix chimeway.gen.migrations` subprocess for both modes so OptionParser,
  app.config, host repo inference/config, stdout, timestamps, and generated tree
  shape are tested together.
- **D-16:** Idempotency tests must cover both modes: a second run should create
  no files and emit only unchanged lines for the existing slugs.
- **D-17:** Add focused static contracts that scan generated prefixed output for
  missed bare Chimeway table references in Ecto operations and raw SQL. These
  are companion guards, not a replacement for golden or DB migration proof.
- **D-18:** Add a real Postgres migration contract for generated default
  migrations. It should run the generated migrations through the normal migrate
  path without `mix ecto.migrate --prefix chimeway`, then verify objects in the
  `chimeway` schema, important indexes/references/columns, raw SQL effects where
  practical, and practical rollback behavior.
- **D-19:** Preserve existing public-schema migration contract assertions as
  explicit legacy compatibility proof. Public-mode generation should continue to
  prove unprefixed DB behavior instead of becoming an accidental default.
- **D-20:** Keep installer verification path-gated or otherwise scoped in CI
  because subprocess generation and DB migration proof are heavier than ordinary
  unit tests. Local and CI entrypoints should remain named and in parity.

#### Lessons Applied

- **D-21:** Follow Elixir/Phoenix generator norms: make the happy path short,
  expose explicit flags for output shape, and keep generated artifacts ordinary
  host files that can be reviewed and committed.
- **D-22:** Follow Ecto/Postgres semantics directly: Ecto can prefix migration
  table/index/reference helpers, but raw SQL is just SQL and must be authored
  with qualified relation names.
- **D-23:** Learn from Rails and Laravel package ecosystems: copied/published
  host migrations are understandable when they are deterministic, timestamped,
  and reviewable; they become painful when generated state is hidden or
  regenerated output drifts silently.
- **D-24:** Learn from Oban: Chimeway's table schema and Oban's job-table prefix
  are separate concerns. Phase 74 should not couple them.
- **D-25:** Learn from Chimeway sibling repos: installer golden-diff tests are
  product surface, not polish. If migrations are generated, the generated tree
  and stdout should be contract tested.

### the agent's Discretion

Downstream agents should choose the smallest implementation that preserves this
architecture: explicit CLI modes, one canonical prefix-aware template tree, no
runtime config derivation, no `ecto.migrate --prefix` requirement, and dual-mode
proof. If implementation details collide, prefer reviewable generated host
migrations and deterministic tests over clever generator internals.

### Deferred Ideas (OUT OF SCOPE)

- Runtime prefix propagation across trigger, deliveries, attempts, workflows,
  digests, policy/preferences, inbox, signals, webhooks, dispatch workers,
  traces, admin, recovery, and string-source `insert_all` calls - Phase 75.
- Demo host running against the default `chimeway` schema and proving
  trigger-to-trace - Phase 76.
- Oban prefix guidance and examples showing that Oban's prefix is separate from
  Chimeway's table prefix - Phase 76.
- Manual public-to-`chimeway` move guide, rollback/failure-mode docs, and release
  gate/doc contract coverage - Phase 76.
- Dynamic per-tenant database prefixes and first-party automated production data
  move task - future requirements, out of v1.13 scope.

### Reviewed Todos (not folded)

None.

## Project Constraints (from AGENTS.md)

- Chimeway is an open-source embedded notification layer for Elixir and Phoenix apps; host applications own their data, policies, and delivery history. [VERIFIED: AGENTS.md]
- Every notification decision must remain explainable. [VERIFIED: AGENTS.md]
- The project stack is Elixir 1.17+/OTP 26+, Ecto 3.x/PostgreSQL 15+, optional Phoenix 1.7/1.8, optional Oban 2.x, and Swoosh 1.x email adapter seams. [VERIFIED: AGENTS.md]
- Durable identity must use stable `notification_key` plus version, not module names. [VERIFIED: AGENTS.md]
- The durable lifecycle spine is `event -> notification -> delivery -> attempt`. [VERIFIED: AGENTS.md]
- Idempotency and suppression reasons must stay first-class product behavior. [VERIFIED: AGENTS.md]
- Adapters must remain replaceable through explicit behaviours and contract tests. [VERIFIED: AGENTS.md]
- Host ownership boundaries for auth, tenancy, URL generation, and correlation IDs must be preserved. [VERIFIED: AGENTS.md]
- Named `mix verify.*` and `mix ci.*` entrypoints must be provided and kept in CI/local parity. [VERIFIED: AGENTS.md]
- Sensitive payload fields must not leak into telemetry or operator surfaces. [VERIFIED: AGENTS.md]

No project-local `.claude/skills/` or `.agents/skills/` skill files were found for this phase. [VERIFIED: `find .claude/skills .agents/skills -name SKILL.md`]

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MIG-01 | `mix chimeway.gen.migrations` defaults to generating migrations for a dedicated `chimeway` schema. | Parse `--prefix` strictly in the Mix task, default missing `--prefix` to generator mode `:chimeway`, and pass that mode into `Chimeway.Install.Migrations.run/1`; do not read runtime `config :chimeway, :prefix`. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| MIG-02 | Generated prefixed migrations create the schema when needed and apply explicit prefixes to Chimeway tables, indexes, references, alters, drops, and raw SQL. | Ecto migrations support table and index prefixes, references inside a prefixed table default to that table prefix, indexes still need the same prefix, and `execute/1` is arbitrary SQL that must be qualified manually. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html] |
| MIG-03 | The installer supports explicit public/legacy generation and emits unprefixed migrations for existing public-schema users. | `--prefix public` should normalize to generator mode `:public`; generated helper functions should omit `:prefix` options rather than passing `prefix: false` to Ecto. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| MIG-04 | Golden fixture, idempotency, and migration contract tests prove prefixed and public generation are deterministic and reversible where practical. | Existing installer fixture already runs the real subprocess, normalizes stdout/tree output, and supports golden/idempotency tests; extend it to two modes and add prefixed DB/static contracts. [VERIFIED: test/support/installer_fixture.ex] [VERIFIED: test/chimeway/install/golden_diff_test.exs] [VERIFIED: test/chimeway/install/idempotency_test.exs] |

## Summary

Phase 74 should change the copy-based migration installer, not runtime storage behavior: the Mix task should parse strict generator flags, the installer core should render one canonical template tree in either `:chimeway` or `:public` mode, and generated files should remain ordinary host migrations under `priv/repo/migrations`. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] [VERIFIED: lib/mix/tasks/chimeway.gen.migrations.ex] [VERIFIED: lib/chimeway/install/migrations.ex]

The safest implementation is small, explicit, and test-led: add a `:prefix` generation option to `Chimeway.Install.Migrations.run/1`, default it to `"chimeway"` only at the generator interface, hand-edit the 31 templates to call local helpers, and substitute only narrow mode sentinels such as the module attribute value. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] [VERIFIED: `find priv/chimeway_migrations -name '*.exs'`]

Verification needs two committed golden fixture trees plus database proof. Current local focused installer tests pass, but local PostgreSQL is 14.17 while the project baseline and CI service are PostgreSQL 15, so the planner should keep Postgres 15 CI proof as authoritative for migration contract behavior. [VERIFIED: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors`] [VERIFIED: `psql --version`] [VERIFIED: .github/workflows/ci.yml]

**Primary recommendation:** extend the existing Mix task, installer core, canonical templates, installer fixture, golden/idempotency tests, migration contract, and path-gated CI job; do not introduce new dependencies, runtime prefix derivation, duplicate template trees, or a requirement to run `mix ecto.migrate --prefix chimeway`. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| CLI mode selection | Installer / Mix task | OptionParser | `Mix.Tasks.Chimeway.Gen.Migrations.run/1` is the only public installer CLI entrypoint today, and OptionParser strict mode returns parsed args plus invalid switches for actionable errors. [VERIFIED: lib/mix/tasks/chimeway.gen.migrations.ex] [CITED: https://hexdocs.pm/elixir/1.17.3/OptionParser.html] |
| Template discovery and file writing | Installer core | Filesystem | `Chimeway.Install.Migrations` already owns template ordering, slug idempotency, namespace rewriting, timestamping, and host repo resolution. [VERIFIED: lib/chimeway/install/migrations.ex] |
| Prefix-aware migration operations | Generated host migrations | Ecto SQL | Ecto migration helpers support prefixes for tables and indexes; generated host files must carry the selected prefix because host users run normal migrations. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Schema creation and rollback cleanup | PostgreSQL database | Generated host migrations | PostgreSQL schemas are namespaces; generated prefixed migrations need `CREATE SCHEMA IF NOT EXISTS chimeway`, and rollback must avoid `DROP SCHEMA ... CASCADE`. [CITED: https://www.postgresql.org/docs/15/sql-createschema.html] [CITED: https://www.postgresql.org/docs/15/sql-dropschema.html] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Raw SQL qualification | Generated host migrations | PostgreSQL SQL | Ecto `execute/1` runs arbitrary SQL, so helper-prefixed Ecto operations do not affect raw SQL strings. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html] |
| Golden and idempotency proof | ExUnit installer tests | Subprocess host fixture | `Chimeway.Test.InstallerFixture.run_install!/2` already executes `mix chimeway.gen.migrations` in a throwaway host app with normalized stdout and migration tree snapshots. [VERIFIED: test/support/installer_fixture.ex] |
| Migration contract proof | ExUnit + PostgreSQL | CI service database | `Chimeway.MigrationContractTest` already proves public-schema compatibility; Phase 74 should add generated prefixed proof against PostgreSQL without relying on `mix ecto.migrate --prefix`. [VERIFIED: test/chimeway/migration_contract_test.exs] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix / OTP | Project baseline Elixir 1.17+ / OTP 26+; local toolchain Elixir 1.19.5 / OTP 28 | Mix task, OptionParser, System subprocess tests, ExUnit | Existing project stack and local runtime; no language/tooling change is needed. [VERIFIED: AGENTS.md] [VERIFIED: `elixir --version`] [VERIFIED: `mix --version`] |
| Ecto SQL | Locked 3.13.5; Hex latest 3.14.0 released 2026-05-19 | Migration DSL, `mix ecto.migrate`, SQL adapter integration | Existing dependency; official docs define prefix behavior for migration helpers and `--prefix` runner option. [VERIFIED: `mix deps`] [VERIFIED: `mix hex.info ecto_sql`] [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html] |
| Ecto | Locked 3.13.6; Hex latest 3.14.0 released 2026-05-19 | Core repo/query dependency used by Ecto SQL | Existing dependency via `ecto_sql`; no upgrade is required for Phase 74. [VERIFIED: `mix deps`] [VERIFIED: `mix hex.info ecto`] |
| Postgrex | Locked 0.22.2; released 2026-05-12 | PostgreSQL driver for migration contract tests | Existing dependency and driver for `Chimeway.Repo`. [VERIFIED: `mix deps`] [VERIFIED: `mix hex.info postgrex`] |
| PostgreSQL | Project baseline 15+; local psql/server 14.17; CI service image `postgres:15` | Schema namespace, migration contract database | CI already uses PostgreSQL 15; local 14.17 is acceptable for quick smoke but below the project baseline. [VERIFIED: AGENTS.md] [VERIFIED: `psql --version`] [VERIFIED: .github/workflows/ci.yml] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Oban | Locked 2.23.0; released 2026-05-27 | Optional async dispatch package outside generated Chimeway migrations | Do not change in Phase 74; Chimeway schema prefix and Oban job-table prefix are separate concerns. [VERIFIED: `mix deps`] [VERIFIED: `mix hex.info oban`] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| ExUnit | Bundled with Elixir 1.17+ | Golden, idempotency, static, and migration contract tests | Existing test framework; no new test library is needed. [VERIFIED: mix.exs] [VERIFIED: test/chimeway/install/golden_diff_test.exs] |
| GitHub Actions | Existing `.github/workflows/ci.yml` | Path-gated installer verification | Extend the existing `install_golden_contract` path gate rather than adding a parallel CI pattern. [VERIFIED: .github/workflows/ci.yml] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| One canonical template tree with helper calls | Separate `priv/chimeway_migrations_prefixed/` and public template trees | Rejected by locked decision D-06 because duplicate templates would drift. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Narrow mode substitution plus helper calls | Broad string rewrite of generated files | Rejected by D-07 because raw text rewrites are brittle around SQL, atoms, comments, and helper edge cases. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Explicit generated prefixes | Tell users to run `mix ecto.migrate --prefix chimeway` | Rejected by MIG-02 and D-10; `--prefix` is a migration-runner option, but Phase 74 must generate normal host migrations that qualify their own operations. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Mix.Tasks.Ecto.Migrate.html] |
| Generator CLI `--prefix public` | Runtime config `prefix: "public"` | Rejected by Phase 73 and Phase 74 context; runtime public compatibility is `prefix: false`, while generator public mode emits unprefixed files. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| New SQL parser dependency | Whitelisted raw SQL helper and static grep/AST guards | No new package is needed; the raw SQL sites are limited to three current templates and known Chimeway relation names. [VERIFIED: `rg -n "execute\\(" priv/chimeway_migrations`] |

**Installation:**

No new external packages should be installed for Phase 74. [VERIFIED: mix.exs]

```bash
mix deps.get
```

**Version verification:** Existing package versions were verified with `mix deps` and `mix hex.info`; Phase 74 should stay on the locked dependency set unless a separate dependency-upgrade phase is opened. [VERIFIED: `mix deps`] [VERIFIED: `mix hex.info ecto_sql`] [VERIFIED: `mix hex.info ecto`] [VERIFIED: `mix hex.info postgrex`]

## Package Legitimacy Audit

Phase 74 should install no new external packages, so the Package Legitimacy Gate is not applicable to implementation. [VERIFIED: mix.exs] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| None | - | - | - | - | - | No new package install recommended. [VERIFIED: mix.exs] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: no package recommendations]  
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: no package recommendations]

## Codebase Findings

### Current Installer Shape

- `Mix.Tasks.Chimeway.Gen.Migrations.run/1` currently calls `Mix.Task.run("app.config")`, parses with `OptionParser.parse(argv, strict: [])`, rejects all args, and delegates to `Chimeway.Install.Migrations.run([])`. [VERIFIED: lib/mix/tasks/chimeway.gen.migrations.ex]
- `Chimeway.Install.Migrations.run/1` resolves the host repo, computes the host migration namespace, creates `priv/repo/migrations`, copies 31 templates, rewrites only the namespace, timestamps each file, and emits `created` or `unchanged` lines. [VERIFIED: lib/chimeway/install/migrations.ex]
- `Chimeway.Install.Migrations.find_existing_by_slug/2` performs slug-based idempotency and raises on duplicate slug files. [VERIFIED: lib/chimeway/install/migrations.ex] [VERIFIED: test/chimeway/install/migrations_test.exs]
- The canonical template tree contains 31 files under `priv/chimeway_migrations/`, and the current installer excludes Oban migrations. [VERIFIED: `find priv/chimeway_migrations -name '*.exs'`] [VERIFIED: test/chimeway/install/migrations_test.exs]

### Prefix-Sensitive Template Audit

- Most templates use bare `table(:chimeway_*)`, `alter table(:chimeway_*)`, `index(:chimeway_*)`, `unique_index(:chimeway_*)`, and `references(:chimeway_*)` calls today. [VERIFIED: `rg -n "table|index|references|alter" priv/chimeway_migrations`]
- Current raw SQL appears in `009_add_attempt_history_columns.exs`, `027_create_chimeway_signals_and_spine.exs`, and `030_add_tenant_and_actor_to_chimeway_deliveries.exs`. [VERIFIED: `rg -n "execute\\(|UPDATE|FROM" priv/chimeway_migrations`]
- The first migration `001_create_chimeway_events.exs` currently creates `:chimeway_events` and its idempotency index in the default schema. [VERIFIED: priv/chimeway_migrations/001_create_chimeway_events.exs]
- The highest-risk raw SQL backfills currently reference `chimeway_delivery_attempts`, `chimeway_workflow_runs`, `chimeway_deliveries`, and `chimeway_notifications` without a schema qualifier. [VERIFIED: priv/chimeway_migrations/009_add_attempt_history_columns.exs] [VERIFIED: priv/chimeway_migrations/027_create_chimeway_signals_and_spine.exs] [VERIFIED: priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs]

### Current Test and CI Shape

- `test/support/installer_fixture.ex` already scaffolds a throwaway Mix host app, runs `mix deps.get`, compiles, executes `mix chimeway.gen.migrations` via `System.cmd/3`, captures stdout, snapshots generated migrations, normalizes timestamps and temp paths, and writes/loads golden fixtures. [VERIFIED: test/support/installer_fixture.ex]
- Current committed installer golden fixtures live under `test/fixtures/installer_golden/` and contain 31 normalized generated migration files plus `STDOUT.txt`. [VERIFIED: `find test/fixtures/installer_golden/tree/priv/repo/migrations -maxdepth 1 -type f`] [VERIFIED: test/fixtures/installer_golden/STDOUT.txt]
- `test/chimeway/install/golden_diff_test.exs` compares first-run generated output to committed fixtures and supports `MIX_INSTALLER_ACCEPT_GOLDEN=1` refresh. [VERIFIED: test/chimeway/install/golden_diff_test.exs]
- `test/chimeway/install/idempotency_test.exs` proves a second run creates no files and emits 31 `unchanged` lines. [VERIFIED: test/chimeway/install/idempotency_test.exs]
- `test/chimeway/migration_contract_test.exs` currently proves public-schema legacy objects and labels those assertions as public compatibility proof. [VERIFIED: test/chimeway/migration_contract_test.exs]
- `mix ci.install_golden` runs golden and idempotency tests, and `.github/workflows/ci.yml` has a path-gated `install_golden_contract` job for installer-related paths. [VERIFIED: mix.exs] [VERIFIED: .github/workflows/ci.yml]

### Verification Evidence Gathered During Research

- `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` passed 13 tests, 0 failures; optional Threadline background cleanup logged DB sandbox ownership errors but did not fail the suite. [VERIFIED: command output 2026-06-30]
- `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs --warnings-as-errors` passed 2 tests, 0 failures in 44.1 seconds; running concurrently with DB tests caused transient local PostgreSQL connection-limit noise. [VERIFIED: command output 2026-06-30]
- `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/migration_contract_test.exs --warnings-as-errors` passed 3 tests, 0 failures. [VERIFIED: command output 2026-06-30]
- `mix ecto.migrations` shows all current root Chimeway migrations are up locally in public schema, including `create_chimeway_webhook_ingress`. [VERIFIED: `mix ecto.migrations`]

## Architecture Patterns

### System Architecture Diagram

```text
CLI: mix chimeway.gen.migrations [--prefix chimeway|public]
  |
  v
Mix task parses strict options and normalizes generator mode
  |-- invalid flag/value --> Mix.raise with accepted examples
  |
  v
Chimeway.Install.Migrations.run(prefix: :chimeway | :public)
  |
  v
Resolve host repo + host migration namespace
  |
  v
Read one canonical priv/chimeway_migrations template tree
  |
  v
Render narrow mode sentinels only
  |-- :chimeway --> @chimeway_prefix "chimeway" + CREATE SCHEMA helper active
  |-- :public   --> @chimeway_prefix false + helpers omit Ecto :prefix opts
  |
  v
Write priv/repo/migrations/TIMESTAMP_slug.exs by slug idempotency
  |
  v
Generated host runs normal mix ecto.migrate
  |
  v
PostgreSQL objects:
  |-- chimeway mode --> chimeway.chimeway_* tables/indexes/FKs/raw SQL targets
  |-- public mode   --> public/unprefixed legacy chimeway_* objects
```

This flow matches the locked Phase 74 boundary: generation-time choice, reviewable host files, and no runtime config derivation. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

### Recommended Project Structure

```text
lib/
├── mix/tasks/chimeway.gen.migrations.ex       # strict CLI parsing and user-facing errors
└── chimeway/install/migrations.ex             # mode-aware rendering, slug idempotency, host repo resolution

priv/
└── chimeway_migrations/                       # single canonical helper-based template tree

test/
├── support/installer_fixture.ex               # subprocess fixture accepts mode args and golden roots
├── chimeway/install/golden_diff_test.exs       # two-mode golden fixture comparison
├── chimeway/install/idempotency_test.exs       # two-mode second-run contract
├── chimeway/install/prefix_contract_test.exs   # static generated-output guards for bare refs
├── chimeway/migration_contract_test.exs        # public legacy + prefixed generated DB proof
└── fixtures/
    ├── installer_golden_prefixed/              # default chimeway schema fixture
    └── installer_golden_public/                # explicit public legacy fixture
```

The exact fixture directory names may differ, but Phase 74 requires separate committed golden fixture trees for default prefixed and explicit public modes. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

### Pattern 1: Strict Generator Mode Parsing

**What:** Use `OptionParser.parse/2` with `strict: [prefix: :string, legacy_public: :boolean]`, reject all rest/invalid values, and normalize `nil` or `"chimeway"` to `:chimeway` and `"public"` to `:public`. [CITED: https://hexdocs.pm/elixir/1.17.3/OptionParser.html] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

**When to use:** Use in the Mix task before calling installer core so subprocess golden tests cover the real user entrypoint. [VERIFIED: test/support/installer_fixture.ex]

**Example:**

```elixir
# Source: OptionParser strict docs plus Phase 74 D-01..D-05.
defp parse_prefix_mode!(argv) do
  {opts, rest, invalid} =
    OptionParser.parse(argv, strict: [prefix: :string, legacy_public: :boolean])

  cond do
    rest != [] or invalid != [] ->
      Mix.raise("Installation blocked: use --prefix chimeway or --prefix public")

    opts[:legacy_public] ->
      :public

    opts[:prefix] in [nil, "chimeway"] ->
      :chimeway

    opts[:prefix] == "public" ->
      :public

    true ->
      Mix.raise("Installation blocked: unsupported --prefix #{inspect(opts[:prefix])}")
  end
end
```

### Pattern 2: Narrow Template Rendering, Not Broad Rewrites

**What:** Keep namespace rewriting, add mode rendering for explicit sentinels only, and leave table/reference/index/raw SQL qualification to helper calls already present in templates. [VERIFIED: lib/chimeway/install/migrations.ex] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

**When to use:** Use when generating each destination file after `rewrite_namespace/2` and before writing to disk. [VERIFIED: lib/chimeway/install/migrations.ex]

**Example:**

```elixir
# Source: existing Chimeway.Install.Migrations pipeline plus Phase 74 D-06..D-08.
defp render_template(content, host_prefix, mode) do
  content
  |> rewrite_namespace(host_prefix)
  |> String.replace("@chimeway_prefix __CHIMEWAY_PREFIX__", prefix_attribute(mode))
end

defp prefix_attribute(:chimeway), do: ~s(@chimeway_prefix "chimeway")
defp prefix_attribute(:public), do: "@chimeway_prefix false"
```

### Pattern 3: Local Migration Helpers

**What:** Generated migrations should include small local helpers for `table`, `index`, `unique_index`, `references`, and raw relation names so every migration is self-contained and reviewable. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

**When to use:** Use in every canonical template that touches Chimeway-owned tables, indexes, references, alters, drops, or raw SQL. [VERIFIED: `rg -n "table|index|references|execute" priv/chimeway_migrations`]

**Example:**

```elixir
# Source: Ecto.Migration prefix docs plus Phase 74 D-07..D-11.
@chimeway_prefix "chimeway"

defp chimeway_prefix_opts(opts \\ []) do
  case @chimeway_prefix do
    false -> opts
    prefix -> Keyword.put_new(opts, :prefix, prefix)
  end
end

defp chimeway_table(name, opts \\ []) do
  table(name, chimeway_prefix_opts(opts))
end

defp chimeway_index(table_name, columns, opts \\ []) do
  index(table_name, columns, chimeway_prefix_opts(opts))
end

defp chimeway_unique_index(table_name, columns, opts \\ []) do
  unique_index(table_name, columns, chimeway_prefix_opts(opts))
end

defp chimeway_references(table_name, opts \\ []) do
  references(table_name, chimeway_prefix_opts(opts))
end
```

### Pattern 4: Raw SQL Relation Helper

**What:** Raw SQL should qualify only known Chimeway relation names and should emit bare names for public mode. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

**When to use:** Use in the three current raw SQL templates and any future generated migration that calls `execute/1` or `execute/2` with Chimeway-owned relations. [VERIFIED: `rg -n "execute\\(" priv/chimeway_migrations`]

**Example:**

```elixir
# Source: Ecto execute/1 arbitrary SQL docs plus Phase 74 D-11.
@chimeway_relations ~w(
  chimeway_delivery_attempts
  chimeway_deliveries
  chimeway_notifications
  chimeway_workflow_runs
)

defp chimeway_relation(name) when name in @chimeway_relations do
  case @chimeway_prefix do
    false -> name
    "chimeway" -> ~s("chimeway".#{name})
  end
end
```

The helper should not accept arbitrary user input; Phase 74 only supports the fixed generator prefixes `chimeway` and public compatibility. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

### Anti-Patterns to Avoid

- **Runtime config derivation:** Do not read `Application.fetch_env(:chimeway, :prefix)` while generating files because Phase 74 locks reproducibility to CLI arguments. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]
- **`prefix: false` in Ecto calls:** Public generated helpers should omit `:prefix`, not pass `prefix: false`, because public mode means unprefixed Ecto operations. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]
- **Raw SQL left bare in prefixed mode:** Ecto helper prefixes do not rewrite SQL inside `execute/1`. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html]
- **`DROP SCHEMA ... CASCADE`:** PostgreSQL warns that `CASCADE` can remove dependent objects beyond the named schema, and the phase context forbids destructive cleanup. [CITED: https://www.postgresql.org/docs/15/sql-dropschema.html] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]
- **Duplicate template trees:** Separate prefixed/public template directories would create drift and violate D-06. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CLI parsing | Custom argv parser | `OptionParser.parse/2` with strict options | Official OptionParser strict mode returns invalid unknown switches and bad types, which supports actionable Mix errors. [CITED: https://hexdocs.pm/elixir/1.17.3/OptionParser.html] |
| Migration prefixing | Broad string rewrite over generated files | Ecto `table/index/references` `:prefix` options via local helpers | Ecto's migration DSL already supports PostgreSQL schema prefixes; string rewrites can miss SQL, comments, atoms, or names. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html] |
| Raw SQL parsing | General SQL parser or unbounded identifier quoting | Whitelisted relation helper for known Chimeway table names | The current raw SQL surface is limited to three templates and fixed Chimeway relations. [VERIFIED: `rg -n "execute\\(" priv/chimeway_migrations`] |
| Public compatibility | Runtime `"public"` prefix mode | Generator `--prefix public` emits bare operations; runtime remains `prefix: false` | Phase 73 and Phase 74 separate generator compatibility sugar from runtime config. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Schema rollback | `DROP SCHEMA ... CASCADE` | Omit generated schema-drop SQL and verify rollback of Chimeway-owned objects in the DB contract | `CASCADE` may remove dependent objects, and Phase 74 does not need generated schema cleanup to prove table/index/reference rollback. [CITED: https://www.postgresql.org/docs/15/sql-dropschema.html] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-10-PLAN.md] |

**Key insight:** Ecto solves migration helper prefixing, but it cannot solve raw SQL qualification or generation-mode determinism; those must be authored into the copied templates and proved in generated output. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

## Runtime State Inventory

Phase 74 is a migration-generation phase, but it must not move existing production data or thread runtime prefix options. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | Local `chimeway_test` currently has all existing Chimeway migrations up in public schema. [VERIFIED: `mix ecto.migrations`] | Do not migrate or move this data as Phase 74 implementation; use isolated test DBs/schemas or throwaway host fixtures for prefixed proof. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Live service config | GitHub Actions has a path-gated `install_golden_contract` job and CI Postgres service config. [VERIFIED: .github/workflows/ci.yml] | Extend the existing path gate and named alias in parity; no external service UI config was found in repo. [VERIFIED: .github/workflows/ci.yml] |
| OS-registered state | None found or required for copied migration generation. [VERIFIED: phase scope and repo scan] | No OS registration task is required. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Secrets/env vars | Test database selection uses `DATABASE_URL`, `PGUSER`, `PGPASSWORD`, `PGHOST`, and related Postgres env vars; installer golden fixture subprocess sets `MIX_ENV=dev`. [VERIFIED: config/test.exs] [VERIFIED: test/support/installer_fixture.ex] | Keep tests deterministic by passing explicit env vars and avoiding dependence on runtime `config :chimeway, :prefix`. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Build artifacts | Existing `_build`/deps caches and committed `test/fixtures/installer_golden/` reflect current public generation. [VERIFIED: git status] [VERIFIED: test/fixtures/installer_golden/STDOUT.txt] | Add/refresh committed dual golden fixture directories; do not rely on stale generated host files outside fixtures. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |

## Common Pitfalls

### Pitfall 1: Prefixing Tables But Not Indexes

**What goes wrong:** Generated tables are created under `chimeway`, but indexes are attempted against the default schema or fail to attach to the intended table. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html]  
**Why it happens:** Ecto documents that prefixed tables require the same prefix for indexes. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html]  
**How to avoid:** Route both `index/3` and `unique_index/3` through prefix helpers. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]  
**Warning signs:** Static generated-output scan finds `index(:chimeway_` or `unique_index(:chimeway_` outside a helper call. [VERIFIED: test plan derived from D-17]

### Pitfall 2: Raw SQL Ignores Ecto Prefix Helpers

**What goes wrong:** The migration creates prefixed tables but backfill SQL updates `public.chimeway_*` or errors because bare relation names resolve through `search_path`. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html]  
**Why it happens:** `execute/1` executes arbitrary SQL and does not inspect relation names. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html]  
**How to avoid:** Use `chimeway_relation/1` or literal safe qualified names in `009`, `027`, and `030`. [VERIFIED: `rg -n "execute\\(" priv/chimeway_migrations`]  
**Warning signs:** Prefixed generated output contains `FROM chimeway_`, `UPDATE chimeway_`, or `ALTER TABLE chimeway_` without a preceding `chimeway.` or `"chimeway".` qualifier. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

### Pitfall 3: Making Public Mode a Runtime Prefix

**What goes wrong:** `--prefix public` leaks into generated Ecto calls as `prefix: false` or runtime docs as `prefix: "public"`. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]  
**Why it happens:** Generator CLI compatibility sugar and runtime storage config are easy to conflate. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]  
**How to avoid:** Normalize generator mode to `:public`, render helper no-ops, and keep docs/config wording as `prefix: false` for runtime public legacy. [VERIFIED: README.md] [VERIFIED: guides/introduction/installation.md]  
**Warning signs:** Generated public fixtures contain `prefix: false`, `prefix: "public"`, or `@chimeway_prefix "public"`. [VERIFIED: D-08/D-03 from context]

### Pitfall 4: Accidentally Requiring `mix ecto.migrate --prefix`

**What goes wrong:** Adopters must run a special migration command to get Chimeway objects under the `chimeway` schema. [VERIFIED: .planning/REQUIREMENTS.md]  
**Why it happens:** Ecto exposes a `--prefix` option on `mix ecto.migrate`, but Phase 74 requires generated host files to carry explicit prefixes instead. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Mix.Tasks.Ecto.Migrate.html] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]  
**How to avoid:** In the prefixed DB contract, run generated migrations through the normal migration path without `--prefix chimeway`. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]  
**Warning signs:** Tests pass only when the command includes `--prefix chimeway`. [VERIFIED: .planning/REQUIREMENTS.md]

### Pitfall 5: Rollback Drops Host-Owned Objects

**What goes wrong:** A rollback removes a host-owned object placed in the `chimeway` schema. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]  
**Why it happens:** `DROP SCHEMA ... CASCADE` removes objects contained in the schema and dependent objects. [CITED: https://www.postgresql.org/docs/15/sql-dropschema.html]  
**How to avoid:** Omit generated schema-drop SQL and prove rollback of Chimeway-owned objects in the DB contract. [CITED: https://www.postgresql.org/docs/15/sql-dropschema.html] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-10-PLAN.md]
**Warning signs:** Generated files contain `DROP SCHEMA` with `CASCADE`. [VERIFIED: D-12]

### Pitfall 6: Golden Fixtures Drift By Mode

**What goes wrong:** Public compatibility accidentally becomes the default, or prefixed output silently loses a helper call. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]  
**Why it happens:** A single public-era golden fixture cannot prove both user-visible generation modes. [VERIFIED: test/fixtures/installer_golden/STDOUT.txt]  
**How to avoid:** Keep separate prefixed and public committed fixture roots, and make idempotency test both modes. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]  
**Warning signs:** Golden test only calls `InstallerFixture.run_install!(root, [])` once with no explicit public-mode run. [VERIFIED: test/chimeway/install/golden_diff_test.exs]

## Code Examples

Verified patterns from official and project sources:

### Generated First Migration Schema Creation

```elixir
# Source: PostgreSQL CREATE SCHEMA docs and Phase 74 D-09/D-12.
def change do
  create_chimeway_schema()

  create chimeway_table(:chimeway_events, primary_key: false) do
    add :id, :uuid, primary_key: true
    add :notification_key, :string, null: false
    add :notification_version, :integer, null: false
    add :idempotency_key, :string, null: false
    add :payload, :map, null: false

    timestamps(type: :utc_datetime_usec)
  end

  create chimeway_unique_index(:chimeway_events, [:idempotency_key],
           name: :chimeway_events_idempotency_key_index
         )
end

defp create_chimeway_schema do
  case @chimeway_prefix do
    false -> :ok
    "chimeway" -> execute("CREATE SCHEMA IF NOT EXISTS chimeway")
  end
end
```

### Mode-Aware Installer Fixture

```elixir
# Source: existing test/support/installer_fixture.ex plus Phase 74 D-14..D-16.
def run_install!(root, opts \\ []) when is_binary(root) do
  ensure_deps!(root)

  args =
    case Keyword.get(opts, :prefix, :default) do
      :default -> ["chimeway.gen.migrations"]
      :chimeway -> ["chimeway.gen.migrations", "--prefix", "chimeway"]
      :public -> ["chimeway.gen.migrations", "--prefix", "public"]
    end

  System.cmd("mix", args,
    cd: root,
    stderr_to_stdout: true,
    env: [{"MIX_ENV", "dev"}]
  )
end
```

### Static Raw SQL Guard

```elixir
# Source: Phase 74 D-17 and current raw SQL audit.
@bare_sql_relation ~r/(FROM|UPDATE|JOIN|ALTER TABLE)\s+chimeway_[a-z_]+/

for {path, content} <- prefixed_generated_tree do
  assert not Regex.match?(@bare_sql_relation, content),
         "prefixed migration has bare Chimeway relation in #{path}"
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Generated migrations implicitly target public schema. | Default generated migrations target the dedicated `chimeway` PostgreSQL schema, while `--prefix public` explicitly preserves legacy unprefixed generation. | Planned Phase 74, 2026-06-30. [VERIFIED: .planning/ROADMAP.md] | New installs get schema isolation by default without a special `mix ecto.migrate --prefix` command. [VERIFIED: .planning/REQUIREMENTS.md] |
| Runtime missing prefix implicitly behaved like public. | Phase 73 made runtime prefix config explicit: `"chimeway"` or `false`. | Phase 73 complete by 2026-06-30. [VERIFIED: .planning/STATE.md] | Phase 74 must not read runtime config for generation; generator mode is CLI-controlled. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| One public-era installer golden fixture. | Two committed fixture trees, one prefixed default and one public legacy. | Planned Phase 74. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] | Golden diffs become product-surface proof for both modes. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Ecto SQL 3.13.5 locked. | Ecto SQL 3.14.0 exists on Hex, but Phase 74 should stay on locked 3.13.5. | Hex release check on 2026-06-30. [VERIFIED: `mix hex.info ecto_sql`] | No dependency upgrade is needed to implement prefixes. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html] |

**Deprecated/outdated:**

- Relying on public-schema generation as the default is outdated for v1.13 because MIG-01 makes the `chimeway` schema the generated default. [VERIFIED: .planning/REQUIREMENTS.md]
- Relying on `mix ecto.migrate --prefix chimeway` is out of scope for Phase 74 because generated migrations must be explicit and normal-host-runnable. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]
- Using `@schema_prefix` is rejected for this phase because it does not qualify raw SQL and belongs to runtime/schema metadata rather than copied migration generation. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| - | None | - | All material implementation claims are verified from project files, command output, or cited official docs. [VERIFIED: research sources listed below] |

## Open Questions (RESOLVED)

1. **Rollback schema cleanup decision:** RESOLVED - generated Phase 74 migrations should not emit schema-drop SQL. D-12 remains satisfied by omitting `DROP SCHEMA` entirely in generated output; `DROP SCHEMA ... CASCADE` is forbidden, and `RESTRICT` cleanup is not part of the executable plan because no generated schema drop is needed to prove rollback of Chimeway-owned objects. The DB contract must verify rollback behavior for Chimeway-owned objects and static contracts must forbid destructive schema cleanup in generated output. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-10-PLAN.md] [CITED: https://www.postgresql.org/docs/15/sql-dropschema.html]

2. **DB proof file boundary:** RESOLVED - generated database migration proof lives in `test/chimeway/migration_contract_test.exs`. Static generated-output proof lives in `test/chimeway/install/prefix_contract_test.exs`; golden and idempotency contracts remain under `test/chimeway/install/`. Plan 74-10 extends `test/chimeway/migration_contract_test.exs` to run both generated fixture roots through normal `Ecto.Migrator` execution: default prefixed output must create and roll back objects under the `chimeway` schema without a migration-runner prefix flag, and generated `--prefix public` output must create and roll back unprefixed/public objects. [VERIFIED: test/chimeway/migration_contract_test.exs] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-10-PLAN.md]

No unresolved research questions remain for Phase 74 planning. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-01-PLAN.md] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-10-PLAN.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Mix task and tests | yes | 1.19.5 local; project baseline 1.17+ | CI uses Elixir 1.17. [VERIFIED: `elixir --version`] [VERIFIED: .github/workflows/ci.yml] |
| Erlang/OTP | Elixir runtime | yes | OTP 28 local; project baseline OTP 26+ | CI matrix includes OTP 26 and 27. [VERIFIED: `elixir --version`] [VERIFIED: .github/workflows/ci.yml] |
| Mix | Dependencies and test commands | yes | 1.19.5 local | CI installs Mix with setup-beam. [VERIFIED: `mix --version`] [VERIFIED: .github/workflows/ci.yml] |
| Hex public registry | Version checks/deps | partial | Public queries work; auth session expired warning | Public package queries and `mix deps.get` still work for public deps; no private deps needed. [VERIFIED: `mix hex.info ecto_sql`] |
| PostgreSQL server | Migration contract tests | yes, but below baseline locally | 14.17 local server accepting connections | CI service uses `postgres:15`; Docker is available for local PG 15 if needed. [VERIFIED: `psql --version`] [VERIFIED: `pg_isready`] [VERIFIED: .github/workflows/ci.yml] [VERIFIED: `docker --version`] |
| Docker | Optional local PG 15 fallback | yes | Docker 29.5.2 client available | Use CI if local Docker daemon/service setup is not desired. [VERIFIED: `docker --version`] |
| GitHub Actions | Path-gated installer proof | yes | Existing workflow | Extend `install_golden_contract`. [VERIFIED: .github/workflows/ci.yml] |

**Missing dependencies with no fallback:** none found. [VERIFIED: environment audit]  
**Missing dependencies with fallback:** local PostgreSQL is 14.17 instead of project baseline 15+; use CI `postgres:15` or local Docker Postgres 15 for authoritative migration proof. [VERIFIED: `psql --version`] [VERIFIED: .github/workflows/ci.yml] [VERIFIED: `docker --version`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit bundled with Elixir 1.17+; local Elixir 1.19.5. [VERIFIED: mix.exs] [VERIFIED: `elixir --version`] |
| Config file | `config/test.exs` configures `Chimeway.Repo` with `Ecto.Adapters.SQL.Sandbox`. [VERIFIED: config/test.exs] |
| Quick run command | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` [VERIFIED: command output 2026-06-30] |
| Full suite command | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` [VERIFIED: component commands passed 2026-06-30] |
| CI path gate | `mix ci.install_golden` inside `.github/workflows/ci.yml` `install_golden_contract`. [VERIFIED: mix.exs] [VERIFIED: .github/workflows/ci.yml] |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| MIG-01 | Default `mix chimeway.gen.migrations` emits `@chimeway_prefix "chimeway"` and schema-qualified migrations. | golden + static | `MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors` | Existing file, needs dual-mode update. [VERIFIED: test/chimeway/install/golden_diff_test.exs] |
| MIG-01 | Explicit `--prefix chimeway` equals default output except intentional stdout/fixture naming. | unit + golden | `MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` | Existing file, needs option tests. [VERIFIED: test/chimeway/install/migrations_test.exs] |
| MIG-02 | Prefixed generated migrations create schema and qualify tables/indexes/references/alters/drops/raw SQL. | static + DB integration | `MIX_ENV=test mix test test/chimeway/install/prefix_contract_test.exs --warnings-as-errors` | Missing; Wave 0 gap. [VERIFIED: no file found] |
| MIG-02 | Normal migration path creates `chimeway.chimeway_*` without `mix ecto.migrate --prefix chimeway`. | DB integration | `MIX_ENV=test mix test test/chimeway/migration_contract_test.exs --warnings-as-errors` | Existing file, needs prefixed generated proof. [VERIFIED: test/chimeway/migration_contract_test.exs] |
| MIG-03 | `--prefix public` emits unprefixed migrations and no `prefix: false` Ecto options. | golden + static | `MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors` | Existing file, needs public fixture root. [VERIFIED: test/chimeway/install/golden_diff_test.exs] |
| MIG-04 | Both modes are idempotent: second run emits only `unchanged` lines. | integration | `MIX_ENV=test mix test test/chimeway/install/idempotency_test.exs --warnings-as-errors` | Existing file, needs mode loop. [VERIFIED: test/chimeway/install/idempotency_test.exs] |

### Sampling Rate

- **Per task commit:** Run `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/install/migrations_test.exs --warnings-as-errors` for installer-core changes. [VERIFIED: command output 2026-06-30]
- **Per wave merge:** Run golden/idempotency plus migration contract tests for both modes. [VERIFIED: test/chimeway/install/golden_diff_test.exs] [VERIFIED: test/chimeway/install/idempotency_test.exs] [VERIFIED: test/chimeway/migration_contract_test.exs]
- **Phase gate:** Run `mix ci.install_golden`, the prefixed migration contract command, and the existing `mix ci.test` path in CI/local parity. [VERIFIED: mix.exs] [VERIFIED: .github/workflows/ci.yml]

### Wave 0 Gaps

- [ ] `test/chimeway/install/prefix_contract_test.exs` - static generated-output guard for bare Ecto and raw SQL Chimeway references in prefixed mode. [VERIFIED: no existing file found]
- [ ] `test/fixtures/installer_golden_prefixed/` - committed default prefixed fixture tree and stdout. [VERIFIED: current fixture is only `test/fixtures/installer_golden`]
- [ ] `test/fixtures/installer_golden_public/` - committed explicit public legacy fixture tree and stdout. [VERIFIED: current fixture is only `test/fixtures/installer_golden`]
- [ ] `InstallerFixture.run_install!/2` option support - pass `--prefix chimeway` and `--prefix public` to the real subprocess. [VERIFIED: test/support/installer_fixture.ex]
- [ ] Prefixed migration contract setup - generate migrations into an isolated host/repo or isolated migrations path, run normal migration execution without `--prefix`, verify `chimeway` schema objects, and prove public legacy still passes. [VERIFIED: test/chimeway/migration_contract_test.exs] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase 74 does not touch auth paths. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| V3 Session Management | no | Phase 74 does not touch session or browser state. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| V4 Access Control | no | Phase 74 changes generated migration files only; host auth/tenancy remains out of scope. [VERIFIED: AGENTS.md] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| V5 Input Validation | yes | Strict OptionParser validation for `--prefix` values and unsupported flags. [CITED: https://hexdocs.pm/elixir/1.17.3/OptionParser.html] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| V6 Cryptography | no | Phase 74 does not introduce cryptography. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |

### Known Threat Patterns for Elixir/Ecto Migration Generation

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| SQL injection through prefix or relation name | Tampering | Only accept fixed generator prefixes `chimeway` and `public`, and qualify raw SQL through known Chimeway relation helpers. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Accidental writes to public schema in default mode | Tampering | Static generated-output scan plus DB contract that verifies objects under `chimeway` and not accidental reliance on `search_path`. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |
| Destructive rollback removes host-owned objects | Tampering / Denial of Service | Forbid `DROP SCHEMA ... CASCADE`; omit generated schema-drop SQL and verify object rollback in DB proof. [CITED: https://www.postgresql.org/docs/15/sql-dropschema.html] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-10-PLAN.md] |
| Sensitive payload exposure in generated/operator surfaces | Information Disclosure | Phase 74 should not add telemetry/operator surfaces; keep generated migration output structural and avoid payload inspection. [VERIFIED: AGENTS.md] [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/74-prefixed-migration-generator/74-CONTEXT.md` - locked generator interface, template shape, verification strategy, and deferred scope. [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` - MIG-01 through MIG-04 requirement text and phase mapping. [VERIFIED: file read]
- `.planning/ROADMAP.md` - Phase 74 scope, dependency on Phase 73, and success criteria. [VERIFIED: file read]
- `.planning/STATE.md` - Phase 73 completion history and runtime prefix decisions. [VERIFIED: file read]
- `AGENTS.md` - project stack, build principles, and quality gates. [VERIFIED: file read]
- `lib/mix/tasks/chimeway.gen.migrations.ex` - current Mix task behavior. [VERIFIED: file read]
- `lib/chimeway/install/migrations.ex` - current installer core behavior. [VERIFIED: file read]
- `priv/chimeway_migrations/*.exs` - 31 canonical templates and raw SQL sites. [VERIFIED: file scan]
- `test/support/installer_fixture.ex`, `test/chimeway/install/*.exs`, `test/chimeway/migration_contract_test.exs` - existing verification harness. [VERIFIED: file read]
- `mix.exs`, `.github/workflows/ci.yml`, `config/test.exs` - aliases, CI gates, and DB test setup. [VERIFIED: file read]

### Secondary (MEDIUM confidence)

- `https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html` - migration prefix, index/reference, and `execute` behavior. [CITED: official docs]
- `https://hexdocs.pm/ecto_sql/3.13.5/Mix.Tasks.Ecto.Migrate.html` - migrations path and `--prefix` option. [CITED: official docs]
- `https://hexdocs.pm/elixir/1.17.3/OptionParser.html` - strict option parsing behavior. [CITED: official docs]
- `https://hexdocs.pm/elixir/1.17.3/System.html` - subprocess execution options used by installer fixture. [CITED: official docs]
- `https://www.postgresql.org/docs/15/sql-createschema.html` - `CREATE SCHEMA IF NOT EXISTS` and schema namespace behavior. [CITED: official docs]
- `https://www.postgresql.org/docs/15/sql-dropschema.html` - `DROP SCHEMA`, `CASCADE`, and `RESTRICT` behavior. [CITED: official docs]
- `mix hex.info ecto_sql`, `mix hex.info ecto`, `mix hex.info postgrex`, `mix hex.info oban` - current Hex release and download information for existing dependencies. [VERIFIED: command output]

### Tertiary (LOW confidence)

- None used for implementation recommendations. [VERIFIED: sources audit]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - all packages are existing locked dependencies or project baselines; no new packages are recommended. [VERIFIED: mix.exs] [VERIFIED: `mix deps`]
- Architecture: HIGH - Phase 74 context is explicit, and current installer/test seams match the required changes. [VERIFIED: .planning/phases/74-prefixed-migration-generator/74-CONTEXT.md] [VERIFIED: lib/chimeway/install/migrations.ex]
- Ecto/Postgres behavior: MEDIUM - verified against official docs via web fetch because Context7 MCP/CLI were unavailable in this runtime. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html] [CITED: https://www.postgresql.org/docs/15/sql-createschema.html]
- Pitfalls: HIGH - each pitfall maps to locked decisions, current raw SQL/template audit, or official Ecto/Postgres docs. [VERIFIED: `rg -n "execute\\(" priv/chimeway_migrations`] [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html]

**Research date:** 2026-06-30  
**Valid until:** 2026-07-30 for project/codebase findings; re-check HexDocs and Hex releases after 30 days or before dependency upgrades. [VERIFIED: current date]
