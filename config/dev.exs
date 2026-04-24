import Config

pg_user = System.get_env("PGUSER") || System.get_env("USER") || "postgres"

config :chimeway, Chimeway.Repo,
  username: pg_user,
  password: System.get_env("PGPASSWORD"),
  hostname: System.get_env("PGHOST") || "localhost",
  database: "chimeway_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
