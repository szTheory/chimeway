# Phase 73: Storage Prefix Contract - Research

**Researched:** 2026-06-30  
**Domain:** Elixir/Ecto static PostgreSQL schema prefix contract  
**Confidence:** HIGH

## User Constraints (from CONTEXT.md)

The phase boundary, locked decisions, discretion note, and deferred ideas in this section are copied from `73-CONTEXT.md`. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

### Phase Boundary

Phase 73 establishes the static Chimeway storage-prefix contract before migration
generation or broad runtime propagation changes. It covers PFX-01, PFX-02, PFX-03,
PFX-04, and UPG-01: explicit runtime prefix values, early validation, one internal
repo-option contract, and public-schema legacy compatibility with no silent data
move. It should not rewrite migration templates, add `mix chimeway.gen.migrations`
prefix flags, qualify raw SQL, thread prefix options through runtime flows, change
Oban configuration, update the demo host, or create the full docs/verification
gate; those are Phase 74, Phase 75, and Phase 76 scope.

### Locked Decisions

#### Runtime Prefix Semantics

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

#### Validation and Errors

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

#### Internal Storage Contract

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

#### Phase 73 Verification Shape

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

#### Lessons Applied

- **D-20:** Learn from Noticed/Laravel durable identity footguns: storage behavior
  and durable row identity must be explicit and rename-safe, not inferred from
  module/class names or hidden defaults.
- **D-21:** Learn from Symfony-style DSN/config footguns: compact config can be
  brittle when values encode too much meaning. Prefer boring, typed values over
  overloaded strings such as `"public"`.
- **D-22:** Learn from Ecto and Oban prefix semantics: Chimeway's table prefix and
  Oban's job-table prefix are separate concerns and must remain documented as
  separate in later phases.

### the agent's Discretion

Downstream agents may choose the narrowest implementation that satisfies the
decisions above. If naming conflicts appear, keep the architecture the same:
one internal storage-prefix helper, one branded config error, strict static
runtime values, and no dynamic database-prefix tenancy.

### Deferred Ideas (OUT OF SCOPE)

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

## Project Constraints (from AGENTS.md)

- Chimeway is an open-source embedded notification layer for Elixir and Phoenix apps, and host applications own their data, policies, and delivery history. [VERIFIED: AGENTS.md]
- Every notification decision must remain explainable. [VERIFIED: AGENTS.md]
- The project stack is Elixir 1.17+/OTP 26+, Ecto 3.x/PostgreSQL 15+, optional Phoenix 1.7/1.8, optional Oban 2.x, and Swoosh 1.x email seams. [VERIFIED: AGENTS.md]
- Durable identity must use stable `notification_key` plus version, not module names. [VERIFIED: AGENTS.md]
- The durable lifecycle spine is `event -> notification -> delivery -> attempt`. [VERIFIED: AGENTS.md]
- Idempotency and suppression reasons are first-class behavior. [VERIFIED: AGENTS.md]
- Adapters must remain replaceable through explicit behaviours and contract tests. [VERIFIED: AGENTS.md]
- Host ownership boundaries for auth, tenancy, URL generation, and correlation IDs must be preserved. [VERIFIED: AGENTS.md]
- Named `mix verify.*` and `mix ci.*` entrypoints must be maintained with CI/local parity. [VERIFIED: AGENTS.md]
- Sensitive payload fields must not leak into telemetry or operator surfaces. [VERIFIED: AGENTS.md]

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PFX-01 | Host apps can configure `prefix: "chimeway"` for default new installs or `prefix: false` for explicit public-schema legacy mode. | Use one strict validator and one internal `Chimeway.Storage.repo_opts/1`; Ecto repo operations accept `:prefix`. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Repo.html] |
| PFX-02 | Invalid prefix config fails early with actionable errors. | `Chimeway.Application.start/2` already validates app config before starting children; extend that boot pattern. [VERIFIED: lib/chimeway/application.ex:9] |
| PFX-03 | Runtime code does not hand-roll prefix logic. | Existing `Chimeway.Admin.repo_opts/1` and `Chimeway.Traces` option filtering show the local option-wrapper pattern; replace per-context prefix construction with a shared storage contract. [VERIFIED: lib/chimeway/admin.ex:318] [VERIFIED: lib/chimeway/traces.ex:70] |
| PFX-04 | Existing public-schema installs remain supported without silent migration or changed behavior when configured for legacy mode. | Current migration contract test is explicitly public-schema based; Phase 73 should rename this as legacy compatibility, not change generated migrations. [VERIFIED: test/chimeway/migration_contract_test.exs:28] |
| UPG-01 | Existing public-schema installs have an explicit compatibility path that does not move data automatically. | Context locks `prefix: false` as no move/copy/rewrite, and Phase 73 defers manual move guidance to Phase 76. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |

