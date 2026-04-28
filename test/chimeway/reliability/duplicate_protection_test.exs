defmodule Chimeway.Reliability.DuplicateProtectionTest.IdempotentNotifier do
  @moduledoc false
  @behaviour Chimeway.Notifier

  @impl true
  def notification_key, do: "comment.created"

  @impl true
  def version, do: 1

  @impl true
  def recipients(_params),
    do: {:ok, [%{recipient_identity: "user-1", recipient_type: "member"}]}

  @impl true
  def build(_params, _recipient), do: {:ok, %{"topic" => "mentions"}}
end

defmodule Chimeway.Reliability.DuplicateProtectionTest do
  @moduledoc """
  REL-01 D-02 / D-03 / D-14 — duplicate protection contract tests.

  Asserts that Phase 14 preserves Phase 1/12 dedup guarantees:
  - Trigger.trigger returns {:duplicate, event} on re-fire (serial + concurrent).
  - Trigger.dispatch_after_trigger/4 is INERT on {:duplicate, event} (D-03):
    no Oban jobs enqueued, no deliveries planned.
  - DeliveryPlanning.plan_notifications/2 is idempotent on re-entry.
  - Sync and Oban dispatch short-circuit on already-terminal deliveries.
  - Phase 12 transactional rollback still applies on enqueue failure (mirrors
    oban_transactional_test.exs:44-73 — failing_multi wraps the real
    Chimeway.Dispatch.Oban.dispatch/2 seam).
  """

  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban

  import Chimeway.Test.DispatchHelpers
  import Ecto.Query, only: [from: 2]

  alias Chimeway.{Deliveries, DeliveryAttempt, DeliveryPlanning, Repo, Trigger}
  alias Chimeway.Delivery
  alias Chimeway.Dispatch.{Oban, ObanWorker, Sync}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Reliability.DuplicateProtectionTest.IdempotentNotifier

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    end)

    :ok
  end

  # ----- D-02a: serial re-fire returns {:duplicate, event} -----

  describe "Trigger.trigger/{:duplicate, event} contract (D-02a)" do
    test "serial re-fire returns {:duplicate, event} and preserves a single canonical event row" do
      assert {:ok, first} =
               Trigger.trigger(
                 IdempotentNotifier,
                 %{"body" => "hello"},
                 idempotency_key: "rel01-d02a-serial"
               )

      assert {:duplicate, existing_event} =
               Trigger.trigger(
                 IdempotentNotifier,
                 %{"body" => "hello"},
                 idempotency_key: "rel01-d02a-serial"
               )

      assert existing_event.id == first.event.id

      assert Repo.aggregate(
               from(e in Event, where: e.idempotency_key == "rel01-d02a-serial"),
               :count,
               :id
             ) == 1

      assert Repo.aggregate(
               from(n in Notification, where: n.event_id == ^first.event.id),
               :count,
               :id
             ) == 1
    end
  end

  # ----- D-03: dispatch_after_trigger/4 is INERT on {:duplicate, event} -----
  # Two tests, one per dispatcher path (Sync default + explicit Oban override).

  describe "dispatch_after_trigger/4 inert on {:duplicate, event} (D-03)" do
    test "duplicate trigger does NOT plan additional deliveries (Sync dispatcher path)" do
      assert {:ok, first_result} =
               Trigger.trigger(
                 IdempotentNotifier,
                 %{"body" => "hello"},
                 idempotency_key: "rel01-d03-inert-sync"
               )

      first_delivery_count =
        Repo.aggregate(
          from(d in Delivery,
            join: n in Notification,
            on: d.notification_id == n.id,
            where: n.event_id == ^first_result.event.id
          ),
          :count,
          :id
        )

      assert {:duplicate, _existing_event} =
               Trigger.trigger(
                 IdempotentNotifier,
                 %{"body" => "hello"},
                 idempotency_key: "rel01-d03-inert-sync"
               )

      after_delivery_count =
        Repo.aggregate(
          from(d in Delivery,
            join: n in Notification,
            on: d.notification_id == n.id,
            where: n.event_id == ^first_result.event.id
          ),
          :count,
          :id
        )

      assert after_delivery_count == first_delivery_count,
             "duplicate trigger added deliveries; D-03 contract violated (after=#{after_delivery_count}, before=#{first_delivery_count})"
    end

    test "duplicate trigger does NOT enqueue Oban jobs (Oban dispatcher path)" do
      previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
      Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)

      on_exit(fn ->
        Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
      end)

      assert {:ok, _first_result} =
               Trigger.trigger(
                 IdempotentNotifier,
                 %{"body" => "hello"},
                 idempotency_key: "rel01-d03-inert-oban"
               )

      # Drain any enqueued jobs from the first trigger so the assertion below
      # observes only NEW (post-duplicate) inserts.
      _ = Repo.delete_all(Elixir.Oban.Job)

      assert {:duplicate, _existing_event} =
               Trigger.trigger(
                 IdempotentNotifier,
                 %{"body" => "hello"},
                 idempotency_key: "rel01-d03-inert-oban"
               )

      refute_enqueued(worker: ObanWorker)
    end
  end

  # ----- D-02b: plan_notifications/2 re-entry -----

  describe "plan_notifications/2 re-entry (D-02b)" do
    test "double-call for same event creates exactly one delivery per channel" do
      ctx = create_notification()

      assert {:ok, [delivery_a]} = DeliveryPlanning.plan_notifications([ctx.notification], [])
      assert {:ok, [delivery_b]} = DeliveryPlanning.plan_notifications([ctx.notification], [])

      assert delivery_a.id == delivery_b.id

      delivery_count =
        Repo.aggregate(
          from(d in Delivery, where: d.notification_id == ^ctx.notification.id),
          :count,
          :id
        )

      assert delivery_count == 1
    end
  end

  # ----- D-02c: sync + Oban dispatch short-circuit on already-terminal delivery -----

  describe "dispatch short-circuit on terminal delivery (D-02c)" do
    test "sync dispatch on already-terminal delivery records no new attempts" do
      ctx = create_notification()

      assert {:ok, [{:ok, delivery}]} = Sync.dispatch([ctx.notification], [])
      assert delivery.status == :succeeded
      assert delivery.status in Deliveries.terminal_states()

      attempt_count_before =
        Repo.aggregate(
          from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id),
          :count,
          :id
        )

      assert {:ok, [{:ok, returned}]} = Sync.dispatch([ctx.notification], [])
      assert returned.status == delivery.status

      attempt_count_after =
        Repo.aggregate(
          from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id),
          :count,
          :id
        )

      assert attempt_count_after == attempt_count_before
    end

    test "Oban dispatch on already-terminal delivery records no new attempts" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, _cancelled} = Deliveries.transition_status(delivery, :cancelled)
      assert Deliveries.get_delivery!(delivery.id).status in Deliveries.terminal_states()

      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []

      attempt_count =
        Repo.aggregate(
          from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id),
          :count,
          :id
        )

      assert attempt_count == 0
    end
  end

  # ----- D-02d: Phase 12 atomicity preserved (D-15 regression) -----
  # MIRRORS test/chimeway/dispatch/oban_transactional_test.exs:44-73 — the failing_multi
  # is passed to the actual Chimeway.Dispatch.Oban.dispatch/2 seam (the same seam Phase 12
  # protected). This is W2's required pattern.

  describe "Phase 12 atomicity preserved (D-02d)" do
    test "failing_multi passed to Chimeway.Dispatch.Oban.dispatch/2 rolls back planning rows" do
      ctx = create_notification()

      failing_multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:fail, fn _repo, _changes -> {:error, :forced_failure} end)

      assert {:error, :forced_failure} = Oban.dispatch([ctx.notification], multi: failing_multi)

      delivery_count =
        Repo.aggregate(
          from(d in Delivery, where: d.notification_id == ^ctx.notification.id),
          :count,
          :id
        )

      assert delivery_count == 0
      refute_enqueued(worker: ObanWorker)
    end
  end

  # ----- D-14a: concurrent re-fires of same trigger -----

  describe "concurrent re-fires of same trigger (D-14a)" do
    test "10 concurrent triggers with same idempotency_key produce one canonical event row" do
      parent = self()

      results =
        1..10
        |> Task.async_stream(
          fn _attempt ->
            Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

            Trigger.trigger(
              IdempotentNotifier,
              %{"body" => "hello"},
              idempotency_key: "rel01-d14a-concurrent"
            )
          end,
          ordered: false,
          max_concurrency: 10,
          timeout: 15_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.count(results, &match?({:ok, _payload}, &1)) == 1
      assert Enum.count(results, &match?({:duplicate, %Event{}}, &1)) == 9

      assert Repo.aggregate(
               from(e in Event, where: e.idempotency_key == "rel01-d14a-concurrent"),
               :count,
               :id
             ) == 1

      event =
        Repo.one!(from(e in Event, where: e.idempotency_key == "rel01-d14a-concurrent", limit: 1))

      assert Repo.aggregate(
               from(n in Notification, where: n.event_id == ^event.id),
               :count,
               :id
             ) == 1
    end
  end

  # ----- D-14b: concurrent plan_notifications/2 for same event -----

  describe "concurrent plan_notifications/2 (D-14b)" do
    test "concurrent planning for the same event produces no duplicate deliveries" do
      ctx = create_notification()
      parent = self()

      results =
        1..10
        |> Task.async_stream(
          fn _attempt ->
            Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
            DeliveryPlanning.plan_notifications([ctx.notification], [])
          end,
          ordered: false,
          max_concurrency: 10,
          timeout: 15_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, &match?({:ok, [%Delivery{}]}, &1))

      delivery_count =
        Repo.aggregate(
          from(d in Delivery, where: d.notification_id == ^ctx.notification.id),
          :count,
          :id
        )

      assert delivery_count == 1
    end
  end

  # ----- D-14c: concurrent dispatch re-entry against terminal delivery -----

  describe "concurrent dispatch re-entry against terminal delivery (D-14c)" do
    test "10 concurrent perform_job calls on a :cancelled delivery record no extra attempts" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, _cancelled} = Deliveries.transition_status(delivery, :cancelled)
      assert Deliveries.get_delivery!(delivery.id).status in Deliveries.terminal_states()

      Chimeway.Adapters.Test.clear()
      parent = self()

      results =
        1..10
        |> Task.async_stream(
          fn _attempt ->
            Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
            perform_job(ObanWorker, %{delivery_id: delivery.id})
          end,
          ordered: false,
          max_concurrency: 10,
          timeout: 15_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, &(&1 == :ok))
      assert Chimeway.Adapters.Test.delivered_messages() == []

      attempt_count =
        Repo.aggregate(
          from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id),
          :count,
          :id
        )

      assert attempt_count == 0
    end
  end
end
