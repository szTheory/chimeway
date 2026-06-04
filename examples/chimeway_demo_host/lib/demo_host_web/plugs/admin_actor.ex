defmodule DemoHostWeb.Plugs.AdminActor do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_session("current_actor", "demo:operator")
    |> put_session("chimeway_admin_tenant_id", "demo-tenant")
  end
end
