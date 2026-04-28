defmodule Chimeway.Integration.DigestDeliveryLifecycleTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.{Deliveries, Delivery, Repo}
  alias Chimeway.Adapters.Test, as: TestAdapter
  alias Chimeway.Digests
  alias Chimeway.Digests.{Accumulation, DigestBucket, DigestMembership}
  alias Chimeway.Dispatch.{DigestFlushWorker, ObanWorker}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  setup do
    Repo.delete_all(DigestMembership)
    Repo.delete_all(DigestBucket)
    Repo.delete_all(Chimeway.Digests.DigestRule)
    Repo.delete_all(Delivery)
    Repo.delete_all(Notification)
    Repo.delete_all(Event)

    original_adapter = Application.get_env(:chimeway, :adapter)
    original_dispatcher = Application.get_env(:chimeway, :dispatcher)

    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    TestAdapter.clear()

    on_exit(fn ->
      restore_env(:adapter, original_adapter)
      restore_env(:dispatcher, original_dispatcher)
      TestAdapter.clear()
    end)

    :ok
  end

  test "sync emit_bucket creates a canonical ready delivery and dispatches it after commit" do
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

    insert_rule("digest.comment.sync")

    included =
      insert_digest_held_delivery(%{
        notification_key: "comment.sync",
        recipient_id: "user-sync",
        channel: "email"
      })

    immediate =
      insert_digest_held_delivery(%{
        notification_key: "comment.sync",
        recipient_id: "user-sync",
        channel: "email",
        planning_context: %{
          "channel" => "email",
          "source" => "notifier",
          "rule_identity" => "digest_rule",
          "digest_flush_behavior" => "immediate",
          "digest_flush_reason" => "window_closed"
        }
      })

    accumulated_at = ~U[2026-01-15 13:05:00.000000Z]
    emitted_at = ~U[2026-01-15 13:35:00.000000Z]

    {:ok, bucket} = Accumulation.accumulate_delivery(included, accumulated_at: accumulated_at)

    {:ok, _same_bucket} =
      Accumulation.accumulate_delivery(immediate, accumulated_at: accumulated_at)

    assert {:ok, %{digest_delivery: emitted, immediate_deliveries: [immediate_delivery]}} =
             Digests.emit_bucket(bucket.id, emitted_at: emitted_at, dispatch: :sync)

    emitted = Repo.get!(Delivery, emitted.id)
    immediate_delivery = Repo.get!(Delivery, immediate_delivery.id)

    assert emitted.orchestration_state == :ready
    assert emitted.metadata["subject"] == "Digest for digest.comment.sync"
    assert emitted.metadata["body"] =~ "Digest window closed"
    assert emitted.metadata["summary"] =~ "notification"
    assert emitted.metadata["digest"]["bucket_id"] == bucket.id

    assert emitted.status == :succeeded
    assert immediate_delivery.status == :succeeded

    TestAdapter.assert_delivered(emitted)
    TestAdapter.assert_delivered(immediate_delivery)
  end

  test "oban emit_bucket enqueues by delivery_id and duplicate flush worker execution reuses the same emitted identity" do
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)

    insert_rule("digest.comment.oban")

    included =
      insert_digest_held_delivery(%{
        notification_key: "comment.oban",
        recipient_id: "user-oban",
        channel: "email"
      })

    accumulated_at = ~U[2026-01-15 14:05:00.000000Z]
    emitted_at = ~U[2026-01-15 14:35:00.000000Z]
    {:ok, bucket} = Accumulation.accumulate_delivery(included, accumulated_at: accumulated_at)

    assert {:ok, %{digest_delivery: emitted}} =
             Digests.emit_bucket(bucket.id, emitted_at: emitted_at, dispatch: :oban)

    assert_enqueued(worker: ObanWorker, args: %{delivery_id: emitted.id})

    assert :ok = perform_job(DigestFlushWorker, %{bucket_id: bucket.id})
    assert :ok = perform_job(DigestFlushWorker, %{bucket_id: bucket.id})

    reloaded_bucket = Repo.get!(DigestBucket, bucket.id)
    assert reloaded_bucket.digest_delivery_id == emitted.id

    digest_delivery_count =
      Repo.aggregate(
        from(delivery in Delivery,
          where: delivery.id == ^emitted.id
        ),
        :count
      )

    assert digest_delivery_count == 1
  end

  defp insert_rule(rule_key) do
    {:ok, _rule} =
      Digests.upsert_rule(%{
        rule_key: rule_key,
        rule_version: 1,
        channel: "email",
        match_notification_key: String.replace_prefix(rule_key, "digest.", ""),
        match_category: nil,
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30,
        boundary_hour: nil,
        boundary_minute: nil,
        boundary_time_zone: nil
      })
  end

  defp insert_digest_held_delivery(attrs) do
    {:ok, event} =
      Repo.insert(%Event{
        notification_key: attrs.notification_key,
        notification_version: 1,
        idempotency_key: "digest-lifecycle-#{System.unique_integer([:positive])}",
        payload: %{"category" => "comment"}
      })

    {:ok, notification} =
      Repo.insert(%Notification{
        event_id: event.id,
        recipient_identity: attrs.recipient_id,
        recipient_type: "user",
        metadata: %{}
      })

    {:ok, delivery} = Deliveries.plan_delivery(notification.id, attrs.channel)

    {:ok, updated} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :digest_held,
        planning_reason: "digest_rule",
        planning_context:
          Map.get(attrs, :planning_context, %{
            "channel" => attrs.channel,
            "source" => "notifier",
            "rule_identity" => "digest_rule"
          }),
        next_eligible_at: nil
      })

    updated
  end

  defp restore_env(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore_env(key, value), do: Application.put_env(:chimeway, key, value)
end
