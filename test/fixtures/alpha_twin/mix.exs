defmodule AlphaTwin.MixProject do
  use Mix.Project

  def project do
    [
      app: :alpha_twin,
      version: "0.1.0",
      elixir: "~> 1.17",
      build_path: System.get_env("MIX_BUILD_PATH") || "_build",
      deps_path: System.get_env("MIX_DEPS_PATH") || "deps",
      lockfile: System.get_env("MIX_LOCKFILE") || "mix.lock",
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger], mod: {AlphaTwin.Application, []}]

  defp deps do
    [
      {:chimeway, path: System.fetch_env!("CHIMEWAY_PACKAGE_PATH")},
      {:crosswake, path: System.fetch_env!("CROSSWAKE_PATH"), override: true},
      {:crosswake_chimeway,
       path: Path.join(System.fetch_env!("CROSSWAKE_PATH"), "packages/crosswake_chimeway")},
      {:crosswake_sigra,
       path: Path.join(System.fetch_env!("CROSSWAKE_PATH"), "packages/crosswake_sigra")},
      # Chimeway's dispatch worker uses this optional production dependency at
      # compile time, so the clean-room host must opt into it explicitly.
      {:oban, "~> 2.17"}
    ]
  end
end
