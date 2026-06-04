defmodule ChimewayAdmin.Live.RecoveryLiveTest do
  use ChimewayAdmin.LiveViewCase, async: false

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  defmodule RecoveryCaptureAuth do
    @behaviour ChimewayAdmin.Auth

    @impl true
    def authorize(actor, action, context) do
      :chimeway_admin
      |> Application.fetch_env!(:capture_pid)
      |> send({:authorized, actor, action, context})

      :ok
    end
  end

  setup do
    Application.put_env(:chimeway_admin, :capture_pid, self())

    Application.put_env(:chimeway_admin, :auth_module, RecoveryCaptureAuth)
    :ok
  end

  test "renders tenant scope label and safe selected candidate evidence", %{conn: conn} do
    delivery = recoverable_delivery(tenant_id: "tenant-a", notification_key: "recovery.safe")

    {:ok, view, html} =
      mount_recovery(conn,
        tenant_id: "tenant-a",
        session_extra: %{"raw_secret" => "session-secret"}
      )

    assert html =~ "Tenant scope:"
    assert html =~ "tenant-a"

    html =
      view
      |> element("button[phx-value-id=\"#{delivery.id}\"]")
      |> render_click()

    assert html =~ "cw-scope-label"
    assert html =~ "cw-confirm-form"
    assert html =~ "cw-button--danger"
    assert html =~ "Resource ID"
    assert html =~ delivery.id
    assert html =~ "recovery.safe"
    refute html =~ "session-secret"
    refute html =~ "raw_secret"
  end

  test "missing confirmation blocks authorization and recovery", %{conn: conn} do
    delivery = recoverable_delivery(tenant_id: "tenant-a")
    {:ok, view, _html} = mount_recovery(conn, tenant_id: "tenant-a")

    view
    |> element("button[phx-value-id=\"#{delivery.id}\"]")
    |> render_click()

    html =
      view
      |> form(".cw-confirm-form", %{
        "candidate_id" => delivery.id,
        "type" => "delivery",
        "reason" => "operator checked row"
      })
      |> render_submit()

    assert html =~ "Recovery failed. Confirm the recovery reason and marker before retrying."
    refute_receive {:authorized, _actor, :recover_delivery, _context}, 50

    reloaded = Repo.get!(Chimeway.Delivery, delivery.id)
    refute Map.has_key?(reloaded.metadata || %{}, "recovered_at")
  end

  test "confirmed submit re-authorizes with candidate facts and safe tenant context", %{
    conn: conn
  } do
    delivery = recoverable_delivery(tenant_id: "tenant-a", notification_key: "recovery.auth")
    delivery_id = delivery.id
    {:ok, view, _html} = mount_recovery(conn, tenant_id: "tenant-a")

    view
    |> element("button[phx-value-id=\"#{delivery.id}\"]")
    |> render_click()

    html =
      view
      |> form(".cw-confirm-form", %{
        "candidate_id" => delivery.id,
        "type" => "delivery",
        "reason" => "operator checked row",
        "confirmation_marker" => "operator_confirmed_recovery"
      })
      |> render_submit()

    assert html =~ "Delivery recovery"

    assert_receive {:authorized, "ops:1", :recover_delivery,
                    %{
                      tenant_id: "tenant-a",
                      resource_id: ^delivery_id,
                      recovery_type: "delivery",
                      candidate: %{id: ^delivery_id, tenant_id: "tenant-a"}
                    }}

    reloaded = Repo.get!(Chimeway.Delivery, delivery.id)
    assert reloaded.metadata["recovery_source"] == "chimeway_admin"
    assert reloaded.metadata["recovery_reason"] == "operator checked row"
    assert reloaded.tenant_id == "tenant-a"
  end

  test "noop recovery shows approved stale copy, clears selection, and refreshes scoped candidates",
       %{
         conn: conn
       } do
    delivery = recoverable_delivery(tenant_id: "tenant-a", notification_key: "recovery.noop")
    {:ok, view, _html} = mount_recovery(conn, tenant_id: "tenant-a")

    view
    |> element("button[phx-value-id=\"#{delivery.id}\"]")
    |> render_click()

    {:ok, _result} =
      Chimeway.recover_delivery(delivery.id,
        source: "chimeway_admin",
        reason: "already recovered"
      )

    html =
      view
      |> form(".cw-confirm-form", %{
        "candidate_id" => delivery.id,
        "type" => "delivery",
        "reason" => "operator checked row",
        "confirmation_marker" => "operator_confirmed_recovery"
      })
      |> render_submit()

    assert html =~
             "Recovery skipped: the row is no longer eligible. Refresh Recovery to review current candidates."

    assert html =~ "cw-alert--warning"
    refute html =~ "Resource ID"
  end

  test "recovery markup exposes confirmation and alert css hooks", %{conn: conn} do
    delivery = recoverable_delivery(tenant_id: "tenant-a")
    {:ok, view, _html} = mount_recovery(conn, tenant_id: "tenant-a")

    html =
      view
      |> element("button[phx-value-id=\"#{delivery.id}\"]")
      |> render_click()

    document = Floki.parse_document!(html)

    assert [_] = Floki.find(document, ".cw-scope-label")
    assert [_] = Floki.find(document, ".cw-confirm-form")
    assert [_] = Floki.find(document, ".cw-confirm-marker")
    assert [_] = Floki.find(document, ".cw-button--danger")
  end

  defp mount_recovery(conn, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    session_extra = Keyword.get(opts, :session_extra, %{})

    live_isolated(conn, ChimewayAdmin.Live.RecoveryLive,
      session:
        Map.merge(
          %{"current_actor" => "ops:1", "chimeway_admin_tenant_id" => tenant_id},
          session_extra
        ),
      on_mount: [{ChimewayAdmin.LiveAuth, :list_recovery_candidates}]
    )
  end

  defp recoverable_delivery(attrs) do
    old = ~U[2026-01-15 12:00:00.000000Z]

    event =
      %Event{}
      |> Event.changeset(%{
        notification_key: Keyword.get(attrs, :notification_key, "recovery.delivery"),
        notification_version: 1,
        idempotency_key: "recovery-live-#{System.unique_integer([:positive])}",
        payload: %{},
        correlation_id: "corr-#{System.unique_integer([:positive])}"
      })
      |> Repo.insert!()

    notification =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: "user:recovery@example.test",
        recipient_type: "user",
        metadata: %{},
        render_assigns: %{},
        render_channels: %{"email" => %{"render_key" => "recovery.email", "render_version" => 1}}
      })
      |> Repo.insert!()

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, :email,
        tenant_id: Keyword.fetch!(attrs, :tenant_id),
        actor_id: "system",
        metadata: %{},
        render_key: "recovery.email",
        render_version: 1,
        render_data: %{}
      )

    delivery
    |> Ecto.Changeset.change(%{inserted_at: old, updated_at: old})
    |> Repo.update!()
  end
end
