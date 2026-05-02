import Config

config :demo_host, DemoHostWeb.Endpoint,
  http: [port: 4001],
  debug_errors: true,
  code_reloader: false,
  check_origin: false,
  watchers: []

config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:request_id]
