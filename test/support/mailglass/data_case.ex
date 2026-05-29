if Code.ensure_loaded?(Mailglass) and not Code.ensure_loaded?(Mailglass.DataCase) do
  defmodule Mailglass.DataCase do
    @moduledoc false

    use ExUnit.CaseTemplate

    using do
      quote do
        alias Mailglass.TestRepo
        import Ecto
        import Ecto.Changeset
        import Ecto.Query
        import Mailglass.DataCase
      end
    end

    setup tags do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Mailglass.TestRepo, shared: not tags[:async])
      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

      tenant_id = Map.get(tags, :tenant, "test-tenant")

      unless tenant_id == :unset do
        Mailglass.Tenancy.put_current(tenant_id)
      end

      :ok
    end

    def with_tenant(tenant_id, fun), do: Mailglass.Tenancy.with_tenant(tenant_id, fun)
  end
end
