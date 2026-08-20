defmodule Chimeway.GeneratedPrefixedRuntimeCase do
  @moduledoc """
  Isolated test case for proving generated prefixed migrations support runtime APIs.

  This case intentionally avoids `Chimeway.DataCase`: the bridge runs generated
  fixture migrations in a temporary database, outside SQL Sandbox ownership.
  """

  use ExUnit.CaseTemplate

  import ExUnit.Assertions

  alias Chimeway.Repo

  @runtime_prefix "chimeway"
  @fixture_root "test/fixtures/installer_golden_prefixed"
  @migration_version_base 20_260_101_000_000
  @identifier_regex ~r/\A[a-z][a-z0-9_]*\z/

  using do
    quote do
      import Chimeway.GeneratedPrefixedRuntimeCase

      setup_all {Chimeway.GeneratedPrefixedRuntimeCase, :prepare_generated_runtime_storage}
      setup {Chimeway.GeneratedPrefixedRuntimeCase, :reset_generated_runtime_storage}
    end
  end

  def prepare_generated_runtime_storage(_context) do
    unique = System.unique_integer([:positive])
    database = "chimeway_generated_prefixed_runtime_#{unique}"
    tmp_root = Path.join(System.tmp_dir!(), "chimeway_generated_prefixed_runtime_#{unique}")
    migrations_path = Path.join(tmp_root, "migrations")
    config = generated_repo_config(database)
    previous_prefix = Application.fetch_env(:chimeway, :prefix)
    previous_dynamic_repo = Repo.get_dynamic_repo()

    cleanup = fn repo_pid ->
      restore_dynamic_repo(previous_dynamic_repo)

      if repo_pid && Process.alive?(repo_pid) do
        try do
          GenServer.stop(repo_pid)
        catch
          :exit, _ -> :ok
        end
      end

      _ = Ecto.Adapters.Postgres.storage_down(config)
      File.rm_rf!(tmp_root)
      purge_fixture_modules!(@fixture_root)
      restore_env(:prefix, previous_prefix)
    end

    try do
      File.rm_rf!(tmp_root)
      File.mkdir_p!(migrations_path)
      write_numbered_fixture_migrations!(@fixture_root, migrations_path)
      Application.put_env(:chimeway, :prefix, @runtime_prefix)

      # Drop any stale same-named DB first so migrations can never run against a
      # dirty database (closes the {:error, :already_up} -> :ok masking below).
      _ = Ecto.Adapters.Postgres.storage_down(config)

      case Ecto.Adapters.Postgres.storage_up(config) do
        :ok -> :ok
        {:error, :already_up} -> :ok
        {:error, reason} -> flunk("failed to create #{database}: #{inspect(reason)}")
      end
    rescue
      exception ->
        cleanup.(nil)
        reraise exception, __STACKTRACE__
    catch
      kind, reason ->
        cleanup.(nil)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end

    repo_pid =
      case Repo.start_link(Keyword.put(config, :name, nil)) do
        {:ok, repo_pid} ->
          repo_pid

        {:error, reason} ->
          cleanup.(nil)
          flunk("failed to start generated runtime repo: #{inspect(reason)}")
      end

    migrated =
      try do
        Repo.put_dynamic_repo(repo_pid)

        # Query the throwaway repo directly by pid (passing the Repo module would use
        # its static sandbox meta, not the dynamic repo). Guard that we're on the
        # throwaway DB, then drop any residual prefixed schema so migrations cannot
        # hit the CI-only `42P07 duplicate_table` on chimeway_events.
        %{rows: [[current_db]]} =
          Ecto.Adapters.SQL.query!(repo_pid, "SELECT current_database()", [])

        unless current_db == database do
          cleanup.(repo_pid)

          flunk(
            "generated runtime repo connected to #{current_db}, expected throwaway #{database}"
          )
        end

        Ecto.Adapters.SQL.query!(
          repo_pid,
          ~s[DROP SCHEMA IF EXISTS "#{@runtime_prefix}" CASCADE],
          []
        )

        migrated = run_fixture_migrations(migrations_path, :up, repo_pid)

        assert length(migrated) == 36

        Repo.put_dynamic_repo(previous_dynamic_repo)

        migrated
      rescue
        exception ->
          cleanup.(repo_pid)
          reraise exception, __STACKTRACE__
      catch
        kind, reason ->
          cleanup.(repo_pid)
          :erlang.raise(kind, reason, __STACKTRACE__)
      end

    on_exit(fn ->
      cleanup.(repo_pid)
    end)

    {:ok,
     generated_runtime_repo: repo_pid,
     generated_runtime_migration_count: length(migrated),
     generated_runtime_config: config,
     generated_runtime_migrations_path: migrations_path}
  end

  def checkout_generated_runtime_repo(%{generated_runtime_repo: repo_pid}) do
    previous_dynamic_repo = Repo.get_dynamic_repo()
    Repo.put_dynamic_repo(repo_pid)
    assert Repo.get_dynamic_repo() == repo_pid

    on_exit(fn -> restore_dynamic_repo(previous_dynamic_repo) end)

    :ok
  end

  def reset_generated_runtime_storage(context) do
    :ok = checkout_generated_runtime_repo(context)

    truncate_chimeway_rows!(@runtime_prefix)
    truncate_chimeway_rows!("public")

    :ok
  end

  def generated_migration_count do
    # Count only the generated fixture migrations, which occupy the contiguous
    # band base+1 .. base+N (well under base+1_000_000). Scoping to that band
    # keeps the assertion correct even when schema_migrations also contains the
    # host app's real migrations (dated 2026-04+), which some CI environments
    # surface here through the shared connection where local runs do not.
    sql_repo()
    |> Ecto.Adapters.SQL.query!(
      "SELECT count(*) FROM schema_migrations WHERE version > #{@migration_version_base} AND version < #{@migration_version_base + 1_000_000}",
      []
    )
    |> then(fn %{rows: [[count]]} -> count end)
  end

  def assert_generated_prefixed_runtime_tables! do
    assert schema_exists?(@runtime_prefix)

    for table_name <- [
          "chimeway_events",
          "chimeway_notifications",
          "chimeway_deliveries",
          "chimeway_delivery_attempts",
          "chimeway_delivery_targets"
        ] do
      assert regclass?(@runtime_prefix, table_name),
             "expected #{@runtime_prefix}.#{table_name} to exist"
    end
  end

  def prefixed_count(table_name) do
    table_count(@runtime_prefix, table_name)
  end

  def public_count(table_name) do
    table_count("public", table_name)
  end

  def table_count(schema, table_name) do
    schema = normalize_identifier!(schema)
    table_name = normalize_identifier!(table_name)

    if regclass?(schema, table_name) do
      sql = "SELECT count(*) FROM #{qualified_name(schema, table_name)}"

      sql_repo()
      |> Ecto.Adapters.SQL.query!(sql, [])
      |> then(fn %{rows: [[count]]} -> count end)
    else
      0
    end
  end

  def assert_prefixed_only(table_name, expected_count) when is_integer(expected_count) do
    assert prefixed_count(table_name) == expected_count
    assert public_count(table_name) == 0
  end

  def assert_prefixed_only(table_name, :nonzero) do
    assert prefixed_count(table_name) > 0
    assert public_count(table_name) == 0
  end

  def assert_prefixed_only(table_name) do
    assert_prefixed_only(table_name, :nonzero)
  end

  defp generated_repo_config(database) do
    base_database_config()
    |> Keyword.merge(
      # Repo.start_link/1 merges these opts over the app-env config, which on CI
      # carries `url: DATABASE_URL` (…/chimeway_test). When both :url and :database
      # are present the URL's database wins, so the throwaway repo would connect to
      # chimeway_test and collide with the sibling-cloned `chimeway` schema. Force
      # url: nil so the explicit `database` below is authoritative.
      url: nil,
      database: database,
      pool_size: 2,
      queue_target: 5_000,
      queue_interval: 10_000
    )
  end

  defp base_database_config do
    case System.get_env("DATABASE_URL") do
      nil ->
        Repo.config()
        |> Keyword.drop([:database, :pool, :url])
        |> Keyword.put_new(:hostname, "localhost")

      database_url ->
        database_url_config(database_url)
    end
  end

  defp database_url_config(database_url) do
    uri = URI.parse(database_url)
    {username, password} = parse_userinfo(uri.userinfo)

    [
      username: username,
      password: password,
      hostname: uri.host || "localhost",
      port: uri.port || 5432
    ]
  end

  defp parse_userinfo(nil), do: {"postgres", nil}

  defp parse_userinfo(userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [username, password] -> {URI.decode(username), URI.decode(password)}
      [username] -> {URI.decode(username), nil}
    end
  end

  defp write_numbered_fixture_migrations!(fixture_root, migrations_path) do
    fixture_root
    |> migration_order()
    |> Enum.with_index(1)
    |> Enum.each(fn {fixture_name, index} ->
      src = Path.join([fixture_root, "tree", "priv", "repo", "migrations", fixture_name])
      version = @migration_version_base + index

      dest =
        Path.join(
          migrations_path,
          "#{version}_#{String.replace_prefix(fixture_name, "TIMESTAMP_", "")}"
        )

      content = File.read!(src)
      purge_modules!(migration_modules(content))
      File.write!(dest, content)
    end)
  end

  defp migration_order(fixture_root) do
    fixture_root
    |> Path.join("STDOUT.txt")
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(fn "created priv/repo/migrations/" <> fixture_name -> fixture_name end)
  end

  defp purge_fixture_modules!(fixture_root) do
    fixture_root
    |> Path.join("tree/priv/repo/migrations/*.exs")
    |> Path.wildcard()
    |> Enum.flat_map(fn path -> path |> File.read!() |> migration_modules() end)
    |> purge_modules!()
  end

  defp purge_modules!(modules) do
    Enum.each(modules, fn module ->
      :code.purge(module)
      :code.delete(module)
    end)
  end

  defp migration_modules(content) do
    for [_, module] <- Regex.scan(~r/defmodule\s+([A-Za-z0-9_.]+)\s+do/, content) do
      module
      |> String.split(".")
      |> Module.concat()
    end
  end

  defp run_fixture_migrations(migrations_path, direction, repo_pid)
       when direction in [:up, :down] do
    parent = self()
    ref = make_ref()

    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      # Pin the migrator to the throwaway repo explicitly. Ecto.Migrator resolves the
      # target via Keyword.get(opts, :dynamic_repo, repo.get_dynamic_repo()) inside a
      # spawned Task; without the explicit opt the get_dynamic_repo/0 fallback is
      # process-dependent and can intermittently route migrations at the default
      # Chimeway.Repo (chimeway_test), colliding with the sibling-cloned `chimeway`
      # schema (42P07 duplicate_table). Passing dynamic_repo makes it deterministic.
      result =
        Ecto.Migrator.run(Repo, migrations_path, direction,
          all: true,
          log: false,
          dynamic_repo: repo_pid
        )

      send(parent, {ref, result})
    end)

    receive do
      {^ref, result} -> result
    end
  end

  defp schema_exists?(schema) do
    schema = normalize_identifier!(schema)

    result =
      Ecto.Adapters.SQL.query!(
        sql_repo(),
        "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = $1)",
        [schema]
      )

    result.rows == [[true]]
  end

  defp regclass?(schema, name) do
    schema = normalize_identifier!(schema)
    name = normalize_identifier!(name)

    case Ecto.Adapters.SQL.query!(sql_repo(), "SELECT to_regclass($1)", ["#{schema}.#{name}"]).rows do
      [[nil]] -> false
      [[_value]] -> true
    end
  end

  defp chimeway_tables(schema) do
    schema = normalize_identifier!(schema)

    sql_repo()
    |> Ecto.Adapters.SQL.query!(
      """
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = $1
        AND table_name LIKE 'chimeway_%'
      ORDER BY table_name
      """,
      [schema]
    )
    |> then(fn %{rows: rows} -> Enum.map(rows, fn [table_name] -> table_name end) end)
  end

  defp truncate_chimeway_rows!(schema) do
    tables = chimeway_tables(schema)

    if tables != [] do
      qualified_tables =
        Enum.map_join(tables, ", ", &qualified_name(schema, &1))

      Ecto.Adapters.SQL.query!(
        sql_repo(),
        "TRUNCATE TABLE #{qualified_tables} RESTART IDENTITY CASCADE",
        []
      )
    end
  end

  defp qualified_name(schema, table_name) do
    ~s("#{normalize_identifier!(schema)}"."#{normalize_identifier!(table_name)}")
  end

  defp normalize_identifier!(identifier) when is_atom(identifier) do
    identifier
    |> Atom.to_string()
    |> normalize_identifier!()
  end

  defp normalize_identifier!(identifier) when is_binary(identifier) do
    if Regex.match?(@identifier_regex, identifier) do
      identifier
    else
      raise ArgumentError, "unsafe SQL identifier: #{inspect(identifier)}"
    end
  end

  defp restore_env(key, {:ok, value}), do: Application.put_env(:chimeway, key, value)
  defp restore_env(key, :error), do: Application.delete_env(:chimeway, key)

  defp restore_dynamic_repo(repo) do
    Repo.put_dynamic_repo(repo)
  end

  defp sql_repo do
    Repo.get_dynamic_repo()
  end
end
