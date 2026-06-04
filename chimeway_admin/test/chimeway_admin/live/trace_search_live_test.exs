defmodule ChimewayAdmin.Live.TraceSearchLiveTest do
  use ChimewayAdmin.LiveViewCase, async: true

  import Phoenix.LiveViewTest

  test "mounts search form with empty results", %{conn: conn} do
    {:ok, _view, html} =
      live_isolated(conn, ChimewayAdmin.Live.TraceSearchLive,
        session: %{"current_actor" => "ops:1"},
        on_mount: [{ChimewayAdmin.LiveAuth, :search_traces}]
      )

    assert html =~ "Trace Lookup"
    assert html =~ "trace-search-form"
  end

  test "dashboard mounts command center", %{conn: conn} do
    {:ok, _view, html} =
      live_isolated(conn, ChimewayAdmin.Live.DashboardLive,
        session: %{"current_actor" => "ops:1"},
        on_mount: [{ChimewayAdmin.LiveAuth, :search_traces}]
      )

    assert html =~ "Command Center"
    assert html =~ "Open Trace Lookup"
    assert html =~ "Health"
    assert html =~ "Recovery queue"
    assert html =~ "Definitions"
    assert html =~ "Feed Debug"
    assert_sidebar_labels(html)
  end

  test "pillar pages mount", %{conn: conn} do
    pages = [
      {ChimewayAdmin.Live.FeedLive, :view_feed, "Feed Debug"},
      {ChimewayAdmin.Live.DefinitionsLive, :view_definitions, "Definitions"},
      {ChimewayAdmin.Live.HealthLive, :view_health, "Health"},
      {ChimewayAdmin.Live.RecoveryLive, :list_recovery_candidates, "Recovery"}
    ]

    for {live_view, action, text} <- pages do
      {:ok, _view, html} =
        live_isolated(conn, live_view,
          session: %{"current_actor" => "ops:1"},
          on_mount: [{ChimewayAdmin.LiveAuth, action}]
        )

      assert html =~ text
      assert_sidebar_labels(html)
    end
  end

  defp assert_sidebar_labels(html) do
    assert html =~ "Command Center"
    assert html =~ "Trace Lookup"
    assert html =~ "Feed Debug"
    assert html =~ "Definitions"
    assert html =~ "Health"
    assert html =~ "Recovery"
  end
end
