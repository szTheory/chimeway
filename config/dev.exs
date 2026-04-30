import Config

repo_config =
  case System.get_env("DATABASE_URL") do
    nil ->
      pg_user = System.get_env("PGUSER") || System.get_env("USER") || "postgres"

      [
        username: pg_user,
        password: System.get_env("PGPASSWORD"),
        hostname: System.get_env("PGHOST") || "localhost",
        database: "chimeway_dev",
        stacktrace: true,
        show_sensitive_data_on_connection_error: true,
        pool_size: 10
      ]

    database_url ->
      [
        url: database_url,
        stacktrace: true,
        show_sensitive_data_on_connection_error: true,
        pool_size: 10
      ]
  end

config :chimeway, Chimeway.Repo, repo_config

config :chimeway, Oban,
  repo: Chimeway.Repo,
  queues: [chimeway_delivery: 10, chimeway_signals: 5]
