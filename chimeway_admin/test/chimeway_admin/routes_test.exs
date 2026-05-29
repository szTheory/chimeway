defmodule ChimewayAdmin.RoutesTest do
  use ExUnit.Case, async: true

  alias ChimewayAdmin.Routes

  setup do
    previous = Application.get_env(:chimeway_admin, :path_prefix)
    on_exit(fn -> Application.put_env(:chimeway_admin, :path_prefix, previous) end)
    :ok
  end

  test "path/1 returns suffix when no prefix configured" do
    Application.put_env(:chimeway_admin, :path_prefix, "")

    assert Routes.path("/") == "/"
    assert Routes.delivery_path("abc") == "/deliveries/abc"
  end

  test "path/1 prepends configured mount prefix" do
    Application.put_env(:chimeway_admin, :path_prefix, "/admin/chimeway")

    assert Routes.search_path() == "/admin/chimeway/"
    assert Routes.delivery_path("abc") == "/admin/chimeway/deliveries/abc"
  end
end
