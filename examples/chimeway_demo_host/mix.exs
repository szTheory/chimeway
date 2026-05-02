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
      {:chimeway, path: "../.."}
    ]
  end

  defp aliases do
    [
      test: ["test"]
    ]
  end
end
