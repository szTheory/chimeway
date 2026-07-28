import Config

config :demo_host, DemoHostWeb.Endpoint,
  http: [port: 4001],
  debug_errors: true,
  code_reloader: false,
  check_origin: false,
  watchers: []

config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:request_id]

config :chimeway,
  ecto_repos: [Chimeway.Repo],
  time_zone_database: Tzdata.TimeZoneDatabase,
  dispatcher: Chimeway.Dispatch.Sync,
  prefix: "chimeway"

# Honor DATABASE_URL like the root chimeway dev config so `mix demo.up --check`
# (JOUR-05) reuses the CI-provisioned DB instead of a hardcoded chimeway_dev
# that CI never creates. Local dev (no DATABASE_URL) is unchanged.
repo_config =
  case System.get_env("DATABASE_URL") do
    nil ->
      [
        username: System.get_env("PGUSER") || System.get_env("USER") || "postgres",
        password: System.get_env("PGPASSWORD"),
        hostname: System.get_env("PGHOST") || "localhost",
        database: "chimeway_dev",
        pool_size: 10
      ]

    database_url ->
      [url: database_url, pool_size: 10]
  end

config :chimeway, Chimeway.Repo, repo_config

config :chimeway, Oban,
  repo: Chimeway.Repo,
  queues: [chimeway_delivery: 10, chimeway_signals: 5]

config :phoenix, :json_library, Jason
