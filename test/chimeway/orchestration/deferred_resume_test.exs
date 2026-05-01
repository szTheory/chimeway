defmodule Chimeway.Orchestration.DeferredResumeTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  import Ecto.Query

  alias Chimeway.{
    Deliveries,
    Delivery,
    Dispatch.DeferredResumeWorker,
    Dispatch.ObanWorker,
    Repo,
    Traces
  }

  alias Chimeway.Test.DispatchHelpers

  setup do
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, previous_adapter)
      Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
      Chimeway.Adapters.Test.clear()
    end)

    :ok
  end

  describe "list_due_deferred_deliveries/1 and resume_deferred_delivery/2" do
    test "only one caller can promote a due deferred delivery and later calls no-op" do
      delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.ready-once",
          recipient_identity: "user:deferred-resume-ready-once",
          next_eligible_at: ~U[2026-01-15 13:00:00Z]
        )

      assert [due_delivery] =
               Deliveries.list_due_deferred_deliveries(now: ~U[2026-01-15 13:00:00Z])

      assert due_delivery.id == delivery.id

      assert {:ok, resumed_delivery} =
               Deliveries.resume_deferred_delivery(
                 delivery.id,
                 now: ~U[2026-01-15 13:05:00Z],
                 source: "scheduled_resume"
               )

      assert resumed_delivery.id == delivery.id
      assert resumed_delivery.status == :pending
      assert resumed_delivery.orchestration_state == :ready
      assert resumed_delivery.metadata["resume_source"] == "scheduled_resume"
      assert resumed_delivery.metadata["resume_scheduled_at"] == "2026-01-15T13:00:00.000000Z"
      assert resumed_delivery.metadata["resumed_at"] == "2026-01-15T13:05:00.000000Z"
      assert DateTime.compare(resumed_delivery.updated_at, ~U[2026-01-15 13:05:00Z]) == :eq

      assert {:noop, already_resumed} =
               Deliveries.resume_deferred_delivery(
                 delivery.id,
                 now: ~U[2026-01-15 13:06:00Z],
                 source: "scheduled_resume"
               )

      assert already_resumed.id == delivery.id
      assert already_resumed.orchestration_state == :ready

      assert Repo.aggregate(
               from(d in Delivery, where: d.notification_id == ^delivery.notification_id),
               :count,
               :id
             ) == 1
    end

    test "only due pending deferred rows are listed and resumable" do
      due_delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.due",
          recipient_identity: "user:deferred-resume-due",
          next_eligible_at: ~U[2026-01-15 13:00:00Z]
        )

      future_delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.future",
          recipient_identity: "user:deferred-resume-future",
          next_eligible_at: ~U[2026-01-15 14:00:00Z]
        )

      ready_delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.ready",
          recipient_identity: "user:deferred-resume-ready",
          next_eligible_at: ~U[2026-01-15 12:55:00Z]
        )
        |> then(fn delivery ->
          delivery
          |> Ecto.Changeset.change(orchestration_state: :ready)
          |> Repo.update!()
        end)

      assert Enum.map(
               Deliveries.list_due_deferred_deliveries(now: ~U[2026-01-15 13:00:00Z]),
               & &1.id
             ) == [due_delivery.id]

      assert {:noop, not_due_delivery} =
               Deliveries.resume_deferred_delivery(
                 future_delivery.id,
                 now: ~U[2026-01-15 13:00:00Z],
                 source: "scheduled_resume"
               )

      assert not_due_delivery.id == future_delivery.id
      assert not_due_delivery.orchestration_state == :deferred

      assert {:noop, already_ready_delivery} =
               Deliveries.resume_deferred_delivery(
                 ready_delivery.id,
                 now: ~U[2026-01-15 13:00:00Z],
                 source: "scheduled_resume"
               )

      assert already_ready_delivery.id == ready_delivery.id
      assert already_ready_delivery.orchestration_state == :ready
    end
  end

  describe "cancel_deferred_delivery/3" do
    test "cancelled, suppressed, and superseded rows do not resume" do
      cancelled_delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.cancelled",
          recipient_identity: "user:deferred-resume-cancelled",
          next_eligible_at: ~U[2026-01-15 13:00:00Z]
        )

      suppressed_delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.suppressed",
          recipient_identity: "user:deferred-resume-suppressed",
          next_eligible_at: ~U[2026-01-15 13:00:00Z]
        )
        |> then(fn delivery ->
          delivery
          |> Ecto.Changeset.change(status: :suppressed, suppression_reason: "policy_blocked")
          |> Repo.update!()
        end)

      superseded_delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.superseded",
          recipient_identity: "user:deferred-resume-superseded",
          next_eligible_at: ~U[2026-01-15 13:00:00Z]
        )

      assert {:ok, cancelled_delivery} =
               Deliveries.cancel_deferred_delivery(
                 cancelled_delivery,
                 "resume_cancelled",
                 now: ~U[2026-01-15 12:59:00Z]
               )

      assert cancelled_delivery.status == :cancelled
      assert cancelled_delivery.orchestration_state == :deferred
      assert cancelled_delivery.suppression_reason == "resume_cancelled"
      assert DateTime.compare(cancelled_delivery.updated_at, ~U[2026-01-15 12:59:00Z]) == :eq

      assert {:ok, superseded_delivery} =
               Deliveries.cancel_deferred_delivery(
                 superseded_delivery,
                 "superseded",
                 now: ~U[2026-01-15 12:59:00Z]
               )

      assert superseded_delivery.status == :cancelled
      assert superseded_delivery.suppression_reason == "superseded"
      assert DateTime.compare(superseded_delivery.updated_at, ~U[2026-01-15 12:59:00Z]) == :eq

      assert {:noop, cancelled_delivery} =
               Deliveries.resume_deferred_delivery(
                 cancelled_delivery.id,
                 now: ~U[2026-01-15 13:01:00Z],
                 source: "scheduled_resume"
               )

      assert cancelled_delivery.status == :cancelled

      assert {:noop, suppressed_delivery} =
               Deliveries.resume_deferred_delivery(
                 suppressed_delivery.id,
                 now: ~U[2026-01-15 13:01:00Z],
                 source: "scheduled_resume"
               )

      assert suppressed_delivery.status == :suppressed

      assert {:noop, superseded_delivery} =
               Deliveries.resume_deferred_delivery(
                 superseded_delivery.id,
                 now: ~U[2026-01-15 13:01:00Z],
                 source: "scheduled_resume"
               )

      assert superseded_delivery.status == :cancelled
      assert superseded_delivery.suppression_reason == "superseded"
      assert suppressed_delivery.suppression_reason != "superseded"
    end

    test "superseded deferred rows stay explainable as one converged history with zero attempts" do
      delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.superseded-trace",
          recipient_identity: "user:deferred-resume-superseded-trace",
          next_eligible_at: ~U[2026-01-15 13:00:00Z]
        )

      assert {:ok, cancelled_delivery} =
               Deliveries.cancel_deferred_delivery(
                 delivery,
                 "superseded",
                 now: ~U[2026-01-15 12:59:00Z]
               )

      assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: cancelled_delivery.id})

      assert {:ok, explanation} = Traces.explain_delivery(cancelled_delivery.id)
      assert explanation.status == :cancelled
      assert explanation.suppression_reason == "superseded"
      assert explanation.last_attempt == nil

      assert Repo.aggregate(
               from(d in Delivery,
                 where: d.notification_id == ^cancelled_delivery.notification_id
               ),
               :count,
               :id
             ) == 1

      assert Repo.aggregate(
               from(a in assoc(cancelled_delivery, :attempts)),
               :count,
               :id
             ) == 0

      assert Enum.map(explanation.timeline, & &1.event) == [
               :event_created,
               :notification_created,
               :delivery_planned,
               :deferred,
               :cancelled
             ]

      [%{at: cancelled_at}] = Enum.filter(explanation.timeline, &(&1.event == :cancelled))
      assert DateTime.compare(cancelled_at, ~U[2026-01-15 12:59:00Z]) == :eq
    end
  end

  describe "DeferredResumeWorker" do
    test "promotes a deferred row and enqueues exactly one canonical dispatch worker" do
      delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.worker.promotes-once",
          recipient_identity: "user:deferred-resume-worker-promotes-once",
          next_eligible_at: ~U[2026-01-15 13:00:00Z]
        )

      refute_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})

      assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: delivery.id})

      resumed = Deliveries.get_delivery!(delivery.id)
      assert resumed.orchestration_state == :ready
      assert resumed.status == :pending
      assert resumed.metadata["resume_source"] == "oban_scheduler"

      assert_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})
      assert length(all_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})) == 1

      assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: delivery.id})

      assert length(all_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})) == 1
      refute_enqueued(worker: ObanWorker, args: %{delivery_id: "#{delivery.id}-other"})
    end

    test "duplicate scheduled resume jobs and terminal rows no-op safely" do
      ready_delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.worker.already-ready",
          recipient_identity: "user:deferred-resume-worker-already-ready",
          next_eligible_at: ~U[2026-01-15 13:00:00Z]
        )
        |> then(fn delivery ->
          delivery
          |> Ecto.Changeset.change(orchestration_state: :ready)
          |> Repo.update!()
        end)

      cancelled_delivery =
        deferred_delivery_fixture(
          notification_key: "deferred-resume.worker.cancelled",
          recipient_identity: "user:deferred-resume-worker-cancelled",
          next_eligible_at: ~U[2026-01-15 13:00:00Z]
        )
        |> then(fn delivery ->
          delivery
          |> Ecto.Changeset.change(status: :cancelled, suppression_reason: "superseded")
          |> Repo.update!()
        end)

      assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: ready_delivery.id})
      assert :ok = perform_job(DeferredResumeWorker, %{delivery_id: cancelled_delivery.id})

      refute_enqueued(worker: ObanWorker, args: %{delivery_id: ready_delivery.id})
      refute_enqueued(worker: ObanWorker, args: %{delivery_id: cancelled_delivery.id})
    end
  end

  defp deferred_delivery_fixture(attrs) do
    fixture =
      DispatchHelpers.create_notification(
        notification_key: Keyword.fetch!(attrs, :notification_key),
        recipient_identity: Keyword.fetch!(attrs, :recipient_identity)
      )

    {:ok, delivery} = Deliveries.plan_delivery(fixture.notification.id, :email, tenant_id: "default", actor_id: "system")

    {:ok, delivery} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :deferred,
        planning_reason: "quiet_hours",
        planning_context: %{"rule" => "quiet_hours"},
        next_eligible_at: Keyword.fetch!(attrs, :next_eligible_at)
      })

    delivery
  end
end
