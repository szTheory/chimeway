defmodule Chimeway.Install.Migrations do
  @moduledoc """
  Copy-based installer core for Chimeway schema migrations.

  Reads canonical templates from `priv/chimeway_migrations/` and writes
  host-namespaced files under `priv/repo/migrations/` with slug-based idempotency.

  Oban job tables are **not** included — configure Oban separately via
  [Oban integration guide](guides/recipes/oban-integration.md).
  """

  defmodule RepoMissingError do
    defexception message: "repo_missing"
  end

  @template_dir "chimeway_migrations"
  @migrations_dir Path.join(["priv", "repo", "migrations"])
  @source_namespace "Chimeway.Repo.Migrations"

  @doc """
  Returns `[{order, slug, template_path}]` sorted by order prefix.
  """
  def list_templates do
    templates_root()
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".exs"))
    |> Enum.map(&parse_template_entry/1)
    |> Enum.sort_by(&elem(&1, 0))
  end

  @doc """
  Generates host migration files from shipped templates.

  Options:

    * `:repo` — override host repo module (defaults to resolved config or mix.exs inference)
    * `:io` — IO device for progress output (defaults to `Mix.shell()`)

  Returns `:ok` on success or `{:error, :repo_missing}` when the host repo cannot be resolved.
  """
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

  @doc """
  Resolves the host Ecto repo module.

  Returns `{:ok, repo}` or `{:error, :repo_missing}`.
  """
  def resolve_repo(repo_override \\ nil)

  def resolve_repo(nil) do
    case Application.get_env(:chimeway, :repo) do
      repo when is_atom(repo) and not is_nil(repo) ->
        validate_repo!(repo)

      _ ->
        infer_repo_from_mix_exs()
    end
  end

  def resolve_repo(repo) when is_atom(repo) do
    validate_repo!(repo)
  end

  def resolve_repo(_invalid) do
    {:error, :repo_missing}
  end

  @doc """
  Resolves the host Ecto repo module or raises `RepoMissingError`.
  """
  def resolve_repo! do
    case resolve_repo() do
      {:ok, repo} -> repo
      {:error, :repo_missing} -> raise RepoMissingError
    end
  end

  @doc """
  Extracts the stable migration slug from a template filename or marker comment.
  """
  def extract_slug(filename) when is_binary(filename) do
    basename = Path.basename(filename, ".exs")

    case Regex.run(~r/^[0-9]{3}_(.+)$/, basename) do
      [_, slug] -> slug
      _ -> extract_slug_from_marker(filename)
    end
  end

  def extract_slug(path) when is_list(path) do
    path |> Path.join() |> extract_slug()
  end

  @doc """
  Rewrites template namespace from `Chimeway.Repo.Migrations` to the host prefix.
  """
  def rewrite_namespace(content, host_prefix) when is_binary(content) and is_binary(host_prefix) do
    String.replace(content, @source_namespace, host_prefix)
  end

  @doc """
  Finds an existing host migration file matching `*_{slug}.exs`, or `nil`.
  """
  def find_existing_by_slug(slug, migrations_dir \\ @migrations_dir) do
    :ok = validate_slug!(slug)

    Path.wildcard(Path.join(migrations_dir, "*_#{slug}.exs"))
    |> Enum.sort()
    |> List.first()
  end

  @doc """
  Derives the host migrations module prefix string from a repo module.

      iex> Chimeway.Install.Migrations.host_migrations_prefix(MyApp.Repo)
      "MyApp.Repo.Migrations"
  """
  def host_migrations_prefix(repo) when is_atom(repo) do
    repo
    |> Module.split()
    |> Enum.drop(-1)
    |> Kernel.++(["Repo", "Migrations"])
    |> Enum.join(".")
  end

  defp templates_root do
    Path.join(:code.priv_dir(:chimeway), @template_dir)
  end

  defp parse_template_entry(filename) do
    slug = extract_slug(filename)
    :ok = validate_slug!(slug)

    order =
      filename
      |> String.slice(0, 3)
      |> String.to_integer()

    {order, slug, Path.join(templates_root(), filename)}
  end

  defp extract_slug_from_marker(path) do
    path
    |> File.read!()
    |> String.split("\n", parts: 2)
    |> List.first()
    |> case do
      "# chimeway_migration: " <> slug -> String.trim(slug)
      _ -> raise ArgumentError, "invalid template slug in #{path}"
    end
  end

  defp validate_slug!(slug) do
    if Regex.match?(~r/^[a-z0-9_]+$/, slug) do
      :ok
    else
      raise ArgumentError, "invalid migration slug: #{inspect(slug)}"
    end
  end

  defp validate_repo!(repo) when is_atom(repo) do
    repo_string = Atom.to_string(repo)

    if String.ends_with?(repo_string, ".Repo") do
      {:ok, repo}
    else
      {:error, :repo_missing}
    end
  end

  defp validate_repo!(_), do: {:error, :repo_missing}

  defp infer_repo_from_mix_exs do
    mix_exs = Path.join(File.cwd!(), "mix.exs")

    with {:ok, content} <- File.read(mix_exs),
         [_, app] <- Regex.run(~r/app:\s*:(\w+)/, content) do
      app_module = Macro.camelize(app)
      validate_repo!(Module.concat([app_module, Repo]))
    else
      _ -> {:error, :repo_missing}
    end
  end

  defp batch_base_timestamp do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end

  defp timestamp_for_index(base_ts, index) do
    base_ts
    |> NaiveDateTime.add(index, :second)
    |> Calendar.strftime("%Y%m%d%H%M%S")
  end
end
