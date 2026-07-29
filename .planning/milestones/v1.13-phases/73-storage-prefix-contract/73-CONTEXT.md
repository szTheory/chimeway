# Phase 73: Storage Prefix Contract - Context

**Gathered:** 2026-06-30 (assumptions mode + advisor research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 73 establishes the static Chimeway storage-prefix contract before migration
generation or broad runtime propagation changes. It covers PFX-01, PFX-02, PFX-03,
PFX-04, and UPG-01: explicit runtime prefix values, early validation, one internal
repo-option contract, and public-schema legacy compatibility with no silent data
move. It should not rewrite migration templates, add `mix chimeway.gen.migrations`
prefix flags, qualify raw SQL, thread prefix options through runtime flows, change
Oban configuration, update the demo host, or create the full docs/verification
gate; those are Phase 74, Phase 75, and Phase 76 scope.
</domain>

<decisions>
## Implementation Decisions

### Runtime Prefix Semantics

- **D-01:** Runtime storage config is strict and static: valid values are
  `config :chimeway, prefix: "chimeway"` for schema-isolated Chimeway storage and
  `config :chimeway, prefix: false` for explicit public-schema legacy mode.
- **D-02:** Missing config, `nil`, `"public"`, arbitrary strings, functions, MFA,
  process-local values, and tenant-derived/dynamic prefixes are invalid runtime
  configuration for Phase 73.
- **D-03:** "Default new install" means the installer/docs should write
  `prefix: "chimeway"` for new hosts; runtime missing config must not silently
  mean either `public` or `chimeway`.
- **D-04:** `prefix: false` is the only runtime representation of public-schema
  compatibility. It means "keep using existing unprefixed/public Chimeway tables"
  and does not move, copy, or rewrite data.
- **D-05:** Phase 74 may accept generator CLI sugar such as `--prefix public`, but
  that must normalize to legacy unprefixed migration output and docs must still
  teach `prefix: false` as the runtime config.

### Validation and Errors

- **D-06:** Add one shared normalizer/validator for storage prefix config and call
  it before Chimeway starts Repo/Oban children, following the existing
  `Chimeway.Application` boot-validation pattern.
- **D-07:** Add a branded `Chimeway.ConfigError` for invalid prefix configuration
  with structured fields such as `type: :invalid_prefix`, `key: :prefix`, and the
  rejected value.
- **D-08:** Error copy must be actionable: name the accepted values, show
  copy-paste config for both new installs and public legacy mode, and state that
  dynamic/per-tenant database prefixes are out of scope.
- **D-09:** Do not validate database schema existence at application boot. Phase 73
  validates configuration shape only; schema creation/proof belongs to migration
  and runtime phases.
- **D-10:** Avoid compile-time config, `@schema_prefix`, or schema module rewrites
  as the primary mechanism because they make `prefix: false` opt-out surprising
  and do not fit host runtime configuration.

### Internal Storage Contract

- **D-11:** Add an internal `Chimeway.Storage` module as the storage-prefix contract
  surface. Keep it internal/documented for maintainers, not as a broad public API.
- **D-12:** `Chimeway.Storage.repo_opts/1` maps validated storage config to Ecto
  repo options: configured string prefix becomes `[prefix: "chimeway"]`; `false`
  becomes no `:prefix` option.
- **D-13:** `repo_opts/1` should add the configured prefix with `Keyword.put_new/3`
  so explicit caller `prefix:` remains possible for tests, admin/debug reads, and
  maintenance probes. This is not a public per-tenant or per-request prefix API.
- **D-14:** Context-specific helpers may still drop domain/query options such as
  `:limit`, `:tenant_id`, `:recipient_id`, or `:older_than`, but they must delegate
  prefix construction to `Chimeway.Storage.repo_opts/1`.
- **D-15:** Do not use `@schema_prefix`, process dictionary state, raw option
  threading everywhere, or context-private prefix logic as the primary contract.

### Phase 73 Verification Shape

- **D-16:** Keep Phase 73 contract-only: focused config/helper/docs tests are in
  scope; migration output changes and runtime propagation are not.
- **D-17:** Tests should cover valid prefix values, invalid values, missing config,
  boot-time validation, `prefix: false` mapping to unprefixed repo opts, explicit
  caller override behavior for test/admin/debug repo opts, and current public
  migration contract language as intentional legacy behavior.
- **D-18:** Doc-contract or copy tests should lock the public-mode microcopy:
  `prefix: false` is only for existing installs whose Chimeway tables already live
  in `public`; it keeps using those unprefixed tables and does not move data.
- **D-19:** Do not expose backend implementation details to ordinary adopters. The
  API/docs should frame the choice as "new isolated Chimeway schema" versus
  "existing public-schema legacy install", not as Ecto internals.

### Lessons Applied

- **D-20:** Learn from Noticed/Laravel durable identity footguns: storage behavior
  and durable row identity must be explicit and rename-safe, not inferred from
  module/class names or hidden defaults.
- **D-21:** Learn from Symfony-style DSN/config footguns: compact config can be
  brittle when values encode too much meaning. Prefer boring, typed values over
  overloaded strings such as `"public"`.
- **D-22:** Learn from Ecto and Oban prefix semantics: Chimeway's table prefix and
  Oban's job-table prefix are separate concerns and must remain documented as
  separate in later phases.

### Claude's Discretion

Downstream agents may choose the narrowest implementation that satisfies the
decisions above. If naming conflicts appear, keep the architecture the same:
one internal storage-prefix helper, one branded config error, strict static
runtime values, and no dynamic database-prefix tenancy.

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
- `.planning/research/v1.12-quality-readiness/PG-SCHEMA-ISOLATION-DECISION.md`
- `.planning/research/v1.12-quality-readiness/SYNTHESIS-ROADMAP.md`
- `prompts/chimeway-host-app-integration-seam.md`
- `prompts/chimeway-engineering-dna-from-prior-libs.md`
- `prompts/chimeway-testing-and-e2e-strategy.md`
- `prompts/chimeway-release-engineering-and-ci.md`
- `prompts/elixir_notifykit_research_brief.md`
- `prompts/prior-art/SOURCE-CANONICAL.md`
- `lib/chimeway/application.ex`
- `lib/chimeway/repo.ex`
- `lib/chimeway/install/migrations.ex`
- `lib/mix/tasks/chimeway.gen.migrations.ex`
- `lib/chimeway/traces.ex`
- `lib/chimeway/admin.ex`
- `lib/chimeway/trigger.ex`
- `lib/chimeway/deliveries.ex`
- `lib/chimeway/inbox.ex`
- `config/config.exs`
- `test/chimeway/application_validation_test.exs`
- `test/chimeway/traces_test.exs`
- `test/chimeway/install/migrations_test.exs`
- `test/chimeway/migration_contract_test.exs`
- `README.md`
- `guides/introduction/installation.md`
- `guides/introduction/golden-path.md`
- `guides/recipes/oban-integration.md`
- `https://hexdocs.pm/ecto/Ecto.Repo.html`
- `https://hexdocs.pm/ecto/Ecto.Query.html`
- `https://hexdocs.pm/ecto/Ecto.Schema.html`
- `https://hexdocs.pm/ecto_sql/Ecto.Migration.html`
- `https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html`
- `https://hexdocs.pm/oban/Oban.Migration.html`
- `https://hexdocs.pm/oban/testing.html`
- `https://hexdocs.pm/elixir/Application.html`
- `https://hexdocs.pm/elixir/Config.html`
- `https://hexdocs.pm/mix/Mix.html`
- `https://github.com/excid3/noticed`
- `https://laravel.com/docs/notifications`
- `https://symfony.com/doc/current/notifier.html`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Chimeway.Application.start/2` already performs early config validation before
  starting children via `validate_channel_render_modules!/0`; Phase 73 should
  mirror that pattern for storage prefix config.
- `test/chimeway/application_validation_test.exs` already shows how to test
  app-env validation with `async: false` and `on_exit` restoration.
- `Chimeway.Traces` already accepts repo opts such as `prefix:` on several read
  paths and has tests proving opts propagation with a nonexistent schema.
- `Chimeway.Admin` already has a context-private `repo_opts/1` that filters
  non-Repo options before `Repo.all/2`; it is a good local wrapper pattern but not
  enough as the global prefix contract.
- `Chimeway.Install.Migrations` already centralizes copied migration template
  behavior and repo resolution for the installer.

### Established Patterns

- Chimeway favors explicit, durable, inspectable behavior over hidden magic.
- Host applications own auth, tenancy, URLs, correlation, and operational choices;
  Chimeway owns its durable notification lifecycle and storage conventions.
- Named `mix verify.*` and contract tests are product surface, not optional polish.
- Public docs must teach adopter-facing choices in terms of outcomes and safety,
  not internal implementation details.

### Integration Points

- `config/config.exs` currently has no `:prefix`; Phase 73 planning should expect
  implementation to update project/test config once validation is added.
- `lib/chimeway/trigger.ex`, `lib/chimeway/deliveries.ex`, `lib/chimeway/inbox.ex`,
  dispatch workers, policies, workflows, digests, signal routing, and webhooks
  contain many direct `Repo.*` calls; broad propagation is Phase 75.
- `lib/chimeway/trigger.ex` uses string-source `insert_all("chimeway_notifications", rows)`;
  this is a known Phase 75 footgun and should not be solved piecemeal in Phase 73.
- `test/chimeway/migration_contract_test.exs` currently asserts public-schema
  tables; Phase 73 should reframe that as current intentional legacy/public
  compatibility, while Phase 74 changes generated migration proof.
</code_context>

<specifics>
## Specific Ideas

- Suggested config error copy:

  ```text
  [chimeway] invalid :prefix config.
  Use prefix: "chimeway" for new schema-isolated installs, or prefix: false for
  an existing public-schema legacy install. Dynamic per-tenant database prefixes
  are not supported in this milestone.
  ```

- Suggested public-mode microcopy:

  ```text
  Use prefix: false only for an existing install whose Chimeway tables already
  live in public. This keeps using those unprefixed tables and does not move data.
  ```

- Suggested helper behavior:

  ```elixir
  Chimeway.Storage.repo_opts([])
  #=> [prefix: "chimeway"]

  # when configured with prefix: false
  Chimeway.Storage.repo_opts([])
  #=> []
  ```

- Tests should assert behavior through structured fields or stable phrases rather
  than brittle full exception strings.
</specifics>

<deferred>
## Deferred Ideas

- `mix chimeway.gen.migrations --prefix public` / `--prefix chimeway` CLI parsing
  and output behavior - Phase 74.
- Prefixing 31 migration templates, indexes, references, alters, drops, and raw SQL
  - Phase 74.
- Golden fixture refresh and prefixed migration contract tests - Phase 74.
- Runtime prefix propagation across trigger, deliveries, attempts, workflows,
  digests, policies, inbox, signals, webhooks, traces, admin, recovery, and workers
  - Phase 75.
- Oban prefix examples and proof that Oban prefix remains independent from
  Chimeway's table prefix - Phase 76.
- Demo-host default `chimeway` schema proof and trigger-to-trace verification -
  Phase 76.
- Manual public-to-`chimeway` move guide, rollback notes, and release gate/docs
  coverage - Phase 76.
- Dynamic per-tenant database prefixes and automatic production data move tasks -
  future requirements, out of v1.13 scope.

### Reviewed Todos (not folded)

None.
</deferred>
