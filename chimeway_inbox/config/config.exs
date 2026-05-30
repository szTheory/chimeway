import Config

# Host applications must configure their auth implementation:
#
#   config :chimeway_inbox, auth_module: MyApp.InboxAuth

config :chimeway_inbox, auth_module: ChimewayInbox

import_config "#{config_env()}.exs"
