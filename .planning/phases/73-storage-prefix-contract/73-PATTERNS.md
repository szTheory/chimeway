# Phase 73: Storage Prefix Contract - Pattern Map

**Mapped:** 2026-06-30  
**Files analyzed:** 11 new/modified files  
**Analogs found:** 11 / 11  
**Scope:** Contract-only storage prefix validation, internal repo option helper, public-legacy docs/tests. Do not change migration template prefixing, generator CLI flags, broad runtime propagation, Oban config, or demo-host behavior in this phase.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/chimeway/config_error.ex` | utility | transform | `lib/chimeway/dispatch/oban_worker.ex`; `lib/chimeway/install/migrations.ex` | role-match |
| `lib/chimeway/storage.ex` | utility | transform | `lib/chimeway/traces.ex`; `lib/chimeway/admin.ex` | role-match |
| `lib/chimeway/application.ex` | provider | event-driven | `lib/chimeway/application.ex` | exact |
| `config/config.exs` | config | request-response | `config/config.exs`; `config/test.exs` | exact |
| `test/chimeway/storage_test.exs` | test | transform | `test/chimeway/application_validation_test.exs`; `test/chimeway/traces_test.exs` | role-match |
| `test/chimeway/application_validation_test.exs` | test | event-driven | `test/chimeway/application_validation_test.exs` | exact |
| `test/chimeway/doc_contract_test.exs` | test | file-I/O | `test/chimeway/doc_contract_test.exs` | exact |
| `test/chimeway/migration_contract_test.exs` | test | file-I/O | `test/chimeway/migration_contract_test.exs` | exact |
| `README.md` | docs | file-I/O | `README.md`; `test/chimeway/doc_contract_test.exs` | exact |
| `guides/introduction/installation.md` | docs | file-I/O | `guides/introduction/installation.md`; `test/chimeway/doc_contract_test.exs` | exact |
| `guides/introduction/golden-path.md` | docs | file-I/O | `guides/introduction/golden-path.md`; `test/chimeway/doc_contract_test.exs` | exact |

## Pattern Assignments

### `lib/chimeway/config_error.ex` (utility, transform)

**Analog:** `lib/chimeway/dispatch/oban_worker.ex` for structured exception fields; `lib/chimeway/install/migrations.ex` for local installer/config-adjacent errors.

**Structured exception pattern** (`lib/chimeway/dispatch/oban_worker.ex` lines 2-22):

```elixir
defmodule Chimeway.Dispatch.UnhandledOutcomeError do
  @moduledoc """
  Raised by `Chimeway.Dispatch.ObanWorker` when `map_outcome_to_oban_return/4`
  encounters a (outcome, error_class, status) shape that none of the documented
  clauses match AND the in-band convergence guard cannot legally fire (delivery
  is not in :failed status, or this is not the final attempt). This is the
  loud-failure branch of the BL-02 fix - see Plan 14-10.

  The exception carries enough metadata for an operator to reproduce the
  scenario and extend either `Executor.classify/1` or the documented worker
  clauses.
  """
  defexception [
    :message,
    :delivery_id,
    :outcome,
    :error_class,
    :status,
    :attempt,
    :max_attempts
  ]
```

**Exception builder pattern** (`lib/chimeway/dispatch/oban_worker.ex` lines 24-48):

```elixir
@impl true
def exception(opts) do
  delivery_id = Keyword.fetch!(opts, :delivery_id)
  outcome = Keyword.fetch!(opts, :outcome)
  error_class = Keyword.fetch!(opts, :error_class)
  status = Keyword.fetch!(opts, :status)
  attempt = Keyword.fetch!(opts, :attempt)
  max_attempts = Keyword.fetch!(opts, :max_attempts)

  message =
    "unhandled delivery outcome shape (BL-02): " <>
      "delivery_id=#{inspect(delivery_id)} outcome=#{inspect(outcome)} " <>
      "error_class=#{inspect(error_class)} status=#{inspect(status)} " <>
      "attempt=#{attempt}/#{max_attempts}"

  %__MODULE__{
    message: message,
    delivery_id: delivery_id,
    outcome: outcome,
    error_class: error_class,
    status: status,
    attempt: attempt,
    max_attempts: max_attempts
  }
