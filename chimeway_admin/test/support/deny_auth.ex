defmodule ChimewayAdmin.TestSupport.DenyAuth do
  @moduledoc false
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(_actor, _action, _context), do: {:error, :unauthorized}
end
