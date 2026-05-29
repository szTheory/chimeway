defmodule Mix.Tasks.Demo.Seed do
  @moduledoc "Seed TeamPulse demo scenarios (idempotent)."
  @shortdoc "Seed TeamPulse demo notification data"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    {:ok, _} = Application.ensure_all_started(:chimeway)

    case DemoHost.Seeds.run() do
      {:ok, _} ->
        Mix.shell().info("TeamPulse demo data seeded.")
        Mix.shell().info("Admin: #{DemoHost.Seeds.admin_url()}")
        Mix.shell().info("Search recipient: #{DemoHost.Seeds.alex_identity()}")

      {:error, reason} ->
        Mix.raise("demo.seed failed: #{inspect(reason)}")
    end
  end
end
