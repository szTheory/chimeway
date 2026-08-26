defmodule AlphaTwin.MixProject do
  use Mix.Project

  def project do
    [app: :alpha_twin, version: "0.1.0", elixir: "~> 1.17", deps: deps()]
  end

  def application, do: [extra_applications: [:logger], mod: {AlphaTwin.Application, []}]

  defp deps do
    [
      {:chimeway, path: System.fetch_env!("CHIMEWAY_PACKAGE_PATH")},
      {:crosswake, path: System.fetch_env!("CROSSWAKE_PATH"), override: true},
      {:crosswake_chimeway,
       path: Path.join(System.fetch_env!("CROSSWAKE_PATH"), "packages/crosswake_chimeway")},
      # Chimeway's dispatch worker uses this optional production dependency at
      # compile time, so the clean-room host must opt into it explicitly.
      {:oban, "~> 2.17"}
    ]
  end
end
