defmodule Chimeway.Install.MigrationsTest do
  use ExUnit.Case, async: false

  alias Chimeway.Install.Migrations
  alias Chimeway.Install.Migrations.RepoMissingError

  @moduletag :installer

  @expected_slugs [
    "create_chimeway_events",
    "create_chimeway_notifications",
    "create_chimeway_deliveries",
    "create_chimeway_delivery_attempts",
    "create_chimeway_notification_preferences",
    "add_correlation_id_to_chimeway_events",
    "create_chimeway_category_preferences",
    "create_chimeway_policy_settings",
    "add_attempt_history_columns",
    "add_delivery_orchestration_fields_to_chimeway_deliveries",
    "add_time_zone_to_chimeway_policy_settings",
    "create_chimeway_digest_rules",
    "create_chimeway_digest_buckets",
    "create_chimeway_digest_memberships",
    "alter_chimeway_digest_buckets_for_emission",
    "alter_chimeway_digest_memberships_for_resolution",
    "alter_chimeway_deliveries_for_digest_outcome",
    "add_rendering_contract_fields",
    "add_render_channels_to_chimeway_notifications",
    "add_orchestration_snapshot_to_chimeway_notifications",
    "create_chimeway_workflow_definitions",
    "create_chimeway_workflow_steps",
    "add_workflow_definition_id_to_chimeway_notifications",
    "create_chimeway_workflow_runs",
    "create_chimeway_workflow_transitions",
    "alter_chimeway_deliveries_for_workflow_linkage",
    "create_chimeway_signals_and_spine",
    "add_adapter_module_to_chimeway_delivery_attempts",
    "add_provider_message_id_to_delivery_attempts",
    "add_tenant_and_actor_to_chimeway_deliveries",
    "create_chimeway_webhook_ingress"
  ]

  test "list_templates/0 returns 31 ordered entries matching canonical slugs" do
    templates = Migrations.list_templates()

    assert length(templates) == 31

    slugs = Enum.map(templates, fn {_order, slug, _path} -> slug end)
    assert slugs == @expected_slugs

    orders = Enum.map(templates, fn {order, _slug, _path} -> order end)
    assert orders == Enum.to_list(1..31)

    refute "create_oban_jobs_tables" in slugs
  end

  test "extract_slug/1 from template filename" do
    assert Migrations.extract_slug("001_create_chimeway_events.exs") == "create_chimeway_events"
  end

  test "rewrite_namespace/2 replaces Chimeway.Repo.Migrations with host prefix" do
    content = """
    defmodule Chimeway.Repo.Migrations.CreateChimewayEvents do
      use Ecto.Migration
    end
    """

    result = Migrations.rewrite_namespace(content, "InstallerHost.Repo.Migrations")

    assert result =~ "InstallerHost.Repo.Migrations.CreateChimewayEvents"
    refute result =~ "Chimeway.Repo.Migrations"
  end

  test "host_migrations_prefix/1 derives host migrations module string" do
    assert Migrations.host_migrations_prefix(InstallerHost.Repo) ==
             "InstallerHost.Repo.Migrations"
  end

  test "find_existing_by_slug/2 matches slug in host migrations directory" do
    tmp_dir = System.tmp_dir!() |> Path.join("chimeway_install_test_#{System.unique_integer()}")
    migrations_dir = Path.join(tmp_dir, "priv/repo/migrations")
    File.mkdir_p!(migrations_dir)

    path = Path.join(migrations_dir, "99999999999999_create_chimeway_events.exs")
    File.write!(path, "# stub")

    try do
      assert Migrations.find_existing_by_slug("create_chimeway_events", migrations_dir) == path
    after
      File.rm_rf!(tmp_dir)
    end
  end

  describe "resolve_repo" do
    test "resolve_repo!/0 uses config :chimeway, :repo when set" do
      previous = Application.get_env(:chimeway, :repo)

      on_exit(fn ->
        if previous do
          Application.put_env(:chimeway, :repo, previous)
        else
          Application.delete_env(:chimeway, :repo)
        end
      end)

      Application.put_env(:chimeway, :repo, TestHost.Repo)

      assert Migrations.resolve_repo!() == TestHost.Repo
      assert Migrations.resolve_repo() == {:ok, TestHost.Repo}
    end

    test "resolve_repo/0 returns repo_missing when config and mix.exs inference fail" do
      previous = Application.get_env(:chimeway, :repo)
      previous_cwd = File.cwd!()

      tmp_dir = System.tmp_dir!() |> Path.join("chimeway_repo_test_#{System.unique_integer()}")
      File.mkdir_p!(tmp_dir)

      on_exit(fn ->
        File.cd!(previous_cwd)

        if previous do
          Application.put_env(:chimeway, :repo, previous)
        else
          Application.delete_env(:chimeway, :repo)
        end

        File.rm_rf!(tmp_dir)
      end)

      Application.delete_env(:chimeway, :repo)
      File.cd!(tmp_dir)

      assert Migrations.resolve_repo() == {:error, :repo_missing}

      assert_raise RepoMissingError, fn ->
        Migrations.resolve_repo!()
      end
    end
  end
end
