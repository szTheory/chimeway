import Config

pg_user = System.get_env("PGUSER") || System.get_env("USER") || "postgres"

config :chimeway, Chimeway.Repo,
  username: pg_user,
  password: System.get_env("PGPASSWORD"),
  hostname: System.get_env("PGHOST") || "localhost",
  database: "chimeway_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warning
