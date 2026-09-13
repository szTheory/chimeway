import Config

config :chimeway,
  ecto_repos: [Chimeway.Repo],
  channel_render_modules: %{},
  prefix: false

config :chimeway, Chimeway.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "127.0.0.1",
  database: "chimeway_apns_consumer",
  pool_size: 1
