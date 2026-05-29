defmodule Mix.Tasks.Demo.Admin do
  @moduledoc "Seed TeamPulse data and start the demo host with admin UI."
  @shortdoc "Seed demo data and start admin UI server"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("demo.seed")

    Mix.shell().info("")
    Mix.shell().info("Starting demo host — open #{DemoHost.Seeds.admin_url()}")
    Mix.shell().info("Search recipient: #{DemoHost.Seeds.alex_identity()}")
    Mix.shell().info("")

    Mix.Task.run("phx.server")
  end
end
