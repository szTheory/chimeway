defmodule ChimewayAdmin.TestSupport.AllowAuth do
  @moduledoc false
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(_actor, _action, _context), do: :ok
end
