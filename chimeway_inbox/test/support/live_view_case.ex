defmodule ChimewayInbox.LiveViewCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      use Phoenix.ConnTest, otp_app: :chimeway_inbox
      import Phoenix.LiveViewTest

      @endpoint ChimewayInbox.TestSupport.Endpoint
    end
  end

  setup _tags do
    previous = Application.get_env(:chimeway_inbox, :auth_module)
    Application.put_env(:chimeway_inbox, :auth_module, ChimewayInbox.TestSupport.AllowAuth)
    on_exit(fn -> Application.put_env(:chimeway_inbox, :auth_module, previous) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
