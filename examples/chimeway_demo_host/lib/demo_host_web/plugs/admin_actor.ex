defmodule DemoHostWeb.Plugs.AdminActor do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    put_session(conn, "current_actor", "demo:operator")
  end
end
