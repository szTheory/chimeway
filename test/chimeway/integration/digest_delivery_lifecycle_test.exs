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
  alias Chimeway.Test.DispatchHelpers

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

  test "scheduled digest flush worker drives canonical oban dispatch and source-row convergence" do
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)

    insert_rule("digest.comment.worker", match_notification_key: "comment.worker")

    included =
      insert_digest_held_delivery(%{
        notification_key: "comment.worker",
        recipient_id: "user-worker",
        channel: "email"
      })

    immediate =
      insert_digest_held_delivery(%{
        notification_key: "comment.worker",
        recipient_id: "user-worker",
        channel: "email",
        planning_context: %{
          "channel" => "email",
          "source" => "notifier",
          "rule_identity" => "digest_rule",
          "digest_flush_behavior" => "immediate",
          "digest_flush_reason" => "window_closed"
        }
      })

    accumulated_at = ~U[2026-01-15 14:05:00.000000Z]
    {:ok, bucket} = Accumulation.accumulate_delivery(included, accumulated_at: accumulated_at)

    {:ok, _same_bucket} =
      Accumulation.accumulate_delivery(immediate, accumulated_at: accumulated_at)

    assert_enqueued(
      worker: DigestFlushWorker,
      args: %{bucket_id: bucket.id},
      scheduled_at: bucket.window_ends_at
    )

    assert :ok = perform_job(DigestFlushWorker, %{bucket_id: bucket.id})
    assert :ok = perform_job(DigestFlushWorker, %{bucket_id: bucket.id})

    reloaded_bucket = Repo.get!(DigestBucket, bucket.id)
    emitted = Repo.get!(Delivery, reloaded_bucket.digest_delivery_id)
    included = Repo.get!(Delivery, included.id)
    immediate = Repo.get!(Delivery, immediate.id)

    assert_enqueued(worker: ObanWorker, args: %{delivery_id: emitted.id})
    assert_enqueued(worker: ObanWorker, args: %{delivery_id: immediate.id})

    assert included.status == :digested
    assert included.orchestration_state == :ready
    assert included.digest_delivery_id == emitted.id

    assert immediate.status == :pending
    assert immediate.orchestration_state == :ready
    assert immediate.digest_delivery_id == emitted.id
    assert immediate.digest_flush_outcome == :emitted_immediately

    assert :ok = perform_job(ObanWorker, %{delivery_id: emitted.id})
    assert :ok = perform_job(ObanWorker, %{delivery_id: immediate.id})

    assert Repo.get!(Delivery, emitted.id).status == :succeeded
    assert Repo.get!(Delivery, immediate.id).status == :succeeded

    digest_delivery_count =
      Repo.aggregate(
        from(delivery in Delivery,
          where: delivery.id == ^emitted.id
        ),
        :count
      )

    assert digest_delivery_count == 1
  end

  test "recovery-replayed digest-held deliveries join the scheduled bucket path before flush" do
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)

    insert_rule("digest.comment.recovery",
      match_notification_key: "comment.recovery",
      group_by: :digest_key
    )

    %{event: event, notification: persisted_notification} =
      DispatchHelpers.create_notification(
        notification_key: "comment.recovery",
        recipient_identity: "user:recover"
      )

    persisted_notification =
      persisted_notification
      |> Ecto.Changeset.change(
        orchestration: %{
          "default" => "digest_held",
          "channels" => %{"email" => "digest_held"},
          "default_digest_key" => nil,
          "digest_keys" => %{"email" => "thread:user:recover"},
          "source" => "notifier"
        },
        render_channels: %{"email" => %{"render_key" => "test", "render_version" => 1}},
        updated_at: ~U[2026-01-15 11:00:00.000000Z]
      )
      |> Repo.update!()

    event =
      event
      |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
      |> Repo.update!()

    assert {:ok, recovery} =
             Deliveries.recover_event(event.id,
               tenant_id: event.tenant_id,
               now: ~U[2026-01-15 12:30:00Z],
               older_than: 60,
               source: "ops_console",
               reason: "digest_replay_gap"
             )

    [recovered_delivery] = recovery.deliveries
    assert recovered_delivery.status == :pending
    assert recovered_delivery.orchestration_state == :digest_held
    assert persisted_notification.id == recovered_delivery.notification_id

    bucket =
      Repo.one!(
        from(bucket in DigestBucket,
          where: bucket.rule_key == ^"digest.comment.recovery",
          order_by: [desc: bucket.inserted_at],
          limit: 1
        )
      )

    peer_delivery =
      insert_digest_held_delivery(%{
        notification_key: "comment.recovery",
        recipient_id: "user:recover",
        channel: "email",
        planning_context: %{
          "channel" => "email",
          "source" => "planner_override",
          "digest_key" => "thread:user:recover"
        }
      })

    assert {:ok, %DigestBucket{id: same_bucket_id}} =
             Accumulation.accumulate_delivery(
               peer_delivery,
               accumulated_at: DateTime.add(bucket.window_starts_at, 60, :second)
             )

    assert same_bucket_id == bucket.id

    assert Repo.aggregate(
             from(membership in DigestMembership,
               where: membership.digest_bucket_id == ^bucket.id
             ),
             :count
           ) == 2

    assert_enqueued(
      worker: DigestFlushWorker,
      args: %{bucket_id: bucket.id},
      scheduled_at: bucket.window_ends_at
    )

    due_bucket =
      bucket
      |> Ecto.Changeset.change(
        window_starts_at: DateTime.add(DateTime.utc_now(), -120, :second),
        window_ends_at: DateTime.add(DateTime.utc_now(), -60, :second)
      )
      |> Repo.update!()

    assert :ok = perform_job(DigestFlushWorker, %{bucket_id: due_bucket.id})

    emitted_bucket = Repo.get!(DigestBucket, due_bucket.id)
    emitted = Repo.get!(Delivery, emitted_bucket.digest_delivery_id)

    assert_enqueued(worker: ObanWorker, args: %{delivery_id: emitted.id})

    recovered_delivery = Repo.get!(Delivery, recovered_delivery.id)
    peer_delivery = Repo.get!(Delivery, peer_delivery.id)

    assert recovered_delivery.status == :digested
    assert recovered_delivery.digest_delivery_id == emitted.id
    assert peer_delivery.status == :digested
    assert peer_delivery.digest_delivery_id == emitted.id
  end

  defp insert_rule(rule_key, overrides \\ []) do
    {:ok, _rule} =
      Digests.upsert_rule(%{
        rule_key: rule_key,
        rule_version: 1,
        channel: "email",
        match_notification_key:
          Keyword.get(
            overrides,
            :match_notification_key,
            String.replace_prefix(rule_key, "digest.", "")
          ),
        match_category: nil,
        group_by: Keyword.get(overrides, :group_by, :notification_key),
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
        tenant_id: "default",
        payload: %{"category" => "comment"}
      })

    {:ok, notification} =
      Repo.insert(%Notification{
        event_id: event.id,
        tenant_id: event.tenant_id,
        recipient_identity: attrs.recipient_id,
        recipient_type: "user",
        metadata: %{}
      })

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, attrs.channel,
        tenant_id: "default",
        actor_id: "system"
      )

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
