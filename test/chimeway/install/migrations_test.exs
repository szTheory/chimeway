defmodule Chimeway.Install.MigrationsTest do
  use ExUnit.Case, async: false

  alias Chimeway.Install.Migrations
  alias Chimeway.Install.Migrations.{DuplicateSlugError, RepoMissingError}

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
    "create_chimeway_webhook_ingress",
    "add_tenant_identity_to_events_and_notifications",
    "make_chimeway_delivery_tenant_nullable",
    "privacy_safe_delivery_evidence",
    "create_chimeway_delivery_targets",
    "enforce_delivery_target_tenant_integrity",
    "add_apns_request_intent"
  ]

  test "list_templates/0 returns 37 ordered entries matching canonical slugs" do
    templates = Migrations.list_templates()

    assert length(templates) == 37

    slugs = Enum.map(templates, fn {_order, slug, _path} -> slug end)
    assert slugs == @expected_slugs

    orders = Enum.map(templates, fn {order, _slug, _path} -> order end)
    assert orders == Enum.to_list(1..37)

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

  describe "render_template/3" do
    test "rewrites namespace and renders chimeway prefix sentinel" do
      content = """
      defmodule Chimeway.Repo.Migrations.CreateChimewayEvents do
        use Ecto.Migration

        @chimeway_prefix __CHIMEWAY_PREFIX__
      end
      """

      result =
        Migrations.render_template(
          content,
          "InstallerHost.Repo.Migrations",
          :chimeway
        )

      assert result =~ "InstallerHost.Repo.Migrations.CreateChimewayEvents"
      assert result =~ ~s(@chimeway_prefix "chimeway")
      refute result =~ "__CHIMEWAY_PREFIX__"
      refute result =~ "Chimeway.Repo.Migrations"
    end

    test "renders public prefix sentinel without runtime prefix config influence" do
      previous = Application.fetch_env(:chimeway, :prefix)

      on_exit(fn ->
        case previous do
          {:ok, value} -> Application.put_env(:chimeway, :prefix, value)
          :error -> Application.delete_env(:chimeway, :prefix)
        end
      end)

      Application.put_env(:chimeway, :prefix, "chimeway")

      content = """
      defmodule Chimeway.Repo.Migrations.CreateChimewayEvents do
        use Ecto.Migration

        @chimeway_prefix __CHIMEWAY_PREFIX__
      end
      """

      result =
        Migrations.render_template(
          content,
          "InstallerHost.Repo.Migrations",
          :public
        )

      assert result =~ "@chimeway_prefix false"
      refute result =~ ~s(@chimeway_prefix "chimeway")
      refute result =~ "__CHIMEWAY_PREFIX__"
    end
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

  test "find_existing_by_slug/2 raises when duplicate slug files exist" do
    tmp_dir = System.tmp_dir!() |> Path.join("chimeway_install_test_#{System.unique_integer()}")
    migrations_dir = Path.join(tmp_dir, "priv/repo/migrations")
    File.mkdir_p!(migrations_dir)

    first = Path.join(migrations_dir, "11111111111111_create_chimeway_events.exs")
    second = Path.join(migrations_dir, "22222222222222_create_chimeway_events.exs")
    File.write!(first, "# stub")
    File.write!(second, "# stub")

    try do
      assert_raise DuplicateSlugError,
                   ~r/duplicate migration slug "create_chimeway_events"/,
                   fn ->
                     Migrations.find_existing_by_slug("create_chimeway_events", migrations_dir)
                   end
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

    test "resolve_repo/0 returns umbrella_root when mix.exs declares apps_path" do
      previous = Application.get_env(:chimeway, :repo)
      previous_cwd = File.cwd!()

      tmp_dir =
        System.tmp_dir!() |> Path.join("chimeway_umbrella_test_#{System.unique_integer()}")

      File.mkdir_p!(tmp_dir)

      File.write!(
        Path.join(tmp_dir, "mix.exs"),
        """
        defmodule UmbrellaRoot.MixProject do
          use Mix.Project

          def project do
            [
              apps_path: "apps",
              app: :umbrella_root,
              version: "0.0.1",
              elixir: "~> 1.17",
              deps: []
            ]
          end
        end
        """
      )

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

      assert Migrations.resolve_repo() == {:error, :umbrella_root}
    end
  end

  describe "run/1 in tmp host" do
    test "first run creates 37 files with host namespaces" do
      tmp = scaffold_tmp_host!(include_config: true)
      restore_repo_env()

      Application.put_env(:chimeway, :repo, InstallerHost.Repo)

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          File.cd!(tmp, fn ->
            assert :ok = Migrations.run()
          end)
        end)

      migrations_dir = Path.join(tmp, "priv/repo/migrations")
      files = File.ls!(migrations_dir)

      assert length(files) == 37
      refute Enum.any?(files, &String.contains?(&1, "create_oban_jobs_tables"))

      Enum.each(files, fn file ->
        content = File.read!(Path.join(migrations_dir, file))
        assert content =~ "# chimeway_migration:"
        refute content =~ "Chimeway.Repo.Migrations"
      end)

      created_lines =
        output
        |> String.split("\n", trim: true)
        |> Enum.filter(&String.starts_with?(&1, "created "))

      assert length(created_lines) == 37
      assert Enum.all?(created_lines, &String.contains?(&1, "priv/repo/migrations/"))
    end

    test "repo inference without config uses mix.exs app module" do
      tmp = scaffold_tmp_host!(include_config: false)
      restore_repo_env()
      Application.delete_env(:chimeway, :repo)

      File.cd!(tmp, fn ->
        assert :ok = Migrations.run()
      end)

      migrations_dir = Path.join(tmp, "priv/repo/migrations")
      assert length(File.ls!(migrations_dir)) == 37

      [sample | _] = File.ls!(migrations_dir)
      content = File.read!(Path.join(migrations_dir, sample))
      assert content =~ "InstallerHost.Repo.Migrations"
    end

    test "second run is idempotent with unchanged output only" do
      tmp = scaffold_tmp_host!(include_config: true)
      restore_repo_env()
      Application.put_env(:chimeway, :repo, InstallerHost.Repo)

      File.cd!(tmp, fn ->
        ExUnit.CaptureIO.capture_io(fn -> assert :ok = Migrations.run() end)

        second_output =
          ExUnit.CaptureIO.capture_io(fn ->
            assert :ok = Migrations.run()
          end)

        assert length(File.ls!("priv/repo/migrations")) == 37

        lines = second_output |> String.split("\n", trim: true)

        unchanged_lines = Enum.filter(lines, &String.starts_with?(&1, "unchanged "))
        created_lines = Enum.filter(lines, &String.starts_with?(&1, "created "))

        assert length(unchanged_lines) == 37
        assert created_lines == []
      end)
    end
  end

  describe "mix chimeway.gen.migrations subprocess" do
    test "accepted generation prefix modes exit successfully via app.config path" do
      tmp = scaffold_tmp_host!(include_config: true)

      install_deps!(tmp)

      for args <- [
            ["chimeway.gen.migrations"],
            ["chimeway.gen.migrations", "--prefix", "chimeway"],
            ["chimeway.gen.migrations", "--prefix", "public"]
          ] do
        assert {_output, 0} = run_mix(tmp, args)
      end

      migrations_dir = Path.join(tmp, "priv/repo/migrations")
      assert length(File.ls!(migrations_dir)) == 37
    end

    test "invalid generation prefix inputs fail with actionable accepted flags" do
      tmp = scaffold_tmp_host!(include_config: true)

      install_deps!(tmp)

      for args <- [
            ["chimeway.gen.migrations", "--prefix", "tenant_a"],
            ["chimeway.gen.migrations", "--tenant", "tenant_a"],
            ["chimeway.gen.migrations", "tenant_a"]
          ] do
        {output, exit} = run_mix(tmp, args)

        assert exit != 0
        assert output =~ "mix chimeway.gen.migrations --prefix chimeway"
        assert output =~ "mix chimeway.gen.migrations --prefix public"
      end
    end
  end

  defp chimeway_root do
    __DIR__ |> Path.join("../../..") |> Path.expand()
  end

  defp scaffold_tmp_host!(opts) do
    include_config? = Keyword.get(opts, :include_config, true)
    unique = Integer.to_string(System.unique_integer([:positive]))
    tmp = Path.join(System.tmp_dir!(), "chimeway_install_" <> unique)

    File.mkdir_p!(Path.join(tmp, "priv/repo/migrations"))

    mix_exs = """
    defmodule InstallerHost.MixProject do
      use Mix.Project

      def project do
        [
          app: :installer_host,
          version: "0.0.1",
          elixir: "~> 1.17",
          start_permanent: Mix.env() == :prod,
          deps: deps()
        ]
      end

      defp deps do
        [
          {:chimeway, path: #{inspect(chimeway_root())}},
          {:oban, "~> 2.17"}
        ]
      end
    end
    """

    File.write!(Path.join(tmp, "mix.exs"), mix_exs)

    if include_config? do
      File.mkdir_p!(Path.join(tmp, "config"))

      File.write!(
        Path.join(tmp, "config/config.exs"),
        """
        import Config

        config :chimeway, repo: InstallerHost.Repo
        """
      )
    end

    on_exit(fn -> File.rm_rf!(tmp) end)

    tmp
  end

  defp install_deps!(tmp) do
    assert {_output, 0} =
             System.cmd("mix", ["deps.get"],
               cd: tmp,
               stderr_to_stdout: true,
               env: [{"MIX_ENV", "dev"}]
             )
  end

  defp run_mix(tmp, args) do
    System.cmd("mix", args,
      cd: tmp,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}]
    )
  end

  defp restore_repo_env do
    previous = Application.get_env(:chimeway, :repo)

    on_exit(fn ->
      if previous do
        Application.put_env(:chimeway, :repo, previous)
      else
        Application.delete_env(:chimeway, :repo)
      end
    end)
  end
end
