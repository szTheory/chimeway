defmodule DemoHostWeb.AdminTraceLiveTest do
  @moduledoc "Host-mount admin integration (JOUR-04, JOUR-07, JOUR-08)."
  use DemoHostWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @tag :journey
  @tag :jour_04
  test "JOUR-04 admin search finds seeded invite delivery", %{conn: conn} do
    assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.seed_invite()

    conn = get(conn, "/admin/chimeway")
    assert html_response(conn, 200) =~ "Trace search"

    {:ok, view, _html} = live(conn)

    html =
      view
      |> form("#trace-search-form", %{
        "mode" => "recipient",
        "query" => DemoHost.Seeds.alex_identity(),
        "notification_key" => ""
      })
      |> render_submit()

    assert html =~ DemoHost.Seeds.alex_identity()

    delivery_id =
      Enum.find(delivery_ids, &String.contains?(html, &1)) ||
        flunk("expected search results to include a seeded delivery id")

    {:ok, detail_view, detail_html} = live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
    assert detail_html =~ "Trace detail"
    assert render(detail_view) =~ "teampulse.invite_sent"
    assert render(detail_view) =~ "teampulse-seed-invite-corr"
  end

  @tag :journey
  @tag :jour_07
  test "JOUR-07 admin shows Sam password-reset suppression", %{conn: conn} do
    assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.seed_password_reset()

    conn = get(conn, "/admin/chimeway")
    assert html_response(conn, 200) =~ "Trace search"

    {:ok, view, _html} = live(conn)

    html =
      view
      |> form("#trace-search-form", %{
        "mode" => "recipient",
        "query" => DemoHost.Seeds.sam_identity(),
        "notification_key" => ""
      })
      |> render_submit()

    assert html =~ DemoHost.Seeds.sam_identity()

    delivery_id =
      Enum.find(delivery_ids, &String.contains?(html, &1)) ||
        flunk("expected search results to include a seeded delivery id")

    {:ok, detail_view, detail_html} = live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
    assert detail_html =~ "Trace detail"

    detail = render(detail_view)
    assert detail =~ "suppressed"
    assert detail =~ "channel_disabled"
    assert detail =~ "teampulse.password_reset"
  end
end
