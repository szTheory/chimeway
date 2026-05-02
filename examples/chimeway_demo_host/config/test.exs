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
