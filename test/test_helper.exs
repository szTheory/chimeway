ExUnit.start()
Code.require_file("support/data_case.ex", __DIR__)
Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, :manual)
