defmodule ChimewayInbox.Auth do
  @moduledoc """
  Host-implemented authorization for end-user inbox surfaces.

  Resolves the current recipient identity from the LiveView session and socket
  context. Configure the implementation module:

      config :chimeway_inbox, auth_module: MyApp.InboxAuth
  """

  @callback current_recipient(session :: map(), context :: map()) ::
              {:ok, String.t()} | {:error, :unauthorized}

  @doc """
  Returns the configured auth module (`Application.fetch_env!/2`).
  """
  @spec auth_module() :: module()
  def auth_module, do: Application.fetch_env!(:chimeway_inbox, :auth_module)
end
