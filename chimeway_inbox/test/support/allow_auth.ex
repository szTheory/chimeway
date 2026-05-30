defmodule ChimewayInbox.TestSupport.AllowAuth do
  @moduledoc false
  @behaviour ChimewayInbox.Auth

  @impl true
  def current_recipient(_session, _context), do: {:ok, "user:42"}
end
