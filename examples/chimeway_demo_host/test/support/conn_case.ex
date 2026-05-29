defmodule DemoHostWeb.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      use Phoenix.ConnTest

      @endpoint DemoHostWeb.Endpoint
    end
  end

  setup tags do
    {:ok, _} = Application.ensure_all_started(:chimeway)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chimeway.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
