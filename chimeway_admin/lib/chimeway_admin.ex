defmodule ChimewayAdmin do
  @moduledoc """
  Optional operator trace UI for Chimeway.

  Host applications mount `ChimewayAdmin.Router` under an authenticated scope
  and configure `config :chimeway_admin, auth_module: MyApp.AdminAuth`.
  The core `chimeway` package stays free of required Phoenix dependencies.
  """
end
