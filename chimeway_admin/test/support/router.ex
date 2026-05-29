defmodule ChimewayAdmin.TestSupport.Router do
  @moduledoc false
  use Phoenix.Router

  import Phoenix.LiveView.Router
  import ChimewayAdmin.Router

  chimeway_admin_routes()
end
