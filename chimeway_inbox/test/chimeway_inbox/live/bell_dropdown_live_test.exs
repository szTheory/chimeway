defmodule ChimewayInbox.Live.BellDropdownLiveTest do
  use ChimewayInbox.LiveViewCase, async: false

  import Phoenix.LiveViewTest

  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias ChimewayInbox.TestSupport.DenyAuth

  defmodule MissingTenantAuth do
    @behaviour ChimewayInbox.Auth

    @impl true
    def current_recipient(_session, _context), do: {:ok, "user:42"}

    @impl true
    def current_tenant(_session, _context), do: {:error, :missing_tenant}
  end

  defp mount_bell(conn, session \\ %{"current_actor" => "user:42"}) do
    conn
    |> Phoenix.ConnTest.init_test_session(session)
    |> live("/")
  end

  test "mount lists notifications when panel opens", %{conn: conn} do
    first = insert_inbox_notification!("user:42", %{metadata: %{"subject" => "First"}})
    second = insert_inbox_notification!("user:42", %{metadata: %{"subject" => "Second"}})

    {:ok, view, html} = mount_bell(conn)

    assert html =~ ~s(data-cw-inbox-bell)
    assert html =~ "Notifications, 2 unread"

    panel_html = view |> element("button[data-cw-inbox-bell]") |> render_click()

    assert panel_html =~ "Notifications"
    assert panel_html =~ ~s(data-cw-inbox-items)
    assert panel_html =~ ~s(data-notification-id="#{first.id}")
    assert panel_html =~ ~s(data-notification-id="#{second.id}")
    assert panel_html =~ "Mark as read"
  end

  test "mark_read updates badge count after row click", %{conn: conn} do
    notification =
      insert_inbox_notification!("user:42", %{metadata: %{"subject" => "Unread item"}})

    {:ok, view, html} = mount_bell(conn)

    assert html =~ ~s(data-cw-inbox-badge)
    assert html =~ "Notifications, 1 unread"

    view |> element("button[data-cw-inbox-bell]") |> render_click()

    updated_html =
      view
      |> element("button[phx-click=\"mark_read\"][phx-value-id=\"#{notification.id}\"]")
      |> render_click()

    assert updated_html =~ ~s(data-cw-inbox-badge)
    assert updated_html =~ ~s(hidden="")
    assert updated_html =~ ~s(aria-label="Notifications")
    refute updated_html =~ "1 unread"

    persisted = Repo.get!(Notification, notification.id)
    assert persisted.read_at
  end

  test "unauthorized mount redirects without inbox chrome", %{conn: conn} do
    previous = Application.get_env(:chimeway_inbox, :auth_module)
    Application.put_env(:chimeway_inbox, :auth_module, DenyAuth)
    Application.put_env(:chimeway_inbox, :unauthorized_redirect, "/login")

    on_exit(fn ->
      Application.put_env(:chimeway_inbox, :auth_module, previous)
      Application.delete_env(:chimeway_inbox, :unauthorized_redirect)
    end)

    assert {:error, {:redirect, %{to: "/login"}}} = mount_bell(conn)
  end

  test "missing host tenant redirects before inbox access", %{conn: conn} do
    previous = Application.get_env(:chimeway_inbox, :auth_module)
    Application.put_env(:chimeway_inbox, :auth_module, MissingTenantAuth)
    Application.put_env(:chimeway_inbox, :unauthorized_redirect, "/login")

    on_exit(fn ->
      Application.put_env(:chimeway_inbox, :auth_module, previous)
      Application.delete_env(:chimeway_inbox, :unauthorized_redirect)
    end)

    assert {:error, {:redirect, %{to: "/login"}}} = mount_bell(conn)
  end

  test "a notification from another tenant is indistinguishable from an absent row", %{conn: conn} do
    visible = insert_inbox_notification!("user:42", %{metadata: %{"subject" => "Visible"}})

    hidden =
      insert_inbox_notification!("user:42", %{
        tenant_id: "tenant-b",
        metadata: %{"subject" => "Other tenant"}
      })

    {:ok, view, _html} = mount_bell(conn)
    panel_html = view |> element("button[data-cw-inbox-bell]") |> render_click()

    assert panel_html =~ ~s(data-notification-id="#{visible.id}")
    refute panel_html =~ hidden.id
    refute panel_html =~ "Other tenant"

    unchanged_html = render_click(view, "mark_read", %{"id" => hidden.id})
    assert unchanged_html =~ ~s(data-notification-id="#{visible.id}")

    assert is_nil(Repo.get!(Notification, hidden.id).read_at)
  end

  test "empty state renders UI-SPEC copy", %{conn: conn} do
    {:ok, view, _html} = mount_bell(conn)

    panel_html = view |> element("button[data-cw-inbox-bell]") |> render_click()

    assert panel_html =~ "No notifications yet"
    assert panel_html =~ "When something needs your attention, it will show up here."
    refute panel_html =~ "Mark as read"
  end

  test "footer shows Load more notifications when page has more items", %{conn: conn} do
    for index <- 1..21 do
      insert_inbox_notification!("user:42", %{
        metadata: %{"subject" => "Item #{index}"},
        idempotency_key: "inbox-load-more-#{index}"
      })
    end

    {:ok, view, _html} = mount_bell(conn)

    panel_html = view |> element("button[data-cw-inbox-bell]") |> render_click()

    assert panel_html =~ "Load more notifications"
  end

  # mark_seen is not invoked by BellDropdownLive v1.9 (D-08 discretion) — only mark_read
  # is wired from row actions. Seen lifecycle remains host/API responsibility until a
  # future panel-open hook is added.
end
