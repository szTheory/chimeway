defmodule Chimeway.Webhooks.ProcessFeedbackWorkerTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Webhooks.ProcessFeedbackWorker
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  setup do
    event = insert_event("test.webhook")
    notification = insert_notification(event, "user-webhook")
    
    assert {:ok, delivery} = Deliveries.plan_delivery(notification.id, "email", status: :pending)

    %{delivery: delivery}
  end

  defp insert_event(notification_key) do
    {:ok, event} =
      %Event{}
      |> Event.changeset(%{
        notification_key: notification_key,
        notification_version: 1,
        idempotency_key: "webhook-test-#{System.unique_integer([:positive])}",
        payload: %{}
      })
      |> Repo.insert()

    event
  end

  defp insert_notification(event, recipient_identity) do
    {:ok, notification} =
      %Notification{}
      |> Notification.changeset(%{
        event_id: event.id,
        recipient_identity: recipient_identity,
        recipient_type: "user",
        metadata: %{}
      })
      |> Repo.insert()

    notification
  end

  describe "perform/1" do
    test "processes feedback for a given delivery_id", %{delivery: delivery} do
      payload = %{"some" => "data"}

      args = %{
        "delivery_id" => delivery.id,
        "status" => "bounced",
        "provider_response" => payload,
        "adapter_module" => "SomeAdapter"
      }

      assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: args})

      # Verify the attempt was recorded
      updated_delivery = Deliveries.get_delivery!(delivery.id)
      assert updated_delivery.status == :cancelled
      assert updated_delivery.suppression_reason == "bounced"

      attempts = Chimeway.Repo.all(Chimeway.DeliveryAttempt)
      assert length(attempts) == 1
      attempt = hd(attempts)
      assert attempt.outcome == :bounced
      assert attempt.error_class == "bounced"
      assert attempt.provider_response == payload
      assert attempt.adapter_module == "SomeAdapter"
    end

    test "processes feedback for a given provider_message_id", %{delivery: delivery} do
      payload = %{"some" => "data"}

      delivery = Ecto.Changeset.change(delivery, status: :dispatched) |> Chimeway.Repo.update!()

      # Insert an initial attempt with a provider_message_id
      {:ok, _} = Deliveries.record_attempt(delivery, %{
        outcome: :succeeded,
        adapter_module: "InitialAdapter",
        provider_message_id: "msg_12345"
      })

      args = %{
        "provider_message_id" => "msg_12345",
        "status" => "delivered",
        "provider_response" => payload,
        "adapter_module" => "FeedbackAdapter"
      }

      assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: args})

      updated_delivery = Deliveries.get_delivery!(delivery.id)
      assert updated_delivery.status == :succeeded

      attempts = Chimeway.Repo.all(Chimeway.DeliveryAttempt)
      assert length(attempts) == 2
      attempt = Enum.at(attempts, 1)
      assert attempt.outcome == :succeeded
      assert attempt.error_class == nil
      assert attempt.provider_response == payload
      assert attempt.adapter_module == "FeedbackAdapter"
    end

    test "returns error if delivery cannot be found by delivery_id" do
      args = %{
        "delivery_id" => Ecto.UUID.generate(),
        "status" => "delivered",
        "provider_response" => %{}
      }

      assert_raise Ecto.NoResultsError, fn ->
        ProcessFeedbackWorker.perform(%Oban.Job{args: args})
      end
    end

    test "returns error if delivery cannot be found by provider_message_id" do
      args = %{
        "provider_message_id" => "unknown_msg",
        "status" => "delivered",
        "provider_response" => %{}
      }

      assert {:error, :not_found} = ProcessFeedbackWorker.perform(%Oban.Job{args: args})
    end
  end
end
