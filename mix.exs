defmodule Chimeway.MixProject do
  use Mix.Project

  def project do
    [
      app: :chimeway,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Chimeway.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},
      {:nimble_options, "~> 1.1"},
      {:jason, "~> 1.4"}
    ]
  end

  defp aliases do
    [
      "verify.phase1": ["format --check-formatted", "compile --warnings-as-errors", "test"]
    ]
  end
end
