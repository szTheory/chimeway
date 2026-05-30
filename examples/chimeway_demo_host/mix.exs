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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:plug, "~> 1.16"},
      {:jason, "~> 1.4"},
      # Oban is required by chimeway's optional workers (e.g. SignalRouterWorker, ProcessFeedbackWorker).
      # Even though chimeway declares it optional: true, the path-dep compilation resolves all
      # modules at compile time, so Oban must be present in the host's dep tree.
      {:oban, "~> 2.17"},
      {:chimeway, path: "../.."},
      {:chimeway_admin, path: "../../chimeway_admin"},
      {:mailglass, "~> 1.3"},
      # Local dev: ACCRUE_PATH=../../accrue/accrue mix deps.get
      accrue_dep(),
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  defp accrue_dep do
    case System.get_env("ACCRUE_PATH") do
      nil -> {:accrue, "~> 1.2", optional: true, runtime: false, override: true}
      path -> {:accrue, path: path, optional: true, runtime: false, override: true}
    end
  end

  defp aliases do
    [
      test: ["test"],
      "demo.trace": ["run priv/scripts/trace_demo.exs"]
    ]
  end
end