end
```

**Local error-module pattern** (`lib/chimeway/install/migrations.ex` lines 12-35):

```elixir
defmodule RepoMissingError do
  defexception message: "repo_missing"
end

defmodule UmbrellaRootError do
  defexception message: "umbrella_root"
end

defmodule DuplicateSlugError do
  defexception [:message, :slug, :paths]

  @impl true
  def exception(opts) do
    slug = Keyword.fetch!(opts, :slug)
    paths = Keyword.fetch!(opts, :paths)

    %__MODULE__{
      message:
        "duplicate migration slug #{inspect(slug)}: #{Enum.join(paths, ", ")}. " <>
          "Remove duplicate files before re-running the installer.",
      slug: slug,
      paths: paths
    }
  end
end
```

**Apply to Phase 73:** Create a top-level `Chimeway.ConfigError`, not a nested module. Copy the `defexception` plus `exception/1` field-population style. Required stable fields are `:type`, `:key`, `:value`, and `:message`; invalid prefix raises should use `type: :invalid_prefix`, `key: :prefix`, and the rejected value, including a sentinel such as `:missing` for absent config.

### `lib/chimeway/storage.ex` (utility, transform)

**Analog:** `lib/chimeway/traces.ex` for repo option pass-through/filtering; `lib/chimeway/admin.ex` for context-private repo option filtering.

**Imports and alias pattern** (`lib/chimeway/traces.ex` lines 31-36):

```elixir
import Ecto.Query

alias Chimeway.{Delivery, Events.Event, Notifications.Notification, Repo}
alias Chimeway.Digests.DigestMembership
alias Chimeway.Traces.Explanation
alias Chimeway.Workflows.{WorkflowRun, WorkflowStep, WorkflowTransition}
```

`Chimeway.Storage` should not need Ecto imports. Keep the module internal with `@moduledoc false`, and only alias `Chimeway.ConfigError` if it improves readability.

**Repo option filtering pattern** (`lib/chimeway/traces.ex` lines 67-90):

```elixir
@spec find_traces_for_recipient(String.t(), keyword()) :: [Notification.t()]
def find_traces_for_recipient(recipient_id, opts \\ []) do
  limit = Keyword.get(opts, :limit, 50)
  notification_key = Keyword.get(opts, :notification_key)
  repo_opts = Keyword.drop(opts, [:limit, :notification_key])

  query =
    from(n in Notification,
      join: e in Event,
      on: e.id == n.event_id,
      where: n.recipient_identity == ^recipient_id,
      order_by: [desc: n.inserted_at],
      limit: ^limit,
      preload: [deliveries: :attempts, event: []]
    )

  query =
    if notification_key do
      from([n, e] in query, where: e.notification_key == ^notification_key)
    else
      query
    end

  Repo.all(query, repo_opts)
end
```

**Context-private helper pattern** (`lib/chimeway/admin.ex` lines 318-320):

```elixir
defp repo_opts(opts) do
  Keyword.drop(opts, [:limit, :tenant_id, :recipient_id, :now, :older_than])
end
```

**Direct pass-through pattern** (`lib/chimeway/traces.ex` lines 45-54):

```elixir
@spec get_trace(String.t(), keyword()) :: {:ok, Event.t()} | {:error, :not_found}
def get_trace(event_id, opts \\ []) do
  case Repo.get(Event, event_id, opts) do
    nil ->
      {:error, :not_found}

    event ->
      loaded = Repo.preload(event, [notifications: [deliveries: :attempts]], opts)
      {:ok, loaded}
  end
