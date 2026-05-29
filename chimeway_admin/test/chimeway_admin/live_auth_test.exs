defmodule ChimewayAdmin.LiveAuthTest do
  use ExUnit.Case, async: false

  alias ChimewayAdmin.LiveAuth
  alias ChimewayAdmin.TestSupport.DenyAuth

  setup do
    previous = Application.get_env(:chimeway_admin, :auth_module)
    Application.put_env(:chimeway_admin, :auth_module, DenyAuth)
    on_exit(fn -> Application.put_env(:chimeway_admin, :auth_module, previous) end)
    :ok
  end

  test "halts and redirects when authorize returns unauthorized" do
    Application.put_env(:chimeway_admin, :unauthorized_redirect, "/login")

    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}},
        endpoint: ChimewayAdmin.TestSupport.Endpoint,
        router: ChimewayAdmin.Router,
        view: ChimewayAdmin.Live.TraceSearchLive,
        private: %{}
      }

    assert {:halt, redirected} =
             LiveAuth.on_mount(:search_traces, %{}, %{"current_actor" => "ops:1"}, socket)

    assert {:redirect, redirect} = redirected.redirected
    assert redirect.to == "/login"
  end

  test "treats unexpected authorize return as unauthorized" do
    Application.put_env(:chimeway_admin, :auth_module, ChimewayAdmin.TestSupport.UnexpectedAuth)

    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}},
        endpoint: ChimewayAdmin.TestSupport.Endpoint,
        router: ChimewayAdmin.Router,
        view: ChimewayAdmin.Live.TraceSearchLive,
        private: %{}
      }

    assert {:halt, _} =
             LiveAuth.on_mount(:search_traces, %{}, %{"current_actor" => "ops:1"}, socket)
  end
end
