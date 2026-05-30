defmodule ChimewayInbox.Router do
  @moduledoc """
  Mountable LiveView routes for end-user inbox bell dropdown.

  ## Host integration

      # router.ex
      scope "/inbox" do
        pipe_through [:browser]

        import ChimewayInbox.Router
        chimeway_inbox_routes()
      end

      # config/config.exs
      config :chimeway_inbox, auth_module: MyApp.InboxAuth
  """

  defmacro chimeway_inbox_routes(_opts \\ []) do
    quote do
      import Phoenix.LiveView.Router

      live_session :chimeway_inbox_bell,
        on_mount: [{ChimewayInbox.LiveAuth, :inbox_bell}] do
        live "/", ChimewayInbox.Live.BellDropdownLive, :index
      end
    end
  end
end
