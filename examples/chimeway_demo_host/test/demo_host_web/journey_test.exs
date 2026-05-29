defmodule DemoHostWeb.JourneyTest do
  @moduledoc """
  TeamPulse consumer journey proofs — part of the JOUR-01..08 suite (9 tests total).

  This module covers JOUR-01, JOUR-02, JOUR-03, and JOUR-06.

  Other journey modules:

  * `DemoHostWeb.AdminTraceLiveTest` — JOUR-04, JOUR-07, JOUR-08
  * `Mix.Tasks.Demo.UpTest` (`demo_up_test.exs`) — JOUR-05

  All tests are tagged `:journey` for `mix test --only journey` / `mix verify.journeys`.
  """
  use DemoHostWeb.ConnCase, async: false
  import Ecto.Query, only: [from: 2]
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.{Delivery, Repo, Traces}
  alias Chimeway.Notifications.Notification
  alias Chimeway.Signals.Signal
  alias Chimeway.Workflows
  alias Chimeway.Workflows.Progression
  alias Chimeway.Workflows.WorkflowRun
  alias Chimeway.Workflows.WorkflowTransition

  setup do
    Application.put_env(:demo_host, :chimeway_adapter_config, [])
    :ok
  end

  @tag :journey
  @tag :jour_01
  test "JOUR-01 seed invite delivers successfully", _context do
    assert {:ok, %{trace: %{delivery_ids: [_ | _] = ids}}} = DemoHost.Seeds.seed_invite()

    for delivery_id <- ids do
      {:ok, explanation} = Traces.explain_delivery(delivery_id)
      assert explanation.status in [:succeeded, :pending, :dispatched]
    end

    {:ok, explanation} = Traces.explain_delivery(hd(ids))
    assert explanation.status == :succeeded
  end

  @tag :journey
  @tag :jour_02
  test "JOUR-02 password reset explains channel suppression", _context do
    assert {:ok, explanation} = DemoHost.Seeds.password_reset_explanation()
    assert explanation.status == :suppressed
    assert explanation.suppression_reason == "channel_disabled"
  end

  @tag :journey
  @tag :jour_03
  test "JOUR-03 seeded escalation progresses via mark_read", _context do
    assert {:ok, %{trace: %{delivery_ids: ids}}} = DemoHost.Seeds.escalation_waiting!()

    in_app_delivery =
      ids
      |> Enum.map(&Repo.get!(Delivery, &1))
      |> Enum.find(&(&1.channel == "in_app"))

    refute is_nil(in_app_delivery)

    notification = Repo.get!(Notification, in_app_delivery.notification_id)
    run = Repo.get!(WorkflowRun, in_app_delivery.workflow_run_id)

    assert run.state == :waiting
    assert run.pending_signals == ["chimeway.notification.read"]
    assert run.status_reason == "waiting_for_step_progression"

    assert :ok = Chimeway.mark_read(notification.id, DemoHost.Seeds.morgan_identity())

    drain_oban!(:chimeway_signals)

    signals = Repo.all(Signal)
    assert Enum.any?(signals, &(&1.event_name == "chimeway.notification.read"))

    updated_run = Repo.get!(WorkflowRun, run.id)
    assert updated_run.state == :active
    assert updated_run.pending_signals == []

    [signal_received_transition] =
      Repo.all(
        from(wt in WorkflowTransition,
          where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
        )
      )

    assert signal_received_transition.reason == "signal_received"
    assert signal_received_transition.context == %{"event_name" => "chimeway.notification.read"}
    refute Map.has_key?(signal_received_transition.context, "notification_id")
    refute Map.has_key?(signal_received_transition.context, "payload")
  end

  @tag :journey
  @tag :jour_06
  test "JOUR-06 mark_read cancels escalation before due_at", _context do
    assert {:ok, %{trace: %{delivery_ids: ids}}} = DemoHost.Seeds.escalation_waiting!()

    in_app_delivery =
      ids
      |> Enum.map(&Repo.get!(Delivery, &1))
      |> Enum.find(&(&1.channel == "in_app"))

    refute is_nil(in_app_delivery)

    notification = Repo.get!(Notification, in_app_delivery.notification_id)
    run = Repo.get!(WorkflowRun, in_app_delivery.workflow_run_id)

    assert run.state == :waiting
    assert run.pending_signals == ["chimeway.notification.read"]
    assert run.status_reason == "waiting_for_step_progression"

    assert :ok = Chimeway.mark_read(notification.id, DemoHost.Seeds.morgan_identity())

    drain_oban!(:chimeway_signals)

    updated_run = Repo.get!(WorkflowRun, run.id)
    assert updated_run.state == :active
    assert updated_run.pending_signals == []

    [signal_received_transition] =
      Repo.all(
        from(wt in WorkflowTransition,
          where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
        )
      )

    assert signal_received_transition.reason == "signal_received"
    assert signal_received_transition.context == %{"event_name" => "chimeway.notification.read"}

    email_deliveries =
      from(d in Delivery,
        where: d.workflow_run_id == ^run.id and d.channel == "email"
      )
      |> Repo.all()

    assert email_deliveries == []

    current_step = Workflows.get_current_step!(updated_run)
    assert current_step.step_key == "initial_notice"
  end

  @tag :journey
  @tag :jour_06
  test "JOUR-06 unread time-fallback advances to email_escalation", _context do
    assert {:ok, %{trace: %{delivery_ids: ids}}} = DemoHost.Seeds.escalation_waiting!()

    in_app_delivery =
      ids
      |> Enum.map(&Repo.get!(Delivery, &1))
      |> Enum.find(&(&1.channel == "in_app"))

    refute is_nil(in_app_delivery)

    notification = Repo.get!(Notification, in_app_delivery.notification_id)
    run = Repo.get!(WorkflowRun, in_app_delivery.workflow_run_id)

    assert run.state == :waiting

    due_at = parse_due_at!(run.status_context["due_at"])
    past_due_now = DateTime.add(due_at, 1, :second)

    assert {:ok, {:advanced, advanced_run, [next_delivery]}} =
             Progression.progress_run(run.id, now: past_due_now)

    assert advanced_run.state == :active
    assert next_delivery.channel == "email"

    email_count =
      from(d in Delivery,
        where: d.notification_id == ^notification.id and d.channel == "email"
      )
      |> Repo.aggregate(:count)

    assert email_count == 1
  end

  defp parse_due_at!(iso8601) when is_binary(iso8601) do
    case DateTime.from_iso8601(iso8601) do
      {:ok, dt, _offset} -> dt
      {:error, reason} -> flunk("invalid due_at #{inspect(iso8601)}: #{inspect(reason)}")
    end
  end

  defp drain_oban!(queue) do
    result = Oban.drain_queue(queue: queue, with_scheduled: true)

    total =
      Map.get(result, :success, 0) +
        Map.get(result, :failure, 0) +
        Map.get(result, :discard, 0)

    assert total >= 1, "expected #{queue} worker to run; got #{inspect(result)}"
  end
end
