# Phase 74: Prefixed Migration Generator - Context

**Gathered:** 2026-06-30 (assumptions mode + subagent research)
**Status:** Ready for planning

<domain>
## Phase Boundary

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
</domain>

<decisions>
## Implementation Decisions

### Generator Interface and DX

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

### Generated Migration Shape

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

### Verification Strategy

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

### Lessons Applied

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

### Claude's Discretion

Downstream agents should choose the smallest implementation that preserves this
architecture: explicit CLI modes, one canonical prefix-aware template tree, no
runtime config derivation, no `ecto.migrate --prefix` requirement, and dual-mode
proof. If implementation details collide, prefer reviewable generated host
migrations and deterministic tests over clever generator internals.

### Folded Todos

None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/METHODOLOGY.md`
- `.planning/phases/73-storage-prefix-contract/73-CONTEXT.md`
- `.planning/research/v1.12-quality-readiness/PG-SCHEMA-ISOLATION-DECISION.md`
- `.planning/research/v1.12-quality-readiness/SYNTHESIS-ROADMAP.md`
- `prompts/chimeway-engineering-dna-from-prior-libs.md`
- `prompts/chimeway-testing-and-e2e-strategy.md`
- `prompts/chimeway-host-app-integration-seam.md`
- `prompts/chimeway-release-engineering-and-ci.md`
- `prompts/elixir_notifykit_research_brief.md`
- `prompts/prior-art/SOURCE-CANONICAL.md`
- `/Users/jon/projects/rulestead/prompts/ecto-best-practices-deep-research.md`
- `/Users/jon/projects/rulestead/prompts/elixir-opensource-libs-best-practices-deep-research.md`
- `/Users/jon/projects/rulestead/prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md`
- `lib/mix/tasks/chimeway.gen.migrations.ex`
- `lib/chimeway/install/migrations.ex`
- `lib/chimeway/storage.ex`
- `priv/chimeway_migrations/001_create_chimeway_events.exs`
- `priv/chimeway_migrations/003_create_chimeway_deliveries.exs`
- `priv/chimeway_migrations/009_add_attempt_history_columns.exs`
- `priv/chimeway_migrations/027_create_chimeway_signals_and_spine.exs`
- `priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs`
- `test/chimeway/install/migrations_test.exs`
- `test/chimeway/install/golden_diff_test.exs`
- `test/chimeway/install/idempotency_test.exs`
- `test/support/installer_fixture.ex`
- `test/chimeway/migration_contract_test.exs`
- `test/chimeway/release_gate_contract_test.exs`
- `test/fixtures/installer_golden/STDOUT.txt`
- `test/fixtures/installer_golden/tree/priv/repo/migrations/`
- `mix.exs`
- `.github/workflows/ci.yml`
- `README.md`
- `guides/introduction/installation.md`
- `https://hexdocs.pm/elixir/OptionParser.html`
- `https://hexdocs.pm/mix/Mix.Task.html`
- `https://hexdocs.pm/elixir/System.html#cmd/3`
- `https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Schema.html`
- `https://hexdocs.pm/ecto_sql/Ecto.Migration.html`
- `https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html`
- `https://hexdocs.pm/ecto_sql/Ecto.Migrator.html`
- `https://hexdocs.pm/ecto/Ecto.Schema.html`
- `https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html`
- `https://hexdocs.pm/oban/Oban.Migration.html`
- `https://www.postgresql.org/docs/current/sql-createschema.html`
- `https://www.postgresql.org/docs/current/sql-dropschema.html`
- `https://guides.rubyonrails.org/engines.html`
- `https://laravel.com/docs/packages`
- `https://hexdocs.pm/ash_postgres/migrations-and-tasks.html`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `lib/chimeway/install/migrations.ex` already centralizes template discovery,
  host repo resolution, namespace rewriting, timestamping, slug validation, and
  slug-based idempotency.
- `lib/mix/tasks/chimeway.gen.migrations.ex` is the only public installer CLI
  entrypoint and already runs `app.config` before invoking installer core.
- `test/support/installer_fixture.ex` already scaffolds throwaway host apps,
  runs the Mix task in a subprocess, normalizes timestamps/stdout, snapshots the
  generated tree, and writes committed golden fixtures.
- `test/chimeway/install/golden_diff_test.exs` and
  `test/chimeway/install/idempotency_test.exs` already establish the golden tree
  and second-run contract for the current unprefixed path.
- `test/chimeway/migration_contract_test.exs` already reframes current public DB
  assertions as legacy compatibility proof.
- `lib/chimeway/storage.ex` is the Phase 73 runtime prefix contract; it should
  inform language and tests, but generator output should not be derived from it.

### Established Patterns

- Chimeway favors explicit, durable, reviewable behavior over hidden magic.
- Generated host files are part of adopter DX. They should be ordinary Phoenix
  app migrations that can be inspected, committed, and run with normal
  `mix ecto.migrate`.
- Runtime public compatibility is `prefix: false`; generator public
  compatibility is `--prefix public`.
- Named `mix verify.*` and `mix ci.*` entrypoints plus CI parity are part of the
  product contract.
- Public mode is compatibility for existing installs, not the new default.

### Integration Points

- Current templates under `priv/chimeway_migrations/` contain bare Ecto
  `table`, `index`, `references`, and `alter` calls that need prefix helpers.
- Raw SQL currently appears in attempt-history, signal-spine, and tenant/actor
  migrations; those migrations are the highest-risk Phase 74 files.
- `mix.exs` already has `ci.install_golden`, and `.github/workflows/ci.yml` has a
  path-gated `install_golden_contract` job that should evolve with dual-mode
  fixtures and prefixed migration proof.
- README and installation guide already mention `prefix: "chimeway"` and
  `prefix: false`; Phase 74 planner should keep those docs consistent with the
  generator CLI, but full prefix docs and demo proof remain Phase 76.
</code_context>

<specifics>
## Specific Ideas

- Preferred CLI examples:

  ```bash
  mix chimeway.gen.migrations
  mix chimeway.gen.migrations --prefix chimeway
  mix chimeway.gen.migrations --prefix public
  ```

- Public-mode copy should say:

  ```text
  --prefix public generates legacy unprefixed migrations for existing
  public-schema installs. Runtime config for that mode is still
  config :chimeway, prefix: false.
  ```

- Generated default host migrations can make intent visible with a local module
  attribute and helpers:

  ```elixir
  @chimeway_prefix "chimeway"

  defp chimeway_prefix_opts(opts \\ []) do
    Keyword.put_new(opts, :prefix, @chimeway_prefix)
  end
  ```

- Public-mode helpers must not pass `prefix: false` to Ecto. They should return
  bare table/index/reference operations.
- Raw SQL helpers should quote or otherwise safely construct only known
  Chimeway-owned relation names. Do not introduce arbitrary user-controlled SQL
  qualification.
- Static tests should fail if prefixed generated migrations contain bare raw SQL
  references such as `FROM chimeway_delivery_attempts` without the `chimeway`
  schema qualifier.
- The generated default path should prove that normal `mix ecto.migrate` creates
  `chimeway.chimeway_*` tables without moving host `schema_migrations`.
</specifics>

<deferred>
## Deferred Ideas

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
</deferred>
