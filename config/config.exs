import Config

config :chimeway,
  ecto_repos: [Chimeway.Repo],
  time_zone_database: Tzdata.TimeZoneDatabase,
  dispatcher: Chimeway.Dispatch.Sync

config :chimeway, Oban,
  repo: Chimeway.Repo,
  queues: [chimeway_delivery: 10, chimeway_signals: 5]

import_config "#{config_env()}.exs"
