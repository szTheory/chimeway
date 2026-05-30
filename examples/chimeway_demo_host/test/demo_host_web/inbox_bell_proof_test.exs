defmodule DemoHostWeb.InboxBellProofTest do
  @moduledoc """
  DEMO-08 proof: end-user inbox list → mark_read → badge count update; mark_seen via API.

  Tagged `:inbox` only — journey suite keeps default Logger adapter (D-06).
  """
  use DemoHostWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo

  @moduletag :inbox

  test "DEMO-08 list, mark_read, and badge update" do
    assert {:ok, %{notification_ids: [first_id | _]}} = DemoHost.Seeds.seed_inbox()

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{"demo_user_email" => DemoHost.Seeds.alex_email()})

    {:ok, view, html} = live(conn, "/inbox")

    assert html =~ ~s(data-cw-inbox-badge)
    assert html =~ "Notifications, 2 unread"

    view |> element("button[data-cw-inbox-bell]") |> render_click()

    updated_html =
      view
      |> element("button[phx-click=\"mark_read\"][phx-value-id=\"#{first_id}\"]")
      |> render_click()

    assert updated_html =~ ~s(data-cw-inbox-badge)
    assert updated_html =~ "Notifications, 1 unread"
    refute updated_html =~ "2 unread"

    persisted = Repo.get!(Notification, first_id)
    assert persisted.read_at
  end

  test "DEMO-08 mark_seen via host API" do
    assert {:ok, %{notification_ids: [_first_id, second_id | _]}} = DemoHost.Seeds.seed_inbox()

    assert :ok = Chimeway.mark_seen(second_id, DemoHost.Seeds.alex_identity())

    persisted = Repo.get!(Notification, second_id)
    assert persisted.seen_at
  end
end
