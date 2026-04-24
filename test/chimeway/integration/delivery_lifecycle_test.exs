# Test notifiers defined at module level so they are compiled as named modules.
# Each uses a unique notification_key to prevent cross-scenario idempotency collisions.

defmodule ChimewayTest.Notifiers.LifecycleA do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_a"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test A"}}
end

defmodule ChimewayTest.Notifiers.LifecycleB do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_b"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test B"}}
end

defmodule ChimewayTest.Notifiers.LifecycleC do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_c"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test C"}}
end

defmodule ChimewayTest.Notifiers.LifecycleFanout do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_fanout"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test Fanout"}}

  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}
end

defmodule ChimewayTest.Notifiers.LifecycleDelayedFallback do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_delayed_fallback"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test Delayed Fallback"}}

  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}
  def delayed_fallback_channels(_params, _recipient), do: {:ok, [:email]}
end

defmodule ChimewayTest.Notifiers.LifecycleNoDelayedFallback do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_no_delayed_fallback"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test No Delayed Fallback"}}

  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}
end

defmodule Chimeway.Integration.DeliveryLifecycleTest do
  use Chimeway.DataCase, async: false

  @moduletag :integration

  import Ecto.Query

  alias Chimeway.Adapters.Test, as: TestAdapter
  alias Chimeway.{Delivery, DeliveryAttempt, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  # ---- Scenario A — in-app delivery via default (Logger) adapter ----

  describe "Scenario A: trigger → event → notification → delivery → attempt (in-app)" do
    test "all records in the chain are created and have correct state" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleA,
                 %{user_id: 1},
                 idempotency_key: "lifecycle_a_001"
               )

      # Event row
      events =
        Repo.all(
          from(e in Event,
            where:
              e.notification_key == "test.lifecycle_a" and
                e.idempotency_key == "lifecycle_a_001"
          )
        )

      assert length(events) == 1
      [event] = events

      # Notification row
      notifications =
        Repo.all(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:1"
          )
        )

      assert length(notifications) == 1
      [notification] = notifications

      # Delivery row
      deliveries =
        Repo.all(
          from(d in Delivery,
            where: d.notification_id == ^notification.id and d.channel == "in_app"
          )
        )

      assert length(deliveries) == 1
      [delivery] = deliveries
      assert delivery.status == :succeeded

      # Attempt row
      attempts =
        Repo.all(
          from(a in DeliveryAttempt,
            where: a.delivery_id == ^delivery.id
          )
        )

      assert length(attempts) == 1
      [attempt] = attempts
      assert attempt.outcome == :succeeded
    end
  end

  # ---- Scenario B — outbound delivery via Test adapter ----

  describe "Scenario B: Test adapter captures delivery; attempt records provider_response" do
    setup do
      original = Application.get_env(:chimeway, :adapter)
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      TestAdapter.clear()

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:chimeway, :adapter)
          mod -> Application.put_env(:chimeway, :adapter, mod)
        end

        TestAdapter.clear()
      end)

      :ok
    end

    test "delivery and attempt rows exist; assert_delivered passes; provider_response is non-nil" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleB,
                 %{user_id: 2},
                 idempotency_key: "lifecycle_b_001"
               )

      # Get notification
      [notification] =
        Repo.all(
          from(n in Notification,
            join: e in Event,
            on: n.event_id == e.id,
            where:
              e.notification_key == "test.lifecycle_b" and
                n.recipient_identity == "user:2"
          )
        )

      # Delivery row
      [delivery] =
        Repo.all(
          from(d in Delivery,
            where: d.notification_id == ^notification.id
          )
        )

      assert delivery.status == :succeeded

      # Attempt row
      [attempt] =
        Repo.all(
          from(a in DeliveryAttempt,
            where: a.delivery_id == ^delivery.id
          )
        )

      assert attempt.outcome == :succeeded
      assert attempt.provider_response != nil

      # Test adapter captured the delivery
      TestAdapter.assert_delivered(delivery)
    end
  end

  # ---- Scenario C — duplicate trigger is idempotent ----

  describe "Scenario C: duplicate trigger produces single rows in all four tables" do
    test "second trigger returns :duplicate and does not create new rows" do
      # First trigger — persists all rows and dispatches
      assert {:ok, _} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleC,
                 %{user_id: 3},
                 idempotency_key: "lifecycle_c_001"
               )

      # Second trigger — same idempotency_key returns {:duplicate, event}
      assert {:duplicate, _event} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleC,
                 %{user_id: 3},
                 idempotency_key: "lifecycle_c_001"
               )

      # Exactly one event row
      event_count =
        Repo.aggregate(
          from(e in Event, where: e.idempotency_key == "lifecycle_c_001"),
          :count,
          :id
        )

      assert event_count == 1

      # Exactly one notification row for the recipient
      [event] = Repo.all(from(e in Event, where: e.idempotency_key == "lifecycle_c_001"))

      notification_count =
        Repo.aggregate(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:3"
          ),
          :count,
          :id
        )

      assert notification_count == 1

      # Exactly one delivery row per channel per recipient
      [notification] =
        Repo.all(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:3"
          )
        )

      delivery_count =
        Repo.aggregate(
          from(d in Delivery, where: d.notification_id == ^notification.id),
          :count,
          :id
        )

      assert delivery_count == 1

      # Exactly one attempt row (second trigger dispatches nothing)
      [delivery] =
        Repo.all(from(d in Delivery, where: d.notification_id == ^notification.id))

      attempt_count =
        Repo.aggregate(
          from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id),
          :count,
          :id
        )

      assert attempt_count == 1
    end
  end

  # DLVR-01 / INTG-02: outbound fanout remains durable across notification -> delivery -> attempt.
  describe "Scenario D: multi-channel fanout creates durable delivery and attempt records" do
    setup do
      original = Application.get_env(:chimeway, :adapter)
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      TestAdapter.clear()

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:chimeway, :adapter)
          mod -> Application.put_env(:chimeway, :adapter, mod)
        end

        TestAdapter.clear()
      end)

      :ok
    end

    test "one notification fans out to two channel deliveries and attempts for dispatchable channels" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleFanout,
                 %{user_id: 4},
                 idempotency_key: "lifecycle_fanout_001"
               )

      [event] =
        Repo.all(
          from(e in Event,
            where:
              e.notification_key == "test.lifecycle_fanout" and
                e.idempotency_key == "lifecycle_fanout_001"
          )
        )

      notification_count =
        Repo.aggregate(
          from(n in Notification, where: n.event_id == ^event.id and n.recipient_identity == "user:4"),
          :count,
          :id
        )

      assert notification_count == 1

      [notification] =
        Repo.all(
          from(n in Notification, where: n.event_id == ^event.id and n.recipient_identity == "user:4")
        )

      deliveries = Repo.all(from(d in Delivery, where: d.notification_id == ^notification.id))
      assert length(deliveries) == 2
      assert MapSet.new(Enum.map(deliveries, & &1.channel)) == MapSet.new(["email", "in_app"])

      dispatchable_delivery_ids =
        deliveries
        |> Enum.reject(&(&1.status == :suppressed))
        |> Enum.map(& &1.id)
        |> MapSet.new()

      attempts =
        Repo.all(
          from(a in DeliveryAttempt,
            join: d in Delivery,
            on: a.delivery_id == d.id,
            where: d.notification_id == ^notification.id
          )
        )

      assert length(attempts) == MapSet.size(dispatchable_delivery_ids)
      assert MapSet.new(Enum.map(attempts, & &1.delivery_id)) == dispatchable_delivery_ids
      assert Enum.all?(attempts, &(&1.outcome == :succeeded))

      Enum.each(deliveries, &TestAdapter.assert_delivered/1)
    end
  end

  # POLC-03: trigger-driven planner wiring persists delay_fallback semantics and provenance.
  describe "Scenario E: trigger-driven delayed fallback persistence" do
    setup do
      original = Application.get_env(:chimeway, :adapter)
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      TestAdapter.clear()

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:chimeway, :adapter)
          mod -> Application.put_env(:chimeway, :adapter, mod)
        end

        TestAdapter.clear()
      end)

      :ok
    end

    test "planner persists delay_fallback and delayed_fallback_source from notifier callback" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleDelayedFallback,
                 %{user_id: 5},
                 idempotency_key: "lifecycle_delayed_fallback_001"
               )

      [event] =
        Repo.all(
          from(e in Event,
            where:
              e.notification_key == "test.lifecycle_delayed_fallback" and
                e.idempotency_key == "lifecycle_delayed_fallback_001"
          )
        )

      [notification] =
        Repo.all(
          from(n in Notification, where: n.event_id == ^event.id and n.recipient_identity == "user:5")
        )

      deliveries =
        Repo.all(
          from(d in Delivery,
            where: d.notification_id == ^notification.id,
            order_by: [asc: d.channel]
          )
        )

      assert length(deliveries) == 2
      assert MapSet.new(Enum.map(deliveries, & &1.channel)) == MapSet.new(["email", "in_app"])

      deliveries_by_channel =
        deliveries
        |> Map.new(fn delivery -> {delivery.channel, delivery} end)

      email_delivery = Map.fetch!(deliveries_by_channel, "email")
      in_app_delivery = Map.fetch!(deliveries_by_channel, "in_app")

      assert email_delivery.delay_fallback
      assert email_delivery.metadata["delayed_fallback_source"] == "notifier"
      refute in_app_delivery.delay_fallback
      assert in_app_delivery.metadata["delayed_fallback_source"] == "default"
    end

    test "notifier without delayed_fallback callback keeps planned rows at delay_fallback false" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleNoDelayedFallback,
                 %{user_id: 6},
                 idempotency_key: "lifecycle_no_delayed_fallback_001"
               )

      [event] =
        Repo.all(
          from(e in Event,
            where:
              e.notification_key == "test.lifecycle_no_delayed_fallback" and
                e.idempotency_key == "lifecycle_no_delayed_fallback_001"
          )
        )

      [notification] =
        Repo.all(
          from(n in Notification, where: n.event_id == ^event.id and n.recipient_identity == "user:6")
        )

      deliveries = Repo.all(from(d in Delivery, where: d.notification_id == ^notification.id))

      assert length(deliveries) == 2
      assert Enum.all?(deliveries, &(!&1.delay_fallback))
      assert Enum.all?(deliveries, &(&1.metadata["delayed_fallback_source"] == "default"))
    end
  end
end
