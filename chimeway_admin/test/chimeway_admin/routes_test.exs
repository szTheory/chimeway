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
    assert Routes.traces_path() == "/traces"
    assert Routes.feed_path() == "/feed"
    assert Routes.definitions_path() == "/definitions"
    assert Routes.health_path() == "/health"
    assert Routes.recovery_path() == "/recovery"
    assert Routes.delivery_path("abc") == "/deliveries/abc"
  end

  test "path/1 prepends configured mount prefix" do
    Application.put_env(:chimeway_admin, :path_prefix, "/admin/chimeway")

    assert Routes.search_path() == "/admin/chimeway/"
    assert Routes.traces_path() == "/admin/chimeway/traces"
    assert Routes.feed_path() == "/admin/chimeway/feed"
    assert Routes.definitions_path() == "/admin/chimeway/definitions"
    assert Routes.health_path() == "/admin/chimeway/health"
    assert Routes.recovery_path() == "/admin/chimeway/recovery"
    assert Routes.delivery_path("abc") == "/admin/chimeway/deliveries/abc"
  end
end