end
```

**Apply to Phase 73:** `Chimeway.Storage.repo_opts/1` should accept keyword opts, validate the configured prefix, then add the configured prefix with `Keyword.put_new/3`. It must preserve explicit caller `:prefix` and return the original opts unchanged when configured with `prefix: false`. Do not add schema existence checks, process dictionary state, per-tenant prefixes, `@schema_prefix`, or runtime propagation in this phase.

### `lib/chimeway/application.ex` (provider, event-driven)

**Analog:** self.

**Boot validation before children** (`lib/chimeway/application.ex` lines 8-20):

```elixir
@impl true
def start(_type, _args) do
  validate_channel_render_modules!()

  children =
    [
      Chimeway.Repo
    ] ++ oban_child()

  # See https://hexdocs.pm/elixir/Supervisor.html
  # for other strategies and supported options
  opts = [strategy: :one_for_one, name: Chimeway.Supervisor]
  Supervisor.start_link(children, opts)
end
```

**Shape validation pattern** (`lib/chimeway/application.ex` lines 41-65):

```elixir
def validate_channel_render_modules! do
  registry = Application.get_env(:chimeway, :channel_render_modules, %{})

  Enum.each(registry, fn {channel, module} ->
    cond do
      not is_atom(module) ->
        raise ArgumentError,
              "[chimeway] :channel_render_modules[#{inspect(channel)}] must be a module atom, " <>
                "got: #{inspect(module)}"

      not Code.ensure_loaded?(module) ->
        raise ArgumentError,
              "[chimeway] :channel_render_modules[#{inspect(channel)}] module #{inspect(module)} " <>
                "could not be loaded"

      not function_exported?(module, :validate, 1) ->
        raise ArgumentError,
              "[chimeway] :channel_render_modules[#{inspect(channel)}] module #{inspect(module)} " <>
                "does not export validate/1"

      true ->
        :ok
    end
  end)
end
```

**Apply to Phase 73:** Add a call to `Chimeway.Storage.validate_prefix!/0` in `start/2` before `children` are constructed and before Repo/Oban are started. Use the same early, deterministic validation style, but raise `Chimeway.ConfigError` instead of `ArgumentError` for prefix errors.

### `config/config.exs` (config, request-response)

**Analog:** self plus `config/test.exs`.

**Top-level Chimeway app config pattern** (`config/config.exs` lines 1-12):

```elixir
import Config

config :chimeway,
  ecto_repos: [Chimeway.Repo],
  time_zone_database: Tzdata.TimeZoneDatabase,
  dispatcher: Chimeway.Dispatch.Sync

config :chimeway, Oban,
  repo: Chimeway.Repo,
  queues: [chimeway_delivery: 10, chimeway_signals: 5]

import_config "#{config_env()}.exs"
```

**Environment-specific repo config pattern** (`config/test.exs` lines 20-29):

```elixir
config :chimeway, Chimeway.Repo, repo_config

if System.get_env("CHIMEWAY_SKIP_OBAN") in ["1", "true"] do
  config :chimeway, Oban, nil
else
  config :chimeway, Oban,
    repo: Chimeway.Repo,
    testing: :manual,
    queues: [chimeway_delivery: 10, chimeway_signals: 5]
end
```

**Apply to Phase 73:** Add explicit `prefix: false` for this repo's current public-schema test/dev behavior unless the planner intentionally chooses environment-specific config. Do not hide runtime missing config with a default in `Chimeway.Storage`; the application env must be explicit.

### `test/chimeway/storage_test.exs` (test, transform)

**Analog:** `test/chimeway/application_validation_test.exs` for global app env tests; `test/chimeway/traces_test.exs` for repo prefix option proof.

**Async false and env restoration pattern** (`test/chimeway/application_validation_test.exs` lines 14-31):

```elixir
use ExUnit.Case, async: false

