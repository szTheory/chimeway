defmodule Chimeway.Digests.FlushSchedulingTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Digests
  alias Chimeway.Digests.{Accumulation, DigestBucket, DigestMembership}
  alias Chimeway.Dispatch.DigestFlushWorker
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  setup do
    Repo.delete_all(DigestMembership)
    Repo.delete_all(DigestBucket)
    Repo.delete_all(Chimeway.Digests.DigestRule)
    :ok
  end

  describe "accumulate_delivery/2 scheduling" do
    test "schedules one DigestFlushWorker job at bucket.window_ends_at" do
      insert_rule(%{
        rule_key: "digest.comment.fixed",
        match_notification_key: "comment.created",
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30
      })

      delivery =
        insert_digest_held_delivery(%{
          notification_key: "comment.created",
          recipient_id: "user-schedule",
          channel: "email"
        })

      accumulated_at = ~U[2026-01-15 10:05:00.000000Z]

      assert {:ok, %DigestBucket{} = bucket} =
               Accumulation.accumulate_delivery(delivery, accumulated_at: accumulated_at)

      assert bucket.window_ends_at == ~U[2026-01-15 10:30:00.000000Z]

      assert_enqueued(
        worker: DigestFlushWorker,
        args: %{bucket_id: bucket.id},
        scheduled_at: bucket.window_ends_at
      )
    end

    test "repeated accumulation into the same bucket does not enqueue duplicate future flush jobs" do
      insert_rule(%{
        rule_key: "digest.comment.fixed",
        match_notification_key: "comment.created",
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30
      })

      first =
        insert_digest_held_delivery(%{
          notification_key: "comment.created",
          recipient_id: "user-duplicate",
          channel: "email"
        })

      second =
        insert_digest_held_delivery(%{
          notification_key: "comment.created",
          recipient_id: "user-duplicate",
          channel: "email"
        })

      accumulated_at = ~U[2026-01-15 10:05:00.000000Z]

      assert {:ok, %DigestBucket{} = first_bucket} =
               Accumulation.accumulate_delivery(first, accumulated_at: accumulated_at)

      assert {:ok, %DigestBucket{} = second_bucket} =
               Accumulation.accumulate_delivery(second, accumulated_at: accumulated_at)

      assert first_bucket.id == second_bucket.id

      assert [%Oban.Job{args: %{"bucket_id" => bucket_id}, scheduled_at: scheduled_at}] =
               all_enqueued(worker: DigestFlushWorker)

      assert bucket_id == first_bucket.id
      assert scheduled_at == first_bucket.window_ends_at
    end
  end

  defp insert_rule(overrides) do
    attrs =
      %{
        rule_key: "digest.rule",
        rule_version: 1,
        channel: "email",
        match_notification_key: "comment.created",
        match_category: "comments",
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30,
        boundary_hour: nil,
        boundary_minute: nil,
        boundary_time_zone: nil
      }
      |> Map.merge(overrides)

    assert {:ok, rule} = Digests.upsert_rule(attrs)
    rule
  end

  defp insert_digest_held_delivery(attrs) do
    notification_key = Map.get(attrs, :notification_key, "comment.created")
    recipient_id = Map.get(attrs, :recipient_id, "user-default")
    payload = Map.get(attrs, :payload, %{})
    channel = Map.get(attrs, :channel, "email")
    next_eligible_at = Map.get(attrs, :next_eligible_at)
    digest_key = Map.get(attrs, :digest_key)

    event = insert_event(notification_key, payload: payload)
    notification = insert_notification(event, recipient_id)

    assert {:ok, delivery} =
             Deliveries.plan_delivery(notification.id, channel,
               notification_key: notification_key,
               event_id: event.id
             )

    assert {:ok, planned_delivery} =
             Deliveries.apply_planning_decision(delivery, %{
               orchestration_state: :digest_held,
               planning_reason: "digest_rule",
               planning_context: %{
                 "channel" => channel,
                 "source" => "test",
                 "rule_identity" => "digest_rule"
               }
               |> maybe_put("digest_key", digest_key),
               next_eligible_at: next_eligible_at
             })

    planned_delivery
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp insert_event(notification_key, opts) do
    payload = Keyword.get(opts, :payload, %{})

    {:ok, event} =
      %Event{}
      |> Event.changeset(%{
        notification_key: notification_key,
        notification_version: 1,
        idempotency_key: "flush-scheduling-#{System.unique_integer([:positive])}",
        payload: payload
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
end
