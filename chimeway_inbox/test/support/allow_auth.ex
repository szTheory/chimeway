defmodule ChimewayInbox.TestSupport.AllowAuth do
  @moduledoc false
  @behaviour ChimewayInbox.Auth

  @impl true
  def current_recipient(_session, _context), do: {:ok, "user:42"}

  @impl true
  def current_tenant(session, _context) do
    {:ok, Map.get(session, "tenant_id", "tenant-a")}
  end
end
