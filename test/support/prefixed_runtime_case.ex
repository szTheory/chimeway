defmodule Chimeway.PrefixedRuntimeCase do
  @moduledoc """
  Serialized test case for runtime storage-prefix proof.

  The case uses `Chimeway.Repo` against the generated prefixed fixture migrations
  and keeps row-placement assertions schema-qualified so tests do not rely on
  ambient PostgreSQL search_path state.
  """

  use ExUnit.CaseTemplate

  import ExUnit.Assertions

  alias Chimeway.Repo

  @runtime_prefix "chimeway"
  @fixture_root "test/fixtures/installer_golden_prefixed"
  @migration_version_base 20_260_201_000_000
  @identifier_regex ~r/\A[a-z][a-z0-9_]*\z/

  using do
    quote do
      use Chimeway.DataCase, async: false

      import Chimeway.PrefixedRuntimeCase

      setup_all {Chimeway.PrefixedRuntimeCase, :prepare_prefixed_runtime_storage}
      setup {Chimeway.PrefixedRuntimeCase, :reset_prefixed_runtime_storage}
    end
  end

  def prepare_prefixed_runtime_storage(_context) do
    previous_prefix = Application.fetch_env(:chimeway, :prefix)
    Application.put_env(:chimeway, :prefix, "chimeway")

    on_exit(fn -> restore_prefix(previous_prefix) end)

    prepare_generated_prefixed_migrations!()

    :ok
  end

  def reset_prefixed_runtime_storage(_context) do
    truncate_chimeway_rows!(@runtime_prefix)
    truncate_chimeway_rows!("public")

    :ok
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

    sql = "SELECT count(*) FROM #{qualified_name(schema, table_name)}"

    Repo
    |> Ecto.Adapters.SQL.query!(sql, [])
    |> then(fn %{rows: [[count]]} -> count end)
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

  def prefixed_schema_exists? do
    schema_exists?(@runtime_prefix)
  end

  def schema_exists?(schema) do
    schema = normalize_identifier!(schema)

    result =
      Ecto.Adapters.SQL.query!(
        Repo,
        "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = $1)",
        [schema]
      )

    result.rows == [[true]]
  end

  def chimeway_tables(schema) do
    schema = normalize_identifier!(schema)

    Repo
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

  defp prepare_generated_prefixed_migrations! do
    with_temporary_prefix(false, fn ->
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        if generated_prefixed_schema_ready?() do
          :ok
        else
          delete_generated_migration_versions!()
          run_generated_prefixed_migrations!()
        end
      end)
    end)
  end

  defp generated_prefixed_schema_ready? do
    schema_exists?(@runtime_prefix) and
      Enum.all?(
        [
          "chimeway_events",
          "chimeway_notifications",
          "chimeway_deliveries",
          "chimeway_delivery_attempts"
        ],
        &regclass?(@runtime_prefix, &1)
      )
  end

  defp run_generated_prefixed_migrations! do
    tmp_root =
      Path.join(
        System.tmp_dir!(),
        "chimeway_prefixed_runtime_#{System.unique_integer([:positive])}"
      )

    migrations_path = Path.join(tmp_root, "migrations")

    File.rm_rf!(tmp_root)
    File.mkdir_p!(migrations_path)
    write_numbered_fixture_migrations!(migrations_path)

    try do
      Ecto.Migrator.run(Repo, migrations_path, :up, all: true, log: false)
    after
      File.rm_rf!(tmp_root)
      purge_fixture_modules!()
    end
  end

  defp write_numbered_fixture_migrations!(migrations_path) do
    @fixture_root
    |> migration_order()
    |> Enum.with_index(1)
    |> Enum.each(fn {fixture_name, index} ->
      src = Path.join([@fixture_root, "tree", "priv", "repo", "migrations", fixture_name])
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

  defp truncate_chimeway_rows!(schema) do
    tables = chimeway_tables(schema)

    if tables != [] do
      qualified_tables =
        tables
        |> Enum.map(&qualified_name(schema, &1))
        |> Enum.join(", ")

      Ecto.Adapters.SQL.query!(
        Repo,
        "TRUNCATE TABLE #{qualified_tables} RESTART IDENTITY CASCADE",
        []
      )
    end
  end

  defp delete_generated_migration_versions! do
    Ecto.Adapters.SQL.query!(
      Repo,
      "DELETE FROM schema_migrations WHERE version > $1 AND version <= $2",
      [@migration_version_base, @migration_version_base + 31]
    )
  end

  defp regclass?(schema, name) do
    case Ecto.Adapters.SQL.query!(Repo, "SELECT to_regclass($1)", ["#{schema}.#{name}"]).rows do
      [[nil]] -> false
      [[_value]] -> true
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

  defp with_temporary_prefix(value, fun) do
    previous_prefix = Application.fetch_env(:chimeway, :prefix)
    Application.put_env(:chimeway, :prefix, value)

    try do
      fun.()
    after
      restore_prefix(previous_prefix)
    end
  end

  defp restore_prefix({:ok, value}) do
    Application.put_env(:chimeway, :prefix, value)
  end

  defp restore_prefix(:error) do
    Application.delete_env(:chimeway, :prefix)
  end

  defp purge_fixture_modules! do
    @fixture_root
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
end