describe "validate_channel_render_modules!/0" do
  test "raises ArgumentError for non-existent module (D-13)" do
    original = Application.get_env(:chimeway, :channel_render_modules)

    Application.put_env(
      :chimeway,
      :channel_render_modules,
      %{"custom" => Chimeway.NonExistent.Channel}
    )

    on_exit(fn ->
      case original do
        nil -> Application.delete_env(:chimeway, :channel_render_modules)
        val -> Application.put_env(:chimeway, :channel_render_modules, val)
      end
    end)
```

**Error assertion pattern** (`test/chimeway/application_validation_test.exs` lines 33-35):

```elixir
assert_raise ArgumentError, ~r/could not be loaded/, fn ->
  :erlang.apply(Chimeway.Application, :validate_channel_render_modules!, [])
end
```

**Prefix option proof pattern** (`test/chimeway/traces_test.exs` lines 993-1025):

```elixir
describe "opts propagation" do
  test "get_trace/2 passes opts to Repo" do
    assert_raise Postgrex.Error,
                 ~r/relation "nonexistent_schema.chimeway_events" does not exist/,
                 fn ->
                   Traces.get_trace(Ecto.UUID.generate(), prefix: "nonexistent_schema")
                 end
  end

  test "find_traces_for_recipient/2 passes opts to Repo" do
    assert_raise Postgrex.Error,
                 ~r/relation "nonexistent_schema.chimeway_notifications" does not exist/,
                 fn ->
                   Traces.find_traces_for_recipient("user:123", prefix: "nonexistent_schema")
                 end
  end

  test "find_traces_by_correlation_id/2 passes opts to Repo" do
    assert_raise Postgrex.Error,
                 ~r/relation "nonexistent_schema.chimeway_events" does not exist/,
                 fn ->
                   Traces.find_traces_by_correlation_id("req-xyz", prefix: "nonexistent_schema")
                 end
  end

  test "explain_delivery/2 passes opts to Repo" do
    assert_raise Postgrex.Error,
                 ~r/relation "nonexistent_schema.chimeway_deliveries" does not exist/,
                 fn ->
                   Traces.explain_delivery(Ecto.UUID.generate(), prefix: "nonexistent_schema")
                 end
  end
end
```

**Apply to Phase 73:** Create focused unit tests for `Chimeway.Storage.validate_prefix!/0` and `repo_opts/1`: valid `"chimeway"`, valid `false`, missing config, `nil`, `"public"`, arbitrary strings, function values, MFA-like tuples, `false` mapping to no `:prefix`, `"chimeway"` mapping to `[prefix: "chimeway"]`, and caller `prefix:` preservation through `Keyword.put_new/3`. Prefer assertions on `Chimeway.ConfigError` fields plus stable phrases rather than full message equality.

### `test/chimeway/application_validation_test.exs` (test, event-driven)

**Analog:** self.

**Module/test isolation pattern** (`test/chimeway/application_validation_test.exs` lines 1-16):

```elixir
defmodule Chimeway.ApplicationValidationTest do
  @moduledoc """
  Tests D-13: validate_channel_render_modules!/0 raises at boot for invalid modules.

  The validate_channel_render_modules!/0 function is private. Tests reach it via
  :erlang.apply/3 which bypasses Elixir compile-time visibility checks but invokes
  the BEAM-level function dispatch - the function is fully exported at the BEAM
  level for any private/public Elixir function.

  These tests mutate global :channel_render_modules application env, so async: false
  is required.
  """

  use ExUnit.Case, async: false

  describe "validate_channel_render_modules!/0" do
```

**Successful validation assertion** (`test/chimeway/application_validation_test.exs` lines 61-75):

```elixir
test "passes silently when :channel_render_modules is empty (D-13)" do
  original = Application.get_env(:chimeway, :channel_render_modules)
  Application.put_env(:chimeway, :channel_render_modules, %{})

  on_exit(fn ->
    case original do
      nil -> Application.delete_env(:chimeway, :channel_render_modules)
      val -> Application.put_env(:chimeway, :channel_render_modules, val)
    end
  end)

  # Empty registry must not raise - call returns :ok-equivalent (Enum.each returns :ok)
  assert :ok =
           :erlang.apply(Chimeway.Application, :validate_channel_render_modules!, [])
