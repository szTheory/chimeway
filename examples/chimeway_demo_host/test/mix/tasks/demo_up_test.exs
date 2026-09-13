defmodule Mix.Tasks.Demo.UpTest do
  @moduledoc false
  use ExUnit.Case, async: false

  test "resolves the demo host from an explicit Chimeway checkout root" do
    repo_root = Path.expand("../../../../..", __DIR__)
    expected = Path.join(repo_root, "examples/chimeway_demo_host")

    assert Mix.Tasks.Demo.Up.demo_host_path!(repo_root) == expected
  end

  test "rejects a root without the demo host before repository work begins" do
    missing_root =
      Path.join(
        System.tmp_dir!(),
        "chimeway-demo-up-missing-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(missing_root)
    on_exit(fn -> File.rm_rf!(missing_root) end)

    expected_path = Path.join(missing_root, "examples/chimeway_demo_host")

    error =
      assert_raise Mix.Error, fn ->
        Mix.Tasks.Demo.Up.demo_host_path!(missing_root)
      end

    assert error.message =~ "requires a Chimeway source checkout"
    assert error.message =~ expected_path
    assert error.message =~ "guides/introduction/golden-path.md"
  end

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
