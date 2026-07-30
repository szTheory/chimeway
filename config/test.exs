import Config

# Sized for async ExUnit (CONC-02/D-04): ExUnit's default max_cases is
# System.schedulers_online() * 2, so the pool tracks that with headroom and
# self-scales — the 4-vCPU CI runner resolves to 8+10=18.
#
# The cap matters: test_helper.exs starts FIVE repos against one Postgres
# (Chimeway + Mailglass/Accrue/Threadline/Sigra), and the prefix suite creates
# throwaway databases mid-run — all sharing the server's default max_connections
# (100). An uncapped pool on a high-core box (e.g. 18 cores → 46) starves that
# shared budget: verified on an 18-core machine that pool 46/40 exhausted
# connections and invalidated GeneratedPrefixedRuntimeProofTest, while the
# baseline pool-10 run was clean. CI's max_cases is only 8, so it never needs
# more than ~18; the cap of 24 keeps CI unchanged (min picks 18), stays ≥
# max_cases for machines up to 12 cores, and on higher-core boxes leaves ample
# headroom under 100 (short sandbox tests recycle connections faster than any
# mild client-side queueing costs).
pool_size = min(System.schedulers_online() * 2 + 10, 24)

repo_config =
  case System.get_env("DATABASE_URL") do
    nil ->
      pg_user = System.get_env("PGUSER") || System.get_env("USER") || "postgres"

      [
        username: pg_user,
        password: System.get_env("PGPASSWORD"),
        hostname: System.get_env("PGHOST") || "localhost",
        database: "chimeway_test#{System.get_env("MIX_TEST_PARTITION")}",
        pool: Ecto.Adapters.SQL.Sandbox,
        pool_size: pool_size
      ]

    database_url ->
      [url: database_url, pool: Ecto.Adapters.SQL.Sandbox, pool_size: pool_size]
  end

config :chimeway, Chimeway.Repo, repo_config

if System.get_env("CHIMEWAY_SKIP_OBAN") in ["1", "true"] do
  config :chimeway, Oban, nil
else
  config :chimeway, Oban,
    repo: Chimeway.Repo,
    testing: :manual,
    queues: [chimeway_delivery: 10, chimeway_signals: 5]
end

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
  password: System.get_env("POSTGRES_PASSWORD") || System.get_env("PGPASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || System.get_env("PGHOST") || "localhost",
  database: "chimeway_mailglass_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  prepare: :unnamed,
  disconnect_on_error_codes: [:internal_error]

# Accrue harness config is unconditional (mirrors Mailglass — config loads before
# optional dep compile). verify.accrue recompiles accrue so Accrue.Integrations.Chimeway
# exists; test_helper pins :dunning engine to that module when loaded (D-12).
config :ex_cldr, default_backend: Accrue.Cldr
config :ex_money, default_cldr_backend: Accrue.Cldr

config :accrue, ecto_repos: [Accrue.TestRepo]
config :accrue, repo: Accrue.TestRepo
config :accrue, processor: Accrue.Processor.Fake
config :accrue, :env, :test
config :accrue, :mailer, Accrue.Mailer.Test

config :accrue, :branding,
  from_email: "noreply@example.test",
  support_email: "support@example.test"

config :accrue, :webhook_signing_secrets, %{
  stripe: ["whsec_test_accrue_harness"],
  fake: ["whsec_test_accrue_harness"]
}

config :accrue, :dunning,
  engine: Accrue.Dunning.Engine.Oban,
  campaign: [enabled: true]

config :accrue, Oban,
  repo: Accrue.TestRepo,
  testing: :manual,
  queues: [accrue_webhooks: 10, accrue_mailers: 10]

config :accrue, Accrue.TestRepo,
  username:
    System.get_env("POSTGRES_USER") || System.get_env("PGUSER") ||
      System.get_env("USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || System.get_env("PGPASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || System.get_env("PGHOST") || "localhost",
  database: "chimeway_accrue_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox

config :threadline, ecto_repos: [Threadline.Test.Repo]

config :threadline, Threadline.Test.Repo,
  username:
    System.get_env("POSTGRES_USER") || System.get_env("PGUSER") ||
      System.get_env("USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || System.get_env("PGPASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || System.get_env("PGHOST") || "localhost",
  database: "chimeway_threadline_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox

# Sigra harness config is unconditional (mirrors Accrue/Threadline — config loads before
# optional dep compile). Integration :chimeway config is set in test fixtures (Wave 64-02).
config :sigra, ecto_repos: [Sigra.TestRepo]
config :sigra, repo: Sigra.TestRepo
config :sigra, :user_schema, Chimeway.TestSupport.Sigra.User
config :sigra, :user_token_schema, Chimeway.TestSupport.Sigra.UserToken

config :sigra, Sigra.TestRepo,
  username:
    System.get_env("POSTGRES_USER") || System.get_env("PGUSER") ||
      System.get_env("USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || System.get_env("PGPASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || System.get_env("PGHOST") || "localhost",
  database: "chimeway_sigra_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox
