import Config

config :demo_host, DemoHostWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false

# Share Chimeway.Repo with the parent project's SQL sandbox
config :chimeway, Chimeway.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

# Oban inline mode for synchronous test assertions
config :chimeway, Oban, testing: :manual

config :phoenix, :json_library, Jason
