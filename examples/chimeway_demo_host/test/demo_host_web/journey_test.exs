defmodule DemoHostWeb.JourneyTest do
  @moduledoc """
  TeamPulse consumer journey proofs (JOUR-01..03).

  Tagged `:journey` for `mix test --only journey` / `mix verify.journeys`.
  """
  use DemoHostWeb.ConnCase, async: false
  import Ecto.Query, only: [from: 2]
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.{Delivery, Repo, Traces}
  alias Chimeway.Notifications.Notification
  alias Chimeway.Signals.Signal
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

  defp drain_oban!(queue) do
    result = Oban.drain_queue(queue: queue, with_scheduled: true)

    total =
      Map.get(result, :success, 0) +
        Map.get(result, :failure, 0) +
        Map.get(result, :discard, 0)

    assert total >= 1, "expected #{queue} worker to run; got #{inspect(result)}"
  end
end
