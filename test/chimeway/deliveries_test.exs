defmodule Chimeway.DeliveriesTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Deliveries, Delivery, DeliveryAttempt, Repo}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  # ---- Fixtures ----

  defp insert_notification(_ctx \\ %{}) do
    {:ok, event} =
      %Event{}
      |> Event.changeset(%{
        notification_key: "test.notification",
        notification_version: 1,
        idempotency_key: "test-#{System.unique_integer()}",
        payload: %{}
      })
      |> Repo.insert()

    {:ok, notification} =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: "user-1",
        recipient_type: "user",
        metadata: %{}
      })
      |> Repo.insert()

    %{notification: notification}
  end

  # ---- plan_delivery/2 ----

  describe "plan_delivery/2" do
    test "creates a delivery row with status :pending" do
      %{notification: notification} = insert_notification()

      assert {:ok, %Delivery{} = delivery} =
               Deliveries.plan_delivery(notification.id, :in_app)

      assert delivery.channel == "in_app"
      assert delivery.status == :pending
      assert delivery.notification_id == notification.id
    end

    test "is idempotent: duplicate calls create exactly one row" do
      %{notification: notification} = insert_notification()

      assert {:ok, _} = Deliveries.plan_delivery(notification.id, :in_app)
      assert {:ok, _} = Deliveries.plan_delivery(notification.id, :in_app)

      count = Repo.aggregate(Delivery, :count, :id)
      assert count == 1
    end

    test "accepts channel as string" do
      %{notification: notification} = insert_notification()

      assert {:ok, %Delivery{channel: "email"}} =
               Deliveries.plan_delivery(notification.id, "email")
    end

    test "allows different channels for same notification" do
      %{notification: notification} = insert_notification()

      assert {:ok, _} = Deliveries.plan_delivery(notification.id, :in_app)
      assert {:ok, _} = Deliveries.plan_delivery(notification.id, :email)

      count = Repo.aggregate(Delivery, :count, :id)
      assert count == 2
    end
  end

  # ---- get_delivery!/1 ----

  describe "get_delivery!/1" do
    test "fetches delivery by id" do
      %{notification: notification} = insert_notification()
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)

      fetched = Deliveries.get_delivery!(delivery.id)
      assert fetched.id == delivery.id
    end

    test "raises if not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Deliveries.get_delivery!(Ecto.UUID.generate())
      end
    end
  end

  # ---- transition_status/2 ----

  describe "transition_status/2" do
    setup :insert_notification

    test "transitions pending → dispatched", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      assert {:ok, updated} = Deliveries.transition_status(delivery, :dispatched)
      assert updated.status == :dispatched
    end

    test "transitions pending → suppressed", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      assert {:ok, updated} = Deliveries.transition_status(delivery, :suppressed)
      assert updated.status == :suppressed
    end

    test "transitions pending → cancelled", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      assert {:ok, updated} = Deliveries.transition_status(delivery, :cancelled)
      assert updated.status == :cancelled
    end

    test "transitions dispatched → succeeded", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      assert {:ok, updated} = Deliveries.transition_status(dispatched, :succeeded)
      assert updated.status == :succeeded
    end

    test "transitions dispatched → failed", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      assert {:ok, updated} = Deliveries.transition_status(dispatched, :failed)
      assert updated.status == :failed
    end

    test "transitions failed → dispatched (retry)", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, failed} = Deliveries.transition_status(dispatched, :failed)
      assert {:ok, updated} = Deliveries.transition_status(failed, :dispatched)
      assert updated.status == :dispatched
    end

    test "rejects invalid transition: pending → succeeded", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)

      assert {:error, {:invalid_transition, from: :pending, to: :succeeded}} =
               Deliveries.transition_status(delivery, :succeeded)
    end

    test "rejects invalid transition: succeeded → dispatched", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, succeeded} = Deliveries.transition_status(dispatched, :succeeded)

      assert {:error, {:invalid_transition, from: :succeeded, to: :dispatched}} =
               Deliveries.transition_status(succeeded, :dispatched)
    end

    test "rejects general-path failed → cancelled (reserved for exhaust_delivery/1)", %{
      notification: notification
    } do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, failed} = Deliveries.transition_status(dispatched, :failed)

      assert {:error, {:invalid_transition, from: :failed, to: :cancelled}} =
               Deliveries.transition_status(failed, :cancelled)
    end
  end

  # ---- terminal_states/0 ----

  describe "terminal_states/0" do
    test "returns the canonical terminal-state list" do
      assert Deliveries.terminal_states() == [:succeeded, :suppressed, :cancelled]
    end
  end

  # ---- exhaust_delivery/1 ----

  describe "exhaust_delivery/1" do
    setup :insert_notification

    test "transitions :failed → :cancelled with retries_exhausted suppression_reason", %{
      notification: notification
    } do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, failed} = Deliveries.transition_status(dispatched, :failed)

      assert {:ok, exhausted} = Deliveries.exhaust_delivery(failed)
      assert exhausted.status == :cancelled
      assert exhausted.suppression_reason == "retries_exhausted"
    end

    test "records policy_checkpoint=\"perform\" in metadata", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, failed} = Deliveries.transition_status(dispatched, :failed)

      {:ok, exhausted} = Deliveries.exhaust_delivery(failed)
      assert exhausted.metadata["policy_checkpoint"] == "perform"
    end

    test "rejects exhaust from :pending", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)

      assert {:error, {:invalid_exhaust_from, :pending}} =
               Deliveries.exhaust_delivery(delivery)
    end

    test "rejects exhaust from :succeeded", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, succeeded} = Deliveries.transition_status(dispatched, :succeeded)

      assert {:error, {:invalid_exhaust_from, :succeeded}} =
               Deliveries.exhaust_delivery(succeeded)
    end

    test "rejects exhaust from :dispatched", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:error, {:invalid_exhaust_from, :dispatched}} =
               Deliveries.exhaust_delivery(dispatched)
    end

    test "preserves prior metadata keys (Phase 10 correlation_id/event_id)", %{
      notification: notification
    } do
      {:ok, delivery} =
        Deliveries.plan_delivery(notification.id, :in_app,
          correlation_id: "corr-123",
          event_id: "evt-456",
          notification_key: "test.notification"
        )

      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      {:ok, failed} = Deliveries.transition_status(dispatched, :failed)

      {:ok, exhausted} = Deliveries.exhaust_delivery(failed)
      assert exhausted.metadata["correlation_id"] == "corr-123"
      assert exhausted.metadata["event_id"] == "evt-456"
      assert exhausted.metadata["notification_key"] == "test.notification"
      assert exhausted.metadata["policy_checkpoint"] == "perform"
    end
  end

  # ---- record_attempt/2 ----

  describe "record_attempt/2" do
    setup :insert_notification

    test "atomically creates attempt row and updates delivery status to :succeeded", %{
      notification: notification
    } do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:ok, %{delivery: updated_delivery, attempt: attempt}} =
               Deliveries.record_attempt(dispatched, %{outcome: :succeeded})

      assert updated_delivery.status == :succeeded
      assert attempt.outcome == :succeeded
      assert attempt.delivery_id == dispatched.id

      # Verify attempt row exists in DB
      assert Repo.get(DeliveryAttempt, attempt.id) != nil
    end

    test "atomically creates attempt row and updates delivery status to :failed", %{
      notification: notification
    } do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:ok, %{delivery: updated_delivery, attempt: attempt}} =
               Deliveries.record_attempt(dispatched, %{outcome: :failed})

      assert updated_delivery.status == :failed
      assert attempt.outcome == :failed
    end

    test "rolls back attempt insert if status transition fails", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)

      # Attempt to record from :pending status with outcome :succeeded;
      # transition pending → succeeded is invalid, forcing a rollback.
      result = Deliveries.record_attempt(delivery, %{outcome: :succeeded})

      assert {:error, :delivery, {:invalid_transition, from: :pending, to: :succeeded}, _} =
               result

      # No attempt row should have been persisted
      assert Repo.aggregate(DeliveryAttempt, :count, :id) == 0
    end

    test "stores provider_response in attempt row", %{notification: notification} do
      {:ok, delivery} = Deliveries.plan_delivery(notification.id, :in_app)
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      {:ok, %{attempt: attempt}} =
        Deliveries.record_attempt(dispatched, %{
          outcome: :succeeded,
          provider_response: %{"message_id" => "abc123"}
        })

      assert attempt.provider_response == %{"message_id" => "abc123"}
    end
  end
end
