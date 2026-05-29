import Config

config :chimeway_admin, auth_module: ChimewayAdmin.TestSupport.DenyAuth
config :chimeway_admin, :endpoint, ChimewayAdmin.TestSupport.Endpoint

config :chimeway_admin, ChimewayAdmin.TestSupport.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvwxyz012345", 2),
  live_view: [signing_salt: "chimeway-admin-test"]

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
config :chimeway, Oban, repo: Chimeway.Repo, testing: :manual, queues: false
config :logger, level: :warning
