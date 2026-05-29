ExUnit.start()

# Start the DemoHost supervisor (PubSub + Endpoint with `server: false` from
# config/test.exs). Phoenix Endpoint and Router plugs require PubSub to be
# alive; without this start, Endpoint.call/2 in tests fails at boot with a
# PubSub lookup error. The supervisor is fast and side-effect-free under
# Mix.env() == :test because `server: false` means Cowboy is NOT started.
Application.ensure_all_started(:demo_host)

# Reuse Chimeway core's Repo + SQL sandbox so example app tests share durable state.
Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, :manual)

if Code.ensure_loaded?(Mailglass) do
  {:ok, _} = Application.ensure_all_started(:mailglass)

  migrations_path = Path.expand("../../../test/support/mailglass/migrations", __DIR__)

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
