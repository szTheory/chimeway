defmodule Mix.Tasks.Chimeway.Gen.Migrations do
  @moduledoc """
  Copy Chimeway migration templates into the host priv/repo/migrations.

  Generates Chimeway schema migrations in the host repo.

  ## Usage

      mix chimeway.gen.migrations

  Copies 31 migration templates from `priv/chimeway_migrations/` (Oban excluded).
  See `guides/recipes/oban-integration.md` for Oban setup (D-10).

  Re-running is idempotent — existing slugs print `unchanged`.
  """

  use Mix.Task

  @shortdoc "Copy Chimeway migration templates into the host priv/repo/migrations"

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.config")

    {_opts, rest, invalid} = OptionParser.parse(argv, strict: [])

    if rest != [] or invalid != [] do
      Mix.raise("Installation blocked: unexpected args for chimeway.gen.migrations")
    end

    case Chimeway.Install.Migrations.run([]) do
      :ok ->
        :ok

      {:error, :repo_missing} ->
        Mix.raise("""
        Could not resolve host Ecto repo.

        Set `config :chimeway, repo: MyApp.Repo` in your host config, or ensure your mix.exs
        declares `app: :my_app` so the installer can infer `MyApp.Repo`.
        """)
    end
  end
end