## Summary

Phase 73 should add the storage-prefix contract only: strict static config validation, a branded config error, a single internal `Chimeway.Storage` helper, and focused tests/docs proving `prefix: "chimeway"` versus `prefix: false`. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

Do not change migration templates, generator CLI flags, runtime `Repo.*` call sites, Oban configuration, demo-host schema setup, or manual data-move docs in this phase. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

The safest implementation is to make missing `:prefix` invalid, configure the repo's current test/dev public-schema behavior explicitly as `prefix: false`, and teach adopter docs that new installs should use `prefix: "chimeway"` while existing public installs must opt into legacy mode with `prefix: false`. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] [VERIFIED: config/config.exs:3]

**Primary recommendation:** implement `Chimeway.ConfigError` plus internal `Chimeway.Storage.repo_opts/1`, call prefix validation in `Chimeway.Application.start/2` before children, and add focused ExUnit/doc-contract coverage before later phases use the helper. [VERIFIED: lib/chimeway/application.ex:9]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Storage prefix config validation | Application boot / Backend | Configuration | Chimeway currently validates app env in `Chimeway.Application.start/2` before starting `Chimeway.Repo` and optional Oban. [VERIFIED: lib/chimeway/application.ex:9] |
| Prefix-to-repo-options mapping | Internal backend library | Ecto Repo | Ecto repo operations accept `:prefix`, so Chimeway needs one helper that produces repo options instead of caller-specific logic. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Repo.html] |
| Public legacy compatibility contract | Docs and tests | Database/storage | Existing runtime and migrations are public-schema today, so Phase 73 should explicitly label that mode without moving data. [VERIFIED: test/chimeway/migration_contract_test.exs:28] |
| Migration prefix generation | Installer/generator | Database/storage | Phase 74 owns generated `prefix:` migration output and raw SQL qualification. [VERIFIED: .planning/ROADMAP.md] |
| Runtime prefix propagation | Backend runtime contexts | Workers/Admin/Inbox | Phase 75 owns threading the helper through trigger, inbox, digests, workflows, admin, workers, and string-source `insert_all`. [VERIFIED: .planning/ROADMAP.md] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / OTP | Project baseline Elixir 1.17+ / OTP 26+; local toolchain Elixir 1.19.5 / OTP 28 | Application config, supervision, ExUnit | Matches project constraints and current local runtime. [VERIFIED: AGENTS.md] [VERIFIED: `elixir --version`] |
| Ecto | 3.13.6 locked | Repo operations, query prefix semantics, schemas | Existing dependency; official docs define `:prefix` behavior for repo/query operations. [VERIFIED: mix.lock] [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Repo.html] |
| Ecto SQL | 3.13.5 locked | Migrations and SQL adapters | Existing dependency; official docs define migration table/index/reference prefix behavior. [VERIFIED: mix.lock] [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html] |
| PostgreSQL | Project baseline 15+; local server 14.17 | Database schemas/prefix target | Project requires PostgreSQL 15+, but local verification is currently on 14.17. [VERIFIED: AGENTS.md] [VERIFIED: `psql -Atqc 'SHOW server_version;'`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Oban | 2.23.0 locked transitively in current deps | Optional async dispatch | Do not change in Phase 73; Oban prefix docs/proof are Phase 76. [VERIFIED: mix deps] [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |
| NimbleOptions | 1.1.1 locked | Option schema validation | Not needed unless the planner wants a schema wrapper; the locked decision only requires one normalizer/validator. [VERIFIED: mix.lock] [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Chimeway.Storage.repo_opts/1` | Ad hoc `prefix:` logic in each context | Rejected because PFX-03 requires one internal contract and Phase 75 has many call sites. [VERIFIED: .planning/REQUIREMENTS.md] |
| Runtime repo opts | `@schema_prefix` on schemas | Rejected because context locks runtime config and public legacy `prefix: false`; Ecto says schema prefix outranks query prefix. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Query.html#module-query-prefix] |
| `prefix: "public"` | `prefix: false` | Rejected because context locks `false` as the only runtime representation of public legacy mode. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |

**Installation:** No new package installation is recommended for Phase 73. [VERIFIED: mix.exs]

## Package Legitimacy Audit

Phase 73 should install no external packages. [VERIFIED: mix.exs]  
**Packages removed due to [SLOP] verdict:** none. [VERIFIED: no package recommendations]  
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: no package recommendations]

## Codebase Findings

### Existing Validation Pattern

- `Chimeway.Application.start/2` calls `validate_channel_render_modules!/0` before building children and starting `Chimeway.Repo` plus optional Oban. [VERIFIED: lib/chimeway/application.ex:9]
- Existing boot validation reads app env with `Application.get_env/3`, performs shape checks, and raises actionable `ArgumentError` messages. [VERIFIED: lib/chimeway/application.ex:41]
- `test/chimeway/application_validation_test.exs` is `async: false`, mutates application env, restores env in `on_exit`, and asserts stable error phrases. [VERIFIED: test/chimeway/application_validation_test.exs:14]
- Focused validation test command passes when Oban is skipped: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs --warnings-as-errors` returned 4 tests, 0 failures. [VERIFIED: command output 2026-06-30]

### Current Config State

- `config/config.exs` configures `:ecto_repos`, `:time_zone_database`, and `:dispatcher`, but no `:prefix` key exists today. [VERIFIED: config/config.exs:3]
- `config/test.exs` starts Oban unless `CHIMEWAY_SKIP_OBAN` is set, which affected local focused verification because `oban_jobs` is not migrated locally. [VERIFIED: config/test.exs:21]
- The local `chimeway_test` database has all Chimeway migrations down, so DB-backed migration-contract tests currently fail until test migrations are run. [VERIFIED: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix ecto.migrations`]

### Existing Repo Option Patterns

- `Chimeway.Traces.get_trace/2`, `find_traces_for_recipient/2`, `find_traces_by_correlation_id/2`, and `explain_delivery/2` already pass caller opts to Repo calls after dropping domain options where needed. [VERIFIED: lib/chimeway/traces.ex:47] [VERIFIED: lib/chimeway/traces.ex:70]
- `test/chimeway/traces_test.exs` already proves that trace APIs pass `prefix:` through by expecting errors for `nonexistent_schema`. [VERIFIED: test/chimeway/traces_test.exs:998]
- `Chimeway.Admin` has a private `repo_opts/1` that drops domain/query-only options before `Repo.all/2`. [VERIFIED: lib/chimeway/admin.ex:318]
- Phase 73 should preserve context-specific option filtering but delegate prefix construction to the new shared helper. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

### Known Later Touch Points

- `Chimeway.Trigger` currently wraps event and notification creation in `Repo.transaction/1` without repo opts. [VERIFIED: lib/chimeway/trigger.ex:93]
- `Chimeway.Trigger.insert_notifications/6` uses string-source `repo.insert_all("chimeway_notifications", rows)`, which will need explicit prefix handling in Phase 75. [VERIFIED: lib/chimeway/trigger.ex:181]
- `Chimeway.Trigger.dispatch_after_trigger/4` reloads notifications with a direct `Repo.all` and no prefix options. [VERIFIED: lib/chimeway/trigger.ex:434]
- `Chimeway.Inbox` uses direct `Repo.one!`, `Repo.all`, `Repo.update_all`, `Repo.get_by`, and `Repo.one` calls without opts today. [VERIFIED: lib/chimeway/inbox.ex:36]
- `Chimeway.Deliveries` and workflow/digest/webhook modules have many direct `Repo.*` calls; these are Phase 75 propagation work, not Phase 73 contract work. [VERIFIED: `rg "Repo\\." lib/chimeway`]

### Installer and Migration Contract

- `Chimeway.Install.Migrations` copies templates from `priv/chimeway_migrations`, writes host files under `priv/repo/migrations`, and rewrites the migration namespace only. [VERIFIED: lib/chimeway/install/migrations.ex:64]
- The Mix task currently rejects all unexpected args; prefix CLI parsing is explicitly Phase 74. [VERIFIED: lib/mix/tasks/chimeway.gen.migrations.ex:28] [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
- `test/chimeway/migration_contract_test.exs` asserts `public.chimeway_*` objects and `information_schema.columns.table_schema = 'public'`; Phase 73 should rename this as legacy/public compatibility. [VERIFIED: test/chimeway/migration_contract_test.exs:28]
- Current README, installation guide, and golden path teach `mix chimeway.gen.migrations` plus `mix ecto.migrate` without prefix config. [VERIFIED: README.md:23] [VERIFIED: guides/introduction/installation.md:30] [VERIFIED: guides/introduction/golden-path.md:30]
- `test/chimeway/doc_contract_test.exs` already has install, README, and golden-path contracts, so prefix microcopy can be locked there. [VERIFIED: test/chimeway/doc_contract_test.exs:1017]

## External/API Facts

- Ecto Repo 3.13.6 documents `:prefix` as an option on repo operations such as `all`, `get`, and related query functions; the option applies to sources without an explicit `from`/`join` prefix or schema prefix. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Repo.html]
- Ecto Query 3.13.6 documents that when no Postgres prefix is set, queries are assumed to be in `public`. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Query.html#module-query-prefix]
- Ecto Query 3.13.6 documents prefix precedence as `from`/`join` prefix first, then `@schema_prefix`, then the query prefix or Repo `:prefix` option. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Query.html#module-query-prefix]
- Ecto SQL 3.13.5 migrations support table and index prefixes; references declared in a prefixed table default to the same prefix. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html#module-prefixes]
- Ecto SQL 3.13.5 says prefixed tables require matching index prefixes so the prefix-qualified table is indexed. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html#module-prefixes]
- Ecto SQL `execute/1` executes arbitrary SQL, so raw SQL qualification is not automatic and belongs to Phase 74 migration-template work. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html#execute/1]
- Elixir Application 1.17.3 documents `fetch_env/2`, `fetch_env!/2`, and `get_env/3` for application environment reads; library code should read its own app env. [CITED: https://hexdocs.pm/elixir/1.17.3/Application.html#get_env/3]
- Elixir Application 1.17.3 defines `start/2` as the application callback that starts the supervision tree, matching Chimeway's existing validation-before-children pattern. [CITED: https://hexdocs.pm/elixir/1.17.3/Application.html#c:start/2]

## Recommended Implementation Approach

### 1. Add the Error Type

Add `Chimeway.ConfigError` with `defexception [:type, :key, :value, :message]`, use `type: :invalid_prefix`, `key: :prefix`, and keep error assertions on fields plus stable phrases. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

Do not reuse plain `ArgumentError` for prefix config because the context explicitly asks for branded structured error fields. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

### 2. Add `Chimeway.Storage`

Recommended internal surface: [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

```elixir
# Source: phase context D-11..D-14 plus Ecto Repo :prefix docs
defmodule Chimeway.Storage do
  @moduledoc false

  def validate_prefix! do
    case Application.fetch_env(:chimeway, :prefix) do
      {:ok, "chimeway"} -> :ok
      {:ok, false} -> :ok
      {:ok, value} -> raise Chimeway.ConfigError, type: :invalid_prefix, key: :prefix, value: value
      :error -> raise Chimeway.ConfigError, type: :invalid_prefix, key: :prefix, value: :missing
    end
  end

  def repo_opts(opts \\ []) do
    validate_prefix!()

    case Application.fetch_env!(:chimeway, :prefix) do
      false -> opts
      prefix -> Keyword.put_new(opts, :prefix, prefix)
    end
  end
end
```

The planner may choose helper names, but the behavior should remain strict: only `"chimeway"` and `false`, no missing/nil/public/arbitrary/dynamic values, and no database schema existence check. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

### 3. Wire Boot Validation

Call `Chimeway.Storage.validate_prefix!/0` in `Chimeway.Application.start/2` before `validate_channel_render_modules!/0` or immediately after it, and before `children` are started. [VERIFIED: lib/chimeway/application.ex:9]

Do not validate that the database schema exists at boot; the locked scope is config shape only. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

### 4. Make Current Public Mode Explicit

Set the repo's current internal test/dev public-schema setup explicitly to `prefix: false` where needed so existing public migrations stay intentional during contract-only work. [VERIFIED: config/test.exs] [VERIFIED: test/chimeway/migration_contract_test.exs:28]

Do not create a runtime fallback that maps missing config to `false` or `"chimeway"`. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

### 5. Add Narrow Docs/Doc Contracts

Update README, installation, and golden path only enough to show copy-paste runtime config for new schema-isolated installs and public legacy mode. [VERIFIED: README.md:23] [VERIFIED: guides/introduction/installation.md:43] [VERIFIED: guides/introduction/golden-path.md:40]

Lock this microcopy in `test/chimeway/doc_contract_test.exs`: `prefix: false` is only for existing installs whose Chimeway tables already live in `public`, keeps using unprefixed tables, and does not move data. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] [VERIFIED: test/chimeway/doc_contract_test.exs:1017]

## Architecture Patterns

### Pattern 1: Config Shape Validation Before Children

**What:** Validate app env in `Chimeway.Application.start/2` before starting Repo/Oban children. [VERIFIED: lib/chimeway/application.ex:9]  
**When to use:** Use for prefix config because invalid prefix should fail before runtime paths start reading/writing. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]  
**Example:** Extend the current `validate_channel_render_modules!/0` boot pattern with `validate_prefix!`. [VERIFIED: lib/chimeway/application.ex:10]

### Pattern 2: Context Option Filtering Plus Shared Repo Options

**What:** Context functions can drop non-Repo options but must call the shared storage helper for prefix behavior. [VERIFIED: lib/chimeway/admin.ex:318]  
**When to use:** Use this in Phase 75 for admin/traces/inbox/deliveries/runtime calls; Phase 73 only creates and tests the shared helper. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

### Anti-Patterns to Avoid

- **Implicit public fallback:** Missing `:prefix` must not mean public. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
- **Accepting `"public"` at runtime:** Runtime public compatibility is represented only by `false`. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
- **`@schema_prefix` as primary mechanism:** Ecto gives schema prefix higher precedence than Repo query prefix, which conflicts with explicit runtime opt-out. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Query.html#module-query-prefix]
- **Dynamic prefix tenancy:** Tenant-derived/function/process prefixes are out of scope and should be rejected. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
- **Boot-time schema checks:** Schema existence belongs to migration/runtime proof phases, not config shape validation. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Runtime prefix propagation | Manual string qualification in runtime queries | Ecto Repo `:prefix` options via `Chimeway.Storage.repo_opts/1` | Ecto already defines prefix behavior for repo/query operations. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Repo.html] |
| Prefix validation | Per-context checks | One normalizer/validator | PFX-03 requires one internal contract. [VERIFIED: .planning/REQUIREMENTS.md] |
| Public legacy mode | Hidden default or `"public"` string | `prefix: false` | Context locks `false` as the only public-schema runtime representation. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |
| Migration raw SQL handling | Runtime helper or boot check | Phase 74 explicit migration qualification | Ecto `execute/1` runs arbitrary SQL; migration output is a separate phase. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html#execute/1] |

**Key insight:** Phase 73 should create a contract later phases can depend on; it should not partially apply the contract to runtime or migration call sites. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

## Testing and Verification Strategy

### Focused Tests to Add or Update

- Add storage config tests for valid `"chimeway"`, valid `false`, missing config, `nil`, `"public"`, arbitrary strings, functions, MFA-like values, and tenant/dynamic-looking values. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
- Add repo option tests: `"chimeway"` maps to `[prefix: "chimeway"]`; `false` maps to no `:prefix`; caller `prefix:` is preserved by `Keyword.put_new/3`. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
- Extend boot-validation tests to assert `Chimeway.ConfigError` type/key/value and stable actionable phrases. [VERIFIED: test/chimeway/application_validation_test.exs:33]
- Update public-schema migration contract naming/copy so `public` is framed as legacy compatibility rather than default behavior. [VERIFIED: test/chimeway/migration_contract_test.exs:6]
- Add doc-contract assertions for copy-paste config and public legacy microcopy in README/installation/golden path. [VERIFIED: test/chimeway/doc_contract_test.exs:1017]

### Commands

Use these focused commands during implementation: [VERIFIED: mix help output]

```bash
CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/storage_test.exs --warnings-as-errors
CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors
CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/migration_contract_test.exs --warnings-as-errors
mix format --check-formatted
```

Before running DB-backed migration contract tests locally, prepare the test database because the current local `chimeway_test` migrations are all down. [VERIFIED: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix ecto.migrations`]

```bash
CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix ecto.create
CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix ecto.migrate
```

### Verification Observed During Research

- `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs --warnings-as-errors` passed with 4 tests, 0 failures. [VERIFIED: command output 2026-06-30]
- `MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/install/migrations_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` failed before tests because local Oban migrations are absent. [VERIFIED: command output 2026-06-30]
- `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/install/migrations_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` ran but failed migration contract assertions because current local public Chimeway tables are not migrated. [VERIFIED: command output 2026-06-30]

## Risks and Edge Cases

- Missing config can be accidentally masked if implementation uses `Application.get_env(:chimeway, :prefix, "chimeway")` or `false`; use fetch-style semantics or explicit missing detection instead. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
- Setting `@schema_prefix` on schemas would outrank repo query prefix and make public legacy mode harder to reason about. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Query.html#module-query-prefix]
- `Repo.insert_all/3` with string table sources is a known Phase 75 risk because string sources do not carry schema metadata; later runtime propagation must pass prefix opts explicitly. [VERIFIED: lib/chimeway/trigger.ex:181] [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Repo.html#c:insert_all/3]
- Raw SQL in migrations will not be corrected by runtime repo opts; Phase 74 must qualify raw SQL explicitly. [VERIFIED: priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs] [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html#execute/1]
- Local verification is currently on PostgreSQL 14.17, below the project baseline of PostgreSQL 15+. [VERIFIED: `psql -Atqc 'SHOW server_version;'`] [VERIFIED: AGENTS.md]
- Oban startup can fail focused tests when the local `oban_jobs` table is absent; use `CHIMEWAY_SKIP_OBAN=1` for Phase 73 tests because Oban behavior is deferred. [VERIFIED: command output 2026-06-30] [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
- Public-schema docs must avoid teaching `prefix: false` as a convenient default; it is only an explicit legacy compatibility path. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Compile/test | yes | 1.19.5 local | Project baseline is 1.17+; CI should still cover supported baseline. [VERIFIED: `elixir --version`] |
| Erlang/OTP | Compile/test | yes | OTP 28 local | Project baseline is OTP 26+. [VERIFIED: `elixir --version`] |
| Mix | Aliases/tests | yes | 1.19.5 local | None needed. [VERIFIED: `mix --version`] |
| PostgreSQL server | DB-backed tests | yes | 14.17 local | Use CI/Postgres 15+ for baseline confidence. [VERIFIED: `psql -Atqc 'SHOW server_version;'`] |
| `pg_isready` | DB availability probe | yes | server accepting connections | None needed. [VERIFIED: `pg_isready`] |
| Ecto test database migrations | `migration_contract_test` | no | all migrations down | Run `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix ecto.migrate` before DB-backed tests. [VERIFIED: `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix ecto.migrations`] |

**Missing dependencies with no fallback:**
- PostgreSQL 15+ is not available locally; local server is PostgreSQL 14.17, so final confidence should come from CI or a PG15 environment. [VERIFIED: `psql -Atqc 'SHOW server_version;'`] [VERIFIED: AGENTS.md]

**Missing dependencies with fallback:**
- Local Oban table is absent; Phase 73 focused tests can set `CHIMEWAY_SKIP_OBAN=1` because Oban prefix behavior is out of scope. [VERIFIED: command output 2026-06-30]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix, local Mix 1.19.5. [VERIFIED: `mix --version`] |
| Config file | `test/test_helper.exs` starts ExUnit and configures SQL sandbox. [VERIFIED: test/test_helper.exs:1] |
| Quick run command | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/storage_test.exs --warnings-as-errors` [VERIFIED: existing test command pattern] |
| Full phase command | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs test/chimeway/doc_contract_test.exs test/chimeway/migration_contract_test.exs --warnings-as-errors` after test DB migrations are up. [VERIFIED: mix help output] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| PFX-01 | `"chimeway"` and `false` are the only valid runtime prefix values. | unit | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/storage_test.exs --warnings-as-errors` | no - Wave 0 should create it. [VERIFIED: `rg --files test/chimeway`] |
| PFX-02 | Invalid/missing config raises branded actionable `Chimeway.ConfigError` before children start. | unit | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/application_validation_test.exs --warnings-as-errors` | yes - extend existing file. [VERIFIED: test/chimeway/application_validation_test.exs:1] |
| PFX-03 | One helper maps storage config to repo options and preserves caller override. | unit | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/storage_test.exs --warnings-as-errors` | no - Wave 0 should create it. [VERIFIED: `rg --files test/chimeway`] |
| PFX-04 | Public-schema mode is explicit legacy compatibility. | contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/migration_contract_test.exs --warnings-as-errors` | yes - rename/extend. [VERIFIED: test/chimeway/migration_contract_test.exs:1] |
| UPG-01 | Docs state public mode does not move data automatically. | doc-contract | `CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | yes - extend existing file. [VERIFIED: test/chimeway/doc_contract_test.exs:1] |

### Sampling Rate

- **Per task commit:** run the focused file touched by that task. [VERIFIED: existing GSD verification style in prior phase plans]
- **Per wave merge:** run storage + application validation + doc contract focused suite. [VERIFIED: mix help output]
- **Phase gate:** run focused suite, `mix format --check-formatted`, and a PG15-backed CI equivalent before claiming storage-prefix contract confidence. [VERIFIED: AGENTS.md]

### Wave 0 Gaps

- [ ] `test/chimeway/storage_test.exs` - new helper/config unit contract. [VERIFIED: `rg --files test/chimeway`]
- [ ] Extend `test/chimeway/application_validation_test.exs` for boot-time prefix validation. [VERIFIED: test/chimeway/application_validation_test.exs:1]
- [ ] Extend `test/chimeway/doc_contract_test.exs` for prefix and legacy-public copy. [VERIFIED: test/chimeway/doc_contract_test.exs:1017]
- [ ] Rename/extend `test/chimeway/migration_contract_test.exs` so current public checks are intentional legacy mode. [VERIFIED: test/chimeway/migration_contract_test.exs:6]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Host owns auth; Phase 73 has no auth surface. [VERIFIED: AGENTS.md] |
| V3 Session Management | no | Phase 73 has no sessions. [VERIFIED: .planning/ROADMAP.md] |
| V4 Access Control | yes | Reject dynamic/per-tenant database prefixes so tenant identity remains domain data, not unvalidated storage routing. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |
| V5 Input Validation | yes | Strict normalizer accepts only `"chimeway"` and `false`; invalid config raises structured error. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |
| V6 Cryptography | no | Phase 73 has no cryptography. [VERIFIED: .planning/ROADMAP.md] |

### Known Threat Patterns for Storage Prefix Config

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tenant-derived prefix value changes storage target | Tampering / Information Disclosure | Reject functions, MFA, process-local values, arbitrary strings, and tenant-derived prefixes. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |
| Missing config silently writes public data | Information Disclosure / Tampering | Missing prefix config is invalid and fails early. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |
| Error messages hide the safe fix | Denial of Service | Error copy names accepted values and provides copy-paste config. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |
| Schema existence checked at boot | Denial of Service | Validate config shape only; migration/runtime phases prove schema existence. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] |

## Common Pitfalls

### Pitfall 1: Treating Runtime Default as New-Install Default

**What goes wrong:** Missing runtime config silently becomes `"chimeway"` or public. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]  
**Why it happens:** Installer/docs defaults and runtime validation defaults get conflated. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]  
**How to avoid:** Require explicit `config :chimeway, prefix: "chimeway"` or `prefix: false`. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]  
**Warning signs:** `Application.get_env(:chimeway, :prefix, ...)` with a default. [VERIFIED: lib/chimeway/application.ex:42]

### Pitfall 2: Using Schema Prefixes Instead of Repo Options

**What goes wrong:** `@schema_prefix` makes public legacy opt-out surprising because it outranks query prefix. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Query.html#module-query-prefix]  
**Why it happens:** Ecto has multiple prefix mechanisms with precedence rules. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Query.html#module-query-prefix]  
**How to avoid:** Use one runtime repo option helper as the primary contract. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]  
**Warning signs:** New `@schema_prefix "chimeway"` in Chimeway schemas. [VERIFIED: `rg "@schema_prefix|schema_prefix" lib test priv config guides README.md`]

### Pitfall 3: Partially Propagating Runtime Prefix in Phase 73

**What goes wrong:** Some runtime paths start using the helper while others continue public, creating split-brain tests and misleading partial support. [VERIFIED: `rg "Repo\\." lib/chimeway`]  
**Why it happens:** The repo has many direct `Repo.*` calls across trigger, inbox, deliveries, workflows, digests, webhooks, admin, and workers. [VERIFIED: `rg "Repo\\." lib/chimeway`]  
**How to avoid:** Keep Phase 73 to helper and contract tests; Phase 75 owns propagation. [VERIFIED: .planning/ROADMAP.md]  
**Warning signs:** Phase 73 modifies `lib/chimeway/trigger.ex`, `lib/chimeway/inbox.ex`, or worker modules for prefix propagation. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

## Code Examples

### Internal Helper Use in a Later Context

```elixir
# Source: recommended pattern from Chimeway.Admin option filtering and Ecto Repo prefix docs.
defp repo_opts(opts) do
  opts
  |> Keyword.drop([:limit, :tenant_id, :recipient_id, :now, :older_than])
  |> Chimeway.Storage.repo_opts()
end
```

This exact pattern is for Phase 75 propagation, but Phase 73 should create and test the helper now. [VERIFIED: lib/chimeway/admin.ex:318] [VERIFIED: .planning/ROADMAP.md]

### Public Legacy Microcopy

```text
Use prefix: false only for an existing install whose Chimeway tables already live in public.
This keeps using those unprefixed tables and does not move data.
```

This copy is recommended by phase context and should be locked with doc-contract tests. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

## State of the Art

| Current Approach | Phase 73 Approach | Later Phase | Impact |
|------------------|-------------------|-------------|--------|
| Public-schema behavior is implicit in migrations/tests/docs. [VERIFIED: test/chimeway/migration_contract_test.exs:28] | Public mode is explicit `prefix: false` legacy mode. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] | Phase 74/75 | Prevents accidental public writes from being treated as default new-install behavior. [VERIFIED: .planning/REQUIREMENTS.md] |
| Runtime DB calls mostly omit repo options. [VERIFIED: `rg "Repo\\." lib/chimeway`] | One helper contract exists but broad propagation is deferred. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] | Phase 75 | Avoids partial runtime support. [VERIFIED: .planning/ROADMAP.md] |
| Migration generator only copies and namespace-rewrites templates. [VERIFIED: lib/chimeway/install/migrations.ex:82] | Generator behavior remains unchanged except docs/tests can describe legacy mode. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md] | Phase 74 | Keeps copied migration changes deterministic and isolated. [VERIFIED: .planning/ROADMAP.md] |

**Deprecated/outdated for Phase 73:**
- Treating `public` as the accidental default storage mode is outdated; it should be explicit legacy mode. [VERIFIED: .planning/REQUIREMENTS.md]
- Teaching runtime `"public"` as a prefix string is out of contract; use `false`. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

## Assumptions Log

All claims in this research were verified from local files, command output, phase context, or official documentation. No `[ASSUMED]` claims are used.

## Open Questions (RESOLVED)

1. **RESOLVED: None blocking; exact helper names are implementation-local.**
   - What we know: Phase context locks the public API shape, helper boundary, error shape, phase deferrals, and tests to add. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
   - What's unclear: Exact function names beyond `Chimeway.Storage.repo_opts/1` are implementation-local. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
   - Recommendation: Keep names boring and follow the context unless a compile conflict appears. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]

## Sources

### Primary (Local / HIGH Confidence)

- `AGENTS.md` - project constraints, stack, quality gates, build principles. [VERIFIED: AGENTS.md]
- `.planning/REQUIREMENTS.md` - PFX/UPG requirements. [VERIFIED: .planning/REQUIREMENTS.md]
- `.planning/ROADMAP.md` - Phase 73 boundary and Phase 74-76 deferrals. [VERIFIED: .planning/ROADMAP.md]
- `.planning/phases/73-storage-prefix-contract/73-CONTEXT.md` - locked decisions and deferred work. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
- `lib/chimeway/application.ex` - boot validation pattern. [VERIFIED: lib/chimeway/application.ex:9]
- `lib/chimeway/install/migrations.ex` and `lib/mix/tasks/chimeway.gen.migrations.ex` - current installer behavior. [VERIFIED: lib/chimeway/install/migrations.ex:64]
- `lib/chimeway/traces.ex`, `lib/chimeway/admin.ex`, `lib/chimeway/trigger.ex`, `lib/chimeway/inbox.ex` - repo option patterns and later propagation touch points. [VERIFIED: lib/chimeway/traces.ex:47]
- `test/chimeway/application_validation_test.exs`, `test/chimeway/migration_contract_test.exs`, `test/chimeway/doc_contract_test.exs` - current tests to extend. [VERIFIED: test/chimeway/application_validation_test.exs:1]

### Official Docs (MEDIUM Confidence)

- Ecto Repo 3.13.6 - repo operation `:prefix` options. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Repo.html]
- Ecto Query 3.13.6 - query prefix behavior and precedence. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Query.html#module-query-prefix]
- Ecto SQL 3.13.5 Migration - table/index/reference prefixes and `execute/1`. [CITED: https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html]
- Elixir Application 1.17.3 - app env APIs and `start/2` callback. [CITED: https://hexdocs.pm/elixir/1.17.3/Application.html]
- Elixir Config 1.17.3 - `config/2`, `config/3`, and runtime config docs. [CITED: https://hexdocs.pm/elixir/1.17.3/Config.html]

### Command Evidence

- `mix deps`, `mix.lock`, `elixir --version`, `mix --version`, `psql -Atqc 'SHOW server_version;'`, `pg_isready`, `mix help`, focused `mix test`, and `mix ecto.migrations` were run on 2026-06-30. [VERIFIED: command output]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions came from `mix.lock`, `mix deps`, and local tool commands. [VERIFIED: mix.lock]
- Architecture: HIGH - phase context and codebase both point to boot validation plus one internal helper. [VERIFIED: .planning/phases/73-storage-prefix-contract/73-CONTEXT.md]
- Ecto semantics: MEDIUM - sourced from official HexDocs for locked Ecto/Ecto SQL versions. [CITED: https://hexdocs.pm/ecto/3.13.6/Ecto.Query.html#module-query-prefix]
- Pitfalls: HIGH - risks are visible in local code and locked phase deferrals. [VERIFIED: `rg "Repo\\." lib/chimeway`]

**Research date:** 2026-06-30  
**Valid until:** 2026-07-30 for local code findings; re-check HexDocs if Ecto/Ecto SQL versions change. [VERIFIED: mix.lock]
