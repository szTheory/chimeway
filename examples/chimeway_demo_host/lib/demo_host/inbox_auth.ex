defmodule DemoHost.InboxAuth do
  @moduledoc """
  Permissive dev/test recipient resolution for `chimeway_inbox` in the demo host.

  Reads `"demo_user_email"` from the session and maps to `DemoHost.Seeds.recipient_identity/1`.
  Production always returns `{:error, :unauthorized}` — replace with a host
  `ChimewayInbox.Auth` implementation before shipping to production.

  Never returns `"demo:operator"` — that is operator admin identity from `AdminActor`.
  """
  @behaviour ChimewayInbox.Auth

  @impl true
  def current_recipient(session, _context) do
    with true <- authorized?(),
         email when is_binary(email) and email != "" <- session["demo_user_email"] do
      {:ok, DemoHost.Seeds.recipient_identity(email)}
    else
      _ -> {:error, :unauthorized}
    end
  end

  @impl true
  def current_tenant(_session, _context) do
    if authorized?(), do: {:ok, DemoHost.Seeds.tenant_id()}, else: {:error, :unauthorized}
  end

  defp authorized? do
    if Mix.env() in [:dev, :test] do
      true
    else
      require Logger

      Logger.warning(
        "DemoHost.InboxAuth denies all requests in :prod — configure a production ChimewayInbox.Auth module"
      )

      false
    end
  end
end
