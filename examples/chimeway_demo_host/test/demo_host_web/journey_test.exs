defmodule DemoHostWeb.JourneyTest do
  @moduledoc """
  TeamPulse consumer journey proofs (JOUR-01..03).

  Tagged `:journey` for `mix test --only journey` / `mix verify.journeys`.
  """
  use DemoHostWeb.ConnCase, async: false
  import Plug.Test
  import Plug.Conn
  import Ecto.Query, only: [from: 2]
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.{Repo, Traces}
  alias Chimeway.DeliveryAttempt
  alias Chimeway.Signals.Signal
  alias Chimeway.Webhooks.Ingress
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
  test "JOUR-03 seeded escalation progresses via webhook", _context do
    assert {:ok, %{delivery: delivery, run: run}} = DemoHost.Seeds.escalation_waiting!()

    body = Jason.encode!(%{"delivery_id" => delivery.id, "status" => "ok"})

    conn =
      conn(:post, "/webhooks/chimeway/echo", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("signature", "valid")
      |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

    assert conn.status == 200
    assert [%Ingress{} = ingress] = Repo.all(Ingress)
    assert ingress.delivery_id == delivery.id
    assert ingress.normalized_status == "delivered"

    drain_oban!(:chimeway_delivery)
    drain_oban!(:chimeway_signals)

    attempts = Repo.all(DeliveryAttempt)
    assert Enum.any?(attempts, &(&1.outcome == :succeeded))

    signals = Repo.all(Signal)
    assert Enum.any?(signals, &(&1.event_name == "chimeway.delivery.succeeded"))

    updated_run = Repo.get!(WorkflowRun, run.id)
    assert updated_run.state == :active
    assert updated_run.pending_signals == []

    [signal_received_transition] =
      Repo.all(
        from(wt in WorkflowTransition,
          where: wt.workflow_run_id == ^run.id and wt.reason == "signal_received"
        )
      )

    assert signal_received_transition.delivery_id == delivery.id

    {:ok, %{timeline: timeline}} = Traces.explain_delivery(delivery.id)
    event_atoms = Enum.map(timeline, & &1.event)
    assert :webhook_received in event_atoms
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
