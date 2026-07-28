defmodule DemoHost.MixProject do
  use Mix.Project

  def project do
    [
      app: :demo_host,
      version: "0.0.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: false,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [mod: {DemoHost.Application, []}, extra_applications: [:logger]]
  end

  defp elixirc_paths(:test) do
    ["lib", "test/support"] ++ accrue_test_paths()
  end

  defp elixirc_paths(_), do: ["lib"]

  defp accrue_test_paths do
    case System.get_env("ACCRUE_PATH") do
      nil -> []
      "" -> []
      _ -> ["accrue_support"]
    end
  end

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:plug, "~> 1.16"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      # Pin decimal to 2.x so the demo host stays on ecto ~> 3.13 (ecto 3.14 forces
      # decimal ~> 3.0). The accrue integration lane adds the accrue path dep, which
      # requires decimal ~> 2.0 / ecto ~> 3.13; without this, deps.get in that lane
      # fails to resolve (locked ecto 3.14 → decimal ~> 3.0 vs accrue's ~> 2.0). Root
      # chimeway already resolves this exact combo (ecto 3.13.6 / decimal 2.4.1).
      {:decimal, "~> 2.0", override: true},
      # Keep ecto on 3.13.x (matches root chimeway); ecto 3.14 requires decimal ~> 3.0,
      # which is incompatible with the accrue path dep's decimal ~> 2.0 (see above).
      {:ecto_sql, "~> 3.13.0", override: true},
      # Oban is required by chimeway's optional workers (e.g. SignalRouterWorker, ProcessFeedbackWorker).
      # Even though chimeway declares it optional: true, the path-dep compilation resolves all
      # modules at compile time, so Oban must be present in the host's dep tree.
      {:oban, "~> 2.17"},
      {:chimeway, path: "../..", override: true},
      {:chimeway_admin, path: "../../chimeway_admin"},
      {:chimeway_inbox, path: "../../chimeway_inbox"},
      {:mailglass, "~> 1.3"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:lazy_html, ">= 0.1.0", only: :test}
    ] ++ accrue_deps() ++ threadline_deps() ++ sigra_deps()
  end

  defp accrue_deps do
    case System.get_env("ACCRUE_PATH") do
      nil -> []
      path -> [{:accrue, path: path, optional: true, runtime: false, override: true}]
    end
  end

  defp threadline_deps do
    if System.get_env("CHIMEWAY_SKIP_THREADLINE_DEP") in ["1", "true"] do
      []
    else
      case System.get_env("THREADLINE_PATH") do
        nil -> [{:threadline, "~> 0.7", runtime: false}]
        path -> [{:threadline, path: path, runtime: false}]
      end
    end
  end

  defp sigra_deps do
    if System.get_env("CHIMEWAY_SKIP_SIGRA_DEP") in ["1", "true"] do
      []
    else
      case System.get_env("SIGRA_PATH") do
        nil -> [{:sigra, "~> 0.3", runtime: false, override: true}]
        path -> [{:sigra, path: path, runtime: false, override: true}]
      end
    end
  end

  defp aliases do
    [
      test: ["test"],
      "demo.trace": ["run priv/scripts/trace_demo.exs"]
    ]
  end
end
