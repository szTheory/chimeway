defmodule ChimewayAdmin.Live.DesignSystemLiveTest do
  use ChimewayAdmin.LiveViewCase, async: false

  import Phoenix.LiveViewTest

  alias Chimeway.Events.Event
  alias Chimeway.Repo

  @sidebar_labels [
    "Command Center",
    "Trace Lookup",
    "Feed Debug",
    "Definitions",
    "Health",
    "Recovery"
  ]

  test "core pages render inside the scoped admin shell", %{conn: conn} do
    pages = [
      {ChimewayAdmin.Live.DashboardLive, :search_traces, %{}, "Command Center"},
      {ChimewayAdmin.Live.TraceSearchLive, :search_traces, %{}, "Trace Lookup"},
      {:route, "/deliveries/00000000-0000-0000-0000-000000000000", "Trace not found"},
      {ChimewayAdmin.Live.FeedLive, :view_feed, %{}, "Feed Debug"},
      {ChimewayAdmin.Live.DefinitionsLive, :view_definitions, %{}, "Definitions"},
      {ChimewayAdmin.Live.HealthLive, :view_health, %{}, "Health"},
      {ChimewayAdmin.Live.RecoveryLive, :list_recovery_candidates, %{}, "Recovery"}
    ]

    for page <- pages do
      html = mount_page(conn, page)
      title = expected_title(page)
      document = Floki.parse_document!(html)

      assert html =~ title
      assert_one(document, ".chimeway-admin[data-cw-theme=\"system\"]")
      assert_one(document, ".cw-shell")
      assert_one(document, ".cw-sidebar[aria-label=\"Chimeway admin\"]")
      assert_one(document, ".cw-nav[aria-label=\"Admin sections\"]")
      assert_one(document, ".cw-main")
      assert_one(document, ".cw-page-header")
    end
  end

  test "sidebar exposes labels and exactly one active item", %{conn: conn} do
    pages = [
      {ChimewayAdmin.Live.DashboardLive, :search_traces, %{}},
      {ChimewayAdmin.Live.TraceSearchLive, :search_traces, %{}},
      {ChimewayAdmin.Live.FeedLive, :view_feed, %{}},
      {ChimewayAdmin.Live.DefinitionsLive, :view_definitions, %{}},
      {ChimewayAdmin.Live.HealthLive, :view_health, %{}},
      {ChimewayAdmin.Live.RecoveryLive, :list_recovery_candidates, %{}}
    ]

    for {live_view, action, params} <- pages do
      html = mount_page(conn, live_view, action, params)
      document = Floki.parse_document!(html)

      for label <- @sidebar_labels do
        assert html =~ label
      end

      assert_one(document, ".cw-nav__item[aria-current=\"page\"]")
    end
  end

  test "shared flow hooks are present across rendered pages and trace detail source", %{
    conn: conn
  } do
    dashboard =
      conn
      |> mount_page(ChimewayAdmin.Live.DashboardLive, :search_traces)
      |> Floki.parse_document!()

    trace_search =
      conn
      |> mount_page(ChimewayAdmin.Live.TraceSearchLive, :search_traces)
      |> Floki.parse_document!()

    feed = conn |> mount_page(ChimewayAdmin.Live.FeedLive, :view_feed) |> Floki.parse_document!()

    definitions =
      conn
      |> mount_page(ChimewayAdmin.Live.DefinitionsLive, :view_definitions)
      |> Floki.parse_document!()

    health =
      conn |> mount_page(ChimewayAdmin.Live.HealthLive, :view_health) |> Floki.parse_document!()

    recovery =
      conn
      |> mount_page(ChimewayAdmin.Live.RecoveryLive, :list_recovery_candidates)
      |> Floki.parse_document!()

    assert_one(trace_search, "#trace-search-form.cw-search-form")
    assert_one(feed, "#feed-search-form.cw-search-form")
    assert_one(dashboard, ".cw-metric-grid")
    assert_one(dashboard, ".cw-grid--two")
    assert_one(definitions, ".cw-table-wrap .cw-table")
    assert_one(health, ".cw-table-wrap .cw-table")
    assert_one(recovery, ".cw-list")

    trace_detail_source =
      File.read!("lib/chimeway_admin/live/trace_detail_live.ex") <>
        File.read!("lib/chimeway_admin/components/core.ex")

    for hook <- ["cw-detail-hero", "cw-detail-hero__ids", "cw-summary-list", "cw-copy-id"] do
      assert trace_detail_source =~ hook
    end
  end

  test "dashboard renders fallback for definitions without delivery channels", %{conn: conn} do
    %Event{}
    |> Event.changeset(%{
      notification_key: "dashboard.no_channels",
      notification_version: 1,
      idempotency_key: "dashboard-no-channels-#{System.unique_integer([:positive])}",
      payload: %{}
    })
    |> Repo.insert!()

    html = mount_page(conn, ChimewayAdmin.Live.DashboardLive, :search_traces)

    assert html =~ "dashboard.no_channels"
    assert html =~ "no deliveries"
  end

  defp mount_page(conn, {:route, path, _title}) do
    {:ok, _view, html} = live(conn, path)
    html
  end

  defp mount_page(conn, {live_view, action, _params, _title}) do
    mount_page(conn, live_view, action)
  end

  defp mount_page(conn, live_view, action, params \\ %{}) do
    {:ok, _view, html} =
      live_isolated(conn, live_view,
        session: %{"current_actor" => "ops:1"},
        on_mount: [{ChimewayAdmin.LiveAuth, action}],
        params: params
      )

    html
  end

  defp expected_title({:route, _path, title}), do: title
  defp expected_title({_live_view, _action, _params, title}), do: title

  defp assert_one(document, selector) do
    assert [_one] = Floki.find(document, selector)
  end
end
