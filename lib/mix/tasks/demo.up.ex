defmodule Mix.Tasks.Demo.Up do
  @moduledoc """
  Prepare TeamPulse demo data for local click-around and CI smoke checks.

  ## Usage

      mix demo.up              # migrate + seed + print admin URL
      mix demo.up --check      # CI smoke — seed only, exit 0
      mix demo.up --serve      # migrate + seed + start demo host admin UI

  """
  @shortdoc "Migrate, seed TeamPulse demo, print admin URL"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    check? = "--check" in args
    serve? = "--serve" in args

    unless check? do
      Mix.Task.run("ecto.create")
    end

    Mix.Task.run("ecto.migrate")
    Mix.Task.run("app.start")

    {output, status} =
      System.cmd("mix", ["demo.seed"],
        cd: demo_host_path(),
        env: demo_env(),
        stderr_to_stdout: true
      )

    if status != 0 do
      Mix.raise("demo.seed failed:\n#{output}")
    end

    print_banner()

    if serve? and not check? do
      System.cmd("mix", ["demo.admin"], cd: demo_host_path(), env: demo_env(), into: IO.stream())
    end

    :ok
  end

  defp print_banner do
    Mix.shell().info("")
    Mix.shell().info("TeamPulse demo ready")
    Mix.shell().info("  Admin UI:  http://localhost:4001/admin/chimeway")
    Mix.shell().info("  Recipient: user:alex@teampulse.test")
    Mix.shell().info("  Run:       cd examples/chimeway_demo_host && mix demo.admin")
    Mix.shell().info("")
  end

  defp demo_host_path do
    Path.expand("examples/chimeway_demo_host", File.cwd!())
  end

  defp demo_env do
    [
      {"PGHOST", System.get_env("PGHOST") || "localhost"},
      {"PGUSER", System.get_env("PGUSER") || System.get_env("USER") || "postgres"},
      {"PGPASSWORD", System.get_env("PGPASSWORD") || ""}
    ]
  end
end
