defmodule APNSConsumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :apns_consumer,
      version: "0.1.0",
      elixir: "~> 1.17",
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [{:chimeway, path: System.fetch_env!("CHIMEWAY_PACKAGE_PATH")}, {:oban, "~> 2.17"} | pigeon_dep()]
  end

  defp pigeon_dep do
    if System.get_env("CHIMEWAY_APNS_ENABLED") == "1" do
      [
        {:pigeon, "== 2.0.1"},
        {:httpoison, "== 3.0.0", override: true},
        {:hackney, "== 4.7.4", override: true}
      ]
    else
      []
    end
  end
end
