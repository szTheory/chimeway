ExUnit.start()

# Start the DemoHost supervisor (PubSub + Endpoint with `server: false` from
# config/test.exs). Phoenix Endpoint and Router plugs require PubSub to be
# alive; without this start, Endpoint.call/2 in tests fails at boot with a
# PubSub lookup error. The supervisor is fast and side-effect-free under
# Mix.env() == :test because `server: false` means Cowboy is NOT started.
Application.ensure_all_started(:demo_host)

# Reuse Chimeway core's Repo + SQL sandbox so example app tests share durable state.
Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, :manual)
