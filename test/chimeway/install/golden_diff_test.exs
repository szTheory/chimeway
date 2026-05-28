defmodule Chimeway.Install.GoldenDiffTest do
  @moduledoc """
  Golden-diff contract for `mix chimeway.gen.migrations` (INST-02, D-11).

  First-run migration tree and stdout are compared against committed fixtures
  under `test/fixtures/installer_golden/`.

  ## Refresh golden fixture

  When templates or installer output change intentionally:

      MIX_INSTALLER_ACCEPT_GOLDEN=1 mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors

  Review the diff carefully before committing updated fixtures.
  """

  use ExUnit.Case, async: false

  alias Chimeway.Test.InstallerFixture

  @moduletag :installer
  @moduletag timeout: 300_000

  test "first run matches golden fixture" do
    root =
      "golden"
      |> InstallerFixture.new_fixture_root!()
      |> InstallerFixture.scaffold_host!()

    try do
      {stdout, 0} = InstallerFixture.run_install!(root, [])

      tree =
        root
        |> InstallerFixture.snapshot_migrations_tree!()
        |> InstallerFixture.normalize_tree()

      stdout = InstallerFixture.normalize_stdout(stdout)

      assert_map_size(tree, 31)
      assert_no_chimeway_repo_migrations!(tree)
      refute Enum.any?(Map.keys(tree), &String.contains?(&1, "create_oban_jobs_tables"))
      assert_chimeway_migration_markers!(tree)

      if InstallerFixture.accept_golden_refresh?() do
        InstallerFixture.write_golden!(tree, stdout)
      else
        assert tree == InstallerFixture.load_golden_tree()
        assert stdout == InstallerFixture.load_golden_stdout()
      end
    after
      File.rm_rf!(root)
    end
  end

  defp assert_map_size(map, expected) do
    count = map_size(map)

    assert count == expected,
           "expected #{expected} migration files, got #{count}"
  end

  defp assert_no_chimeway_repo_migrations!(tree) do
    Enum.each(tree, fn {path, content} ->
      refute String.contains?(content, "Chimeway.Repo.Migrations"),
             "expected host namespace rewrite in #{path}"
    end)
  end

  defp assert_chimeway_migration_markers!(tree) do
    Enum.each(tree, fn {path, content} ->
      slug =
        path
        |> Path.basename()
        |> String.replace_prefix("TIMESTAMP_", "")
        |> String.replace_suffix(".exs", "")

      assert content =~ "# chimeway_migration: #{slug}",
             "missing marker comment in #{path}"
    end)
  end
end
