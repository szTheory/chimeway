defmodule Mix.Tasks.Demo.UpTest do
  @moduledoc false
  use ExUnit.Case, async: false

  @tag :journey
  @tag :jour_05
  # Spawns `mix demo.up --check`, which cold-compiles the demo host in :dev on
  # CI (no dev _build cache) before running the readiness check — well past the
  # 60s ExUnit default. Runs in ~2s warm locally; this is slow-not-hung.
  @tag timeout: 300_000
  test "JOUR-05 mix demo.up --check exits 0" do
    repo_root = Path.expand("../../../../..", __DIR__)

  {output, status} =
    System.cmd("mix", ["demo.up", "--check"],
      cd: repo_root,
      env: [
        {"MIX_ENV", "dev"},
        {"PGHOST", System.get_env("PGHOST") || "localhost"},
        {"PGUSER", System.get_env("PGUSER") || System.get_env("USER") || "postgres"},
        {"PGPASSWORD", System.get_env("PGPASSWORD") || ""}
      ],
      stderr_to_stdout: true
    )

  assert status == 0, "mix demo.up --check failed:\n#{output}"
  assert output =~ "TeamPulse demo ready"
  assert output =~ "admin/chimeway"
  end
end
