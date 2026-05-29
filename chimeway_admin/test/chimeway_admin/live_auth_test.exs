defmodule ChimewayAdmin.LiveAuthTest do
  use ExUnit.Case, async: true

  alias ChimewayAdmin.LiveAuth
  alias ChimewayAdmin.TestSupport.DenyAuth

  setup do
    Application.put_env(:chimeway_admin, :auth_module, DenyAuth)
    :ok
  end

  test "halts and redirects when authorize returns unauthorized" do
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
    assert redirect.to == "/"
  end
end
