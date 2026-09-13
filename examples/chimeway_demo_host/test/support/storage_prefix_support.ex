defmodule DemoHost.StoragePrefixSupport do
  @moduledoc false

  alias Chimeway.Repo

  @runtime_prefix "chimeway"
  @identifier_regex ~r/\A[a-z][a-z0-9_]*\z/

  def prepare_prefixed_schema! do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      create_schema!(@runtime_prefix)
      clone_missing_public_chimeway_tables!()
      clone_missing_public_chimeway_columns!()
    end)
  end

  defp clone_missing_public_chimeway_columns! do
    for table_name <- chimeway_tables(@runtime_prefix),
        [column_name, data_type] <- missing_columns(table_name) do
      Ecto.Adapters.SQL.query!(
        Repo,
        "ALTER TABLE #{qualified_name(@runtime_prefix, table_name)} ADD COLUMN #{quoted_identifier(column_name)} #{data_type}",
        []
      )
    end
  end

  defp missing_columns(table_name) do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        Repo,
        """
        SELECT source.column_name, source.data_type
        FROM (
          SELECT a.attname AS column_name, format_type(a.atttypid, a.atttypmod) AS data_type
          FROM pg_attribute a
          JOIN pg_class c ON c.oid = a.attrelid
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public' AND c.relname = $1
            AND a.attnum > 0 AND NOT a.attisdropped
        ) source
        LEFT JOIN information_schema.columns target
          ON target.table_schema = $2
          AND target.table_name = $1
          AND target.column_name = source.column_name
        WHERE target.column_name IS NULL
        ORDER BY source.column_name
        """,
        [table_name, @runtime_prefix]
      )

    rows
  end

  defp clone_missing_public_chimeway_tables! do
    public_tables = chimeway_tables("public")

    if public_tables == [] do
      raise "public Chimeway tables are missing; run base migrations before demo tests"
    end

    prefixed_tables = MapSet.new(chimeway_tables(@runtime_prefix))

    public_tables
    |> Enum.reject(&MapSet.member?(prefixed_tables, &1))
    |> Enum.each(fn table_name ->
      Ecto.Adapters.SQL.query!(
        Repo,
        """
        CREATE TABLE #{qualified_name(@runtime_prefix, table_name)}
        (LIKE #{qualified_name("public", table_name)} INCLUDING ALL)
        """,
        []
      )
    end)
  end

  defp create_schema!(schema) do
    Ecto.Adapters.SQL.query!(
      Repo,
      ~s(CREATE SCHEMA IF NOT EXISTS "#{normalize_identifier!(schema)}"),
      []
    )
  end

  defp chimeway_tables(schema) do
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

  defp qualified_name(schema, table_name) do
    ~s("#{normalize_identifier!(schema)}"."#{normalize_identifier!(table_name)}")
  end

  defp quoted_identifier(identifier), do: ~s("#{normalize_identifier!(identifier)}")

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
end
