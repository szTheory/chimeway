defmodule DemoHostWeb.InboxBellProofTest do
  @moduledoc """
  DEMO-08 proof: end-user inbox list → mark_read → badge count update; mark_seen via API.

  Tagged `:inbox` only — journey suite keeps default Logger adapter (D-06).
  """
  use DemoHostWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  use Oban.Testing, repo: Chimeway.Repo, prefix: "chimeway"

  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Workflows.{WorkflowDefinition, WorkflowRun, WorkflowStep, WorkflowTransition}

  @moduletag :inbox

  test "DEMO-08 list, mark_read, and badge update" do
    assert {:ok, _opaque_ref} =
             Chimeway.SafeEvidence.opaque_ref(:recipient, DemoHost.Seeds.alex_identity())

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

    assert :ok =
             Chimeway.mark_seen(second_id, DemoHost.Seeds.alex_identity(),
               tenant_id: DemoHost.Seeds.tenant_id()
             )

    persisted = Repo.get!(Notification, second_id)
    assert persisted.seen_at
  end

  test "DEMO-08 mounted bell progresses an eligible seen workflow exactly once" do
    assert {:ok, %{notification_ids: [first_id | _]}} = DemoHost.Seeds.seed_inbox()
    run = insert_waiting_seen_run!(first_id, DemoHost.Seeds.tenant_id())

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{"demo_user_email" => DemoHost.Seeds.alex_email()})

    {:ok, view, _html} = live(conn, "/inbox")
    view |> element("button[data-cw-inbox-bell]") |> render_click()
    drain_signal_queue!()

    assert Repo.get!(WorkflowRun, run.id).state == :active
    assert signal_transition_count(run.id) == 1

    view |> element("button[data-cw-inbox-bell]") |> render_click()
    view |> element("button[data-cw-inbox-bell]") |> render_click()
    _ = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)

    assert signal_transition_count(run.id) == 1
  end

  test "DEMO-08 wrong tenant and recipient seen signals leave waiting workflows unchanged" do
    expected_recipient = "cw_demo_scope_expected"
    notification = insert_notification!("teampulse", expected_recipient)
    run = insert_waiting_seen_run!(notification.id, "teampulse")

    assert {:ok, _signal} =
             Chimeway.Signal.track(
               "other-tenant",
               expected_recipient,
               "chimeway.notification.seen"
             )

    assert {:ok, _signal} =
             Chimeway.Signal.track(
               "teampulse",
               "cw_demo_scope_other",
               "chimeway.notification.seen"
             )

    drain_signal_queue!()

    assert Repo.get!(WorkflowRun, run.id).state == :waiting
    assert signal_transition_count(run.id) == 0
  end

  defp insert_waiting_seen_run!(notification_id, tenant_id) do
    suffix = System.unique_integer([:positive])

    definition =
      %WorkflowDefinition{}
      |> WorkflowDefinition.changeset(%{
        workflow_key: "demo.seen-proof.#{suffix}",
        workflow_version: 1,
        notification_key: "teampulse.invite_sent"
      })
      |> Repo.insert!()

    step =
      %WorkflowStep{}
      |> WorkflowStep.changeset(%{
        workflow_definition_id: definition.id,
        step_key: "wait_for_seen",
        step_order: 1,
        channel: "in_app",
        config: %{}
      })
      |> Repo.insert!()

    now = DateTime.utc_now()

    %WorkflowRun{}
    |> WorkflowRun.changeset(%{
      notification_id: notification_id,
      workflow_definition_id: definition.id,
      current_step_id: step.id,
      state: :waiting,
      started_at: now,
      last_transition_at: now,
      status_reason: "waiting_for_signal",
      tenant_id: tenant_id,
      pending_signals: ["chimeway.notification.seen"]
    })
    |> Repo.insert!()
  end

  defp insert_notification!(tenant_id, recipient_identity) do
    event =
      Repo.insert!(%Event{
        notification_key: "test.seen_scope",
        notification_version: 1,
        idempotency_key: "seen-scope-#{System.unique_integer([:positive])}",
        tenant_id: tenant_id,
        payload: %{}
      })

    Repo.insert!(%Notification{
      event_id: event.id,
      tenant_id: tenant_id,
      recipient_identity: recipient_identity,
      recipient_type: "user",
      metadata: %{},
      render_assigns: %{},
      render_channels: %{}
    })
  end

  defp signal_transition_count(run_id) do
    Repo.one(
      from(t in WorkflowTransition,
        where: t.workflow_run_id == ^run_id and t.reason == "signal_received",
        select: count()
      )
    )
  end

  defp drain_signal_queue! do
    result = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true)
    assert result.success >= 1
  end
end
