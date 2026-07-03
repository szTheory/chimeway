defmodule ChimewayAdmin.Live.DefinitionsLiveTest do
  use ChimewayAdmin.LiveViewCase, async: false

  import Phoenix.LiveViewTest

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  @description "Durable notification keys and versions inferred from persisted Chimeway events and deliveries."
  @forbidden_phrases [
    "code registry",
    "source skew",
    "source-code skew",
    "notifier module discovery",
    "module inventory",
    "loaded modules",
    "source code scan"
  ]

  setup do
    Repo.delete_all(Chimeway.DeliveryAttempt)
    Repo.delete_all(Chimeway.Delivery)
    Repo.delete_all(Notification)
    Repo.delete_all(Event)
    :ok
  end

  test "renders DB-inferred persisted definition copy and facts", %{conn: conn} do
    _delivery = definition_delivery()

    {:ok, _view, html} =
      live_isolated(conn, ChimewayAdmin.Live.DefinitionsLive,
        session: %{"current_actor" => "ops:1"},
        on_mount: [{ChimewayAdmin.LiveAuth, :view_definitions}]
      )

    assert html =~ @description
    assert html =~ "Definitions seen in this app"
    assert html =~ "definitions.copy.71"
    assert html =~ "v4"
    assert html =~ "email"
    assert_no_forbidden_phrases(html)
  end

  test "empty state describes persisted notification history without registry claims", %{
    conn: conn
  } do
    {:ok, _view, html} =
      live_isolated(conn, ChimewayAdmin.Live.DefinitionsLive,
        session: %{"current_actor" => "ops:1"},
        on_mount: [{ChimewayAdmin.LiveAuth, :view_definitions}]
      )

    assert html =~ @description
    assert html =~ "Definitions seen in this app"
    assert html =~ "No definitions seen"

    assert html =~
             "Persisted notification keys and versions will appear after Chimeway records events or deliveries."

    assert_no_forbidden_phrases(html)
  end

  defp definition_delivery do
    event =
      %Event{}
      |> Event.changeset(%{
        notification_key: "definitions.copy.71",
        notification_version: 4,
        idempotency_key: "definitions-copy-#{System.unique_integer([:positive])}",
        payload: %{}
      })
      |> Repo.insert!()

    notification =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: "user:definitions@example.test",
        recipient_type: "user",
        metadata: %{},
        render_assigns: %{},
        render_channels: %{
          "email" => %{"render_key" => "definitions.email", "render_version" => 1}
        }
      })
      |> Repo.insert!()

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, :email,
        tenant_id: "default",
        actor_id: "system"
      )

    delivery
  end

  defp assert_no_forbidden_phrases(html) do
    downcased = String.downcase(html)

    Enum.each(@forbidden_phrases, fn phrase ->
      refute downcased =~ phrase
    end)
  end
end
