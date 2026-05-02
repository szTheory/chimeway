import Config

config :demo_host, DemoHostWeb.Endpoint,
  http: [port: 4001],
  url: [host: "localhost"],
  render_errors: [formats: [json: DemoHostWeb.ErrorJSON], layout: false],
  pubsub_server: DemoHost.PubSub,
  live_view: [signing_salt: "demo-host"]

# Adapter config the controller reads at request time per Chimeway.Adapter discipline
config :demo_host, :chimeway_adapter_config, []

import_config "#{config_env()}.exs"
