defmodule Chimeway.Install.GoldenDiffTest do
  @moduledoc """
  Golden-diff contract for `mix chimeway.gen.migrations` (INST-02, D-11).

  First-run migration tree and stdout are compared against committed fixtures
  under the mode-named fixture roots:

    * `test/fixtures/installer_golden_prefixed/`
    * `test/fixtures/installer_golden_public/`

  ## Refresh golden fixture

  When templates or installer output change intentionally:

      MIX_INSTALLER_ACCEPT_GOLDEN=1 mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors

  Review the diff carefully before committing updated fixtures.
  """

  use ExUnit.Case, async: false

  alias Chimeway.Test.InstallerFixture

  @moduletag :installer
  @moduletag timeout: 300_000

  @modes [
    {"default prefixed", :default, :prefixed},
    {"explicit public legacy", :public, :public}
  ]

  for {label, install_prefix, golden_mode} <- @modes do
    @tag install_prefix: install_prefix
    @tag golden_mode: golden_mode
    test "#{label} first run matches golden fixture", context do
      root =
        "golden_#{context.golden_mode}"
        |> InstallerFixture.new_fixture_root!()
        |> InstallerFixture.scaffold_host!()

      try do
        {stdout, 0} = InstallerFixture.run_install!(root, prefix: context.install_prefix)

        tree =
          root
          |> InstallerFixture.snapshot_migrations_tree!()
          |> InstallerFixture.normalize_tree()

        stdout = InstallerFixture.normalize_stdout(stdout)

        assert_map_size(tree, 37)
        assert_no_chimeway_repo_migrations!(tree)
        refute Enum.any?(Map.keys(tree), &String.contains?(&1, "create_oban_jobs_tables"))
        assert_chimeway_migration_markers!(tree)
        assert_mode_shape!(context.golden_mode, tree)
        assert_migration_034_prefix_contract!(context.golden_mode, tree)
        assert_migration_035_target_contract!(context.golden_mode, tree)
        assert_migration_036_tenant_integrity_contract!(context.golden_mode, tree)
        assert_migration_037_apns_intent_contract!(context.golden_mode, tree)

        if InstallerFixture.accept_golden_refresh?() do
          InstallerFixture.write_golden!(context.golden_mode, tree, stdout)
        else
          InstallerFixture.assert_tree_equal(
            tree,
            InstallerFixture.load_golden_tree(context.golden_mode)
          )

          assert stdout == InstallerFixture.load_golden_stdout(context.golden_mode)
        end
      after
        File.rm_rf!(root)
      end
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

  defp assert_mode_shape!(:prefixed, tree) do
    joined = joined_tree(tree)

    assert joined =~ ~s(@chimeway_prefix "chimeway")
    assert joined =~ ~S(CREATE SCHEMA IF NOT EXISTS #{@chimeway_prefix})
    assert joined =~ "chimeway_relation(:chimeway_delivery_attempts)"
    assert joined =~ ~S|~s("#{@chimeway_prefix}"."chimeway_delivery_attempts")|
    assert joined =~ "add_tenant_identity_to_events_and_notifications"
    refute joined =~ "tenant-derived prefix"
    refute joined =~ "@chimeway_prefix false"
  end

  defp assert_mode_shape!(:public, tree) do
    joined = joined_tree(tree)

    assert joined =~ "@chimeway_prefix false"
    assert joined =~ "add_tenant_identity_to_events_and_notifications"
    refute joined =~ "tenant-derived prefix"
    refute joined =~ ~s(@chimeway_prefix "chimeway")
    refute joined =~ "CREATE SCHEMA IF NOT EXISTS chimeway"
    refute joined =~ "prefix: false"
  end

  defp assert_migration_034_prefix_contract!(mode, tree) do
    migration =
      Map.fetch!(
        tree,
        "priv/repo/migrations/TIMESTAMP_privacy_safe_delivery_evidence.exs"
      )

    expected_prefix =
      case mode do
        :prefixed -> ~s(@chimeway_prefix "chimeway")
        :public -> "@chimeway_prefix false"
      end

    assert length(Regex.scan(~r/^\s*#{Regex.escape(expected_prefix)}\s*$/m, migration)) == 1,
           "migration 034 must render exactly one #{inspect(expected_prefix)} attribute in #{mode} mode"

    refute migration =~ "__CHIMEWAY_PREFIX__",
           "migration 034 must not retain the installer prefix sentinel in #{mode} mode"
  end

  defp assert_migration_035_target_contract!(mode, tree) do
    migration =
      Map.fetch!(
        tree,
        "priv/repo/migrations/TIMESTAMP_create_chimeway_delivery_targets.exs"
      )

    expected_prefix =
      if mode == :prefixed, do: ~s(@chimeway_prefix "chimeway"), else: "@chimeway_prefix false"

    assert migration =~ expected_prefix
    assert migration =~ "chimeway_table(:chimeway_delivery_targets"
    assert migration =~ "chimeway_table(:chimeway_delivery_target_attempts"
    assert migration =~ "chimeway_references(:chimeway_deliveries"
    assert migration =~ "chimeway_references(:chimeway_delivery_targets"
    assert migration =~ "[:delivery_id, :binding_revision_ref]"
    assert migration =~ "[:delivery_target_id, :attempt_number]"
    assert migration =~ "unique: true"
    refute migration =~ "__CHIMEWAY_PREFIX__"
    refute migration =~ "tenant-derived prefix"
  end

  defp assert_migration_036_tenant_integrity_contract!(mode, tree) do
    migration =
      Map.fetch!(
        tree,
        "priv/repo/migrations/TIMESTAMP_enforce_delivery_target_tenant_integrity.exs"
      )

    expected_prefix =
      if mode == :prefixed, do: ~s(@chimeway_prefix "chimeway"), else: "@chimeway_prefix false"

    assert migration =~ expected_prefix

    for token <- [
          "[:tenant_id, :id]",
          "[:tenant_id, :delivery_target_id, :id]",
          "chimeway_delivery_targets_tenant_delivery_fkey",
          "chimeway_delivery_target_attempts_tenant_target_fkey",
          "chimeway_delivery_target_attempts_prior_same_target_fkey",
          "ON DELETE CASCADE"
        ] do
      assert migration =~ token
    end

    refute migration =~ "__CHIMEWAY_PREFIX__"
    refute migration =~ "tenant-derived prefix"
  end

  defp assert_migration_037_apns_intent_contract!(mode, tree) do
    migration =
      Map.fetch!(tree, "priv/repo/migrations/TIMESTAMP_add_apns_request_intent.exs")

    expected_prefix =
      if mode == :prefixed, do: ~s(@chimeway_prefix "chimeway"), else: "@chimeway_prefix false"

    assert length(Regex.scan(~r/^\s*#{Regex.escape(expected_prefix)}\s*$/m, migration)) == 1
    assert migration =~ "alter chimeway_table(:chimeway_delivery_targets)"
    assert migration =~ "add(:apns_request_intent, :map)"
    assert migration =~ "remove(:apns_request_intent)"
    refute migration =~ "__CHIMEWAY_PREFIX__"

    for forbidden <- ["token", "credential", "payload", "response_body"] do
      refute migration =~ forbidden
    end
  end

  defp joined_tree(tree) do
    tree
    |> Enum.sort_by(fn {path, _content} -> path end)
    |> Enum.map_join("\n", fn {_path, content} -> content end)
  end
end
