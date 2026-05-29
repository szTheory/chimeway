import Config

config :demo_host, DemoHostWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false

# Chimeway core config required when running as a standalone example app.
# Mirrors the root project's config/config.exs + config/test.exs setup.
config :chimeway,
  ecto_repos: [Chimeway.Repo],
  time_zone_database: Tzdata.TimeZoneDatabase,
  dispatcher: Chimeway.Dispatch.Sync

# Full Chimeway.Repo config with SQL sandbox pool for tests.
# Uses the same env-var conventions as the root project's config/test.exs.
config :chimeway, Chimeway.Repo,
  username: System.get_env("PGUSER") || System.get_env("USER") || "postgres",
  password: System.get_env("PGPASSWORD"),
  hostname: System.get_env("PGHOST") || "localhost",
  database: "chimeway_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox

# Oban in manual testing mode for synchronous test assertions via assert_enqueued.
config :chimeway, Oban,
  repo: Chimeway.Repo,
  queues: [chimeway_delivery: 10, chimeway_signals: 5],
  testing: :manual

config :phoenix, :json_library, Jason

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
  database: "chimeway_demo_mailglass_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  prepare: :unnamed,
  disconnect_on_error_codes: [:internal_error]
