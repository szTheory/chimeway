defmodule ChimewayInbox.RouterTest do
  use ExUnit.Case, async: true

  test "chimeway_inbox_routes macro mounts bell dropdown live route" do
    routes = Phoenix.Router.routes(ChimewayInbox.TestSupport.Router)

    assert Enum.any?(routes, fn route ->
             route.path == "/" and
               match?(
                 {ChimewayInbox.Live.BellDropdownLive, :index, _, _},
                 route.metadata[:phoenix_live_view]
               )
           end)
  end
end
