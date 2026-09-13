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

config :chimeway,
  inbox_change_publisher: ChimewayInbox.PubSubPublisher

config :chimeway_inbox,
  auth_module: DemoHost.InboxAuth,
  pubsub_server: DemoHost.PubSub,
  topic_secret: String.duplicate("demo-host-inbox-topic-secret-local-only-", 2)

import_config "#{config_env()}.exs"
