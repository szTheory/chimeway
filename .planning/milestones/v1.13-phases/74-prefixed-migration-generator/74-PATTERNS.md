# Phase 74: Prefixed Migration Generator - Pattern Map

**Mapped:** 2026-06-30
**Files analyzed:** 50 logical targets
**Analogs found:** 50 / 50 (2 patterns lack exact Chimeway-owned analogs)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/mix/tasks/chimeway.gen.migrations.ex` | task/config | request-response | `lib/mix/tasks/chimeway.gen.migrations.ex`; `lib/mix/tasks/preview_rendering.ex` for strict switches | exact + role-match |
| `lib/chimeway/install/migrations.ex` | service/utility | file-I/O, transform | `lib/chimeway/install/migrations.ex` | exact |
| `priv/chimeway_migrations/001_create_chimeway_events.exs` | migration template | CRUD, raw SQL setup | self; `chimeway_inbox/deps/oban/lib/oban/migrations/postgres/v01.ex` for prefix/create-schema partial | exact + partial |
| `priv/chimeway_migrations/002_create_chimeway_notifications.exs` | migration template | CRUD | `priv/chimeway_migrations/001_create_chimeway_events.exs`; current file | exact |
| `priv/chimeway_migrations/003_create_chimeway_deliveries.exs` | migration template | CRUD | self | exact |
| `priv/chimeway_migrations/004_create_chimeway_delivery_attempts.exs` | migration template | CRUD | `priv/chimeway_migrations/003_create_chimeway_deliveries.exs`; current file | exact |
| `priv/chimeway_migrations/005_create_chimeway_notification_preferences.exs` | migration template | CRUD | `priv/chimeway_migrations/001_create_chimeway_events.exs`; current file | exact |
| `priv/chimeway_migrations/006_add_correlation_id_to_chimeway_events.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/007_create_chimeway_category_preferences.exs` | migration template | CRUD | `priv/chimeway_migrations/001_create_chimeway_events.exs`; current file | exact |
| `priv/chimeway_migrations/008_create_chimeway_policy_settings.exs` | migration template | CRUD | `priv/chimeway_migrations/001_create_chimeway_events.exs`; current file | exact |
| `priv/chimeway_migrations/009_add_attempt_history_columns.exs` | migration template | CRUD, raw SQL transform | self | exact |
| `priv/chimeway_migrations/010_add_delivery_orchestration_fields_to_chimeway_deliveries.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/011_add_time_zone_to_chimeway_policy_settings.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/012_create_chimeway_digest_rules.exs` | migration template | CRUD | `priv/chimeway_migrations/001_create_chimeway_events.exs`; current file | exact |
| `priv/chimeway_migrations/013_create_chimeway_digest_buckets.exs` | migration template | CRUD | `priv/chimeway_migrations/003_create_chimeway_deliveries.exs`; current file | exact |
| `priv/chimeway_migrations/014_create_chimeway_digest_memberships.exs` | migration template | CRUD | `priv/chimeway_migrations/003_create_chimeway_deliveries.exs`; current file | exact |
| `priv/chimeway_migrations/015_alter_chimeway_digest_buckets_for_emission.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/016_alter_chimeway_digest_memberships_for_resolution.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/017_alter_chimeway_deliveries_for_digest_outcome.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/018_add_rendering_contract_fields.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/019_add_render_channels_to_chimeway_notifications.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/020_add_orchestration_snapshot_to_chimeway_notifications.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/021_create_chimeway_workflow_definitions.exs` | migration template | CRUD | `priv/chimeway_migrations/001_create_chimeway_events.exs`; current file | exact |
| `priv/chimeway_migrations/022_create_chimeway_workflow_steps.exs` | migration template | CRUD | `priv/chimeway_migrations/003_create_chimeway_deliveries.exs`; current file | exact |
| `priv/chimeway_migrations/023_add_workflow_definition_id_to_chimeway_notifications.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/024_create_chimeway_workflow_runs.exs` | migration template | CRUD | `priv/chimeway_migrations/003_create_chimeway_deliveries.exs`; current file | exact |
| `priv/chimeway_migrations/025_create_chimeway_workflow_transitions.exs` | migration template | CRUD | `priv/chimeway_migrations/003_create_chimeway_deliveries.exs`; current file | exact |
| `priv/chimeway_migrations/026_alter_chimeway_deliveries_for_workflow_linkage.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/027_create_chimeway_signals_and_spine.exs` | migration template | CRUD, raw SQL transform | self | exact |
| `priv/chimeway_migrations/028_add_adapter_module_to_chimeway_delivery_attempts.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/029_add_provider_message_id_to_delivery_attempts.exs` | migration template | CRUD | `priv/chimeway_migrations/009_add_attempt_history_columns.exs`; current file | exact |
| `priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs` | migration template | CRUD, raw SQL transform | self | exact |
| `priv/chimeway_migrations/031_create_chimeway_webhook_ingress.exs` | migration template | CRUD | `priv/chimeway_migrations/003_create_chimeway_deliveries.exs`; current file | exact |
| `test/support/installer_fixture.ex` | test utility | file-I/O, subprocess | `test/support/installer_fixture.ex` | exact |
| `test/chimeway/install/migrations_test.exs` | test | file-I/O, request-response | self | exact |
| `test/chimeway/install/golden_diff_test.exs` | test | file-I/O, batch | self | exact |
| `test/chimeway/install/idempotency_test.exs` | test | file-I/O, batch | self | exact |
| `test/chimeway/install/prefix_contract_test.exs` | test | file-I/O, static transform | `test/chimeway/install/golden_diff_test.exs`; `test/chimeway/doc_contract_test.exs` regex checks | role-match |
| `test/chimeway/migration_contract_test.exs` | test | CRUD, request-response | self | exact |
| `test/fixtures/installer_golden/` | fixture | file-I/O | current fixture tree | exact |
| `test/fixtures/installer_golden_prefixed/STDOUT.txt` | fixture | file-I/O | `test/fixtures/installer_golden/STDOUT.txt` | role-match |
| `test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations/*.exs` | fixture | file-I/O | `test/fixtures/installer_golden/tree/priv/repo/migrations/*.exs` | role-match |
| `test/fixtures/installer_golden_public/STDOUT.txt` | fixture | file-I/O | `test/fixtures/installer_golden/STDOUT.txt` | role-match |
| `test/fixtures/installer_golden_public/tree/priv/repo/migrations/*.exs` | fixture | file-I/O | `test/fixtures/installer_golden/tree/priv/repo/migrations/*.exs` | role-match |
| `mix.exs` | config | batch | `mix.exs` aliases | exact |
| `.github/workflows/ci.yml` | config | batch | existing `install_golden_contract` job | exact |
| `README.md` | docs | request-response | current install section | exact |
| `guides/introduction/installation.md` | docs | request-response | current installation guide | exact |
| `test/chimeway/doc_contract_test.exs` | test | static transform | existing installation/README doc contracts | exact |
| `MAINTAINING.md` | docs/config | batch | current installer-template section | exact |

## Pattern Assignments

### `lib/mix/tasks/chimeway.gen.migrations.ex` (task/config, request-response)

**Analog:** `lib/mix/tasks/chimeway.gen.migrations.ex`

**Use/import pattern** (lines 27-35):

```elixir
use Mix.Task

@shortdoc "Copy Chimeway migration templates into the host priv/repo/migrations"

@impl Mix.Task
def run(argv) do
  Mix.Task.run("app.config")

  {_opts, rest, invalid} = OptionParser.parse(argv, strict: [])
```

**Existing invalid-argument error pattern** (lines 37-41):

```elixir
if rest != [] or invalid != [] do
  Mix.raise("Installation blocked: unexpected args for chimeway.gen.migrations")
end

case Chimeway.Install.Migrations.run([]) do
```

**Actionable Mix.raise pattern** (lines 45-63):

```elixir
{:error, :umbrella_root} ->
  Mix.raise("""
  Could not infer host Ecto repo from an umbrella root mix.exs.

  Umbrella projects declare `apps_path` and child apps own their repos. Set an
  explicit repo before running from the umbrella root:

      config :chimeway, repo: MyApp.Repo

  Or run `mix chimeway.gen.migrations` from the child app directory that owns the repo.
  """)

{:error, :repo_missing} ->
  Mix.raise("""
  Could not resolve host Ecto repo.

  Set `config :chimeway, repo: MyApp.Repo` in your host config, or ensure your mix.exs
  declares `app: :my_app` so the installer can infer `MyApp.Repo`.
  """)
```

**Strict switch parsing analog:** `lib/mix/tasks/preview_rendering.ex`

Use this shape when adding `--prefix`, because it already uses an explicit `@switches` list and branches on invalid options.

```elixir
@switches [
  notifier: :string,
  channel: :string,
  params_json: :string,
  params_file: :string,
  param: :keep,
  recipient_json: :string,
  recipient_file: :string,
  recipient_field: :keep,
  help: :boolean
]

@impl Mix.Task
def run(argv) do
  case OptionParser.parse(argv, strict: @switches) do
```

Source: `lib/mix/tasks/preview_rendering.ex` lines 23-37.

**Error handling analog for invalid switches:** `lib/mix/tasks/preview_rendering.ex` lines 61-64.

```elixir
{_opts, _args, invalid} ->
  Mix.shell().error("Unknown options: #{Enum.join(invalid, ", ")}\n\n#{usage()}")
  exit({:shutdown, 1})
```

**Planner guidance:** Keep `Mix.Task.run("app.config")`; add `@switches [prefix: :string, legacy_public: :boolean]` only if the alias is implemented; reject rest args, invalid switches, and unsupported prefix values with `Mix.raise/1`. Pass a normalized generator option into `Chimeway.Install.Migrations.run/1`; do not read runtime `config :chimeway, :prefix`.

---

### `lib/chimeway/install/migrations.ex` (service/utility, file-I/O + transform)

**Analog:** `lib/chimeway/install/migrations.ex`

**Template discovery pattern** (lines 38-50):

```elixir
@template_dir "chimeway_migrations"
@migrations_dir Path.join(["priv", "repo", "migrations"])
@source_namespace "Chimeway.Repo.Migrations"

def list_templates do
  templates_root()
  |> File.ls!()
  |> Enum.filter(&String.ends_with?(&1, ".exs"))
  |> Enum.map(&parse_template_entry/1)
  |> Enum.sort_by(&elem(&1, 0))
end
```

**Core file-copy/idempotency pattern** (lines 64-92):

```elixir
def run(opts \\ []) do
  io = Keyword.get(opts, :io, Mix.shell())

  with {:ok, repo} <- resolve_repo(Keyword.get(opts, :repo)) do
    host_prefix = host_migrations_prefix(repo)
    base_ts = batch_base_timestamp()

    File.mkdir_p!(@migrations_dir)

    list_templates()
    |> Enum.with_index()
    |> Enum.each(fn {{_order, slug, template_path}, index} ->
      :ok = validate_slug!(slug)

      case find_existing_by_slug(slug) do
        nil ->
          ts = timestamp_for_index(base_ts, index)
          dest = Path.join(@migrations_dir, "#{ts}_#{slug}.exs")
          content = template_path |> File.read!() |> rewrite_namespace(host_prefix)
          File.write!(dest, content)
          io.info("created #{dest}")

        existing ->
          io.info("unchanged #{existing}")
      end
    end)

    :ok
  end
end
```

**Namespace transform pattern** (lines 146-152):

```elixir
def rewrite_namespace(content, host_prefix)
    when is_binary(content) and is_binary(host_prefix) do
  String.replace(content, @source_namespace, host_prefix)
end
```

**Slug idempotency and duplicate safety** (lines 157-164):

```elixir
def find_existing_by_slug(slug, migrations_dir \\ @migrations_dir) do
  :ok = validate_slug!(slug)

  case Path.wildcard(Path.join(migrations_dir, "*_#{slug}.exs")) |> Enum.sort() do
    [] -> nil
    [single] -> single
    multiple -> raise(DuplicateSlugError, slug: slug, paths: multiple)
  end
end
```

**Validation pattern** (lines 208-213):

```elixir
defp validate_slug!(slug) do
  if Regex.match?(~r/^[a-z0-9_]+$/, slug) do
    :ok
  else
    raise ArgumentError, "invalid migration slug: #{inspect(slug)}"
  end
end
```

**Repo inference pattern** (lines 228-239):

```elixir
defp infer_repo_from_mix_exs do
  mix_exs = Path.join(File.cwd!(), "mix.exs")

  with {:ok, content} <- File.read(mix_exs),
       false <- umbrella_root?(content),
       [_, app] <- Regex.run(~r/app:\s*:(\w+)/, content) do
    app_module = Macro.camelize(app)
    validate_repo!(Module.concat([app_module, Repo]))
  else
    true -> {:error, :umbrella_root}
    _ -> {:error, :repo_missing}
  end
end
```

**Planner guidance:** Extend `run/1` with a generator-mode option such as `:prefix` or `:generation_prefix`, defaulting in the Mix task to `:chimeway`. Keep one template tree and keep slug idempotency unchanged. Prefer a small explicit render step after namespace rewrite, e.g. mode sentinels for local helper output, not broad relation-name regex rewrites.

---

### `priv/chimeway_migrations/*.exs` (migration templates, CRUD + raw SQL)

**Applies to:** all 31 canonical templates listed in File Classification.

**Primary analog:** current template tree under `priv/chimeway_migrations/`

**Module/import pattern** (lines 1-6):

```elixir
# chimeway_migration: create_chimeway_events
defmodule Chimeway.Repo.Migrations.CreateChimewayEvents do
  use Ecto.Migration

  def change do
    create table(:chimeway_events, primary_key: false) do
```

Source: `priv/chimeway_migrations/001_create_chimeway_events.exs` lines 1-6.

**Table and named-index pattern to preserve** (lines 6-17):

```elixir
create table(:chimeway_events, primary_key: false) do
  add :id, :uuid, primary_key: true
  add :notification_key, :string, null: false
  add :notification_version, :integer, null: false
  add :idempotency_key, :string, null: false
  add :payload, :map, null: false

  timestamps(type: :utc_datetime_usec)
end

create unique_index(:chimeway_events, [:idempotency_key], name: :chimeway_events_idempotency_key_index)
```

Source: `priv/chimeway_migrations/001_create_chimeway_events.exs` lines 6-17.

**Reference/index pattern to qualify** (lines 6-26):

```elixir
create table(:chimeway_deliveries, primary_key: false) do
  add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

  add :notification_id,
      references(:chimeway_notifications, type: :uuid, on_delete: :delete_all),
      null: false
end

create unique_index(:chimeway_deliveries, [:notification_id, :channel],
         name: :chimeway_deliveries_notification_channel_index
       )

create index(:chimeway_deliveries, [:notification_id])
```

Source: `priv/chimeway_migrations/003_create_chimeway_deliveries.exs` lines 6-26.

**Raw SQL backfill pattern to qualify** (lines 17-40):

```elixir
def up do
  alter table(:chimeway_delivery_attempts) do
    add :attempt_number, :integer, null: true
    add :error_class, :string, null: true
  end

  execute(
    """
    UPDATE chimeway_delivery_attempts AS a
    SET attempt_number = sub.rn
    FROM (
      SELECT id, ROW_NUMBER() OVER (PARTITION BY delivery_id ORDER BY inserted_at, id) AS rn
      FROM chimeway_delivery_attempts
    ) AS sub
    WHERE a.id = sub.id;
    """,
    "UPDATE chimeway_delivery_attempts SET attempt_number = NULL;"
  )

  create index(:chimeway_delivery_attempts, [:error_class])
end
```

Source: `priv/chimeway_migrations/009_add_attempt_history_columns.exs` lines 17-40.

**Raw SQL + alter pattern to qualify** (lines 5-38):

```elixir
def change do
  alter table(:chimeway_workflow_runs) do
    add :tenant_id, :string
    add :suspended_until, :utc_datetime_usec
    add :pending_signals, {:array, :string}, default: []
    add :terminal_reason, :string
  end

  execute(
    "UPDATE chimeway_workflow_runs SET tenant_id = 'default' WHERE tenant_id IS NULL",
    ""
  )

  alter table(:chimeway_workflow_runs) do
    modify :tenant_id, :string, null: false, from: :string
  end

  create table(:chimeway_signals, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :tenant_id, :string, null: false
  end

  create index(:chimeway_signals, [:tenant_id, :actor_id])
  create index(:chimeway_signals, [:tenant_id, :event_name])
end
```

Source: `priv/chimeway_migrations/027_create_chimeway_signals_and_spine.exs` lines 5-38.

**Multi-statement raw SQL pattern to qualify** (lines 5-56):

```elixir
def up do
  alter table(:chimeway_deliveries) do
    add(:tenant_id, :string)
    add(:actor_id, :string)
  end

  flush()

  execute("""
  UPDATE chimeway_deliveries d
  SET actor_id = COALESCE(n.recipient_identity, 'system')
  FROM chimeway_notifications n
  WHERE d.notification_id = n.id
  """)

  execute("""
  UPDATE chimeway_deliveries
  SET actor_id = 'system'
  WHERE actor_id IS NULL
  """)

  execute("""
  UPDATE chimeway_deliveries d
  SET tenant_id = COALESCE(wr.tenant_id, 'default')
  FROM chimeway_workflow_runs wr
  WHERE d.workflow_run_id = wr.id
  """)

  alter table(:chimeway_deliveries) do
    modify(:tenant_id, :string, null: false)
    modify(:actor_id, :string, null: false)
  end
end
```

Source: `priv/chimeway_migrations/030_add_tenant_and_actor_to_chimeway_deliveries.exs` lines 5-56.

**Prefix/create-schema partial analog:** `chimeway_inbox/deps/oban/lib/oban/migrations/postgres/v01.ex`

Use only as a partial Ecto/Postgres pattern. Do not couple Chimeway to Oban's migration framework.

```elixir
def up(%{create_schema: create?, prefix: prefix} = opts) do
  %{escaped_prefix: escaped, quoted_prefix: quoted} = opts

  if create?, do: execute("CREATE SCHEMA IF NOT EXISTS #{quoted}")
```

Source: `chimeway_inbox/deps/oban/lib/oban/migrations/postgres/v01.ex` lines 6-10.

```elixir
create_if_not_exists table(:oban_jobs, primary_key: false, prefix: prefix) do
  add :id, :bigserial, primary_key: true
end

create_if_not_exists index(:oban_jobs, [:queue], prefix: prefix)
create_if_not_exists index(:oban_jobs, [:state], prefix: prefix)
create_if_not_exists index(:oban_jobs, [:scheduled_at], prefix: prefix)
```

Source: `chimeway_inbox/deps/oban/lib/oban/migrations/postgres/v01.ex` lines 31-55.

```elixir
execute "DROP TRIGGER IF EXISTS oban_notify ON #{quoted}.oban_jobs"

execute """
CREATE TRIGGER oban_notify
AFTER INSERT OR UPDATE OF state ON #{quoted}.oban_jobs
FOR EACH ROW EXECUTE PROCEDURE #{quoted}.oban_jobs_notify();
"""
```

Source: `chimeway_inbox/deps/oban/lib/oban/migrations/postgres/v01.ex` lines 83-89.

**Prefix option normalization partial analog:** `chimeway_inbox/deps/oban/lib/oban/migrations/postgres.ex` lines 88-96.

```elixir
defp with_defaults(opts, version) do
  opts = Enum.into(opts, %{prefix: @default_prefix, version: version})

  opts
  |> Map.put(:quoted_prefix, inspect(opts.prefix))
  |> Map.put(:escaped_prefix, String.replace(opts.prefix, "'", "''"))
  |> Map.put_new(:unlogged, true)
  |> Map.put_new(:create_schema, opts.prefix != @default_prefix)
end
```

**Planner guidance:** Generated default mode should make the selected prefix explicit in each host migration, likely via `@chimeway_prefix "chimeway"` and local helpers. Public mode should omit Ecto `prefix:` options entirely; do not generate `prefix: false`. For raw SQL helpers, only support known Chimeway-owned relation names and fixed accepted prefixes.

---

### `test/support/installer_fixture.ex` (test utility, file-I/O + subprocess)

**Analog:** `test/support/installer_fixture.ex`

**Subprocess install pattern** (lines 33-45):

```elixir
@doc """
Runs `mix chimeway.gen.migrations` in a subprocess and returns `{output, status}`.
"""
@spec run_install!(Path.t(), keyword()) :: {String.t(), non_neg_integer()}
def run_install!(root, _opts \\ []) when is_binary(root) do
  ensure_deps!(root)

  System.cmd("mix", ["chimeway.gen.migrations"],
    cd: root,
    stderr_to_stdout: true,
    env: [{"MIX_ENV", "dev"}]
  )
end
```

**Snapshot and normalization pattern** (lines 50-103):

```elixir
@spec snapshot_migrations_tree!(Path.t()) :: %{String.t() => String.t()}
def snapshot_migrations_tree!(root) when is_binary(root) do
  migrations_dir = Path.join(root, "priv/repo/migrations")

  migrations_dir
  |> Path.join("*.exs")
  |> Path.wildcard()
  |> Enum.sort()
  |> Map.new(fn abs_path ->
    rel = Path.relative_to(abs_path, root)
    {rel, File.read!(abs_path)}
  end)
end

@spec normalize_tree(%{String.t() => String.t()}) :: %{String.t() => String.t()}
def normalize_tree(tree) when is_map(tree) do
  tree
  |> Enum.map(fn {rel, content} ->
    {normalize_migration_path(rel), normalize_content(content)}
  end)
  |> Map.new()
end
```

**Golden write/load pattern** (lines 113-155):

```elixir
@spec write_golden!(map(), String.t()) :: :ok
def write_golden!(tree, stdout) when is_map(tree) and is_binary(stdout) do
  tree_dir = Path.join(@golden_dir, "tree/priv/repo/migrations")
  File.rm_rf!(Path.dirname(tree_dir))
  File.mkdir_p!(tree_dir)

  Enum.each(tree, fn {rel, content} ->
    dest = Path.join([@golden_dir, "tree", rel])
    File.mkdir_p!(Path.dirname(dest))
    File.write!(dest, content)
  end)

  File.write!(Path.join(@golden_dir, "STDOUT.txt"), stdout <> "\n")
  :ok
end

@spec load_golden_stdout() :: String.t()
def load_golden_stdout do
  @golden_dir
  |> Path.join("STDOUT.txt")
  |> File.read!()
  |> String.trim_trailing()
end
```

**Dependency setup pattern** (lines 196-218):

```elixir
defp ensure_deps!(root) do
  {output, status} =
    System.cmd("mix", ["deps.get"],
      cd: root,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}]
    )

  if status != 0 do
    raise "mix deps.get failed in #{root}:\n#{output}"
  end

  {compile_output, compile_status} =
    System.cmd("mix", ["compile"],
      cd: root,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}]
    )
```

**Planner guidance:** Add a mode argument to `run_install!/2` and golden helper functions. Preserve real subprocess execution. Suggested mode shape from research: default -> `["chimeway.gen.migrations"]`, chimeway -> `["chimeway.gen.migrations", "--prefix", "chimeway"]`, public -> `["chimeway.gen.migrations", "--prefix", "public"]`. Make golden root selection explicit per mode instead of relying on a single module attribute.

---

### `test/chimeway/install/golden_diff_test.exs` (test, file-I/O + batch)

**Analog:** `test/chimeway/install/golden_diff_test.exs`

**Golden comparison pattern** (lines 24-50):

```elixir
test "first run matches golden fixture" do
  root =
    "golden"
    |> InstallerFixture.new_fixture_root!()
    |> InstallerFixture.scaffold_host!()

  try do
    {stdout, 0} = InstallerFixture.run_install!(root, [])

    tree =
      root
      |> InstallerFixture.snapshot_migrations_tree!()
      |> InstallerFixture.normalize_tree()

    stdout = InstallerFixture.normalize_stdout(stdout)

    assert_map_size(tree, 31)
    assert_no_chimeway_repo_migrations!(tree)
    refute Enum.any?(Map.keys(tree), &String.contains?(&1, "create_oban_jobs_tables"))
    assert_chimeway_migration_markers!(tree)

    if InstallerFixture.accept_golden_refresh?() do
      InstallerFixture.write_golden!(tree, stdout)
    else
      assert tree == InstallerFixture.load_golden_tree()
      assert stdout == InstallerFixture.load_golden_stdout()
    end
  after
```

**Marker assertions** (lines 70-80):

```elixir
defp assert_chimeway_migration_markers!(tree) do
  Enum.each(tree, fn {path, content} ->
    slug =
      path
      |> Path.basename()
      |> String.replace_prefix("TIMESTAMP_", "")
      |> String.replace_suffix(".exs", "")

    assert content =~ "# chimeway_migration: #{slug}",
           "missing marker comment in #{path}"
  end)
end
```

**Planner guidance:** Convert this to a two-mode contract over prefixed default and explicit public legacy fixtures. Keep map-size, namespace, Oban exclusion, marker checks, and accept-golden refresh behavior. Add mode-specific assertions: prefixed output contains `@chimeway_prefix "chimeway"` and schema creation; public output contains no `prefix: false` and no generated `@chimeway_prefix "chimeway"` if the public helper uses `false` or bare helpers.

---

### `test/chimeway/install/idempotency_test.exs` (test, file-I/O + batch)

**Analog:** `test/chimeway/install/idempotency_test.exs`

**Second-run unchanged pattern** (lines 9-49):

```elixir
test "second run produces no fixture diff" do
  root =
    "idempotency"
    |> InstallerFixture.new_fixture_root!()
    |> InstallerFixture.scaffold_host!()

  try do
    {_stdout, 0} = InstallerFixture.run_install!(root, [])

    before =
      root
      |> InstallerFixture.snapshot_migrations_tree!()
      |> InstallerFixture.normalize_tree()

    assert map_size(before) == 31

    {second_stdout, 0} = InstallerFixture.run_install!(root, [])

    after_tree =
      root
      |> InstallerFixture.snapshot_migrations_tree!()
      |> InstallerFixture.normalize_tree()

    assert before == after_tree
    assert map_size(after_tree) == 31

    normalized_stdout = InstallerFixture.normalize_stdout(second_stdout)

    unchanged_lines =
      normalized_stdout
      |> String.split("\n", trim: true)
      |> Enum.filter(&String.starts_with?(&1, "unchanged priv/repo/migrations/"))

    created_lines =
      normalized_stdout
      |> String.split("\n", trim: true)
      |> Enum.filter(&String.starts_with?(&1, "created priv/repo/migrations/"))

    assert length(unchanged_lines) == 31
    assert created_lines == []
```

**Planner guidance:** Loop this test over default prefixed and explicit public modes. The slug idempotency should remain mode-independent inside one host directory; run each mode in a fresh fixture root so mode outputs do not mask each other.

---

### `test/chimeway/install/migrations_test.exs` (test, file-I/O + request-response)

**Analog:** `test/chimeway/install/migrations_test.exs`

**Ordered template contract** (lines 43-55):

```elixir
test "list_templates/0 returns 31 ordered entries matching canonical slugs" do
  templates = Migrations.list_templates()

  assert length(templates) == 31

  slugs = Enum.map(templates, fn {_order, slug, _path} -> slug end)
  assert slugs == @expected_slugs

  orders = Enum.map(templates, fn {order, _slug, _path} -> order end)
  assert orders == Enum.to_list(1..31)

  refute "create_oban_jobs_tables" in slugs
end
```

**Namespace rewrite unit pattern** (lines 61-72):

```elixir
test "rewrite_namespace/2 replaces Chimeway.Repo.Migrations with host prefix" do
  content = """
  defmodule Chimeway.Repo.Migrations.CreateChimewayEvents do
    use Ecto.Migration
  end
  """

  result = Migrations.rewrite_namespace(content, "InstallerHost.Repo.Migrations")

  assert result =~ "InstallerHost.Repo.Migrations.CreateChimewayEvents"
  refute result =~ "Chimeway.Repo.Migrations"
end
```

**Installer run pattern** (lines 209-242):

```elixir
describe "run/1 in tmp host" do
  test "first run creates 31 files with host namespaces" do
    tmp = scaffold_tmp_host!(include_config: true)
    restore_repo_env()

    Application.put_env(:chimeway, :repo, InstallerHost.Repo)

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        File.cd!(tmp, fn ->
          assert :ok = Migrations.run()
        end)
      end)

    migrations_dir = Path.join(tmp, "priv/repo/migrations")
    files = File.ls!(migrations_dir)

    assert length(files) == 31
    refute Enum.any?(files, &String.contains?(&1, "create_oban_jobs_tables"))
```

**CLI subprocess pattern** (lines 287-309):

```elixir
describe "mix chimeway.gen.migrations subprocess" do
  test "CLI generates 31 migrations via app.config path" do
    tmp = scaffold_tmp_host!(include_config: true)

    assert {_output, 0} =
             System.cmd("mix", ["deps.get"],
               cd: tmp,
               stderr_to_stdout: true,
               env: [{"MIX_ENV", "dev"}]
             )

    assert {_output, exit} =
             System.cmd("mix", ["chimeway.gen.migrations"],
               cd: tmp,
               stderr_to_stdout: true,
               env: [{"MIX_ENV", "dev"}]
             )

    assert exit == 0
```

**Planner guidance:** Add tests for default, `--prefix chimeway`, `--prefix public`, unsupported `--prefix other`, unsupported flags, and optional `--legacy-public` alias only if implemented. Assert runtime `Application.put_env(:chimeway, :prefix, false)` does not affect generator output.

---

### `test/chimeway/install/prefix_contract_test.exs` (new test, file-I/O + static transform)

**Closest analogs:** `test/chimeway/install/golden_diff_test.exs` and `test/chimeway/doc_contract_test.exs`

**Fixture generation source pattern:** use the golden-diff fixture setup shown above, but run the prefixed mode and inspect the generated normalized tree.

**Regex static-contract pattern:** `test/chimeway/doc_contract_test.exs` lines 1013-1029.

```elixir
@storage_prefix_required_strings [
  "prefix: \"chimeway\"",
  "prefix: false",
  "new isolated Chimeway schema",
  "existing public-schema legacy install",
  "unprefixed tables",
  "does not move data"
]

@storage_prefix_forbidden_phrases [
  "--prefix",
  "automatic data move",
  "automatically move",
  "automatic public-to-chimeway",
  "Oban prefix",
  "oban prefix"
]
```

**Planner guidance:** Build focused guards over generated prefixed files, not over canonical templates alone. Fail on bare Chimeway table references in Ecto operations and raw SQL. Suggested categories:

```elixir
@bare_sql_relation ~r/(FROM|UPDATE|JOIN|ALTER TABLE)\s+chimeway_[a-z_]+/
@bare_ecto_table ~r/(table|index|unique_index|references|alter|drop)\(:chimeway_[a-z_]+/
```

Use allowlists only for helper function definitions or quoted literal construction, not missed migration operations.

---

### `test/chimeway/migration_contract_test.exs` (test, CRUD + request-response)

**Analog:** `test/chimeway/migration_contract_test.exs`

**Legacy naming guard** (lines 6-20):

```elixir
test "public migration assertions are explicitly labeled" do
  labeled_tests =
    __MODULE__.__info__(:functions)
    |> Keyword.keys()
    |> Enum.map(&Atom.to_string/1)
    |> Enum.filter(&String.starts_with?(&1, "test "))
    |> Enum.reject(&String.contains?(&1, "public migration assertions are explicitly labeled"))
    |> Enum.filter(fn name ->
      String.contains?(name, "legacy") or
        String.contains?(name, "public-schema compatibility")
    end)

  assert length(labeled_tests) >= 2,
         "current public-schema checks must be named as legacy compatibility proof"
end
```

**Public object assertion pattern** (lines 22-39):

```elixir
test "legacy public-schema compatibility keeps events and notifications tables with required named indexes" do
  assert regclass("chimeway_events")
  assert regclass("chimeway_notifications")

  assert regclass("chimeway_events_idempotency_key_index")

  assert regclass("chimeway_notifications_event_recipient_index")
  assert regclass("chimeway_notifications_inbox_read_inserted_index")
end

test "legacy public-schema compatibility keeps phase 27 state spine tables and columns" do
  assert regclass("chimeway_signals")

  assert workflow_runs_column("tenant_id") == {false, "character varying"}
  assert workflow_runs_column("pending_signals") == {true, "ARRAY"}
  assert workflow_runs_column("suspended_until") == {true, "timestamp without time zone"}
  assert workflow_runs_column("terminal_reason") == {true, "character varying"}
end
```

**SQL helper pattern** (lines 41-63):

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
```

**Planner guidance:** Preserve the legacy public assertions and add prefixed generated-output DB proof. New helpers should accept schema/prefix parameters rather than duplicating `public`-only SQL. The generated prefixed contract must run normal migrations without `mix ecto.migrate --prefix chimeway` and verify `chimeway.chimeway_*` objects, important indexes, references, raw SQL effects where practical, and rollback behavior without `DROP SCHEMA ... CASCADE`.

---

### Golden Fixture Trees (fixtures, file-I/O)

**Existing analogs:** `test/fixtures/installer_golden/STDOUT.txt` and `test/fixtures/installer_golden/tree/priv/repo/migrations/*.exs`

**STDOUT pattern** (lines 1-31):

```text
created priv/repo/migrations/TIMESTAMP_create_chimeway_events.exs
created priv/repo/migrations/TIMESTAMP_create_chimeway_notifications.exs
created priv/repo/migrations/TIMESTAMP_create_chimeway_deliveries.exs
created priv/repo/migrations/TIMESTAMP_create_chimeway_delivery_attempts.exs
created priv/repo/migrations/TIMESTAMP_create_chimeway_notification_preferences.exs
```

Source: `test/fixtures/installer_golden/STDOUT.txt` lines 1-5. Full file has 31 `created` lines.

**Fixture path pattern:** current generated fixture paths are under:

```text
test/fixtures/installer_golden/tree/priv/repo/migrations/TIMESTAMP_create_chimeway_events.exs
test/fixtures/installer_golden/tree/priv/repo/migrations/TIMESTAMP_create_chimeway_notifications.exs
test/fixtures/installer_golden/tree/priv/repo/migrations/TIMESTAMP_create_chimeway_deliveries.exs
```

Source: fixture scan of `test/fixtures/installer_golden/tree/priv/repo/migrations/`.

**Planner guidance:** Add two committed roots, e.g. `installer_golden_prefixed` and `installer_golden_public`, each with `STDOUT.txt` and `tree/priv/repo/migrations/`. The generated tree shape should stay identical except content. If the current `installer_golden/` is retained, mark it as legacy or update helper naming to avoid ambiguous default-mode meaning.

---

### `mix.exs` and `.github/workflows/ci.yml` (config, batch)

**Alias analog:** `mix.exs` lines 99-102.

```elixir
# Installer golden-diff + idempotency contract (path-gated in CI, not default ci)
"ci.install_golden": [
  "cmd env MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs test/chimeway/install/idempotency_test.exs --warnings-as-errors"
],
```

**CI job analog:** `.github/workflows/ci.yml` lines 504-548.

```yaml
install_golden_contract:
  name: Installer golden + idempotency contract
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      with:
        fetch-depth: 0
    - name: Detect installer-related changes (PRs only)
      id: detect
      shell: bash
      run: |
        set -euo pipefail
        if [ "${{ github.event_name }}" != "pull_request" ]; then
          echo "run=true" >> "$GITHUB_OUTPUT"
          exit 0
        fi
        git fetch origin "${{ github.base_ref }}" --depth=1
        if git diff --name-only "origin/${{ github.base_ref }}...HEAD" | grep -qE '^priv/chimeway_migrations/|^lib/mix/tasks/chimeway\.gen\.migrations\.ex|^lib/chimeway/install/|^test/chimeway/install/|^test/fixtures/installer_golden/|^test/support/installer_fixture\.ex|^mix\.exs$|^\.github/workflows/ci\.yml$|^\.formatter\.exs$|^\.credo\.exs$'; then
          echo "run=true" >> "$GITHUB_OUTPUT"
```

```yaml
    - run: mix ci.install_golden
      if: steps.detect.outputs.run == 'true'
      env:
        MIX_ENV: test
```

Source: `.github/workflows/ci.yml` lines 545-548.

**Planner guidance:** Extend the alias to include the new static/prefixed DB contract tests. Extend the path gate to include both new fixture roots and any new contract file. If prefixed DB proof needs Postgres, add a Postgres service to the path-gated job or route the DB portion to an existing Postgres-backed CI lane; keep local and CI alias names in parity.

---

### README, Installation Guide, Doc Contract, and Maintainer Notes (docs + static tests)

**README install pattern:** `README.md` lines 20-42.

~~~markdown
Then run:

```bash
mix deps.get
mix chimeway.gen.migrations
mix ecto.migrate
```

Choose the runtime storage prefix before starting Chimeway. New installs should
use the new isolated Chimeway schema:

```elixir
config :chimeway, prefix: "chimeway"
```

Use `prefix: false` only for an existing public-schema legacy install whose
Chimeway tables already live in public:
~~~

**Installation guide pattern:** `guides/introduction/installation.md` lines 23-67.

~~~markdown
## 2. Generate and Run Migrations

Chimeway relies on a durable storage spine to ensure notifications are reliable and explainable. To set up the necessary database tables, you must generate and run the Chimeway migrations.

Generate the migrations:

```bash
mix chimeway.gen.migrations
```

This will copy the required migration files into your `priv/repo/migrations` directory.

Then, run Ecto migrations to apply them to your database:

```bash
mix ecto.migrate
```
~~~

**Doc contract required/forbidden pattern:** `test/chimeway/doc_contract_test.exs` lines 1013-1029.

```elixir
@storage_prefix_required_strings [
  "prefix: \"chimeway\"",
  "prefix: false",
  "new isolated Chimeway schema",
  "existing public-schema legacy install",
  "unprefixed tables",
  "does not move data"
]

@storage_prefix_forbidden_phrases [
  "--prefix",
  "automatic data move",
  "automatically move",
  "automatic public-to-chimeway",
  "Oban prefix",
  "oban prefix"
]
```

**Installation doc contract loop:** `test/chimeway/doc_contract_test.exs` lines 1120-1181.

```elixir
describe "installation doc contract (GATE-01)" do
  setup do
    content = File.read!(@installation_guide)
    %{content: content}
  end

  for phrase <- @storage_prefix_forbidden_phrases do
    test "forbids storage prefix drift phrase #{phrase} in installation guide", %{
      content: content
    } do
      refute String.contains?(content, unquote(phrase)),
             "installation guide must not reference #{unquote(phrase)}"
    end
  end

  for required <- @storage_prefix_required_strings do
    test "requires storage prefix phrase #{required} in installation guide", %{
      content: content
    } do
      assert String.contains?(content, unquote(required)),
             "installation guide must reference #{unquote(required)}"
    end
  end
end
```

**README doc contract loop:** `test/chimeway/doc_contract_test.exs` lines 1184-1244.

```elixir
describe "README install doc contract (GATE-01)" do
  setup do
    content = File.read!("README.md")
    %{content: content}
  end

  for phrase <- @storage_prefix_forbidden_phrases do
    test "forbids storage prefix drift phrase #{phrase} in README", %{content: content} do
      refute String.contains?(content, unquote(phrase)),
             "README must not reference #{unquote(phrase)}"
    end
  end

  for required <- @storage_prefix_required_strings do
    test "requires storage prefix phrase #{required} in README", %{content: content} do
      assert String.contains?(content, unquote(required)),
             "README must reference #{unquote(required)}"
    end
  end
end
```

**Maintainer path list pattern:** `MAINTAINING.md` lines 90-100.

```markdown
### Installer template changes

When modifying any of these paths, also run `mix ci.install_golden` locally before merging:

- `priv/chimeway_migrations/`
- `lib/mix/tasks/chimeway.gen.migrations.ex`
- `lib/chimeway/install/`
- `test/chimeway/install/`
- `test/fixtures/installer_golden/`

CI runs `install_golden_contract` on every push to `main` and on PRs that touch installer surfaces (path-gated). Do not change that gating behavior.
```

**Planner guidance:** Phase 74 may need to mention `--prefix public` in README/installation despite the current doc contract forbidding `"--prefix"` in install surfaces. If docs are updated, update `@storage_prefix_forbidden_phrases` or scope the forbidden phrase to runtime-config drift so generator CLI docs can be truthful. Update MAINTAINING to include both new fixture roots.

## Shared Patterns

### No Auth Pattern

**Source:** Phase boundary and repo scan
**Apply to:** all Phase 74 files

Phase 74 does not touch auth, tenancy, trigger, delivery, workflow runtime, inbox, admin, webhook, worker, or trace paths. Do not add auth/tenant runtime plumbing in this phase.

### Strict CLI Input Validation

**Source:** `lib/mix/tasks/chimeway.gen.migrations.ex`; `lib/mix/tasks/preview_rendering.ex`
**Apply to:** `lib/mix/tasks/chimeway.gen.migrations.ex`, installer tests

Use `OptionParser.parse(argv, strict: @switches)`, reject invalid switches and rest args, and normalize accepted prefix values to a small closed set: default/chimeway/public. Use actionable `Mix.raise/1` messages for installer errors.

### Single Canonical Template Tree

**Source:** `lib/chimeway/install/migrations.ex` lines 38-50 and `priv/chimeway_migrations/`
**Apply to:** installer core and all migration templates

Keep `priv/chimeway_migrations/` as the only template source. Do not add separate prefixed/public template trees. Generate mode-specific output from one canonical prefix-aware template set.

### Slug-Based Idempotency

**Source:** `lib/chimeway/install/migrations.ex` lines 73-89 and 157-164
**Apply to:** installer core, golden/idempotency tests

Existing behavior matches by migration slug, not timestamp. Preserve `created` on first run and `unchanged` on second run. Duplicate slug files must still raise `DuplicateSlugError`.

### Host Namespace Rewrite

**Source:** `lib/chimeway/install/migrations.ex` lines 146-152; `test/chimeway/install/migrations_test.exs` lines 61-72
**Apply to:** installer core and generated fixture assertions

Keep replacing `Chimeway.Repo.Migrations` with the host repo migrations namespace. New prefix rendering should compose with, not replace, namespace rewrite.

### Generated Prefix Visibility

**Source:** Phase 74 context and Oban partial analog
**Apply to:** all generated migrations

Default generated migrations should visibly encode the selected prefix, e.g. `@chimeway_prefix "chimeway"` plus local helpers. Public generated migrations should produce bare Ecto operations and bare raw SQL relation names; do not emit `prefix: false` Ecto options.

### Raw SQL Qualification

**Source:** `priv/chimeway_migrations/009_add_attempt_history_columns.exs`, `027_create_chimeway_signals_and_spine.exs`, `030_add_tenant_and_actor_to_chimeway_deliveries.exs`; Oban raw SQL partial analog
**Apply to:** raw SQL migration templates and static prefix contract

Raw SQL is not affected by Ecto helper prefixes. Prefix relation references through small local helpers or fixed qualified literals for known Chimeway relation names. Never accept arbitrary user-controlled SQL relation names.

### Golden Fixture Contract

**Source:** `test/support/installer_fixture.ex`, `test/chimeway/install/golden_diff_test.exs`, `test/chimeway/install/idempotency_test.exs`
**Apply to:** fixture helper, golden fixtures, idempotency tests

Run the real Mix subprocess in a throwaway host, normalize timestamps/tmp paths/stdout, compare committed fixture trees, and support intentional refresh with `MIX_INSTALLER_ACCEPT_GOLDEN=1`.

### CI Path Gate

**Source:** `.github/workflows/ci.yml` lines 504-548; `mix.exs` lines 99-102
**Apply to:** mix aliases, CI workflow, MAINTAINING

Keep installer proof path-gated because generation and migration proof are heavier than normal unit tests. Update path regexes and aliases when adding new fixture roots or contract files.

## No Analog Found

| File / Pattern | Role | Data Flow | Reason |
|----------------|------|-----------|--------|
| Prefix-aware local helpers inside Chimeway generated migrations | migration helper | transform | No Chimeway-owned generated migration currently has mode-aware `table/index/references/raw SQL` helpers. Use current templates plus the Oban prefix partial analog, but keep Chimeway helpers local and fixed to `chimeway`/public modes. |
| `test/chimeway/install/prefix_contract_test.exs` exact behavior | test | static transform | No existing installer test scans generated prefixed output for missed bare Ecto/raw SQL references. Use golden fixture setup plus doc-contract regex style. |

## Metadata

**Analog search scope:** `lib/mix/tasks/`, `lib/chimeway/install/`, `priv/chimeway_migrations/`, `test/support/`, `test/chimeway/install/`, `test/chimeway/migration_contract_test.exs`, `test/chimeway/doc_contract_test.exs`, `test/fixtures/installer_golden/`, `mix.exs`, `.github/workflows/ci.yml`, `README.md`, `guides/introduction/installation.md`, `MAINTAINING.md`; one partial dependency analog in `chimeway_inbox/deps/oban/`.

**Files scanned:** focused scan of 20 project files plus 31 canonical templates and 2 Oban prefix analog files.

**Pattern extraction date:** 2026-06-30
