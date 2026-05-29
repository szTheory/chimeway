defmodule DemoHost.AdminAuth do
  @moduledoc """
  Permissive dev/test auth for `chimeway_admin` in the demo host.

  Production returns `{:error, :unauthorized}` unless `ALLOW_DEMO_ADMIN=true`
  (staging demos only — never ship this stub unchanged to production).
  """
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(_actor, _action, _context) do
    if authorized?(), do: :ok, else: {:error, :unauthorized}
  end

  defp authorized? do
    cond do
      Mix.env() in [:dev, :test] -> true
      System.get_env("ALLOW_DEMO_ADMIN") == "true" -> true
      true -> false
    end
  end
end
