defmodule Chimeway.Install.IdempotencyTest do
  use ExUnit.Case, async: false

  alias Chimeway.Test.InstallerFixture

  @moduletag :installer
  @moduletag timeout: 300_000

  @modes [
    {"default prefixed", :default, :prefixed},
    {"explicit public legacy", :public, :public}
  ]

  for {label, install_prefix, fixture_name} <- @modes do
    @tag install_prefix: install_prefix
    @tag fixture_name: fixture_name
    test "#{label} second run produces no fixture diff", context do
      root =
        "idempotency_#{context.fixture_name}"
        |> InstallerFixture.new_fixture_root!()
        |> InstallerFixture.scaffold_host!()

      try do
        {_stdout, 0} = InstallerFixture.run_install!(root, prefix: context.install_prefix)

        before =
          root
          |> InstallerFixture.snapshot_migrations_tree!()
          |> InstallerFixture.normalize_tree()

        assert map_size(before) == 31

        {second_stdout, 0} = InstallerFixture.run_install!(root, prefix: context.install_prefix)

        after_tree =
          root
          |> InstallerFixture.snapshot_migrations_tree!()
          |> InstallerFixture.normalize_tree()

        assert before == after_tree
        assert map_size(after_tree) == 31

        normalized_stdout = InstallerFixture.normalize_stdout(second_stdout)

        unchanged_lines =
          normalized_stdout
          |> String.split("\n", trim: true)
          |> Enum.filter(&String.starts_with?(&1, "unchanged priv/repo/migrations/"))

        created_lines =
          normalized_stdout
          |> String.split("\n", trim: true)
          |> Enum.filter(&String.starts_with?(&1, "created priv/repo/migrations/"))

        assert length(unchanged_lines) == 31
        assert created_lines == []
      after
        File.rm_rf!(root)
      end
    end
  end
end
