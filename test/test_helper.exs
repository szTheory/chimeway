ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, :manual)

if Code.ensure_loaded?(Mailglass) do
  {:ok, _} = Application.ensure_all_started(:mailglass)

  migrations_path = Path.join([__DIR__, "support", "mailglass", "migrations"])

  test_repo_config = Application.get_env(:mailglass, Mailglass.TestRepo)

  case Ecto.Adapters.Postgres.storage_up(test_repo_config) do
    :ok -> :ok
    {:error, :already_up} -> :ok
    {:error, reason} -> raise "failed to create Mailglass.TestRepo database: #{inspect(reason)}"
  end

  Application.put_env(
    :mailglass,
    Mailglass.TestRepo,
    Keyword.put(test_repo_config, :pool, DBConnection.ConnectionPool)
  )

  {:ok, _, _} =
    Ecto.Migrator.with_repo(Mailglass.TestRepo, fn repo ->
      Ecto.Migrator.run(repo, migrations_path, :up, all: true, log: false)
    end)

  Application.put_env(:mailglass, Mailglass.TestRepo, test_repo_config)

  {:ok, _pid} = Mailglass.TestRepo.start_link()

  Ecto.Adapters.SQL.Sandbox.mode(Mailglass.TestRepo, :manual)
end

if Code.ensure_loaded?(Accrue) do
  if Code.ensure_loaded?(Chimeway) and not Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
    source =
      [:accrue]
      |> Enum.map(&Mix.Project.deps_paths()[&1])
      |> List.first()
      |> Path.join("lib/accrue/integrations/chimeway.ex")

    if File.exists?(source) do
      _ = Code.compile_file(source)

      unless Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
        raise "failed to compile Accrue.Integrations.Chimeway from #{source}"
      end
    else
      raise "Accrue is loaded but its integration source is missing — verify_accrue is pinned to a SHA without lib/accrue/integrations/chimeway.ex"
    end
  end

  migrations_path =
    case Path.wildcard(Path.join([__DIR__, "support", "accrue", "migrations", "*.exs"])) do
      [] ->
        :accrue
        |> :code.priv_dir()
        |> Path.join("repo/migrations")

      _ ->
        Path.join([__DIR__, "support", "accrue", "migrations"])
    end

  test_repo_config = Application.get_env(:accrue, Accrue.TestRepo)

  case Ecto.Adapters.Postgres.storage_up(test_repo_config) do
    :ok -> :ok
    {:error, :already_up} -> :ok
    {:error, reason} -> raise "failed to create Accrue.TestRepo database: #{inspect(reason)}"
  end

  Application.put_env(
    :accrue,
    Accrue.TestRepo,
    Keyword.put(test_repo_config, :pool, DBConnection.ConnectionPool)
  )

  {:ok, _, _} =
    Ecto.Migrator.with_repo(Accrue.TestRepo, fn repo ->
      Ecto.Migrator.run(repo, migrations_path, :up, all: true, log: false)
    end)

  Application.put_env(:accrue, Accrue.TestRepo, test_repo_config)

  {:ok, _pid} = Accrue.TestRepo.start_link()

  Ecto.Adapters.SQL.Sandbox.mode(Accrue.TestRepo, :manual)

  if function_exported?(Accrue.Test, :setup_fake_processor, 0) do
    :ok = Accrue.Test.setup_fake_processor()
  end

  if Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
    Application.put_env(:accrue, :dunning,
      engine: Accrue.Integrations.Chimeway,
      campaign: [enabled: true]
    )
  end
end

if Code.ensure_loaded?(Threadline) do
  {:ok, _} = Application.ensure_all_started(:threadline)

  migrations_path =
    case Path.wildcard(Path.join([__DIR__, "support", "threadline", "migrations", "*.exs"])) do
      [] ->
        :threadline
        |> :code.priv_dir()
        |> Path.join("repo/migrations")

      _ ->
        Path.join([__DIR__, "support", "threadline", "migrations"])
    end

  test_repo_config = Application.get_env(:threadline, Threadline.Test.Repo)

  case Ecto.Adapters.Postgres.storage_up(test_repo_config) do
    :ok -> :ok
    {:error, :already_up} -> :ok
    {:error, reason} -> raise "failed to create Threadline.Test.Repo database: #{inspect(reason)}"
  end

  Application.put_env(
    :threadline,
    Threadline.Test.Repo,
    Keyword.put(test_repo_config, :pool, DBConnection.ConnectionPool)
  )

  {:ok, _, _} =
    Ecto.Migrator.with_repo(Threadline.Test.Repo, fn repo ->
      Ecto.Migrator.run(repo, migrations_path, :up, all: true, log: false)
    end)

  Application.put_env(:threadline, Threadline.Test.Repo, test_repo_config)

  {:ok, _pid} = Threadline.Test.Repo.start_link()

  Ecto.Adapters.SQL.Sandbox.mode(Threadline.Test.Repo, :manual)
end

if Code.ensure_loaded?(Sigra) do
  if Code.ensure_loaded?(Chimeway) and not Code.ensure_loaded?(Sigra.Integrations.Chimeway) do
    source =
      case Mix.Project.deps_paths()[:sigra] do
        nil -> nil
        path -> Path.join(path, "lib/sigra/integrations/chimeway.ex")
      end

    source =
      cond do
        is_binary(source) and File.exists?(source) ->
          source

        env_path = System.get_env("SIGRA_PATH") ->
          Path.join(env_path, "lib/sigra/integrations/chimeway.ex")

        true ->
          nil
      end

    if is_binary(source) and File.exists?(source) do
      _ = Code.compile_file(source)

      unless Code.ensure_loaded?(Sigra.Integrations.Chimeway) do
        raise "failed to compile Sigra.Integrations.Chimeway from #{source}"
      end
    end
  end

  # Load Sigra modules without starting the OTP app — path sigra with optional
  # chimeway dep would otherwise circularly start :chimeway during test boot.
  # Handle the already_loaded case when sigra is a compiled hex dep.
  case Application.load(:sigra) do
    :ok -> :ok
    {:error, {:already_loaded, :sigra}} -> :ok
    {:error, reason} -> raise "failed to load :sigra: #{inspect(reason)}"
  end

  migrations_path =
    case Path.wildcard(Path.join([__DIR__, "support", "sigra", "migrations", "*.exs"])) do
      [] -> nil
      _ -> Path.join([__DIR__, "support", "sigra", "migrations"])
    end

  test_repo_config = Application.get_env(:sigra, Sigra.TestRepo)

  case Ecto.Adapters.Postgres.storage_up(test_repo_config) do
    :ok -> :ok
    {:error, :already_up} -> :ok
    {:error, reason} -> raise "failed to create Sigra.TestRepo database: #{inspect(reason)}"
  end

  Application.put_env(
    :sigra,
    Sigra.TestRepo,
    Keyword.put(test_repo_config, :pool, DBConnection.ConnectionPool)
  )

  if migrations_path do
    {:ok, _, _} =
      Ecto.Migrator.with_repo(Sigra.TestRepo, fn repo ->
        Ecto.Migrator.run(repo, migrations_path, :up, all: true, log: false)
      end)
  end

  Application.put_env(:sigra, Sigra.TestRepo, test_repo_config)

  {:ok, _pid} = Sigra.TestRepo.start_link()

  Ecto.Adapters.SQL.Sandbox.mode(Sigra.TestRepo, :manual)
end
