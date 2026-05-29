defmodule ChimewayAdmin.TestSupport.UnexpectedAuth do
  @moduledoc false
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(_actor, _action, _context), do: {:error, :forbidden}
end
