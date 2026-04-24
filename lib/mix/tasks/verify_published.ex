defmodule Mix.Tasks.Verify.Published do
  @moduledoc """
  Verifies that a specific chimeway version is published and accessible on hex.pm.

  Usage:

      mix verify.published 0.1.0

  Exits non-zero if the version is not found or the hex.pm API is unreachable.
  Run this after `mix hex.publish` as part of the release verification trio.
  """

  use Mix.Task

  @shortdoc "Verify chimeway is published and accessible at the given version on hex.pm"

  @impl Mix.Task
  def run([]) do
    Mix.shell().error("Usage: mix verify.published <version>")
    exit({:shutdown, 1})
  end

  def run([version | _]) do
    url = "https://hex.pm/api/packages/chimeway/releases/#{version}"
    Mix.shell().info("Checking hex.pm for chimeway v#{version}...")

    case System.cmd("curl", ["-sf", "--max-time", "10", url], stderr_to_stdout: true) do
      {_body, 0} ->
        Mix.shell().info("OK: chimeway v#{version} is published on hex.pm.")

      {output, code} ->
        Mix.shell().error(
          "FAIL: chimeway v#{version} not found on hex.pm (exit #{code}).\n#{output}"
        )

        exit({:shutdown, 1})
    end
  end
end
