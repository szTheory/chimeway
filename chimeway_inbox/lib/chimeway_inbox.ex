defmodule ChimewayInbox do
  @moduledoc """
  Optional end-user inbox bell-dropdown UI for Chimeway.

  Host applications mount `ChimewayInbox.Router` under an authenticated scope,
  implement `ChimewayInbox.Auth` to resolve the current recipient identity,
  and configure `config :chimeway_inbox, auth_module: MyApp.InboxAuth`.

  The core `chimeway` package stays free of required Phoenix dependencies.
  """
end
