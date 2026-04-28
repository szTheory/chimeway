defmodule Chimeway.Orchestration.DigestExplainabilityTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{Deliveries, Repo, Traces}
  alias Chimeway.Digests
  alias Chimeway.Digests.{Accumulation, DigestBucket, DigestMembership}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Traces.Explanation

  setup do
    Repo.delete_all(DigestMembership)
    Repo.delete_all(DigestBucket)
    Repo.delete_all(Chimeway.Digests.DigestRule)
    Repo.delete_all(Chimeway.Delivery)
    Repo.delete_all(Notification)
    Repo.delete_all(Event)
    :ok
  end

  test "source explanations expose included, skipped, and emitted_immediately digest reasons" do
    insert_rule()

    included = insert_digest_held_delivery("comment.explain", "user-explain")

    skipped =
      insert_digest_held_delivery("comment.explain", "user-explain", %{
        "channel" => "email",
        "source" => "notifier",
        "rule_identity" => "digest_rule",
        "digest_flush_behavior" => "skip",
        "digest_flush_reason" => "recipient_muted"
      })

    immediate =
      insert_digest_held_delivery("comment.explain", "user-explain", %{
        "channel" => "email",
        "source" => "notifier",
        "rule_identity" => "digest_rule",
        "digest_flush_behavior" => "immediate",
        "digest_flush_reason" => "digest_window_expired"
      })

    accumulated_at = ~U[2026-01-15 15:05:00.000000Z]
    emitted_at = ~U[2026-01-15 15:35:00.000000Z]
    {:ok, bucket} = Accumulation.accumulate_delivery(included, accumulated_at: accumulated_at)

    {:ok, _same_bucket} =
      Accumulation.accumulate_delivery(skipped, accumulated_at: accumulated_at)

    {:ok, _same_bucket} =
      Accumulation.accumulate_delivery(immediate, accumulated_at: accumulated_at)

    assert {:ok, %{digest_delivery: emitted}} =
             Digests.emit_bucket(bucket.id, emitted_at: emitted_at, dispatch: :skip)

    assert {:ok, %Explanation{} = included_exp} = Traces.explain_delivery(included.id)
    assert included_exp.digest["included"] == true
    assert included_exp.digest["digest_delivery_id"] == emitted.id
    assert included_exp.digest["rule_identity"] == "digest.comment.explain:v1"
    assert Enum.any?(included_exp.timeline, &(&1.event == :digested))

    assert {:ok, %Explanation{} = skipped_exp} = Traces.explain_delivery(skipped.id)
    assert skipped_exp.digest["excluded"] == true
    assert skipped_exp.digest["resolution_reason"] == "recipient_muted"
    assert Enum.any?(skipped_exp.timeline, &(&1.event == :digest_skipped))

    assert {:ok, %Explanation{} = immediate_exp} = Traces.explain_delivery(immediate.id)
    assert immediate_exp.digest["emitted_immediately"] == true
    assert immediate_exp.digest["resolution_reason"] == "digest_window_expired"
    assert Enum.any?(immediate_exp.timeline, &(&1.event == :emitted_immediately))
  end

  test "emitted digest explanations list included and excluded source rows without payload leaks" do
    insert_rule()

    included = insert_digest_held_delivery("comment.explain", "user-emitted")

    skipped =
      insert_digest_held_delivery("comment.explain", "user-emitted", %{
        "channel" => "email",
        "source" => "notifier",
        "rule_identity" => "digest_rule",
        "digest_flush_behavior" => "skip",
        "digest_flush_reason" => "recipient_muted",
        "payload" => %{"secret" => "ignored"}
      })

    accumulated_at = ~U[2026-01-15 16:05:00.000000Z]
    emitted_at = ~U[2026-01-15 16:35:00.000000Z]
    {:ok, bucket} = Accumulation.accumulate_delivery(included, accumulated_at: accumulated_at)

    {:ok, _same_bucket} =
      Accumulation.accumulate_delivery(skipped, accumulated_at: accumulated_at)

    assert {:ok, %{digest_delivery: emitted}} =
             Digests.emit_bucket(bucket.id, emitted_at: emitted_at, dispatch: :skip)

    assert {:ok, %Explanation{} = explanation} = Traces.explain_delivery(emitted.id)

    assert explanation.digest["kind"] == "emitted_digest"
    assert explanation.digest["rule_identity"] == "digest.comment.explain:v1"
    assert length(explanation.digest["included"]) == 1
    assert length(explanation.digest["excluded"]) == 1
    assert explanation.digest["deferred"] == []

    [included_entry] = explanation.digest["included"]
    [excluded_entry] = explanation.digest["excluded"]

    assert included_entry["delivery_id"] == included.id
    assert excluded_entry["delivery_id"] == skipped.id
    assert excluded_entry["reason"] == "recipient_muted"

    refute inspect(explanation.digest) =~ "secret"
    refute inspect(explanation.digest) =~ "provider_response"
    assert Enum.any?(explanation.timeline, &(&1.event == :digest_emitted))
  end

  defp insert_rule do
    {:ok, _rule} =
      Digests.upsert_rule(%{
        rule_key: "digest.comment.explain",
        rule_version: 1,
        channel: "email",
        match_notification_key: "comment.explain",
        match_category: nil,
        group_by: :notification_key,
        window_kind: :fixed,
        window_minutes: 30,
        boundary_hour: nil,
        boundary_minute: nil,
        boundary_time_zone: nil
      })
  end

  defp insert_digest_held_delivery(notification_key, recipient_identity, planning_context \\ nil) do
    {:ok, event} =
      Repo.insert(%Event{
        notification_key: notification_key,
        notification_version: 1,
        idempotency_key: "digest-explain-#{System.unique_integer([:positive])}",
        payload: %{"category" => "comment", "secret" => "do-not-leak"}
      })

    {:ok, notification} =
      Repo.insert(%Notification{
        event_id: event.id,
        recipient_identity: recipient_identity,
        recipient_type: "user",
        metadata: %{}
      })

    {:ok, delivery} = Deliveries.plan_delivery(notification.id, :email)

    {:ok, updated} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :digest_held,
        planning_reason: "digest_rule",
        planning_context:
          planning_context ||
            %{
              "channel" => "email",
              "source" => "notifier",
              "rule_identity" => "digest_rule"
            },
        next_eligible_at: nil
      })

    updated
  end
end
