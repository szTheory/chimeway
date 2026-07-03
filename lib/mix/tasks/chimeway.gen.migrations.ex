defmodule Mix.Tasks.Chimeway.Gen.Migrations do
  @moduledoc """
  Copy Chimeway migration templates into the host priv/repo/migrations.

  Generates Chimeway schema migrations in the host repo.

  ## Usage

      mix chimeway.gen.migrations
      mix chimeway.gen.migrations --prefix chimeway
      mix chimeway.gen.migrations --prefix public

  Copies 31 migration templates from `priv/chimeway_migrations/` (Oban excluded).
  See `guides/recipes/oban-integration.md` for Oban setup (D-10).

  Re-running is idempotent — existing slugs print `unchanged`.

  ## Umbrella apps

  Repo inference reads `app:` from the current directory's `mix.exs`. Umbrella roots
  declare `apps_path` and host repos live in child apps, so inference from the root
  is unreliable. Set an explicit repo in config before running from an umbrella root:

      config :chimeway, repo: MyApp.Repo

  Or run the task from the child app directory that owns the repo.
  """

  use Mix.Task

  @shortdoc "Copy Chimeway migration templates into the host priv/repo/migrations"

  @switches [prefix: :string]

  @usage """
  Usage:

      mix chimeway.gen.migrations
      mix chimeway.gen.migrations --prefix chimeway
      mix chimeway.gen.migrations --prefix public

  Accepted flags:

      --prefix chimeway   Generate migrations for the dedicated chimeway schema.
      --prefix public     Generate legacy unprefixed/public-schema migrations.
  """

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.config")

    prefix = parse_generation_prefix!(argv)

    case Chimeway.Install.Migrations.run(prefix: prefix) do
      :ok ->
        :ok

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
    end
  end

  defp parse_generation_prefix!(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      {opts, [], []} ->
        normalize_prefix_option!(Keyword.get_values(opts, :prefix))

      {_opts, rest, invalid} ->
        details =
          [format_rest(rest), format_invalid(invalid)]
          |> Enum.reject(&(&1 == ""))
          |> Enum.join("; ")

        raise_usage!("unsupported arguments#{format_details(details)}")
    end
  end

  defp normalize_prefix_option!([]), do: :chimeway
  defp normalize_prefix_option!(["chimeway"]), do: :chimeway
  defp normalize_prefix_option!(["public"]), do: :public

  defp normalize_prefix_option!([prefix]) do
    raise_usage!("unsupported --prefix value #{inspect(prefix)}")
  end

  defp normalize_prefix_option!(prefixes) do
    raise_usage!("pass --prefix at most once, got #{inspect(prefixes)}")
  end

  defp format_rest([]), do: ""
  defp format_rest(rest), do: "unexpected positional arguments #{inspect(rest)}"

  defp format_invalid([]), do: ""

  defp format_invalid(invalid) do
    invalid =
      Enum.map_join(invalid, ", ", fn {switch, value} ->
        if value do
          "#{switch} #{value}"
        else
          switch
        end
      end)

    "unknown options #{invalid}"
  end

  defp format_details(""), do: ""
  defp format_details(details), do: ": #{details}"

  defp raise_usage!(reason) do
    Mix.raise("""
    Installation blocked: #{reason}

    #{@usage}
    """)
  end
end
