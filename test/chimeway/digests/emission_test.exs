defmodule Chimeway.Digests.EmissionTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Delivery, Deliveries, Repo}
  alias Chimeway.Digests
  alias Chimeway.Digests.{Accumulation, DigestBucket, DigestMembership, Emission}
  alias Chimeway.Dispatch.DigestFlushWorker
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  setup do
    Repo.delete_all(DigestMembership)
    Repo.delete_all(DigestBucket)
    Repo.delete_all(Chimeway.Digests.DigestRule)
    Repo.delete_all(Delivery)
    Repo.delete_all(Notification)
    Repo.delete_all(Event)
    :ok
  end

  describe "emit_bucket/2" do
    test "claims and emits a due bucket at most once, reusing the same digest delivery on retries" do
      rule =
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
          recipient_id: "user-emit",
          channel: "email"
        })

      second =
        insert_digest_held_delivery(%{
          notification_key: "comment.created",
          recipient_id: "user-emit",
          channel: "email"
        })

      accumulated_at = ~U[2026-01-15 10:05:00.000000Z]
      emitted_at = ~U[2026-01-15 10:35:00.000000Z]

      {:ok, bucket} = Accumulation.accumulate_delivery(first, accumulated_at: accumulated_at)

      {:ok, _same_bucket} =
        Accumulation.accumulate_delivery(second, accumulated_at: accumulated_at)

      assert {:ok, %{digest_delivery: emitted, bucket: first_bucket}} =
               Emission.emit_bucket(bucket.id, emitted_at: emitted_at)

      assert {:ok, %{digest_delivery: emitted_again, bucket: second_bucket}} =
               Emission.emit_bucket(bucket.id, emitted_at: emitted_at)

      assert emitted.id == emitted_again.id
      assert first_bucket.id == second_bucket.id
      assert first_bucket.flush_state == :emitted
      assert first_bucket.digest_delivery_id == emitted.id
      assert first_bucket.claimed_at == emitted_at
      assert first_bucket.emitted_at == emitted_at

      assert emitted.channel == "email"
      assert emitted.orchestration_state == :ready
      assert emitted.metadata["digest"] != nil

      reloaded_bucket = Repo.get!(DigestBucket, bucket.id)
      assert reloaded_bucket.flush_state == :emitted
      assert reloaded_bucket.digest_delivery_id == emitted.id
      assert reloaded_bucket.member_count == 2

      assert Repo.aggregate(
               from(d in Delivery,
                 where:
                   d.notification_id == ^emitted.notification_id and
                     d.id == ^emitted.id
               ),
               :count
             ) == 1

      assert rule.id == reloaded_bucket.digest_rule_id
    end

    test "scheduled worker execution and direct emit retries converge on one digest_delivery_id" do
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
          recipient_id: "user-worker",
          channel: "email"
        })

      accumulated_at = ~U[2026-01-15 10:05:00.000000Z]
      {:ok, bucket} = Accumulation.accumulate_delivery(delivery, accumulated_at: accumulated_at)

      assert :ok =
               DigestFlushWorker.perform(%Oban.Job{
                 args: %{"bucket_id" => bucket.id},
                 scheduled_at: bucket.window_ends_at
               })

      assert {:ok, %{digest_delivery: retried_emit, bucket: retried_bucket}} =
               Digests.emit_bucket(bucket.id, emitted_at: bucket.window_ends_at)

      reloaded_bucket = Repo.get!(DigestBucket, bucket.id)

      assert reloaded_bucket.flush_state == :emitted
      assert reloaded_bucket.digest_delivery_id == retried_emit.id
      assert retried_bucket.digest_delivery_id == retried_emit.id

      assert Repo.aggregate(
               from(d in Delivery, where: d.id == ^reloaded_bucket.digest_delivery_id),
               :count,
               :id
             ) == 1
    end

    test "persists included membership resolution facts and converges included source rows to :digested" do
      delivery =
        insert_ready_bucket_member(%{
          notification_key: "comment.included",
          recipient_id: "user-included",
          channel: "email"
        })

      accumulated_at = ~U[2026-01-15 11:05:00.000000Z]
      emitted_at = ~U[2026-01-15 11:35:00.000000Z]
      {:ok, bucket} = Accumulation.accumulate_delivery(delivery, accumulated_at: accumulated_at)

      assert {:ok, %{digest_delivery: emitted}} =
               Emission.emit_bucket(bucket.id, emitted_at: emitted_at)

      membership = Repo.one!(from(m in DigestMembership, where: m.delivery_id == ^delivery.id))
      source = Repo.get!(Delivery, delivery.id)

      assert membership.resolution == :included
      assert membership.resolution_reason == "included_in_digest"
      assert membership.digest_delivery_id == emitted.id
      assert membership.resolved_at == emitted_at
      assert membership.resolved_rule_key == bucket.rule_key
      assert membership.resolved_rule_version == bucket.rule_version
      assert membership.resolved_window_starts_at == bucket.window_starts_at
      assert membership.resolved_window_ends_at == bucket.window_ends_at

      assert source.status == :digested
      assert source.digest_flush_outcome == :digested
      assert source.digest_flush_reason == "included_in_digest"
      assert source.digest_delivery_id == emitted.id
      assert source.digest_flush_resolved_at == emitted_at
      assert source.orchestration_state == :ready
    end

    test "persists explicit skipped_by_policy and emitted_immediately outcomes on canonical source rows" do
      insert_rule(%{
        rule_key: "digest.comment.flush",
        match_notification_key: "comment.flush",
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30
      })

      skipped =
        insert_digest_held_delivery(%{
          notification_key: "comment.flush",
          recipient_id: "user-flush",
          channel: "email",
          planning_context: %{
            "channel" => "email",
            "source" => "notifier",
            "rule_identity" => "digest_rule",
            "digest_flush_behavior" => "skip",
            "digest_flush_reason" => "recipient_muted"
          }
        })

      immediate =
        insert_digest_held_delivery(%{
          notification_key: "comment.flush",
          recipient_id: "user-flush",
          channel: "email",
          planning_context: %{
            "channel" => "email",
            "source" => "notifier",
            "rule_identity" => "digest_rule",
            "digest_flush_behavior" => "immediate",
            "digest_flush_reason" => "digest_window_expired"
          }
        })

      included =
        insert_digest_held_delivery(%{
          notification_key: "comment.flush",
          recipient_id: "user-flush",
          channel: "email"
        })

      accumulated_at = ~U[2026-01-15 12:05:00.000000Z]
      emitted_at = ~U[2026-01-15 12:35:00.000000Z]
      {:ok, bucket} = Accumulation.accumulate_delivery(skipped, accumulated_at: accumulated_at)

      {:ok, _same_bucket} =
        Accumulation.accumulate_delivery(immediate, accumulated_at: accumulated_at)

      {:ok, _same_bucket} =
        Accumulation.accumulate_delivery(included, accumulated_at: accumulated_at)

      assert {:ok, %{digest_delivery: emitted, immediate_deliveries: [immediate_delivery]}} =
               Emission.emit_bucket(bucket.id,
                 emitted_at: emitted_at,
                 dispatch: :skip
               )

      skipped_membership =
        Repo.one!(from(m in DigestMembership, where: m.delivery_id == ^skipped.id))

      immediate_membership =
        Repo.one!(from(m in DigestMembership, where: m.delivery_id == ^immediate.id))

      skipped_source = Repo.get!(Delivery, skipped.id)
      immediate_source = Repo.get!(Delivery, immediate.id)

      assert skipped_membership.resolution == :skipped_by_policy
      assert skipped_membership.resolution_reason == "recipient_muted"
      assert skipped_membership.digest_delivery_id == emitted.id

      assert skipped_source.status == :suppressed
      assert skipped_source.digest_flush_outcome == :skipped_by_policy
      assert skipped_source.digest_flush_reason == "recipient_muted"
      assert skipped_source.digest_delivery_id == emitted.id

      assert immediate_membership.resolution == :emitted_immediately
      assert immediate_membership.resolution_reason == "digest_window_expired"
      assert immediate_membership.digest_delivery_id == emitted.id

      assert immediate_source.status == :pending
      assert immediate_source.orchestration_state == :ready
      assert immediate_source.digest_flush_outcome == :emitted_immediately
      assert immediate_source.digest_flush_reason == "digest_window_expired"
      assert immediate_source.digest_delivery_id == emitted.id
      assert immediate_delivery.id == immediate.id
    end
  end

  defp insert_ready_bucket_member(attrs) do
    insert_rule(%{
      rule_key: "digest.#{attrs.notification_key}",
      match_notification_key: attrs.notification_key,
      group_by: :notification_key,
      window_kind: :fixed,
      window_minutes: 30
    })

    insert_digest_held_delivery(attrs)
  end

  defp insert_digest_held_delivery(attrs) do
    notification = insert_notification(attrs)

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, Map.get(attrs, :channel, "email"),
        tenant_id: "default",
        actor_id: "system"
      )

    planning_context =
      Map.get(attrs, :planning_context, %{
        "channel" => Map.get(attrs, :channel, "email"),
        "source" => "notifier",
        "rule_identity" => "digest_rule"
      })
      |> maybe_put("digest_key", Map.get(attrs, :digest_key))

    {:ok, updated} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :digest_held,
        planning_reason: "digest_rule",
        planning_context: planning_context,
        next_eligible_at: Map.get(attrs, :next_eligible_at)
      })

    updated
  end

  defp insert_notification(attrs) do
    {:ok, event} =
      Repo.insert(%Event{
        notification_key: Map.fetch!(attrs, :notification_key),
        notification_version: 1,
        idempotency_key: "emit-#{System.unique_integer([:positive])}",
        payload: Map.get(attrs, :payload, %{"category" => "comment"})
      })

    {:ok, notification} =
      Repo.insert(%Notification{
        event_id: event.id,
        recipient_identity: Map.fetch!(attrs, :recipient_id),
        recipient_type: "user",
        metadata: %{}
      })

    notification
  end

  defp insert_rule(attrs) do
    {:ok, rule} =
      Digests.upsert_rule(%{
        rule_key: Map.fetch!(attrs, :rule_key),
        rule_version: 1,
        channel: "email",
        match_notification_key: Map.get(attrs, :match_notification_key),
        match_category: Map.get(attrs, :match_category),
        group_by: Map.fetch!(attrs, :group_by),
        window_kind: Map.fetch!(attrs, :window_kind),
        window_minutes: Map.get(attrs, :window_minutes),
        boundary_hour: Map.get(attrs, :boundary_hour),
        boundary_minute: Map.get(attrs, :boundary_minute),
        boundary_time_zone: Map.get(attrs, :boundary_time_zone)
      })

    rule
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
