if Code.ensure_loaded?(Threadline) and not Code.ensure_loaded?(Threadline.DataCase) do
  defmodule Threadline.DataCase do
    @moduledoc false

    use ExUnit.CaseTemplate

    using do
      quote do
        alias Threadline.Test.Repo, as: ThreadlineRepo
        alias Chimeway.Repo, as: ChimewayRepo

        import Ecto
        import Ecto.Changeset
        import Ecto.Query
        import Threadline.DataCase
        import Chimeway.TestSupport.ThreadlineFixtures
      end
    end

    setup tags do
      threadline_owner =
        Ecto.Adapters.SQL.Sandbox.start_owner!(Threadline.Test.Repo, shared: not tags[:async])

      chimeway_owner =
        Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: not tags[:async])

      on_exit(fn ->
        Ecto.Adapters.SQL.Sandbox.stop_owner(chimeway_owner)
        Ecto.Adapters.SQL.Sandbox.stop_owner(threadline_owner)
      end)

      Threadline.Test.Repo.delete_all(Threadline.Semantics.AuditAction)

      :ok
    end

    def allow_repo_access(pid) when is_pid(pid) do
      Ecto.Adapters.SQL.Sandbox.allow(Threadline.Test.Repo, self(), pid)
      Ecto.Adapters.SQL.Sandbox.allow(Chimeway.Repo, self(), pid)
      :ok
    end
  end
end
