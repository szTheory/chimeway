defmodule ChimewayAdmin.Live.TraceSearchLiveTest do
  use ChimewayAdmin.LiveViewCase, async: true

  import Phoenix.LiveViewTest

  test "mounts search form with empty results", %{conn: conn} do
    {:ok, _view, html} =
      live_isolated(conn, ChimewayAdmin.Live.TraceSearchLive,
        session: %{"current_actor" => "ops:1"},
        on_mount: [{ChimewayAdmin.LiveAuth, :search_traces}]
      )

    assert html =~ "Trace search"
    assert html =~ "trace-search-form"
  end
end
