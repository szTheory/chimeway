import Config

config :chimeway_admin, auth_module: ChimewayAdmin.TestSupport.DenyAuth

import_config "#{config_env()}.exs"
