defmodule ChimewayAdmin.MixProject do
  use Mix.Project

  def project do
    [
      app: :chimeway_admin,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [mod: {ChimewayAdmin.Application, []}]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Oban modules compile from chimeway path dep (optional in core, required in hosts).
      {:oban, "~> 2.17"},
      {:chimeway, path: ".."},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.11"},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end
end
