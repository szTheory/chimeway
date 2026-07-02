defmodule DemoHost.StoragePrefixSupport do
  @moduledoc false

  alias Chimeway.Repo

  @runtime_prefix "chimeway"
  @identifier_regex ~r/\A[a-z][a-z0-9_]*\z/

  def prepare_prefixed_schema! do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      create_schema!(@runtime_prefix)
      clone_missing_public_chimeway_tables!()
    end)
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