end
```

**Apply to Phase 73:** Extend this file with boot-validation coverage for prefix config. Keep `async: false`; save and restore `Application.get_env(:chimeway, :prefix)` in every test. Assert that invalid/missing config raises `Chimeway.ConfigError` before children are started by directly calling the public validation function or, if planner chooses, by exercising `Chimeway.Application.start/2` with Oban skipped.

### `test/chimeway/doc_contract_test.exs` (test, file-I/O)

**Analog:** self.

**Doc file setup pattern** (`test/chimeway/doc_contract_test.exs` lines 980-986):

```elixir
@golden_path_guide "guides/introduction/golden-path.md"

describe "golden path doc contract (DOCS-01 / GATE-01)" do
  setup do
    content = File.read!(@golden_path_guide)
    %{content: content}
  end
```

**Required-string loop pattern** (`test/chimeway/doc_contract_test.exs` lines 1016-1030):

```elixir
@required ~w(
  mix chimeway.gen.migrations
  Chimeway.trigger
  idempotency_key
  tenant_id
  Chimeway.Traces.explain_delivery
  installation.md
)

for required <- @required do
  test "requires #{required} in golden path guide", %{content: content} do
    assert String.contains?(content, unquote(required)),
           "golden path guide must reference #{unquote(required)}"
  end
end
```

**Installation guide contract pattern** (`test/chimeway/doc_contract_test.exs` lines 1049-1095):

```elixir
@installation_guide "guides/introduction/installation.md"

describe "installation doc contract (GATE-01)" do
  setup do
    content = File.read!(@installation_guide)
    %{content: content}
  end

  for forbidden <- @adoption_forbidden_strings do
    test "forbids #{forbidden} in installation guide", %{content: content} do
      refute String.contains?(content, unquote(forbidden)),
             "installation guide must not reference #{unquote(forbidden)}"
    end
  end
```

**README contract pattern** (`test/chimeway/doc_contract_test.exs` lines 1097-1144):

```elixir
describe "README install doc contract (GATE-01)" do
  setup do
    content = File.read!("README.md")
    %{content: content}
  end

  for forbidden <- @adoption_forbidden_strings do
    test "forbids #{forbidden} in README", %{content: content} do
      refute String.contains?(content, unquote(forbidden)),
             "README must not reference #{unquote(forbidden)}"
    end
  end
```

**Apply to Phase 73:** Add required-string assertions for the two accepted runtime config snippets and the public legacy microcopy. Lock stable phrases such as `prefix: "chimeway"`, `prefix: false`, `existing install`, `public`, `unprefixed tables`, and `does not move data`. Avoid testing long prose verbatim.

### `test/chimeway/migration_contract_test.exs` (test, file-I/O)

**Analog:** self.

**Public table contract pattern** (`test/chimeway/migration_contract_test.exs` lines 1-14):

```elixir
defmodule Chimeway.MigrationContractTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.Repo

  test "events and notifications tables exist with required named indexes" do
    assert regclass("chimeway_events")
    assert regclass("chimeway_notifications")

    assert regclass("chimeway_events_idempotency_key_index")

    assert regclass("chimeway_notifications_event_recipient_index")
    assert regclass("chimeway_notifications_inbox_read_inserted_index")
  end
```

**Raw SQL public-schema proof** (`test/chimeway/migration_contract_test.exs` lines 25-48):

```elixir
defp regclass(name) do
  sql = "SELECT to_regclass($1)"

  case Ecto.Adapters.SQL.query!(Repo, sql, ["public." <> name]).rows do
    [[nil]] -> nil
    [[value]] -> value
  end
