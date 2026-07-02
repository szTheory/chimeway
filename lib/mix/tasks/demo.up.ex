defmodule Mix.Tasks.Demo.Up do
  @moduledoc """
  Prepare TeamPulse demo data for local click-around and CI smoke checks.

  ## Usage

      mix demo.up              # migrate + seed + print admin URL
      mix demo.up --check      # CI smoke — migrate + app.start + seed (skip ecto.create), exit 0
      mix demo.up --serve      # migrate + seed + start demo host admin UI

  """
  @shortdoc "Migrate, seed TeamPulse demo, print admin URL"

  use Mix.Task

  @demo_storage_prefix "chimeway"

  @impl Mix.Task
  def run(args) do
    check? = "--check" in args
    serve? = "--serve" in args

    unless check? do
      Mix.Task.run("ecto.create")
    end

    Mix.Task.run("ecto.migrate")
    Mix.Task.run("app.start")
    prepare_demo_storage_prefix!()

    {output, status} =
      System.cmd("mix", ["demo.seed"],
        cd: demo_host_path(),
        env: demo_env(),
        stderr_to_stdout: true
      )

    if status != 0 do
      Mix.raise("demo.seed failed:\n#{output}")
    end

    print_banner()

    if serve? and not check? do
      System.cmd("mix", ["demo.admin"], cd: demo_host_path(), env: demo_env(), into: IO.stream())
    end

    :ok
  end

  defp print_banner do
    Mix.shell().info("")
    Mix.shell().info("TeamPulse demo ready")
    Mix.shell().info("  Admin UI:  http://localhost:4001/admin/chimeway")
    Mix.shell().info("  Recipient: user:alex@teampulse.test")
    Mix.shell().info("  Run:       cd examples/chimeway_demo_host && mix demo.admin")
    Mix.shell().info("")
  end

  defp demo_host_path do
    Path.expand("examples/chimeway_demo_host", File.cwd!())
  end

  defp demo_env do
    [
      {"PGHOST", System.get_env("PGHOST") || "localhost"},
      {"PGUSER", System.get_env("PGUSER") || System.get_env("USER") || "postgres"},
      {"PGPASSWORD", System.get_env("PGPASSWORD") || ""}
    ]
  end

  defp prepare_demo_storage_prefix! do
    create_schema!(@demo_storage_prefix)
    clone_missing_public_chimeway_tables!(@demo_storage_prefix)
  end

  defp clone_missing_public_chimeway_tables!(prefix) do
    public_tables = chimeway_tables("public")
    prefixed_tables = MapSet.new(chimeway_tables(prefix))

    public_tables
    |> Enum.reject(&MapSet.member?(prefixed_tables, &1))
    |> Enum.each(fn table_name ->
      Ecto.Adapters.SQL.query!(
        Chimeway.Repo,
        """
        CREATE TABLE #{qualified_name(prefix, table_name)}
        (LIKE #{qualified_name("public", table_name)} INCLUDING ALL)
        """,
        []
      )
    end)
  end

  defp create_schema!(schema) do
    Ecto.Adapters.SQL.query!(
      Chimeway.Repo,
      ~s(CREATE SCHEMA IF NOT EXISTS "#{normalize_identifier!(schema)}"),
      []
    )
  end

  defp chimeway_tables(schema) do
    schema = normalize_identifier!(schema)

    Chimeway.Repo
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

  defp normalize_identifier!(identifier) when is_binary(identifier) do
    if Regex.match?(~r/\A[a-z][a-z0-9_]*\z/, identifier) do
      identifier
    else
      Mix.raise("Unsafe SQL identifier: #{inspect(identifier)}")
    end
  end
end
