defmodule DemoHostWeb.Plugs.AdminActor do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_session("current_actor", "demo:operator")
    |> put_session("chimeway_admin_tenant_id", admin_tenant_id())
  end

  defp admin_tenant_id do
    System.get_env("CHIMEWAY_DEMO_ADMIN_TENANT_ID") || DemoHost.Seeds.tenant_id()
  end
end
