defmodule ChimewayAdmin.TestSupport.ToggleFeedAuth do
  @behaviour ChimewayAdmin.Auth

  @impl true
  def authorize(_actor, :view_feed, context) do
    if capture_pid = Application.get_env(:chimeway_admin, :feed_live_capture_pid) do
      send(capture_pid, {:feed_authorized, context})
    end

    case Application.get_env(:chimeway_admin, :feed_live_access, :allow) do
      :allow -> :ok
      :deny -> {:error, :unauthorized}
    end
  end

  def authorize(_actor, _action, _context), do: :ok
end

defmodule ChimewayAdmin.Live.FeedLiveTest do
  use ChimewayAdmin.LiveViewCase, async: false

  import Phoenix.LiveViewTest

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias ChimewayAdmin.TestSupport.ToggleFeedAuth

  setup do
    previous_access = Application.get_env(:chimeway_admin, :feed_live_access)
    previous_capture_pid = Application.get_env(:chimeway_admin, :feed_live_capture_pid)
    previous_redirect = Application.get_env(:chimeway_admin, :unauthorized_redirect)

    Application.put_env(:chimeway_admin, :auth_module, ToggleFeedAuth)
    Application.put_env(:chimeway_admin, :feed_live_access, :allow)
    Application.put_env(:chimeway_admin, :feed_live_capture_pid, self())
    Application.put_env(:chimeway_admin, :unauthorized_redirect, "/unauthorized")

    on_exit(fn ->
      Application.put_env(:chimeway_admin, :feed_live_access, previous_access)
      Application.put_env(:chimeway_admin, :feed_live_capture_pid, previous_capture_pid)
      Application.put_env(:chimeway_admin, :unauthorized_redirect, previous_redirect)
    end)

    :ok
  end

  test "search re-authorizes view_feed with only the normalized recipient resource", %{conn: conn} do
    fixture = feed_fixture()
    {:ok, view, _html} = conn |> with_session(fixture.tenant_id) |> live("/feed")

    assert_receive {:feed_authorized, %{action: :view_feed}}

    html =
      view
      |> form("#feed-search-form", %{"recipient_id" => "  #{fixture.recipient_id}  "})
      |> render_submit()

    assert_receive {:feed_authorized,
                    %{action: :view_feed, recipient_id: recipient_id} = authorization_context}

    assert recipient_id == fixture.recipient_id
    assert authorization_context.tenant_id == fixture.tenant_id
    assert html =~ "feed.live"
  end

  test "post-mount authorization revocation redirects before feed rows render", %{conn: conn} do
    fixture = feed_fixture()
    {:ok, view, _html} = conn |> with_session(fixture.tenant_id) |> live("/feed")

    Application.put_env(:chimeway_admin, :feed_live_access, :deny)

    view
    |> form("#feed-search-form", %{"recipient_id" => fixture.recipient_id})
    |> render_submit()

    assert_redirect(view, "/unauthorized")
  end

  defp feed_fixture do
    tenant_id = "tenant-feed-live"
    recipient_id = "user:feed-live@example.test"

    event =
      %Event{}
      |> Event.changeset(%{
        notification_key: "feed.live",
        notification_version: 1,
        idempotency_key: "feed-live-#{System.unique_integer([:positive])}",
        tenant_id: tenant_id,
        payload: %{}
      })
      |> Repo.insert!()

    notification =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        tenant_id: tenant_id,
        recipient_identity: recipient_id,
        recipient_type: "user",
        metadata: %{},
        render_assigns: %{},
        render_channels: %{}
      })
      |> Repo.insert!()

    {:ok, _delivery} =
      Deliveries.plan_delivery(notification.id, :email,
        tenant_id: tenant_id,
        actor_id: "system",
        metadata: %{},
        render_key: "feed.live",
        render_version: 1,
        render_data: %{}
      )

    %{tenant_id: tenant_id, recipient_id: recipient_id}
  end

  defp with_session(conn, tenant_id) do
    Plug.Test.init_test_session(conn, %{
      "current_actor" => "ops:feed",
      "chimeway_admin_tenant_id" => tenant_id
    })
  end
end
