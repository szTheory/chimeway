if Code.ensure_loaded?(Accrue) and not Code.ensure_loaded?(Accrue.DataCase) do
  defmodule Accrue.DataCase do
    @moduledoc false

    use ExUnit.CaseTemplate

    using do
      quote do
        alias Accrue.TestRepo, as: Repo
        alias Chimeway.Repo, as: ChimewayRepo

        alias Accrue.Billing.{Customer, Invoice, Subscription}

        import Ecto
        import Ecto.Changeset
        import Ecto.Query
        import Accrue.DataCase
        import Chimeway.TestSupport.AccrueFixtures
      end
    end

    setup tags do
      accrue_owner =
        Ecto.Adapters.SQL.Sandbox.start_owner!(Accrue.TestRepo, shared: not tags[:async])

      chimeway_owner =
        Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: not tags[:async])

      on_exit(fn ->
        Ecto.Adapters.SQL.Sandbox.stop_owner(chimeway_owner)
        Ecto.Adapters.SQL.Sandbox.stop_owner(accrue_owner)
      end)

      start_fake_processor()

      :ok = Accrue.Actor.put_operation_id("test-" <> Ecto.UUID.generate())

      previous_env = Application.get_env(:accrue, :env)
      Application.put_env(:accrue, :env, :test)

      on_exit(fn ->
        if previous_env do
          Application.put_env(:accrue, :env, previous_env)
        else
          Application.delete_env(:accrue, :env)
        end
      end)

      :ok
    end

    def allow_repo_access(pid) when is_pid(pid) do
      Ecto.Adapters.SQL.Sandbox.allow(Accrue.TestRepo, self(), pid)
      Ecto.Adapters.SQL.Sandbox.allow(Chimeway.Repo, self(), pid)
      :ok
    end

    defp start_fake_processor do
      case Accrue.Processor.Fake.start_link([]) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      :ok = Accrue.Processor.Fake.reset_preserve_connect()
    end
  end
end
