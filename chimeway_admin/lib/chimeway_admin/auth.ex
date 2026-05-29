defmodule ChimewayAdmin.Auth do
  @moduledoc """
  Host-implemented authorization for operator trace surfaces.

  Actions:
  - `:search_traces` — trace search/index LiveView
  - `:view_trace` — trace detail LiveView

  Configure the implementation module:

      config :chimeway_admin, auth_module: MyApp.AdminAuth
  """

  @callback authorize(actor :: term(), action :: atom(), context :: map()) ::
              :ok | {:error, :unauthorized}

  @doc """
  Returns the configured auth module (`Application.fetch_env!/2`).
  """
  @spec auth_module() :: module()
  def auth_module, do: Application.fetch_env!(:chimeway_admin, :auth_module)
end
