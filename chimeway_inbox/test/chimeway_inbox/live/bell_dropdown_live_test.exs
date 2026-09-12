defmodule ChimewayInbox.Live.BellDropdownLiveTest do
  use ChimewayInbox.LiveViewCase, async: false

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias Chimeway.Inbox.Change
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Signals.Signal
  alias ChimewayInbox.PubSubPublisher
  alias ChimewayInbox.TestSupport.DenyAuth

  @reload {:chimeway_inbox, :reload, 1}

  defmodule MissingTenantAuth do
    @behaviour ChimewayInbox.Auth

    @impl true
    def current_recipient(_session, _context), do: {:ok, "cw_user_42"}

    @impl true
    def current_tenant(_session, _context), do: {:error, :missing_tenant}
  end

  defmodule UnsafeRecipientAuth do
    @behaviour ChimewayInbox.Auth

    @impl true
    def current_recipient(_session, _context), do: {:ok, "user:42"}

    @impl true
    def current_tenant(_session, _context), do: {:ok, "tenant-a"}
  end

  defmodule MutableAuth do
    @behaviour ChimewayInbox.Auth

    @impl true
    def current_recipient(_session, _context) do
      {:ok, Application.fetch_env!(:chimeway_inbox, :mutable_auth_recipient)}
    end

    @impl true
    def current_tenant(_session, _context) do
      {:ok, Application.fetch_env!(:chimeway_inbox, :mutable_auth_tenant)}
    end
  end

  defp mount_bell(conn, session \\ %{"current_actor" => "cw_user_42"}) do
    conn
    |> Phoenix.ConnTest.init_test_session(session)
    |> live("/")
  end

  test "mount lists notifications when panel opens", %{conn: conn} do
    first = insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "First"}})
    second = insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "Second"}})

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
      insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "Unread item"}})

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

  test "a changed tenant redirects before mark_read and leaves the notification unread", %{
    conn: conn
  } do
    notification =
      insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "Tenant guarded"}})

    use_mutable_auth!("cw_user_42", "tenant-a")

    {:ok, view, _html} = mount_bell(conn)
    view |> element("button[data-cw-inbox-bell]") |> render_click()

    Application.put_env(:chimeway_inbox, :mutable_auth_tenant, "tenant-b")

    assert {:error, {:redirect, %{to: "/login"}}} =
             render_click(view, "mark_read", %{"id" => notification.id})

    assert is_nil(Repo.get!(Notification, notification.id).read_at)
  end

  test "a changed recipient redirects before mark_read and leaves both recipient rows unread", %{
    conn: conn
  } do
    mounted_notification =
      insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "Mounted recipient"}})

    changed_recipient_notification =
      insert_inbox_notification!("cw_user_99", %{metadata: %{"subject" => "Changed recipient"}})

    use_mutable_auth!("cw_user_42", "tenant-a")

    {:ok, view, _html} = mount_bell(conn)
    view |> element("button[data-cw-inbox-bell]") |> render_click()

    Application.put_env(:chimeway_inbox, :mutable_auth_recipient, "cw_user_99")

    assert {:error, {:redirect, %{to: "/login"}}} =
             render_click(view, "mark_read", %{"id" => mounted_notification.id})

    assert is_nil(Repo.get!(Notification, mounted_notification.id).read_at)
    assert is_nil(Repo.get!(Notification, changed_recipient_notification.id).read_at)
  end

  test "a changed recipient and tenant redirect before toggle without loading a new identity", %{
    conn: conn
  } do
    mounted_notification =
      insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "Mounted identity"}})

    changed_identity_notification =
      insert_inbox_notification!("cw_user_99", %{
        tenant_id: "tenant-b",
        metadata: %{"subject" => "Changed identity"}
      })

    use_mutable_auth!("cw_user_42", "tenant-a")

    {:ok, view, _html} = mount_bell(conn)

    Application.put_env(:chimeway_inbox, :mutable_auth_recipient, "cw_user_99")
    Application.put_env(:chimeway_inbox, :mutable_auth_tenant, "tenant-b")

    assert {:error, {:redirect, %{to: "/login"}}} = render_click(view, "toggle_panel", %{})

    assert is_nil(Repo.get!(Notification, mounted_notification.id).read_at)
    assert is_nil(Repo.get!(Notification, changed_identity_notification.id).read_at)
    assert is_nil(Repo.get!(Notification, mounted_notification.id).seen_at)
    assert is_nil(Repo.get!(Notification, changed_identity_notification.id).seen_at)
    assert seen_signal_count() == 0
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

  test "unsafe recipient evidence leaves the bell mountable without rendering an error tuple", %{
    conn: conn
  } do
    previous = Application.get_env(:chimeway_inbox, :auth_module)
    Application.put_env(:chimeway_inbox, :auth_module, UnsafeRecipientAuth)

    on_exit(fn -> Application.put_env(:chimeway_inbox, :auth_module, previous) end)

    {:ok, view, html} = mount_bell(conn)

    assert html =~ ~s(aria-label="Notifications")
    refute html =~ "unsafe_evidence"

    panel_html = view |> element("button[data-cw-inbox-bell]") |> render_click()
    assert panel_html =~ "Couldn&#39;t load notifications"
  end

  test "a notification from another tenant is indistinguishable from an absent row", %{conn: conn} do
    visible = insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "Visible"}})

    hidden =
      insert_inbox_notification!("cw_user_42", %{
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
      insert_inbox_notification!("cw_user_42", %{
        metadata: %{"subject" => "Item #{index}"},
        idempotency_key: "inbox-load-more-#{index}"
      })
    end

    {:ok, view, _html} = mount_bell(conn)

    panel_html = view |> element("button[data-cw-inbox-bell]") |> render_click()

    assert panel_html =~ "Load more notifications"
  end

  test "a same-scope change refreshes the badge and open panel without polling", %{conn: conn} do
    {:ok, view, _html} = mount_bell(conn)
    view |> element("button[data-cw-inbox-bell]") |> render_click()

    notification =
      insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "Arrived live"}})

    publish_change!("tenant-a", "cw_user_42")

    html = render(view)
    assert html =~ "Notifications, 1 unread"
    assert html =~ ~s(data-cw-inbox-panel)
    assert html =~ ~s(data-notification-id="#{notification.id}")
    assert html =~ "Arrived live"
    refute_receive @reload
  end

  test "wrong-scope and unrelated messages do not refresh or reveal durable state", %{conn: conn} do
    {:ok, view, _html} = mount_bell(conn)
    view |> element("button[data-cw-inbox-bell]") |> render_click()

    notification =
      insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "Still hidden"}})

    publish_change!("tenant-b", "cw_user_42")
    publish_change!("tenant-a", "cw_user_99")
    send(view.pid, {:chimeway_inbox, :unrelated, 1})

    html = render(view)
    refute html =~ notification.id
    refute html =~ "Still hidden"
    refute html =~ "1 unread"

    publish_change!("tenant-a", "cw_user_42")
    assert render(view) =~ notification.id
  end

  test "authorization drift redirects before a stream-triggered reload", %{conn: conn} do
    use_mutable_auth!("cw_user_42", "tenant-a")
    {:ok, view, initial_html} = mount_bell(conn)

    hidden =
      insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "Never reloaded"}})

    refute initial_html =~ hidden.id

    Application.put_env(:chimeway_inbox, :mutable_auth_tenant, "tenant-b")
    publish_change!("tenant-a", "cw_user_42")

    assert_redirect(view, "/login")
  end

  test "a stream refresh resets a loaded second page to authoritative page one", %{conn: conn} do
    oldest =
      for index <- 1..21 do
        insert_inbox_notification!("cw_user_42", %{
          metadata: %{"subject" => "Before refresh #{index}"},
          idempotency_key: "inbox-stream-page-#{index}"
        })
      end
      |> hd()

    {:ok, view, _html} = mount_bell(conn)
    view |> element("button[data-cw-inbox-bell]") |> render_click()

    loaded_html = view |> element("button[phx-click=\"load_more\"]") |> render_click()
    assert count_items(loaded_html) == 21
    assert loaded_html =~ oldest.id

    newest =
      insert_inbox_notification!("cw_user_42", %{
        metadata: %{"subject" => "Newest authoritative item"}
      })

    publish_change!("tenant-a", "cw_user_42")

    refreshed_html = render(view)
    assert refreshed_html =~ ~s(data-cw-inbox-panel)
    assert count_items(refreshed_html) == 20
    assert refreshed_html =~ newest.id
    refute refreshed_html =~ oldest.id
    assert refreshed_html =~ "Load more notifications"
  end

  test "invalid stream configuration leaves the current bell render usable", %{conn: conn} do
    previous_server = Application.get_env(:chimeway_inbox, :pubsub_server)
    Application.put_env(:chimeway_inbox, :pubsub_server, "invalid")
    on_exit(fn -> restore_env(:pubsub_server, previous_server) end)

    insert_inbox_notification!("cw_user_42", %{metadata: %{"subject" => "Still usable"}})

    {:ok, view, html} = mount_bell(conn)
    assert html =~ "Notifications, 1 unread"
    assert view |> element("button[data-cw-inbox-bell]") |> render_click() =~ "Still usable"
  end

  test "opening marks the visible first page seen exactly once while closed and reopen do not", %{
    conn: conn
  } do
    notification = insert_inbox_notification!("cw_user_42")

    {:ok, view, _html} = mount_bell(conn)
    assert is_nil(Repo.get!(Notification, notification.id).seen_at)
    assert seen_signal_count() == 0

    view |> element("button[data-cw-inbox-bell]") |> render_click()
    assert Repo.get!(Notification, notification.id).seen_at
    assert seen_signal_count() == 1

    view |> element("button[data-cw-inbox-bell]") |> render_click()
    view |> element("button[data-cw-inbox-bell]") |> render_click()
    assert seen_signal_count() == 1
  end

  test "load more marks only rows as they become visible", %{conn: conn} do
    oldest =
      for index <- 1..21 do
        insert_inbox_notification!("cw_user_42", %{
          idempotency_key: "seen-visible-page-#{index}"
        })
      end
      |> hd()

    {:ok, view, _html} = mount_bell(conn)
    view |> element("button[data-cw-inbox-bell]") |> render_click()

    assert seen_signal_count() == 20
    assert is_nil(Repo.get!(Notification, oldest.id).seen_at)

    view |> element("button[phx-click=\"load_more\"]") |> render_click()
    assert Repo.get!(Notification, oldest.id).seen_at
    assert seen_signal_count() == 21
    assert view |> render() |> count_items() == 21
  end

  test "a relevant reload marks a new item seen only while the panel is open", %{conn: conn} do
    {:ok, closed_view, _html} = mount_bell(conn)
    closed_item = insert_inbox_notification!("cw_user_42")
    publish_change!("tenant-a", "cw_user_42")
    _ = render(closed_view)

    assert is_nil(Repo.get!(Notification, closed_item.id).seen_at)

    closed_view |> element("button[data-cw-inbox-bell]") |> render_click()
    assert Repo.get!(Notification, closed_item.id).seen_at

    open_item = insert_inbox_notification!("cw_user_42")
    publish_change!("tenant-a", "cw_user_42")
    _ = render(closed_view)

    assert Repo.get!(Notification, open_item.id).seen_at
    assert seen_signal_count() == 2
  end

  defp use_mutable_auth!(recipient_identity, tenant_id) do
    previous_auth_module = Application.get_env(:chimeway_inbox, :auth_module)
    previous_redirect = Application.get_env(:chimeway_inbox, :unauthorized_redirect)

    Application.put_env(:chimeway_inbox, :auth_module, MutableAuth)
    Application.put_env(:chimeway_inbox, :unauthorized_redirect, "/login")
    Application.put_env(:chimeway_inbox, :mutable_auth_recipient, recipient_identity)
    Application.put_env(:chimeway_inbox, :mutable_auth_tenant, tenant_id)

    on_exit(fn ->
      restore_env(:auth_module, previous_auth_module)
      restore_env(:unauthorized_redirect, previous_redirect)
      Application.delete_env(:chimeway_inbox, :mutable_auth_recipient)
      Application.delete_env(:chimeway_inbox, :mutable_auth_tenant)
    end)
  end

  defp restore_env(key, nil), do: Application.delete_env(:chimeway_inbox, key)
  defp restore_env(key, value), do: Application.put_env(:chimeway_inbox, key, value)

  defp publish_change!(tenant_id, recipient_ref) do
    assert {:ok, change} = Change.new(tenant_id, recipient_ref, :created)
    assert :ok = PubSubPublisher.publish(change)
  end

  defp count_items(html) do
    html
    |> String.split("data-notification-id=")
    |> length()
    |> Kernel.-(1)
  end

  defp seen_signal_count do
    Repo.one(
      from(s in Signal, where: s.event_name == "chimeway.notification.seen", select: count())
    )
  end

  # mark_seen is not invoked by BellDropdownLive v1.9 (D-08 discretion) — only mark_read
  # is wired from row actions. Seen lifecycle remains host/API responsibility until a
  # future panel-open hook is added.
end
