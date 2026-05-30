defmodule ChimewayInbox.TestSupport.Router do
  @moduledoc false
  use Phoenix.Router

  import Phoenix.LiveView.Router
  import ChimewayInbox.Router

  chimeway_inbox_routes()
end
