defmodule ChimewayInbox.Auth do
  @moduledoc """
  Host-implemented authorization for end-user inbox surfaces.

  Resolves the current recipient identity and concrete tenant from the LiveView
  session and socket context. The host remains responsible for authentication,
  membership, and selecting the tenant; ChimewayInbox passes that host-selected
  tenant to the core lifecycle API.

      config :chimeway_inbox, auth_module: MyApp.InboxAuth
  """

  @callback current_recipient(session :: map(), context :: map()) ::
              {:ok, String.t()} | {:error, :unauthorized}

  @callback current_tenant(session :: map(), context :: map()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  Returns the configured auth module (`Application.fetch_env!/2`).
  """
  @spec auth_module() :: module()
  def auth_module, do: Application.fetch_env!(:chimeway_inbox, :auth_module)
end
