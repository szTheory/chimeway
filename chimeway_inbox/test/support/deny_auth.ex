defmodule ChimewayInbox.TestSupport.DenyAuth do
  @moduledoc false
  @behaviour ChimewayInbox.Auth

  @impl true
  def current_recipient(_session, _context), do: {:error, :unauthorized}
end
