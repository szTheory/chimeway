ExUnit.start()

{:ok, _} = Application.ensure_all_started(:chimeway)

{:ok, _} =
  Supervisor.start_link(
    [{Phoenix.PubSub, name: ChimewayInbox.TestSupport.PubSub}],
    strategy: :one_for_one
  )

{:ok, _} = ChimewayInbox.TestSupport.Endpoint.start_link([])

Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, :manual)
