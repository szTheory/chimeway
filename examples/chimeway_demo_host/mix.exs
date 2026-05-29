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
      {:chimeway, path: "../.."}
    ]
  end

  defp aliases do
    [
      test: ["test"],
      "demo.trace": ["run priv/scripts/trace_demo.exs"]
    ]
  end
end
