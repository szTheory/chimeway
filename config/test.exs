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
  queues: [chimeway_delivery: 10]

config :logger, level: :warning