end

defp workflow_runs_column(column_name) do
  sql = """
  SELECT is_nullable = 'YES', data_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'chimeway_workflow_runs'
    AND column_name = $1
  """

  case Ecto.Adapters.SQL.query!(Repo, sql, [column_name]).rows do
    [[is_nullable, data_type]] -> {is_nullable, data_type}
    _ -> nil
  end
end
```

**Apply to Phase 73:** Rename or extend tests so the current `public` checks are framed as "legacy public-schema compatibility". Do not change migration templates or expect `chimeway` schema output in this phase.

### `README.md` (docs, file-I/O)

**Analog:** self plus README doc-contract tests.

**Current install snippet location** (`README.md` lines 20-30):

````markdown
Then run:

```bash
mix deps.get
mix chimeway.gen.migrations
mix ecto.migrate
```

## Quick Start

Follow the [Golden Path guide](guides/introduction/golden-path.md) for install, notifier setup, and your first explainable trace.
````

**Contract test analog** (`test/chimeway/doc_contract_test.exs` lines 1097-1100, 1127-1144):

```elixir
describe "README install doc contract (GATE-01)" do
  setup do
    content = File.read!("README.md")
    %{content: content}
  end

  @required ~w(
    mix chimeway.gen.migrations
    Chimeway.trigger
    idempotency_key
    tenant_id
    golden-path
    guides/introduction/mailglass-integration.md
    guides/introduction/accrue-dunning-integration.md
    guides/introduction/inbox-integration.md
  )
```

**Apply to Phase 73:** Add a compact runtime config block near installation that shows `config :chimeway, prefix: "chimeway"` for new schema-isolated installs and `config :chimeway, prefix: false` only for existing public-schema legacy installs. Keep README short and link details to the guides.

### `guides/introduction/installation.md` (docs, file-I/O)

**Analog:** self plus installation doc-contract tests.

**Current configuration pattern** (`guides/introduction/installation.md` lines 41-52):

````markdown
## 3. Configuration

You need to configure Chimeway to use your application's Ecto Repo. Add the following to your `config/config.exs` (or `config/dev.exs` / `config/prod.exs` as appropriate):

```elixir
config :chimeway,
  repo: MyApp.Repo
```

Replace `MyApp.Repo` with the actual name of your application's Repo module.

At runtime, Chimeway queries through `Chimeway.Repo`. Configure it to use the same database where your host migrations created the `chimeway_*` tables - see [Golden Path §3](golden-path.md#3-configure-chimeway) for the full shared-database setup.
````

**Apply to Phase 73:** Expand the existing configuration section rather than adding a new standalone storage doc. Include the accepted prefix values, copy-paste snippets, and public legacy warning. Do not discuss Ecto internals or migration-template prefixing beyond what Phase 73 supports.

### `guides/introduction/golden-path.md` (docs, file-I/O)

**Analog:** self plus golden-path doc-contract tests.

**Current setup and config flow** (`guides/introduction/golden-path.md` lines 25-62):

````markdown
## 2. Install database schema

Chimeway stores the durable lifecycle spine (`event` -> `notification` -> `delivery` -> `attempt`) in your database. Generate and run migrations:

```bash
mix chimeway.gen.migrations
mix ecto.migrate
```

For more detail on migration generation, see [Installation §2](installation.md#2-generate-and-run-migrations).

## 3. Configure Chimeway

You need two configuration pieces: one for the **installer** task and one for **runtime queries**.

**Installer (migration generator):**

```elixir
config :chimeway,
  repo: MyApp.Repo
```

Replace `MyApp.Repo` with your host application's Ecto repo module. This tells `mix chimeway.gen.migrations` where to copy migration files.

**Runtime (Chimeway.Repo):**

```elixir
config :chimeway, Chimeway.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "my_app_dev",
  pool_size: 10
