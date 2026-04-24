import Config

config :chimeway,
  ecto_repos: [Chimeway.Repo],
  dispatcher: Chimeway.Dispatch.Sync

import_config "#{config_env()}.exs"
