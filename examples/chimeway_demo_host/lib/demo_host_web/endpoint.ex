defmodule DemoHostWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :demo_host

  @session_options [
    store: :cookie,
    key: "_demo_host_key",
    signing_salt: "demo-host-session"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:demo_host, :endpoint]

  # CRITICAL (Phase 33 D-13 / T-33-RAWBODY): the body_reader MFA caches raw bytes
  # in conn.assigns[:raw_body] BEFORE Jason consumes the body. Webhook signature
  # verification MUST run on the exact raw bytes the provider signed; without
  # this :body_reader the raw bytes are unrecoverable after JSON parsing.
  # Canonical pattern from hexdocs.pm/plug/Plug.Parsers.html.
  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["text/*"],
    body_reader: {DemoHost.Plugs.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug DemoHostWeb.Router
end
