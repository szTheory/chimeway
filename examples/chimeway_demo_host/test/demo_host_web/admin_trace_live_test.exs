defmodule DemoHostWeb.AdminTraceLiveTest do
  @moduledoc """
  Host-mount admin integration — part of the JOUR-01..08 journey suite.

  Covers JOUR-04 (admin search finds seeded invite), JOUR-07 (Sam password-reset
  suppression), and JOUR-08 (Morgan payment-escalation trace). Tagged `:journey`
  for `mix verify.journeys`.
  """
  use DemoHostWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Chimeway.{Delivery, Repo}

  @tag :journey
  @tag :admin_truth
  test "admin command center exposes shipped operator paths", %{conn: conn} do
    conn = get(conn, "/admin/chimeway")
    assert html_response(conn, 200) =~ "Command Center"

    {:ok, view, html} = live(conn)

    assert html =~ "Open Trace Lookup"
    assert html =~ "Trace Lookup"
    assert html =~ "Feed Debug"
    assert html =~ "Definitions"
    assert html =~ "Health"
    assert html =~ "Recovery"

    rendered = render(view)
    assert rendered =~ "Command Center"
    assert rendered =~ "Open Trace Lookup"
  end

  @tag :journey
  @tag :jour_04
  test "JOUR-04 admin search finds seeded invite delivery", %{conn: conn} do
    assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.seed_invite()

    conn = get(conn, "/admin/chimeway/traces")
    assert html_response(conn, 200) =~ "Trace Lookup"

    {:ok, view, _html} = live(conn)

    html =
      view
      |> form("#trace-search-form", %{
        "mode" => "recipient",
        "query" => DemoHost.Seeds.alex_identity(),
        "notification_key" => ""
      })
      |> render_submit()

    assert_redacted_recipient(html, DemoHost.Seeds.alex_identity())

    delivery_id =
      Enum.find(delivery_ids, &String.contains?(html, &1)) ||
        flunk("expected search results to include a seeded delivery id")

    {:ok, detail_view, detail_html} = live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
    assert detail_html =~ "Trace Detail"
    assert render(detail_view) =~ "teampulse.invite_sent"
    assert render(detail_view) =~ "teampulse-seed-invite-corr"
  end

  @tag :journey
  @tag :jour_07
  test "JOUR-07 admin shows Sam password-reset suppression", %{conn: conn} do
    assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.seed_password_reset()

    conn = get(conn, "/admin/chimeway/traces")
    assert html_response(conn, 200) =~ "Trace Lookup"

    {:ok, view, _html} = live(conn)

    html =
      view
      |> form("#trace-search-form", %{
        "mode" => "recipient",
        "query" => DemoHost.Seeds.sam_identity(),
        "notification_key" => ""
      })
      |> render_submit()

    assert_redacted_recipient(html, DemoHost.Seeds.sam_identity())

    delivery_id =
      Enum.find(delivery_ids, &String.contains?(html, &1)) ||
        flunk("expected search results to include a seeded delivery id")

    {:ok, detail_view, detail_html} = live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
    assert detail_html =~ "Trace Detail"

    detail = render(detail_view)
    assert detail =~ "suppressed"
    assert detail =~ "channel_disabled"
    assert detail =~ "teampulse.password_reset"
  end

  @tag :journey
  @tag :jour_08
  test "JOUR-08 admin shows Morgan payment-escalation trace", %{conn: conn} do
    assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.escalation_waiting!()

    in_app_delivery =
      delivery_ids
      |> Enum.map(&Repo.get!(Delivery, &1))
      |> Enum.find(&(&1.channel == "in_app"))

    refute is_nil(in_app_delivery)

    conn = get(conn, "/admin/chimeway/traces")
    assert html_response(conn, 200) =~ "Trace Lookup"

    {:ok, view, _html} = live(conn)

    html =
      view
      |> form("#trace-search-form", %{
        "mode" => "recipient",
        "query" => DemoHost.Seeds.morgan_identity(),
        "notification_key" => ""
      })
      |> render_submit()

    assert_redacted_recipient(html, DemoHost.Seeds.morgan_identity())

    {:ok, detail_view, detail_html} =
      live(conn, "/admin/chimeway/deliveries/#{in_app_delivery.id}")

    assert detail_html =~ "Trace Detail"

    detail = render(detail_view)
    assert detail =~ "teampulse.payment_reminder"
    assert detail =~ "teampulse-seed-payment-corr"
    assert detail =~ "workflow waiting" or detail =~ "Workflow waiting"
  end

  defp assert_redacted_recipient(html, recipient_id) do
    assert html =~ ChimewayAdmin.Redaction.redact_recipient(recipient_id)
    refute html =~ recipient_id
  end
end
