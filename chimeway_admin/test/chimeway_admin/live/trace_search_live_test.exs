defmodule ChimewayAdmin.Live.TraceSearchLiveTest do
  use ChimewayAdmin.LiveViewCase, async: true

  import Phoenix.LiveViewTest

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

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

  test "dashboard labels succeeded metric as provider accepted", %{conn: conn} do
    _delivery = succeeded_delivery("dashboard.provider.accepted")

    {:ok, _view, html} =
      live_isolated(conn, ChimewayAdmin.Live.DashboardLive,
        session: %{"current_actor" => "ops:1"},
        on_mount: [{ChimewayAdmin.LiveAuth, :search_traces}]
      )

    assert html =~ "Provider accepted"
    refute html =~ "Delivered"
  end

  test "trace detail labels succeeded attempts as provider accepted without delivery feedback", %{
    conn: conn
  } do
    delivery = succeeded_delivery("trace.provider.accepted")
    conn = Plug.Test.init_test_session(conn, %{"current_actor" => "ops:1"})

    {:ok, _view, html} = live(conn, "/deliveries/#{delivery.id}")

    assert html =~ "Provider accepted"
    refute html =~ "Delivered"
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

  defp succeeded_delivery(notification_key) do
    event =
      %Event{}
      |> Event.changeset(%{
        notification_key: notification_key,
        notification_version: 1,
        idempotency_key: "#{notification_key}-#{System.unique_integer([:positive])}",
        payload: %{}
      })
      |> Repo.insert!()

    notification =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: "user:provider@example.test",
        recipient_type: "user",
        metadata: %{},
        render_assigns: %{},
        render_channels: %{"email" => %{"render_key" => "provider.email", "render_version" => 1}}
      })
      |> Repo.insert!()

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, :email, tenant_id: "default", actor_id: "system")

    {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

    {:ok, %{delivery: succeeded}} =
      Deliveries.record_attempt(dispatched, %{outcome: :succeeded, provider_response: %{}})

    succeeded
  end
end
