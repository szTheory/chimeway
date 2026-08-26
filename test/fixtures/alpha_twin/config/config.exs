import Config

config :chimeway,
  ecto_repos: [Chimeway.Repo],
  repo: Chimeway.Repo,
  channel_render_modules: %{},
  prefix: false

config :chimeway, Chimeway.Repo,
  url:
    System.get_env("DATABASE_URL") ||
      "postgres://postgres:postgres@127.0.0.1:55432/chimeway_alpha_twin",
  pool_size: 1
