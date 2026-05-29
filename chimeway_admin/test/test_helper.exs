ExUnit.start()

{:ok, _} = Application.ensure_all_started(:chimeway)
{:ok, _} = ChimewayAdmin.TestSupport.Endpoint.start_link([])

Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, :manual)
