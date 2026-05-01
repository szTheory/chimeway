defmodule Chimeway.Digests.Emission do
  @moduledoc "Transactional digest emission for due buckets with durable membership resolution."

  import Ecto.Query

  alias Chimeway.{Deliveries, Delivery, Repo}
  alias Chimeway.Digests.{DigestBucket, DigestMembership}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  @type emit_result :: %{
          bucket: DigestBucket.t(),
          digest_delivery: Delivery.t(),
          immediate_deliveries: [Delivery.t()]
        }

  @spec emit_bucket(binary() | DigestBucket.t(), keyword()) ::
          {:ok, emit_result()} | {:error, term()}
  def emit_bucket(bucket_or_id, opts \\ []) do
    emitted_at =
      opts
      |> Keyword.get(:emitted_at, DateTime.utc_now())
      |> normalize_datetime()

    dispatch_mode = Keyword.get(opts, :dispatch, default_dispatch_mode())

    case Repo.transact(fn ->
           bucket = lock_bucket!(bucket_id!(bucket_or_id))

           cond do
             bucket.flush_state == :emitted and is_binary(bucket.digest_delivery_id) ->
               digest_delivery = Repo.get!(Delivery, bucket.digest_delivery_id)
               immediate_deliveries = immediate_deliveries_for_bucket(bucket.id)

               {:ok,
                %{
                  bucket: bucket,
                  digest_delivery: digest_delivery,
                  immediate_deliveries: immediate_deliveries
                }}

             DateTime.compare(bucket.window_ends_at, emitted_at) == :gt ->
               Repo.rollback({:bucket_not_due, bucket.id})

             true ->
               unresolved_memberships = unresolved_memberships(bucket.id)

               bucket =
                 bucket
                 |> Ecto.Changeset.change(flush_state: :claimed, claimed_at: emitted_at)
                 |> Repo.update!()

               {digest_delivery, bucket} =
                 create_digest_delivery!(bucket, unresolved_memberships, emitted_at)

               immediate_deliveries =
                 resolve_memberships!(
                   unresolved_memberships,
                   bucket,
                   digest_delivery.id,
                   emitted_at
                 )

               dispatch_in_transaction(dispatch_mode, digest_delivery, immediate_deliveries)

               bucket =
                 bucket
                 |> Ecto.Changeset.change(
                   flush_state: :emitted,
                   claimed_at: emitted_at,
                   emitted_at: emitted_at,
                   digest_delivery_id: digest_delivery.id
                 )
                 |> Repo.update!()

               {:ok,
                %{
                  bucket: bucket,
                  digest_delivery: digest_delivery,
                  immediate_deliveries: immediate_deliveries
                }}
           end
         end) do
      {:ok,
       %{digest_delivery: digest_delivery, immediate_deliveries: immediate_deliveries} = result} ->
        dispatch_after_commit(dispatch_mode, digest_delivery, immediate_deliveries)
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp bucket_id!(%DigestBucket{id: id}), do: id
  defp bucket_id!(bucket_id) when is_binary(bucket_id), do: bucket_id

  defp lock_bucket!(bucket_id) do
    from(bucket in DigestBucket, where: bucket.id == ^bucket_id, lock: "FOR UPDATE")
    |> Repo.one!()
  end

  defp unresolved_memberships(bucket_id) do
    Repo.all(
      from(membership in DigestMembership,
        where: membership.digest_bucket_id == ^bucket_id and is_nil(membership.resolution),
        preload: [delivery: [notification: :event]]
      )
    )
  end

  defp create_digest_delivery!(bucket, memberships, emitted_at) do
    digest_payload = digest_payload(bucket, memberships, emitted_at)

    {:ok, event} =
      Repo.insert(%Event{
        notification_key: bucket.rule_key,
        notification_version: bucket.rule_version,
        idempotency_key: "digest-bucket:#{bucket.id}",
        payload: %{
          "digest_bucket_id" => bucket.id,
          "digest_window_starts_at" => DateTime.to_iso8601(bucket.window_starts_at),
          "digest_window_ends_at" => DateTime.to_iso8601(bucket.window_ends_at),
          "member_count" => length(memberships)
        }
      })

    {:ok, notification} =
      Repo.insert(%Notification{
        event_id: event.id,
        recipient_identity: bucket.recipient_id,
        recipient_type: digest_recipient_type(memberships),
        metadata: %{"digest_bucket_id" => bucket.id}
      })

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, bucket.channel,
        notification_key: bucket.rule_key,
        event_id: event.id,
        metadata: digest_payload,
        tenant_id: Map.get(bucket, :tenant_id, "default"),
        actor_id: Map.get(bucket, :actor_id, "system")
      )

    {:ok, ready_delivery} =
      Deliveries.apply_planning_decision(delivery, %{
        orchestration_state: :ready,
        planning_reason: nil,
        planning_context: %{
          "digest_bucket_id" => bucket.id,
          "rule_identity" => "#{bucket.rule_key}:v#{bucket.rule_version}",
          "window_starts_at" => DateTime.to_iso8601(bucket.window_starts_at),
          "window_ends_at" => DateTime.to_iso8601(bucket.window_ends_at)
        },
        next_eligible_at: nil
      })

    updated_bucket =
      bucket
      |> Ecto.Changeset.change(digest_delivery_id: ready_delivery.id)
      |> Repo.update!()

    {ready_delivery, updated_bucket}
  rescue
    Ecto.ConstraintError ->
      existing_bucket = Repo.get!(DigestBucket, bucket.id)
      {Repo.get!(Delivery, existing_bucket.digest_delivery_id), existing_bucket}
  end

  defp resolve_memberships!(memberships, bucket, digest_delivery_id, emitted_at) do
    Enum.reduce(memberships, [], fn membership, acc ->
      resolution = resolve_membership(membership)

      membership
      |> DigestMembership.changeset(%{
        resolution: resolution.kind,
        resolution_reason: resolution.reason,
        resolved_at: emitted_at,
        resolved_rule_key: bucket.rule_key,
        resolved_rule_version: bucket.rule_version,
        resolved_window_starts_at: bucket.window_starts_at,
        resolved_window_ends_at: bucket.window_ends_at,
        digest_delivery_id: digest_delivery_id
      })
      |> Repo.update!()

      immediate_delivery =
        case resolution.kind do
          :included ->
            {:ok, _delivery} =
              Deliveries.mark_digested(
                membership.delivery,
                digest_delivery_id,
                resolution.reason,
                resolved_at: emitted_at
              )

            nil

          :skipped_by_policy ->
            {:ok, _delivery} =
              Deliveries.mark_digest_skipped(
                membership.delivery,
                digest_delivery_id,
                resolution.reason,
                resolved_at: emitted_at
              )

            nil

          :emitted_immediately ->
            {:ok, delivery} =
              Deliveries.mark_digest_immediate(
                membership.delivery,
                digest_delivery_id,
                resolution.reason,
                resolved_at: emitted_at
              )

            delivery
        end

      if immediate_delivery, do: [immediate_delivery | acc], else: acc
    end)
    |> Enum.reverse()
  end

  defp resolve_membership(%DigestMembership{
         delivery: %Delivery{planning_context: planning_context}
       })
       when is_map(planning_context) do
    case Map.get(planning_context, "digest_flush_behavior") do
      "skip" ->
        %{
          kind: :skipped_by_policy,
          reason: Map.get(planning_context, "digest_flush_reason", "skipped_by_policy")
        }

      "immediate" ->
        %{
          kind: :emitted_immediately,
          reason: Map.get(planning_context, "digest_flush_reason", "emitted_immediately")
        }

      _ ->
        %{kind: :included, reason: "included_in_digest"}
    end
  end

  defp resolve_membership(_membership), do: %{kind: :included, reason: "included_in_digest"}

  defp digest_payload(bucket, memberships, emitted_at) do
    items =
      memberships
      |> Enum.filter(&(resolve_membership(&1).kind == :included))
      |> Enum.map(fn membership ->
        %{
          "delivery_id" => membership.delivery_id,
          "notification_id" => membership.notification_id,
          "notification_key" => membership.delivery.notification.event.notification_key
        }
      end)

    %{
      "subject" => "Digest for #{bucket.rule_key}",
      "body" => "Digest window closed with #{length(items)} item(s).",
      "summary" => "#{length(items)} notification(s) grouped for #{bucket.channel}",
      "items" => items,
      "digest" => %{
        "bucket_id" => bucket.id,
        "rule_key" => bucket.rule_key,
        "rule_version" => bucket.rule_version,
        "window_starts_at" => DateTime.to_iso8601(bucket.window_starts_at),
        "window_ends_at" => DateTime.to_iso8601(bucket.window_ends_at),
        "emitted_at" => DateTime.to_iso8601(emitted_at)
      }
    }
  end

  defp digest_recipient_type([]), do: "user"

  defp digest_recipient_type([
         %{delivery: %{notification: %{recipient_type: recipient_type}}} | _
       ]),
       do: recipient_type

  defp immediate_deliveries_for_bucket(bucket_id) do
    Repo.all(
      from(delivery in Delivery,
        join: membership in DigestMembership,
        on: membership.delivery_id == delivery.id,
        where:
          membership.digest_bucket_id == ^bucket_id and
            membership.resolution == :emitted_immediately
      )
    )
  end

  defp dispatch_in_transaction(:skip, _digest_delivery, _immediate_deliveries), do: :ok

  defp dispatch_in_transaction(:sync, _digest_delivery, _immediate_deliveries), do: :ok

  defp dispatch_in_transaction(:oban, digest_delivery, immediate_deliveries) do
    enqueue_delivery!(digest_delivery.id)

    Enum.each(immediate_deliveries, fn delivery ->
      enqueue_delivery!(delivery.id)
    end)

    :ok
  end

  defp dispatch_after_commit(:skip, _digest_delivery, _immediate_deliveries), do: :ok

  defp dispatch_after_commit(:oban, _digest_delivery, _immediate_deliveries), do: :ok

  defp dispatch_after_commit(:sync, digest_delivery, immediate_deliveries) do
    dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

    _ = dispatcher.dispatch_delivery(digest_delivery.id, pre_planned: true, post_commit: true)

    Enum.each(immediate_deliveries, fn delivery ->
      _ = dispatcher.dispatch_delivery(delivery.id, pre_planned: true, post_commit: true)
    end)

    :ok
  end

  defp normalize_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> then(&%{&1 | microsecond: {0, 6}})
  end

  defp enqueue_delivery!(delivery_id) do
    Chimeway.Dispatch.ObanWorker.new(%{delivery_id: delivery_id})
    |> Oban.insert!()
  end

  defp default_dispatch_mode do
    case Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync) do
      Chimeway.Dispatch.Oban -> :oban
      _ -> :sync
    end
  end
end
