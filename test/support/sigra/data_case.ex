if Code.ensure_loaded?(Sigra) and not Code.ensure_loaded?(Sigra.DataCase) do
  defmodule Sigra.DataCase do
    @moduledoc false

    use ExUnit.CaseTemplate

    using do
      quote do
        alias Sigra.TestRepo, as: SigraRepo
        alias Chimeway.Repo, as: ChimewayRepo

        import Ecto
        import Ecto.Changeset
        import Ecto.Query
        import Sigra.DataCase
        import Chimeway.TestSupport.SigraFixtures
      end
    end

    setup tags do
      sigra_owner =
        Ecto.Adapters.SQL.Sandbox.start_owner!(Sigra.TestRepo, shared: not tags[:async])

      chimeway_owner =
        Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: not tags[:async])

      on_exit(fn ->
        Ecto.Adapters.SQL.Sandbox.stop_owner(chimeway_owner)
        Ecto.Adapters.SQL.Sandbox.stop_owner(sigra_owner)
      end)

      :ok
    end

    def allow_repo_access(pid) when is_pid(pid) do
      Ecto.Adapters.SQL.Sandbox.allow(Sigra.TestRepo, self(), pid)
      Ecto.Adapters.SQL.Sandbox.allow(Chimeway.Repo, self(), pid)
      :ok
    end
  end
end
