defmodule Chimeway.MigrationContractTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.Repo

  @moduletag timeout: 300_000

  @tenant_identity_migration_version 20_260_812_000_000
  @generated_tenant_identity_migration_version 20_260_101_000_032
  @tenant_identity_rollback_error "tenant-scoped idempotency cannot safely return to global uniqueness; migration is irreversible"

  defmodule GeneratedRepo do
    use Ecto.Repo,
      otp_app: :chimeway,
      adapter: Ecto.Adapters.Postgres
  end

  @generated_modes [
    %{
      label: "default prefixed",
      fixture_root: "test/fixtures/installer_golden_prefixed",
      schema: "chimeway",
      slug: "prefixed",
      expect_schema_left: true
    },
    %{
      label: "legacy public",
      fixture_root: "test/fixtures/installer_golden_public",
      schema: "public",
      slug: "public",
      expect_schema_left: false
    }
  ]

  test "public migration assertions are explicitly labeled" do
    labeled_tests =
      __MODULE__.__info__(:functions)
      |> Keyword.keys()
      |> Enum.map(&Atom.to_string/1)
      |> Enum.filter(&String.starts_with?(&1, "test "))
      |> Enum.reject(&String.contains?(&1, "public migration assertions are explicitly labeled"))
      |> Enum.filter(fn name ->
        String.contains?(name, "legacy") or
          String.contains?(name, "public-schema compatibility")
      end)

    assert length(labeled_tests) >= 2,
           "current public-schema checks must be named as legacy compatibility proof"
  end

  test "legacy public-schema compatibility keeps events and notifications tables with required named indexes" do
    assert regclass("chimeway_events")
    assert regclass("chimeway_notifications")

    refute regclass("chimeway_events_idempotency_key_index")
    assert regclass("chimeway_events_tenant_id_idempotency_key_index")

    assert regclass("chimeway_notifications_event_recipient_index")
    assert regclass("chimeway_notifications_inbox_read_inserted_index")
  end

  test "legacy public-schema compatibility keeps phase 27 state spine tables and columns" do
    assert regclass("chimeway_signals")

    assert workflow_runs_column("tenant_id") == {false, "character varying"}
    assert workflow_runs_column("pending_signals") == {true, "ARRAY"}
    assert workflow_runs_column("suspended_until") == {true, "timestamp without time zone"}
    assert workflow_runs_column("terminal_reason") == {true, "character varying"}
  end

  for mode <- @generated_modes do
    @tag generated_mode: mode
    test "#{mode.label} generated migrations run through normal Ecto.Migrator",
         %{generated_mode: generated_mode} do
      with_generated_database(generated_mode, fn repo, migrations_path ->
        assert_no_destructive_schema_cleanup!(generated_mode.fixture_root)

        migrated = run_fixture_migrations(repo, migrations_path, :up)
        assert length(migrated) == 33
        assert_migration_versions!(repo, 33)
        assert_generated_objects!(repo, generated_mode.schema)
        assert_generated_foreign_keys!(repo, generated_mode.schema)
      end)
    end
  end

  @tag migration_copy: :repository
  test "repository migration refuses tenant identity rollback without mutating valid tenant rows" do
    migrations_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])

    with_isolated_database("repository", fn repo ->
      run_tenant_identity_rollback_contract!(
        repo,
        migrations_path,
        "public",
        @tenant_identity_migration_version
      )
    end)
  end

  for mode <- @generated_modes do
    @tag migration_copy: :generated
    @tag generated_mode: mode
    test "#{mode.label} generated migration refuses tenant identity rollback without mutating valid tenant rows",
         %{generated_mode: generated_mode} do
      with_generated_database(generated_mode, fn repo, migrations_path ->
        run_tenant_identity_rollback_contract!(
          repo,
          migrations_path,
          generated_mode.schema,
          @generated_tenant_identity_migration_version
        )
      end)
    end
  end

  defp regclass(name) do
    sql = "SELECT to_regclass($1)"

    case Ecto.Adapters.SQL.query!(Repo, sql, ["public." <> name]).rows do
      [[nil]] -> nil
      [[value]] -> value
    end
  end

  defp workflow_runs_column(column_name) do
    sql = """
    SELECT is_nullable = 'YES', data_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'chimeway_workflow_runs'
      AND column_name = $1
    """

    case Ecto.Adapters.SQL.query!(Repo, sql, [column_name]).rows do
      [[is_nullable, data_type]] -> {is_nullable, data_type}
      _ -> nil
    end
  end

  defp with_generated_database(mode, fun) do
    unique = System.unique_integer([:positive])
    database = "chimeway_migration_contract_#{mode.slug}_#{unique}"
    tmp_root = Path.join(System.tmp_dir!(), "chimeway_migration_contract_#{mode.slug}_#{unique}")
    migrations_path = Path.join(tmp_root, "migrations")
    config = generated_repo_config(database)

    File.rm_rf!(tmp_root)
    File.mkdir_p!(migrations_path)
    write_numbered_fixture_migrations!(mode.fixture_root, migrations_path)

    case Ecto.Adapters.Postgres.storage_up(config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, reason} -> flunk("failed to create #{database}: #{inspect(reason)}")
    end

    try do
      {:ok, pid} = GeneratedRepo.start_link(config)

      try do
        fun.(GeneratedRepo, migrations_path)
      after
        if Process.alive?(pid), do: GenServer.stop(pid)
      end
    after
      _ = Ecto.Adapters.Postgres.storage_down(config)
      File.rm_rf!(tmp_root)
      purge_fixture_modules!(mode.fixture_root)
    end
  end

  defp with_isolated_database(label, fun) do
    unique = System.unique_integer([:positive])
    database = "chimeway_migration_contract_#{label}_#{unique}"
    config = generated_repo_config(database)

    case Ecto.Adapters.Postgres.storage_up(config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, reason} -> flunk("failed to create #{database}: #{inspect(reason)}")
    end

    try do
      {:ok, pid} = GeneratedRepo.start_link(config)

      try do
        fun.(GeneratedRepo)
      after
        if Process.alive?(pid), do: GenServer.stop(pid)
      end
    after
      _ = Ecto.Adapters.Postgres.storage_down(config)
    end
  end

  defp generated_repo_config(database) do
    base_database_config()
    |> Keyword.merge(
      database: database,
      pool_size: 2,
      queue_target: 5_000,
      queue_interval: 10_000
    )
  end

  defp base_database_config do
    case System.get_env("DATABASE_URL") do
      nil ->
        Chimeway.Repo.config()
        |> Keyword.drop([:database, :pool, :url])
        |> Keyword.put_new(:hostname, "localhost")

      database_url ->
        database_url_config(database_url)
    end
  end

  defp database_url_config(database_url) do
    uri = URI.parse(database_url)
    {username, password} = parse_userinfo(uri.userinfo)

    [
      username: username,
      password: password,
      hostname: uri.host || "localhost",
      port: uri.port || 5432
    ]
  end

  defp parse_userinfo(nil), do: {"postgres", nil}

  defp parse_userinfo(userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [username, password] -> {URI.decode(username), URI.decode(password)}
      [username] -> {URI.decode(username), nil}
    end
  end

  defp write_numbered_fixture_migrations!(fixture_root, migrations_path) do
    fixture_root
    |> migration_order()
    |> Enum.with_index(1)
    |> Enum.each(fn {fixture_name, index} ->
      src = Path.join([fixture_root, "tree", "priv", "repo", "migrations", fixture_name])
      version = 20_260_101_000_000 + index

      dest =
        Path.join(
          migrations_path,
          "#{version}_#{String.replace_prefix(fixture_name, "TIMESTAMP_", "")}"
        )

      content = File.read!(src)
      purge_modules!(migration_modules(content))
      File.write!(dest, content)
    end)
  end

  defp migration_order(fixture_root) do
    fixture_root
    |> Path.join("STDOUT.txt")
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(fn "created priv/repo/migrations/" <> fixture_name -> fixture_name end)
  end

  defp purge_fixture_modules!(fixture_root) do
    fixture_root
    |> Path.join("tree/priv/repo/migrations/*.exs")
    |> Path.wildcard()
    |> Enum.flat_map(fn path -> path |> File.read!() |> migration_modules() end)
    |> purge_modules!()
  end

  defp purge_modules!(modules) do
    Enum.each(modules, fn module ->
      :code.purge(module)
      :code.delete(module)
    end)
  end

  defp migration_modules(content) do
    for [_, module] <- Regex.scan(~r/defmodule\s+([A-Za-z0-9_.]+)\s+do/, content) do
      module
      |> String.split(".")
      |> Module.concat()
    end
  end

  defp assert_no_destructive_schema_cleanup!(fixture_root) do
    fixture_root
    |> Path.join("tree/priv/repo/migrations/*.exs")
    |> Path.wildcard()
    |> Enum.each(fn path ->
      content = File.read!(path)

      refute Regex.match?(~r/\bDROP\s+SCHEMA\b/i, content),
             "#{path} must not generate DROP SCHEMA rollback SQL"

      refute Regex.match?(~r/\bCASCADE\b/i, content),
             "#{path} must not generate destructive CASCADE cleanup"
    end)
  end

  defp run_fixture_migrations(repo, migrations_path, direction) when direction in [:up, :down] do
    parent = self()
    ref = make_ref()

    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      result = Ecto.Migrator.run(repo, migrations_path, direction, all: true, log: false)
      send(parent, {ref, result})
    end)

    receive do
      {^ref, result} -> result
    end
  end

  defp run_tenant_identity_rollback_contract!(repo, migrations_path, schema, target_version) do
    migrated = run_migrations(repo, migrations_path, :up, all: true)
    assert target_version in migrated

    insert_cross_tenant_duplicate_events!(repo, schema)
    state = tenant_identity_state(repo, schema, target_version)

    assert_raise RuntimeError, @tenant_identity_rollback_error, fn ->
      run_migrations(repo, migrations_path, :down, to: target_version)
    end

    assert tenant_identity_state(repo, schema, target_version) == state

    assert_raise RuntimeError, @tenant_identity_rollback_error, fn ->
      run_migrations(repo, migrations_path, :down, to: target_version)
    end

    assert tenant_identity_state(repo, schema, target_version) == state
  end

  defp run_migrations(repo, migrations_path, direction, opts) do
    parent = self()
    ref = make_ref()

    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      result = Ecto.Migrator.run(repo, migrations_path, direction, Keyword.put(opts, :log, false))
      send(parent, {ref, result})
    end)

    receive do
      {^ref, result} -> result
    end
  end

  defp insert_cross_tenant_duplicate_events!(repo, schema) do
    table = quoted_relation(schema, "chimeway_events")

    Ecto.Adapters.SQL.query!(
      repo,
      """
      INSERT INTO #{table}
        (id, notification_key, notification_version, idempotency_key, payload, tenant_id, inserted_at, updated_at)
      VALUES
        ('11111111-1111-1111-1111-111111111111', 'tenant_identity', 1, 'cross-tenant-key', '{}'::jsonb, 'tenant-a', NOW(), NOW()),
        ('22222222-2222-2222-2222-222222222222', 'tenant_identity', 1, 'cross-tenant-key', '{}'::jsonb, 'tenant-b', NOW(), NOW())
      """,
      []
    )
  end

  defp tenant_identity_state(repo, schema, target_version) do
    %{
      version: migration_version(repo, target_version),
      rows: event_tenant_rows(repo, schema),
      event_tenant_column: column_info(repo, schema, "chimeway_events", "tenant_id"),
      notification_tenant_column:
        column_info(repo, schema, "chimeway_notifications", "tenant_id"),
      composite_index: regclass(repo, schema, "chimeway_events_tenant_id_idempotency_key_index"),
      global_index: regclass(repo, schema, "chimeway_events_idempotency_key_index")
    }
  end

  defp migration_version(repo, version) do
    Ecto.Adapters.SQL.query!(repo, "SELECT version FROM schema_migrations WHERE version = $1", [
      version
    ]).rows
  end

  defp event_tenant_rows(repo, schema) do
    repo
    |> Ecto.Adapters.SQL.query!(
      """
      SELECT id::text, tenant_id, idempotency_key
      FROM #{quoted_relation(schema, "chimeway_events")}
      WHERE idempotency_key = 'cross-tenant-key'
      ORDER BY id
      """,
      []
    )
    |> Map.fetch!(:rows)
  end

  defp quoted_relation(schema, table), do: ~s("#{schema}"."#{table}")

  defp assert_generated_objects!(repo, schema) do
    assert schema_exists?(repo, schema)

    for table <- [
          "chimeway_events",
          "chimeway_notifications",
          "chimeway_delivery_attempts",
          "chimeway_digest_buckets",
          "chimeway_workflow_runs",
          "chimeway_webhook_ingress"
        ] do
      assert regclass(repo, schema, table), "expected #{schema}.#{table} to exist"
    end

    refute regclass(repo, schema, "chimeway_events_idempotency_key_index"),
           "template 032 must replace global idempotency uniqueness"

    for index <- [
          "chimeway_events_tenant_id_idempotency_key_index",
          "chimeway_notifications_event_recipient_index",
          "chimeway_digest_buckets_identity_index",
          "chimeway_webhook_ingress_adapter_provider_event_uniq"
        ] do
      assert regclass(repo, schema, index), "expected #{schema}.#{index} to exist"
    end

    assert column_info(repo, schema, "chimeway_workflow_runs", "tenant_id") ==
             {false, "character varying"}

    assert column_info(repo, schema, "chimeway_workflow_runs", "pending_signals") ==
             {true, "ARRAY"}

    assert column_info(repo, schema, "chimeway_delivery_attempts", "adapter_module") ==
             {true, "character varying"}

    assert column_info(repo, schema, "chimeway_deliveries", "tenant_id") ==
             {true, "character varying"}

    assert column_info(repo, schema, "chimeway_events", "tenant_id") ==
             {true, "character varying"}

    assert column_info(repo, schema, "chimeway_notifications", "tenant_id") ==
             {true, "character varying"}
  end

  defp assert_generated_foreign_keys!(repo, schema) do
    assert foreign_key_exists?(
             repo,
             schema,
             "chimeway_notifications",
             "chimeway_events"
           )

    assert foreign_key_exists?(
             repo,
             schema,
             "chimeway_deliveries",
             "chimeway_notifications"
           )

    assert foreign_key_exists?(
             repo,
             schema,
             "chimeway_digest_buckets",
             "chimeway_digest_rules"
           )
  end

  defp assert_migration_versions!(repo, expected) do
    result =
      Ecto.Adapters.SQL.query!(
        repo,
        "SELECT count(*) FROM schema_migrations WHERE version >= 20260101000001",
        []
      )

    assert result.rows == [[expected]]
  end

  defp regclass(repo, schema, name) do
    case Ecto.Adapters.SQL.query!(repo, "SELECT to_regclass($1)", ["#{schema}.#{name}"]).rows do
      [[nil]] -> nil
      [[value]] -> value
    end
  end

  defp schema_exists?(repo, schema) do
    result =
      Ecto.Adapters.SQL.query!(
        repo,
        "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = $1)",
        [schema]
      )

    result.rows == [[true]]
  end

  defp column_info(repo, schema, table, column) do
    sql = """
    SELECT is_nullable = 'YES', data_type
    FROM information_schema.columns
    WHERE table_schema = $1
      AND table_name = $2
      AND column_name = $3
    """

    case Ecto.Adapters.SQL.query!(repo, sql, [schema, table, column]).rows do
      [[is_nullable, data_type]] -> {is_nullable, data_type}
      _ -> nil
    end
  end

  defp foreign_key_exists?(repo, schema, child_table, parent_table) do
    sql = """
    SELECT EXISTS(
      SELECT 1
      FROM pg_constraint c
      JOIN pg_class child ON child.oid = c.conrelid
      JOIN pg_namespace child_ns ON child_ns.oid = child.relnamespace
      JOIN pg_class parent ON parent.oid = c.confrelid
      JOIN pg_namespace parent_ns ON parent_ns.oid = parent.relnamespace
      WHERE c.contype = 'f'
        AND child_ns.nspname = $1
        AND child.relname = $2
        AND parent_ns.nspname = $1
        AND parent.relname = $3
    )
    """

    Ecto.Adapters.SQL.query!(repo, sql, [schema, child_table, parent_table]).rows == [[true]]
  end
end
