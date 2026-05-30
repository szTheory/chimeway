ExUnit.start()

{:ok, _} = Application.ensure_all_started(:chimeway)
{:ok, _} = ChimewayInbox.TestSupport.Endpoint.start_link([])

Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, :manual)