```

At runtime, Chimeway queries through `Chimeway.Repo`. Configure it to use the **same database** where your host migrations created the `chimeway_*` tables - not a separate database unless you intentionally run Chimeway on its own Postgres instance.
````

**Apply to Phase 73:** Add the storage-prefix choice to section 3, keeping it adopter-facing: "new isolated Chimeway schema" versus "existing public-schema legacy install". Do not claim generated migrations are prefixed yet; Phase 74 owns that.

## Shared Patterns

### Early Boot Validation

**Source:** `lib/chimeway/application.ex` lines 8-20 and 41-65  
**Apply to:** `lib/chimeway/application.ex`, `lib/chimeway/storage.ex`, `test/chimeway/application_validation_test.exs`

Call validation before Repo/Oban children are built. Validate config shape only, not database schema existence. Error messages should be actionable and branded with `[chimeway]`.

### App Env Test Isolation

**Source:** `test/chimeway/application_validation_test.exs` lines 14-31; `test/chimeway/install/migrations_test.exs` lines 115-130 and 190-199  
**Apply to:** `test/chimeway/storage_test.exs`, `test/chimeway/application_validation_test.exs`

Use `async: false`, snapshot the original app env, mutate with `Application.put_env/3` or `delete_env/2`, and restore in `on_exit`.

### Structured Config Errors

**Source:** `lib/chimeway/dispatch/oban_worker.ex` lines 14-48  
**Apply to:** `lib/chimeway/config_error.ex`, storage/application validation tests

Use `defexception` fields and a custom `exception/1` builder. Tests should assert structured fields (`type`, `key`, `value`) plus stable phrases, not the entire message.

### Repo Option Filtering and Prefix Preservation

**Source:** `lib/chimeway/traces.ex` lines 67-90, 101-121, 194-205; `lib/chimeway/admin.ex` lines 318-320  
**Apply to:** `lib/chimeway/storage.ex`, `test/chimeway/storage_test.exs`

Drop non-Repo domain options in context helpers, but centralize prefix construction in `Chimeway.Storage.repo_opts/1`. The storage helper should use `Keyword.put_new/3` so explicit caller `prefix:` wins.

### Doc Contract Tests

**Source:** `test/chimeway/doc_contract_test.exs` lines 980-1144  
**Apply to:** README, installation, golden path, and doc-contract updates

Read target docs with `File.read!/1`, use required/forbidden string loops, and assert stable short phrases. Do not assert full paragraphs.

### Public Legacy Migration Contract

**Source:** `test/chimeway/migration_contract_test.exs` lines 25-48  
**Apply to:** `test/chimeway/migration_contract_test.exs`

Preserve current `public` checks as legacy compatibility proof. The test name and messages should make clear this is intentional public-schema support, not the default new-install migration behavior.

## No Analog Found

None. Exact analogs exist for boot validation, config files, doc contracts, and migration contracts. `Chimeway.ConfigError` and `Chimeway.Storage` have role-match analogs but no exact same-purpose predecessor; use the assigned structured-exception and repo-option patterns above.

## Metadata

**Analog search scope:** `lib/`, `test/`, `config/`, `guides/`, `README.md`  
**Files scanned:** 247 files from `rg --files lib test config guides README.md`  
**Primary analog files read:** `lib/chimeway/application.ex`, `lib/chimeway/dispatch/oban_worker.ex`, `lib/chimeway/install/migrations.ex`, `lib/chimeway/traces.ex`, `lib/chimeway/admin.ex`, `config/config.exs`, `config/test.exs`, `test/chimeway/application_validation_test.exs`, `test/chimeway/traces_test.exs`, `test/chimeway/install/migrations_test.exs`, `test/chimeway/doc_contract_test.exs`, `test/chimeway/migration_contract_test.exs`, `README.md`, `guides/introduction/installation.md`, `guides/introduction/golden-path.md`  
**Pattern extraction date:** 2026-06-30
