import Config

config :chimeway,
  ecto_repos: [Chimeway.Repo]

import_config "#{config_env()}.exs"
