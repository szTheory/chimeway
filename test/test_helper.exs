ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, :manual)

if Code.ensure_loaded?(Mailglass) do
  {:ok, _} = Application.ensure_all_started(:mailglass)

  migrations_path =
    :code.priv_dir(:mailglass)
    |> Path.join("repo/migrations")

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
