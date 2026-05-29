import Config

repo_config =
  case System.get_env("DATABASE_URL") do
    nil ->
      pg_user = System.get_env("PGUSER") || System.get_env("USER") || "postgres"

      [
        username: pg_user,
        password: System.get_env("PGPASSWORD"),
        hostname: System.get_env("PGHOST") || "localhost",
        database: "chimeway_test#{System.get_env("MIX_TEST_PARTITION")}",
        pool: Ecto.Adapters.SQL.Sandbox
      ]

    database_url ->
      [url: database_url, pool: Ecto.Adapters.SQL.Sandbox]
  end

config :chimeway, Chimeway.Repo, repo_config

config :chimeway, Oban,
  repo: Chimeway.Repo,
  testing: :manual,
  queues: [chimeway_delivery: 10, chimeway_signals: 5]

config :logger, level: :warning

config :mailglass, adapter: {Mailglass.Adapters.Fake, []}
config :mailglass, repo: Mailglass.TestRepo
config :mailglass, tenancy: Mailglass.Tenancy.SingleTenant
config :mailglass, suppression_store: Mailglass.SuppressionStore.Ecto
config :mailglass, async_adapter: :oban
config :mailglass, adapter_endpoint: "mailglass-test-endpoint"

config :mailglass, :tracking,
  host: "localhost:4000",
  salts: ["test-salt"]

config :mailglass, Mailglass.TestRepo,
  username:
    System.get_env("POSTGRES_USER") || System.get_env("PGUSER") ||
      System.get_env("USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || System.get_env("PGPASSWORD"),
  hostname: System.get_env("POSTGRES_HOST") || System.get_env("PGHOST") || "localhost",
  database: "chimeway_mailglass_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  prepare: :unnamed,
  disconnect_on_error_codes: [:internal_error]
