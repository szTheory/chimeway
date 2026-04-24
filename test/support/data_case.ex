defmodule Chimeway.DataCase do
  @moduledoc """
  Shared SQL sandbox setup for persistence-oriented tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Chimeway.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Chimeway.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
