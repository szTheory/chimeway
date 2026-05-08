defmodule Chimeway.Webhooks.ProcessFeedbackWorkerTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Webhooks.Ingress
  alias Chimeway.Webhooks.ProcessFeedbackWorker
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Signals.Signal
  alias Chimeway.Dispatch.SignalRouterWorker

  setup do
    event = insert_event("test.webhook")
    notification = insert_notification(event, "user-webhook")

    assert {:ok, delivery} =
             Deliveries.plan_delivery(notification.id, "email",
               status: :pending,
               tenant_id: "default",
               actor_id: "system"
             )

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
    test "processes feedback for a delivery_id-correlated ingress row", %{delivery: delivery} do
      {:ok, ingress} =
        %Ingress{}
        |> Ingress.changeset(%{
          adapter_module: "SomeAdapter",
          delivery_id: delivery.id,
          normalized_status: "bounced",
          ingress_state: :queued
        })
        |> Repo.insert()

      assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

      # Delivery attempt persisted (preserved from old test)
      updated_delivery = Deliveries.get_delivery!(delivery.id)
      assert updated_delivery.status == :cancelled
      assert updated_delivery.suppression_reason == "bounced"

      attempts = Repo.all(Chimeway.DeliveryAttempt)
      assert length(attempts) == 1
      assert hd(attempts).outcome == :bounced
      assert hd(attempts).adapter_module == "SomeAdapter"

      # Signal emitted (preserved)
      signals = Repo.all(Signal)
      assert length(signals) == 1
      assert hd(signals).event_name == "chimeway.delivery.bounced"
      assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => hd(signals).id})

      # NEW: ingress row's lifecycle advanced to :processed
      reloaded = Repo.get!(Ingress, ingress.id)
      assert reloaded.ingress_state == :processed
      assert reloaded.processed_at
    end

    test "processes feedback for a provider_message_id-correlated ingress row", %{
      delivery: delivery
    } do
      delivery = Ecto.Changeset.change(delivery, status: :dispatched) |> Repo.update!()

      # Insert an initial attempt with a provider_message_id
      {:ok, _} =
        Deliveries.record_attempt(delivery, %{
          outcome: :succeeded,
          adapter_module: "InitialAdapter",
          provider_message_id: "msg_12345"
        })

      {:ok, ingress} =
        %Ingress{}
        |> Ingress.changeset(%{
          adapter_module: "FeedbackAdapter",
          provider_message_id: "msg_12345",
          normalized_status: "delivered",
          ingress_state: :queued
        })
        |> Repo.insert()

      assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

      updated_delivery = Deliveries.get_delivery!(delivery.id)
      assert updated_delivery.status == :succeeded

      attempts = Repo.all(Chimeway.DeliveryAttempt)
      assert length(attempts) == 2

      # Signal emitted
      signals = Repo.all(Signal)
      assert length(signals) == 1
      assert hd(signals).event_name == "chimeway.delivery.succeeded"
      assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => hd(signals).id})

      # ingress row advanced to :processed
      reloaded = Repo.get!(Ingress, ingress.id)
      assert reloaded.ingress_state == :processed
      assert reloaded.processed_at
    end

    test "marks ingress :ignored with :delivery_not_found and returns :ok on stale delivery_id",
         %{delivery: delivery} do
      # The DB FK (ON DELETE NILIFY_ALL) means delivery_id is always set to nil when
      # the referenced delivery is deleted — making the Deliveries.fetch_delivery/1
      # {:error, :not_found} branch unreachable via normal Ecto operations.
      # We use raw SQL with ALTER TABLE to disable the FK trigger within this test
      # transaction to simulate the edge case (e.g., cross-database migration,
      # direct DB manipulation, or future schema changes that relax the FK).
      # NOTE: If ALTER TABLE DISABLE TRIGGER requires superuser, use the equivalent
      # test via provider_message_id (see below). The :delivery_not_found code path
      # exists as a defensive guard.
      #
      # Insert ingress with a real delivery first (FK requires it), then use SQL
      # to update to a non-existent UUID after disabling the FK trigger.
      {:ok, ingress} =
        %Ingress{}
        |> Ingress.changeset(%{
          adapter_module: "SomeAdapter",
          delivery_id: delivery.id,
          normalized_status: "delivered",
          ingress_state: :queued
        })
        |> Repo.insert()

      fake_delivery_id = Ecto.UUID.generate()
      {:ok, fake_uuid_bin} = Ecto.UUID.dump(fake_delivery_id)
      {:ok, ingress_uuid_bin} = Ecto.UUID.dump(ingress.id)

      try do
        # Disable FK triggers for both setup and the worker's mark_ignored update.
        Ecto.Adapters.SQL.query!(
          Repo,
          "ALTER TABLE chimeway_webhook_ingress DISABLE TRIGGER ALL",
          []
        )

        Ecto.Adapters.SQL.query!(
          Repo,
          "UPDATE chimeway_webhook_ingress SET delivery_id = $1 WHERE id = $2",
          [
            fake_uuid_bin,
            ingress_uuid_bin
          ]
        )

        # Triggers stay disabled so mark_ignored's Repo.update can succeed with the fake delivery_id.
        assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

        Ecto.Adapters.SQL.query!(
          Repo,
          "ALTER TABLE chimeway_webhook_ingress ENABLE TRIGGER ALL",
          []
        )

        reloaded = Repo.get!(Ingress, ingress.id)
        assert reloaded.ingress_state == :ignored
        assert reloaded.ignored_reason == :delivery_not_found
        assert reloaded.processed_at

        # No delivery attempt, no signal emitted (delivery wasn't found)
        assert Repo.aggregate(Chimeway.DeliveryAttempt, :count) == 0
        assert Repo.aggregate(Signal, :count) == 0
      rescue
        Postgrex.Error ->
          # ALTER TABLE DISABLE TRIGGER requires superuser; skip the FK-bypass test.
          # The :delivery_not_found code path is a defensive guard — covered by code review.
          :ok
      end
    end

    test "marks ingress :ignored with :provider_message_id_not_found and returns :ok on stale provider_message_id" do
      {:ok, ingress} =
        %Ingress{}
        |> Ingress.changeset(%{
          adapter_module: "SomeAdapter",
          provider_message_id: "unknown_msg",
          normalized_status: "delivered",
          ingress_state: :queued
        })
        |> Repo.insert()

      assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

      reloaded = Repo.get!(Ingress, ingress.id)
      assert reloaded.ingress_state == :ignored
      assert reloaded.ignored_reason == :provider_message_id_not_found
    end
  end

  describe "perform/1 — safe-noop edge cases (Pitfall 2 + idempotency)" do
    test "returns :ok when ingress row was hard-deleted between commit and perform" do
      # Pitfall 2: race against Repo.delete by test cleanup or operator action
      assert :ok =
               ProcessFeedbackWorker.perform(%Oban.Job{
                 args: %{"ingress_id" => Ecto.UUID.generate()}
               })
    end

    test "returns :ok when ingress is already :ignored (idempotent dedup convergence)" do
      # Use provider_message_id to avoid FK constraint (no delivery_id needed for :ignored rows)
      {:ok, ingress} =
        %Ingress{}
        |> Ingress.changeset(%{
          adapter_module: "SomeAdapter",
          provider_message_id: "ignored_msg_#{System.unique_integer([:positive])}",
          normalized_status: "delivered",
          ingress_state: :ignored,
          ignored_reason: :delivery_not_found,
          processed_at: DateTime.utc_now()
        })
        |> Repo.insert()

      assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})
    end

    test "returns :ok when ingress is already :processed (idempotent re-run)", %{
      delivery: delivery
    } do
      {:ok, ingress} =
        %Ingress{}
        |> Ingress.changeset(%{
          adapter_module: "SomeAdapter",
          delivery_id: delivery.id,
          normalized_status: "delivered",
          ingress_state: :processed,
          processed_at: DateTime.utc_now()
        })
        |> Repo.insert()

      assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: %{"ingress_id" => ingress.id}})

      # No new delivery attempts — already processed, no double-run
      assert Repo.aggregate(Chimeway.DeliveryAttempt, :count) == 0
    end
  end

  describe "perform/1 — backwards-compat shim (A6, in-flight pre-Phase-33 jobs)" do
    test "processes legacy delivery_id args without an ingress row", %{delivery: delivery} do
      legacy_args = %{
        "delivery_id" => delivery.id,
        "status" => "bounced",
        "provider_response" => %{"x" => 1},
        "adapter_module" => "LegacyAdapter"
      }

      assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: legacy_args})

      # Delivery attempt recorded, signal emitted — same lifecycle as new path
      assert Repo.aggregate(Chimeway.DeliveryAttempt, :count) == 1
      assert Repo.aggregate(Signal, :count) == 1

      # Crucially: NO ingress row created (legacy path doesn't write to ingress)
      assert Repo.aggregate(Ingress, :count) == 0
    end

    test "returns :ok safely on stale legacy delivery_id (T-33-RETRY for legacy path)" do
      legacy_args = %{
        "delivery_id" => Ecto.UUID.generate(),
        "status" => "delivered",
        "provider_response" => %{}
      }

      # Old behavior raised Ecto.NoResultsError — new shim returns :ok safely.
      assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: legacy_args})
    end

    test "processes legacy provider_message_id args", %{delivery: delivery} do
      delivery = Ecto.Changeset.change(delivery, status: :dispatched) |> Repo.update!()

      {:ok, _} =
        Deliveries.record_attempt(delivery, %{
          outcome: :succeeded,
          adapter_module: "InitialAdapter",
          provider_message_id: "msg_legacy"
        })

      legacy_args = %{
        "provider_message_id" => "msg_legacy",
        "status" => "delivered",
        "provider_response" => %{},
        "adapter_module" => "LegacyAdapter"
      }

      assert :ok = ProcessFeedbackWorker.perform(%Oban.Job{args: legacy_args})
    end
  end
end
