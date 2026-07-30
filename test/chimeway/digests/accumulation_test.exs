defmodule Chimeway.Digests.AccumulationTest do
  use Chimeway.DataCase, async: true

  alias Chimeway.{Deliveries, Repo}
  alias Chimeway.Digests
  alias Chimeway.Digests.{Accumulation, DigestBucket, DigestMembership}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  setup do
    Repo.delete_all(DigestMembership)
    Repo.delete_all(DigestBucket)
    Repo.delete_all(Chimeway.Digests.DigestRule)
    :ok
  end

  describe "accumulate_delivery/2" do
    test "inserts one membership for a pending digest-held delivery and creates one bucket" do
      rule =
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
          recipient_id: "user-1",
          channel: "email"
        })

      accumulated_at = ~U[2026-01-15 10:05:00.000000Z]

      assert {:ok, %DigestBucket{} = bucket} =
               Accumulation.accumulate_delivery(delivery, accumulated_at: accumulated_at)

      assert bucket.digest_rule_id == rule.id
      assert bucket.rule_key == "digest.comment.fixed"
      assert bucket.recipient_id == "user-1"
      assert bucket.channel == "email"
      assert bucket.grouping_mode == :notification_key
      assert bucket.grouping_value == "comment.created"
      assert bucket.member_count == 1
      assert bucket.window_kind == :fixed
      assert bucket.window_starts_at == ~U[2026-01-15 10:00:00.000000Z]
      assert bucket.window_ends_at == ~U[2026-01-15 10:30:00.000000Z]

      assert Repo.aggregate(DigestBucket, :count, :id) == 1
      assert Repo.aggregate(DigestMembership, :count, :id) == 1

      membership = Repo.one!(from(m in DigestMembership))
      assert membership.digest_bucket_id == bucket.id
      assert membership.delivery_id == delivery.id
      assert membership.notification_id == delivery.notification_id
    end

    test "calling accumulate_delivery/2 again for the same delivery reuses the bucket and keeps membership count at one" do
      delivery =
        insert_digest_held_delivery(%{
          notification_key: "comment.created",
          recipient_id: "user-2",
          channel: "email"
        })

      insert_rule(%{
        rule_key: "digest.comment.fixed",
        match_notification_key: "comment.created",
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30
      })

      accumulated_at = ~U[2026-01-15 10:05:00.000000Z]

      assert {:ok, %DigestBucket{} = first_bucket} =
               Accumulation.accumulate_delivery(delivery, accumulated_at: accumulated_at)

      assert {:ok, %DigestBucket{} = second_bucket} =
               Accumulation.accumulate_delivery(delivery, accumulated_at: accumulated_at)

      assert first_bucket.id == second_bucket.id
      assert Repo.aggregate(DigestBucket, :count, :id) == 1
      assert Repo.aggregate(DigestMembership, :count, :id) == 1

      bucket = Repo.get!(DigestBucket, first_bucket.id)
      assert bucket.member_count == 1
      assert bucket.first_accumulated_at == accumulated_at
      assert bucket.last_accumulated_at == accumulated_at
    end

    test "keeps first and last accumulated timestamps ordered when deliveries arrive out of chronological order" do
      insert_rule(%{
        rule_key: "digest.comment.fixed",
        match_notification_key: "comment.created",
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30
      })

      later_delivery =
        insert_digest_held_delivery(%{
          notification_key: "comment.created",
          recipient_id: "user-ordered",
          channel: "email"
        })

      earlier_delivery =
        insert_digest_held_delivery(%{
          notification_key: "comment.created",
          recipient_id: "user-ordered",
          channel: "email"
        })

      later_at = ~U[2026-01-15 10:20:00.000000Z]
      earlier_at = ~U[2026-01-15 10:05:00.000000Z]

      assert {:ok, %DigestBucket{} = bucket} =
               Accumulation.accumulate_delivery(later_delivery, accumulated_at: later_at)

      assert {:ok, %DigestBucket{} = second_bucket} =
               Accumulation.accumulate_delivery(earlier_delivery, accumulated_at: earlier_at)

      assert second_bucket.id == bucket.id

      reloaded_bucket = Repo.get!(DigestBucket, bucket.id)

      assert reloaded_bucket.member_count == 2
      assert reloaded_bucket.first_accumulated_at == earlier_at
      assert reloaded_bucket.last_accumulated_at == later_at
    end

    test "returns noop for suppressed, cancelled, or ready deliveries and creates no bucket or membership" do
      insert_rule(%{
        rule_key: "digest.comment.fixed",
        match_notification_key: "comment.created",
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30
      })

      suppressed_delivery =
        insert_delivery_with_state(%{
          notification_key: "comment.created",
          recipient_id: "suppressed-user",
          channel: "email",
          status: :suppressed,
          orchestration_state: :digest_held
        }).delivery

      cancelled_delivery =
        insert_delivery_with_state(%{
          notification_key: "comment.created",
          recipient_id: "cancelled-user",
          channel: "email",
          status: :cancelled,
          orchestration_state: :digest_held
        }).delivery

      ready_delivery =
        insert_delivery_with_state(%{
          notification_key: "comment.created",
          recipient_id: "ready-user",
          channel: "email",
          status: :pending,
          orchestration_state: :ready
        }).delivery

      for delivery <- [suppressed_delivery, cancelled_delivery, ready_delivery] do
        assert {:ok, :noop} =
                 Accumulation.accumulate_delivery(delivery,
                   accumulated_at: ~U[2026-01-15 10:05:00.000000Z]
                 )
      end

      assert Repo.aggregate(DigestBucket, :count, :id) == 0
      assert Repo.aggregate(DigestMembership, :count, :id) == 0
    end

    test "category grouping snapshots the resolved category value from the event payload at accumulation time" do
      %{delivery: delivery, event: event} =
        insert_digest_held_delivery_with_event(%{
          notification_key: "comment.category",
          recipient_id: "user-category",
          payload: %{"category" => "support"},
          channel: "email"
        })

      insert_rule(%{
        rule_key: "digest.comment.category",
        match_category: "support",
        match_notification_key: nil,
        group_by: :category,
        window_kind: :fixed,
        window_minutes: 60
      })

      assert {:ok, %DigestBucket{} = bucket} =
               Accumulation.accumulate_delivery(delivery,
                 accumulated_at: ~U[2026-01-15 11:05:00.000000Z]
               )

      event
      |> Ecto.Changeset.change(payload: %{"category" => "billing"})
      |> Repo.update!()

      reloaded_bucket = Repo.get!(DigestBucket, bucket.id)

      assert reloaded_bucket.grouping_mode == :category
      assert reloaded_bucket.grouping_value == "support"
    end

    test "fixed windows derive concrete boundaries and reuse the bucket only inside the same interval" do
      insert_rule(%{
        rule_key: "digest.fixed.window",
        match_notification_key: "fixed.window",
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30
      })

      first_delivery =
        insert_digest_held_delivery(%{
          notification_key: "fixed.window",
          recipient_id: "user-fixed",
          channel: "email",
          next_eligible_at: ~U[2026-01-15 07:00:00.000000Z]
        })

      second_delivery =
        insert_digest_held_delivery(%{
          notification_key: "fixed.window",
          recipient_id: "user-fixed",
          channel: "email",
          next_eligible_at: ~U[2026-01-15 23:59:00.000000Z]
        })

      third_delivery =
        insert_digest_held_delivery(%{
          notification_key: "fixed.window",
          recipient_id: "user-fixed",
          channel: "email",
          next_eligible_at: ~U[2026-01-15 08:00:00.000000Z]
        })

      assert {:ok, %DigestBucket{} = first_bucket} =
               Accumulation.accumulate_delivery(first_delivery,
                 accumulated_at: ~U[2026-01-15 10:05:00.000000Z]
               )

      assert {:ok, %DigestBucket{} = second_bucket} =
               Accumulation.accumulate_delivery(second_delivery,
                 accumulated_at: ~U[2026-01-15 10:29:59.000000Z]
               )

      assert {:ok, %DigestBucket{} = third_bucket} =
               Accumulation.accumulate_delivery(third_delivery,
                 accumulated_at: ~U[2026-01-15 10:30:00.000000Z]
               )

      assert first_bucket.id == second_bucket.id
      assert third_bucket.id != first_bucket.id

      assert first_bucket.window_kind == :fixed
      assert first_bucket.window_starts_at == ~U[2026-01-15 10:00:00.000000Z]
      assert first_bucket.window_ends_at == ~U[2026-01-15 10:30:00.000000Z]
      assert third_bucket.window_starts_at == ~U[2026-01-15 10:30:00.000000Z]
      assert third_bucket.window_ends_at == ~U[2026-01-15 11:00:00.000000Z]

      refute first_bucket.window_starts_at == first_delivery.next_eligible_at
      refute third_bucket.window_ends_at == third_delivery.next_eligible_at
      assert Repo.aggregate(DigestBucket, :count, :id) == 2
    end

    test "boundary windows derive UTC boundaries from the configured local boundary and split consecutive windows" do
      insert_rule(%{
        rule_key: "digest.boundary.window",
        match_notification_key: "boundary.window",
        group_by: :notification_key,
        window_kind: :boundary,
        boundary_hour: 9,
        boundary_minute: 30,
        boundary_time_zone: "America/New_York"
      })

      before_boundary =
        insert_digest_held_delivery(%{
          notification_key: "boundary.window",
          recipient_id: "user-boundary",
          channel: "email",
          next_eligible_at: ~U[2026-01-20 02:00:00.000000Z]
        })

      after_boundary =
        insert_digest_held_delivery(%{
          notification_key: "boundary.window",
          recipient_id: "user-boundary",
          channel: "email",
          next_eligible_at: ~U[2026-01-20 03:00:00.000000Z]
        })

      assert {:ok, %DigestBucket{} = first_bucket} =
               Accumulation.accumulate_delivery(before_boundary,
                 accumulated_at: ~U[2026-01-15 14:29:00.000000Z]
               )

      assert {:ok, %DigestBucket{} = second_bucket} =
               Accumulation.accumulate_delivery(after_boundary,
                 accumulated_at: ~U[2026-01-15 14:31:00.000000Z]
               )

      assert first_bucket.id != second_bucket.id

      assert first_bucket.window_kind == :boundary
      assert first_bucket.window_starts_at == ~U[2026-01-14 14:30:00.000000Z]
      assert first_bucket.window_ends_at == ~U[2026-01-15 14:30:00.000000Z]
      assert second_bucket.window_starts_at == ~U[2026-01-15 14:30:00.000000Z]
      assert second_bucket.window_ends_at == ~U[2026-01-16 14:30:00.000000Z]

      refute first_bucket.window_starts_at == before_boundary.next_eligible_at
      refute second_bucket.window_ends_at == after_boundary.next_eligible_at
      assert Repo.aggregate(DigestBucket, :count, :id) == 2
    end

    test "rejects invalid_lookup_attrs when recipient_id overrides the persisted notification owner" do
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
          recipient_id: "user-owner",
          channel: "email"
        })

      assert {:error, {:invalid_lookup_attrs, %{recipient_id: "forged-owner"}}} =
               Accumulation.accumulate_delivery(delivery,
                 accumulated_at: ~U[2026-01-15 10:05:00.000000Z],
                 lookup_attrs: %{recipient_id: "forged-owner"}
               )

      assert Repo.aggregate(DigestBucket, :count, :id) == 0
      assert Repo.aggregate(DigestMembership, :count, :id) == 0
    end

    test "rejects invalid_lookup_attrs when channel, notification_key, or notification_version override durable digest identity" do
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
          recipient_id: "user-identity",
          channel: "email"
        })

      invalid_cases = [
        {%{channel: "sms"}, %{channel: "sms"}},
        {%{notification_key: "comment.updated"}, %{notification_key: "comment.updated"}},
        {%{notification_version: 2}, %{notification_version: 2}}
      ]

      for {lookup_attrs, mismatch} <- invalid_cases do
        assert {:error, {:invalid_lookup_attrs, ^mismatch}} =
                 Accumulation.accumulate_delivery(delivery,
                   accumulated_at: ~U[2026-01-15 10:05:00.000000Z],
                   lookup_attrs: lookup_attrs
                 )
      end

      assert Repo.aggregate(DigestBucket, :count, :id) == 0
      assert Repo.aggregate(DigestMembership, :count, :id) == 0
    end

    test "allows category and digest_key helper lookup_attrs without overriding durable identity" do
      insert_rule(%{
        rule_key: "digest.comment.helper",
        match_notification_key: nil,
        match_category: "comments",
        group_by: :digest_key,
        window_kind: :fixed,
        window_minutes: 30
      })

      delivery =
        insert_digest_held_delivery(%{
          notification_key: "comment.created",
          recipient_id: "user-helper",
          channel: "email"
        })

      assert {:ok, %DigestBucket{} = bucket} =
               Accumulation.accumulate_delivery(delivery,
                 accumulated_at: ~U[2026-01-15 10:05:00.000000Z],
                 lookup_attrs: %{category: "comments", digest_key: "team:ops"}
               )

      assert bucket.recipient_id == "user-helper"
      assert bucket.channel == "email"
      assert bucket.grouping_value == "team:ops"
      assert Repo.aggregate(DigestBucket, :count, :id) == 1
      assert Repo.aggregate(DigestMembership, :count, :id) == 1
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
    attrs
    |> insert_delivery_with_state()
    |> then(& &1.delivery)
  end

  defp insert_digest_held_delivery_with_event(attrs) do
    insert_delivery_with_state(attrs)
  end

  defp insert_delivery_with_state(attrs) do
    notification_key = Map.get(attrs, :notification_key, "comment.created")
    recipient_id = Map.get(attrs, :recipient_id, "user-default")
    payload = Map.get(attrs, :payload, %{})
    channel = Map.get(attrs, :channel, "email")
    status = Map.get(attrs, :status, :pending)
    orchestration_state = Map.get(attrs, :orchestration_state, :digest_held)
    next_eligible_at = Map.get(attrs, :next_eligible_at)
    digest_key = Map.get(attrs, :digest_key)

    event = insert_event(notification_key, payload: payload)
    notification = insert_notification(event, recipient_id)

    assert {:ok, delivery} =
             Deliveries.plan_delivery(notification.id, channel,
               notification_key: notification_key,
               event_id: event.id,
               tenant_id: "default",
               actor_id: "system"
             )

    assert {:ok, planned_delivery} =
             Deliveries.apply_planning_decision(delivery, %{
               orchestration_state: orchestration_state,
               planning_reason:
                 if(orchestration_state == :digest_held, do: "digest_rule", else: nil),
               planning_context:
                 digest_planning_context(channel, digest_key, orchestration_state, attrs),
               next_eligible_at: next_eligible_at
             })

    final_delivery =
      planned_delivery
      |> Ecto.Changeset.change(status: status)
      |> Repo.update!()

    %{delivery: final_delivery, notification: notification, event: event}
  end

  defp digest_planning_context(_channel, _digest_key, :ready, _attrs), do: nil

  defp digest_planning_context(channel, digest_key, _state, attrs) do
    %{
      "channel" => channel,
      "source" => "test",
      "rule_identity" => "digest_rule"
    }
    |> maybe_put("digest_key", digest_key)
    |> maybe_put("category", get_in(attrs, [:payload, "category"]))
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
        idempotency_key: "accumulation-#{System.unique_integer([:positive])}",
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
