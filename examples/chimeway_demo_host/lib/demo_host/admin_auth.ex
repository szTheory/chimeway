defmodule DemoHost.AdminAuth do
  @moduledoc """
  Permissive dev/test auth for `chimeway_admin` in the demo host.

  Production always returns `{:error, :unauthorized}` — replace with a host
  `ChimewayAdmin.Auth` implementation before shipping to production.
  """
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(_actor, _action, _context) do
    if authorized?(), do: :ok, else: {:error, :unauthorized}
  end

  defp authorized? do
    if Mix.env() in [:dev, :test] do
      true
    else
      require Logger

      Logger.warning(
        "DemoHost.AdminAuth denies all requests in :prod — configure a production ChimewayAdmin.Auth module"
      )

      false
    end
  end
end
