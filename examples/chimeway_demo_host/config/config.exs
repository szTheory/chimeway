import Config

config :demo_host, DemoHostWeb.Endpoint,
  http: [port: 4001],
  url: [host: "localhost"],
  secret_key_base: String.duplicate("demo-host-secret-key-base-for-local-use-only!", 2),
  render_errors: [formats: [json: DemoHostWeb.ErrorJSON], layout: false],
  pubsub_server: DemoHost.PubSub,
  live_view: [signing_salt: "demo-host"]

# Adapter config the controller reads at request time per Chimeway.Adapter discipline
config :demo_host, :chimeway_adapter_config, []

config :chimeway_admin, auth_module: DemoHost.AdminAuth
config :chimeway_admin, path_prefix: "/admin/chimeway"

import_config "#{config_env()}.exs"
