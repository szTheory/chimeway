defmodule ChimewayInbox.LiveViewCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      use Phoenix.ConnTest, otp_app: :chimeway_inbox
      import Phoenix.LiveViewTest
      import ChimewayInbox.TestSupport.Fixtures

      @endpoint ChimewayInbox.TestSupport.Endpoint
    end
  end

  setup tags do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)

    previous = Application.get_env(:chimeway_inbox, :auth_module)
    Application.put_env(:chimeway_inbox, :auth_module, ChimewayInbox.TestSupport.AllowAuth)
    on_exit(fn -> Application.put_env(:chimeway_inbox, :auth_module, previous) end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Grants a LiveView process access to the SQL sandbox (when not in shared mode).
  """
  def allow_repo_access(live_view_pid) when is_pid(live_view_pid) do
    Ecto.Adapters.SQL.Sandbox.allow(Chimeway.Repo, self(), live_view_pid)
    :ok
  end
end
