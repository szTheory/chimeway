defmodule Chimeway.Test.InstallerFixture do
  @moduledoc false

  @fixtures_dir Path.expand("../fixtures", __DIR__)
  @accept_golden_env "MIX_INSTALLER_ACCEPT_GOLDEN"

  @doc """
  Creates a unique tmp directory under `System.tmp_dir!()/chimeway_installer_*`.
  """
  @spec new_fixture_root!(String.t()) :: Path.t()
  def new_fixture_root!(name) when is_binary(name) do
    # `System.unique_integer/1` is local to one BEAM VM. Installer tests run
    # from independent Mix VMs as well, so their roots need process-independent
    # entropy to avoid deleting each other's transient build trees.
    suffix = :crypto.strong_rand_bytes(12) |> Base.encode32(case: :lower, padding: false)
    root = Path.join(System.tmp_dir!(), "chimeway_installer_#{name}_#{suffix}")
    File.rm_rf!(root)
    File.mkdir_p!(root)
    root
  end

  @doc """
  Writes a minimal host app scaffold with path dep to in-tree chimeway.
  """
  @spec scaffold_host!(Path.t()) :: Path.t()
  def scaffold_host!(root) when is_binary(root) do
    File.mkdir_p!(Path.join(root, "priv/repo/migrations"))
    File.mkdir_p!(Path.join(root, "config"))

    File.write!(Path.join(root, "mix.exs"), host_mix_exs())
    File.write!(Path.join(root, "config/config.exs"), host_config_exs())

    root
  end

  @doc """
  Runs `mix chimeway.gen.migrations` in a subprocess and returns `{output, status}`.
  """
  @spec run_install!(Path.t(), keyword()) :: {String.t(), non_neg_integer()}
  def run_install!(root, opts \\ []) when is_binary(root) do
    ensure_deps!(root)

    System.cmd("mix", install_args(Keyword.get(opts, :prefix, :default)),
      cd: root,
      stderr_to_stdout: true,
      env: command_env()
    )
  end

  @doc """
  Returns the committed golden fixture directory for a generation mode.
  """
  @spec golden_dir(:prefixed | :chimeway | :public) :: Path.t()
  def golden_dir(:prefixed), do: Path.join(@fixtures_dir, "installer_golden_prefixed")
  def golden_dir(:chimeway), do: golden_dir(:prefixed)
  def golden_dir(:public), do: Path.join(@fixtures_dir, "installer_golden_public")

  @doc """
  Returns a map of relative migration path → file contents.
  """
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

  @doc """
  Normalizes migration file content for golden diff (CRLF, timestamps, tmp paths).
  """
  @spec normalize_content(String.t()) :: String.t()
  def normalize_content(content) when is_binary(content) do
    content
    |> normalize_newlines()
    |> normalize_tmp_paths()
    |> normalize_timestamps_in_content()
  end

  @doc """
  Normalizes captured stdout for golden diff.
  """
  @spec normalize_stdout(String.t()) :: String.t()
  def normalize_stdout(stdout) when is_binary(stdout) do
    stdout
    |> strip_ansi()
    |> normalize_newlines()
    |> normalize_tmp_paths()
    |> normalize_timestamps_in_content()
    |> normalize_timestamps_in_paths()
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.reject(&compile_noise?/1)
    |> Enum.join("\n")
    |> String.trim_trailing()
  end

  @doc """
  Normalizes migration tree keys and values for golden diff.
  """
  @spec normalize_tree(%{String.t() => String.t()}) :: %{String.t() => String.t()}
  def normalize_tree(tree) when is_map(tree) do
    tree
    |> Enum.map(fn {rel, content} ->
      {normalize_migration_path(rel), normalize_content(content)}
    end)
    |> Map.new()
  end

  @doc false
  def accept_golden_refresh? do
    System.get_env(@accept_golden_env) == "1"
  end

  @doc """
  Writes normalized tree and stdout to the committed golden fixture directory.
  """
  @spec write_golden!(:prefixed | :chimeway | :public, map(), String.t()) :: :ok
  def write_golden!(mode, tree, stdout) when is_map(tree) and is_binary(stdout) do
    golden_dir = golden_dir(mode)
    tree_dir = Path.join(golden_dir, "tree/priv/repo/migrations")
    File.rm_rf!(Path.dirname(tree_dir))
    File.mkdir_p!(tree_dir)

    Enum.each(tree, fn {rel, content} ->
      dest = Path.join([golden_dir, "tree", rel])
      File.mkdir_p!(Path.dirname(dest))
      File.write!(dest, content)
    end)

    File.write!(Path.join(golden_dir, "STDOUT.txt"), stdout <> "\n")
    :ok
  end

  @doc """
  Loads the committed golden migration tree.
  """
  @spec load_golden_tree(:prefixed | :chimeway | :public) :: %{String.t() => String.t()}
  def load_golden_tree(mode) do
    golden_dir = golden_dir(mode)
    tree_dir = Path.join(golden_dir, "tree")

    tree_dir
    |> Path.join("**/*.exs")
    |> Path.wildcard()
    |> Enum.sort()
    |> Map.new(fn abs_path ->
      rel = Path.relative_to(abs_path, Path.join(golden_dir, "tree"))
      {rel, File.read!(abs_path)}
    end)
  end

  @doc """
  Loads the committed golden stdout fixture.
  """
  @spec load_golden_stdout(:prefixed | :chimeway | :public) :: String.t()
  def load_golden_stdout(mode) do
    mode
    |> golden_dir()
    |> Path.join("STDOUT.txt")
    |> File.read!()
    |> String.trim_trailing()
  end

  @doc """
  Asserts two normalized trees are equal with actionable diff output.
  """
  @spec assert_tree_equal(map(), map()) :: :ok
  def assert_tree_equal(actual, expected) when is_map(actual) and is_map(expected) do
    actual_paths = actual |> Map.keys() |> Enum.sort()
    expected_paths = expected |> Map.keys() |> Enum.sort()

    missing = expected_paths -- actual_paths
    extra = actual_paths -- expected_paths

    if missing != [] or extra != [] do
      flunk("""
      Migration tree differs from golden fixture.

        Missing from generated output:
          #{Enum.join(missing, "\n      ")}

        Extra in generated output:
          #{Enum.join(extra, "\n      ")}
      """)
    end

    for path <- expected_paths do
      actual_content = Map.fetch!(actual, path)
      expected_content = Map.fetch!(expected, path)

      if actual_content != expected_content do
        flunk("""
        Content differs at #{path}:

        #{render_diff(expected_content, actual_content)}
        """)
      end
    end

    :ok
  end

  defp ensure_deps!(root) do
    {output, status} =
      System.cmd("mix", ["deps.get"],
        cd: root,
        stderr_to_stdout: true,
        env: command_env()
      )

    if status != 0 do
      raise "mix deps.get failed in #{root}:\n#{output}"
    end

    {compile_output, compile_status} =
      System.cmd("mix", ["compile"],
        cd: root,
        stderr_to_stdout: true,
        env: command_env()
      )

    if compile_status != 0 do
      raise "mix compile failed in #{root}:\n#{compile_output}"
    end
  end

  defp install_args(:default), do: ["chimeway.gen.migrations"]
  defp install_args(:chimeway), do: ["chimeway.gen.migrations", "--prefix", "chimeway"]
  defp install_args(:public), do: ["chimeway.gen.migrations", "--prefix", "public"]

  defp install_args(prefix) do
    raise ArgumentError,
          "unsupported installer fixture prefix #{inspect(prefix)}; " <>
            "expected :default, :chimeway, or :public"
  end

  # The installer host exercises Chimeway's migration generator only. Keep
  # optional ecosystem adapters out of its dependency graph so unrelated
  # partner packages and their compiler toolchains cannot affect the fixture.
  defp command_env do
    [
      {"MIX_ENV", "dev"},
      {"CHIMEWAY_SKIP_MAILGLASS_DEP", "1"},
      {"CHIMEWAY_SKIP_ACCRUE_DEP", "1"},
      {"CHIMEWAY_SKIP_THREADLINE_DEP", "1"},
      {"CHIMEWAY_SKIP_SIGRA_DEP", "1"}
    ]
  end

  defp host_mix_exs do
    chimeway_root = chimeway_repo_root()

    """
    defmodule InstallerHost.MixProject do
      use Mix.Project

      def project do
        [
          app: :installer_host,
          version: "0.0.1",
          elixir: "~> 1.17",
          start_permanent: Mix.env() == :prod,
          deps: deps()
        ]
      end

      defp deps do
        [
          {:chimeway, path: #{inspect(chimeway_root)}},
          {:oban, "~> 2.17"}
        ]
      end
    end
    """
  end

  defp host_config_exs do
    """
    import Config

    config :chimeway, repo: InstallerHost.Repo
    """
  end

  defp chimeway_repo_root do
    __DIR__
    |> Path.join("../..")
    |> Path.expand()
  end

  defp normalize_newlines(content) do
    String.replace(content, "\r\n", "\n")
  end

  defp normalize_tmp_paths(content) do
    Regex.replace(~r/[^\s"]*chimeway_installer_[^\s"]+/, content, "<TMP_PATH>")
  end

  defp normalize_timestamps_in_content(content) do
    Regex.replace(~r/\b\d{14}(?=_[a-z0-9_]+\.exs)/, content, "TIMESTAMP")
  end

  defp normalize_timestamps_in_paths(content) do
    Regex.replace(~r/\b\d{14}_/, content, "TIMESTAMP_")
  end

  defp normalize_migration_path(rel) do
    rel
    |> String.replace(~r|priv/repo/migrations/\d{14}_|, "priv/repo/migrations/TIMESTAMP_")
  end

  defp strip_ansi(content) do
    Regex.replace(~r/\e\[[0-9;]*[A-Za-z]/, content, "")
  end

  defp compile_noise?(line) do
    cond do
      String.starts_with?(line, "==> ") -> true
      String.starts_with?(line, "===> ") -> true
      String.match?(line, ~r/^Compiling \d+ files?/) -> true
      String.match?(line, ~r/^Generated .+ app$/) -> true
      String.match?(line, ~r/^warning: this clause of defp/) -> true
      String.match?(line, ~r/^│/) -> true
      String.match?(line, ~r/^└─/) -> true
      String.match?(line, ~r/^\s+\d+ │/) -> true
      String.match?(line, ~r/^\s+~$/) -> true
      true -> false
    end
  end

  defp render_diff(expected, actual) do
    String.myers_difference(expected, actual)
    |> Enum.map(fn
      {:eq, _} -> ""
      {:del, s} -> "- " <> inspect(s)
      {:ins, s} -> "+ " <> inspect(s)
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp flunk(message) do
    ExUnit.Assertions.flunk(message)
  end
end
