defmodule ChimewayAdmin.Live.PrivacyLeakLiveTest do
  use ChimewayAdmin.LiveViewCase, async: false

  import Phoenix.LiveViewTest

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  @sensitive_values [
    "raw-payload-secret-71",
    "render-assign-secret-71",
    "render-data-secret-71",
    "provider-body-secret-71",
    "metadata-secret-71",
    "session-secret-71",
    "params-auth-code-71",
    "bearer-token-71",
    "api-key-secret-71",
    "alex.full-pii@example.test",
    "+15551234567"
  ]

  test "dashboard omits raw sensitive values while showing masked operator facts", %{conn: conn} do
    fixture = privacy_fixture()

    {:ok, _view, html} = conn |> with_session(fixture.tenant_id) |> live("/")

    assert_no_sensitive_values(html)
    assert html =~ "privacy.leak.71"
    assert html =~ "a***@example.test"
    assert html =~ "email"
    assert html =~ "Recovery queue"
  end

  test "trace detail omits raw sensitive values while showing redacted explanation facts", %{
    conn: conn
  } do
    fixture = privacy_fixture()

    conn = Plug.Test.init_test_session(conn, session(fixture.tenant_id))
    {:ok, _view, html} = live(conn, "/deliveries/#{fixture.failed_delivery.id}")

    assert_no_sensitive_values(html)
    assert html =~ "privacy.leak.71"
    assert html =~ "a***@example.test"
    assert html =~ "corr-privacy-71"
    assert html =~ "email"
    assert html =~ "temporary"
    assert html =~ "privacy.render v1"
  end

  test "feed search accepts full recipient input without echoing full PII", %{conn: conn} do
    fixture = privacy_fixture()

    {:ok, view, _html} = conn |> with_session(fixture.tenant_id) |> live("/feed")

    html =
      view
      |> form("#feed-search-form", %{"recipient_id" => fixture.recipient_id})
      |> render_submit()

    assert_no_sensitive_values(html)
    assert html =~ "privacy.leak.71"
    assert html =~ "a***@example.test"
    assert html =~ "corr-privacy-71"
  end

  test "recovery omits raw sensitive values while keeping safe candidate evidence", %{conn: conn} do
    fixture = privacy_fixture()

    {:ok, view, html} = conn |> with_session(fixture.tenant_id) |> live("/recovery")

    assert_no_sensitive_values(html)
    assert html =~ "privacy.leak.71"
    assert html =~ fixture.recovery_delivery.id

    html =
      view
      |> element("button[phx-value-id=\"#{fixture.recovery_delivery.id}\"]")
      |> render_click()

    assert_no_sensitive_values(html)
    assert html =~ "Resource ID"
    assert html =~ fixture.recovery_delivery.id
    assert html =~ "corr-privacy-71"
  end

  test "definitions omit sensitive values while showing DB-inferred facts", %{conn: conn} do
    fixture = privacy_fixture()

    {:ok, _view, html} = conn |> with_session(fixture.tenant_id) |> live("/definitions")

    assert_no_sensitive_values(html)
    assert html =~ "privacy.leak.71"
    assert html =~ "v3"
    assert html =~ "email"
    assert html =~ "sms"
  end

  test "trace search does not retain raw full recipient or auth-code query values", %{conn: conn} do
    fixture = privacy_fixture()

    {:ok, view, _html} = conn |> with_session(fixture.tenant_id) |> live("/traces")

    html =
      view
      |> form("#trace-search-form", %{
        "mode" => "recipient",
        "query" => fixture.recipient_id,
        "notification_key" => "privacy.leak.71"
      })
      |> render_submit()

    assert_no_sensitive_values(html)
    assert html =~ "privacy.leak.71"
    assert html =~ "a***@example.test"
    assert html =~ "email"
  end

  defp privacy_fixture do
    old = ~U[2026-01-15 12:00:00.000000Z]
    tenant_id = "tenant-privacy-live-71"
    recipient_id = "alex.full-pii@example.test"

    event =
      %Event{}
      |> Event.changeset(%{
        notification_key: "privacy.leak.71",
        notification_version: 3,
        idempotency_key: "privacy-live-#{System.unique_integer([:positive])}",
        payload: %{
          "secret" => "raw-payload-secret-71",
          "authorization" => "bearer-token-71",
          "auth_code" => "params-auth-code-71",
          "recipient_phone" => "+15551234567"
        },
        correlation_id: "corr-privacy-71",
        tenant_id: tenant_id
      })
      |> Repo.insert!()
      |> Ecto.Changeset.change(%{inserted_at: old, updated_at: old})
      |> Repo.update!()

    notification =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: recipient_id,
        recipient_type: "user",
        tenant_id: tenant_id,
        metadata: %{"session" => "session-secret-71"},
        render_assigns: %{
          "secret" => "render-assign-secret-71",
          "email" => recipient_id
        },
        render_channels: %{
          "email" => %{"render_key" => "privacy.render", "render_version" => 1},
          "sms" => %{"render_key" => "privacy.sms", "render_version" => 1}
        }
      })
      |> Repo.insert!()
      |> Ecto.Changeset.change(%{inserted_at: old, updated_at: old})
      |> Repo.update!()

    {:ok, failed_delivery} =
      Deliveries.plan_delivery(notification.id, :email,
        tenant_id: tenant_id,
        actor_id: "system",
        metadata: %{
          "secret" => "metadata-secret-71",
          "phone" => "+15551234567",
          "policy_checkpoint" => "privacy_policy"
        },
        render_key: "privacy.render",
        render_version: 1,
        render_data: %{
          "secret" => "render-data-secret-71",
          "recipient" => recipient_id
        }
      )

    failed_delivery =
      failed_delivery
      |> Ecto.Changeset.change(%{inserted_at: old, updated_at: old})
      |> Repo.update!()

    {:ok, dispatched} = Deliveries.transition_status(failed_delivery, :dispatched)

    {:ok, %{delivery: failed_delivery}} =
      Deliveries.record_attempt(dispatched, %{
        outcome: :failed,
        error_class: "temporary",
        provider_response: %{
          "provider_body" => "provider-body-secret-71",
          "token" => "api-key-secret-71"
        }
      })

    {:ok, recovery_delivery} =
      Deliveries.plan_delivery(notification.id, :sms,
        tenant_id: tenant_id,
        actor_id: "system",
        metadata: %{"secret" => "metadata-secret-71"},
        render_key: "privacy.sms",
        render_version: 1,
        render_data: %{"secret" => "render-data-secret-71"}
      )

    recovery_delivery =
      recovery_delivery
      |> Ecto.Changeset.change(%{inserted_at: old, updated_at: old})
      |> Repo.update!()

    %{
      tenant_id: tenant_id,
      recipient_id: recipient_id,
      failed_delivery: failed_delivery,
      recovery_delivery: recovery_delivery
    }
  end

  defp session(tenant_id) do
    %{
      "current_actor" => "ops:1",
      "chimeway_admin_tenant_id" => tenant_id,
      "session_secret" => "session-secret-71"
    }
  end

  defp with_session(conn, tenant_id), do: Plug.Test.init_test_session(conn, session(tenant_id))

  defp assert_no_sensitive_values(html) do
    Enum.each(@sensitive_values, fn value ->
      refute html =~ value
    end)
  end
end
