defmodule ChimewayAdmin.LiveViewCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint ChimewayAdmin.TestSupport.Endpoint
    end
  end

  setup _tags do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: false)
    previous = Application.get_env(:chimeway_admin, :auth_module)
    Application.put_env(:chimeway_admin, :auth_module, ChimewayAdmin.TestSupport.AllowAuth)

    on_exit(fn ->
      Application.put_env(:chimeway_admin, :auth_module, previous)
      Ecto.Adapters.SQL.Sandbox.stop_owner(owner)
    end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
