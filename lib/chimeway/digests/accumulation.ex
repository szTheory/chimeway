defmodule Chimeway.Digests.Accumulation do
  @moduledoc "Transactional digest accumulation for held canonical delivery rows."

  import Ecto.Query, only: [from: 2]

  alias Chimeway.{Delivery, Repo}
  alias Chimeway.Digests
  alias Chimeway.Digests.{DigestBucket, DigestMembership, DigestRule}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  @bucket_conflict_target [
    :digest_rule_id,
    :recipient_id,
    :channel,
    :grouping_value,
    :window_starts_at,
    :window_ends_at
  ]

  @doc """
  Accumulates a digest-held delivery into a durable bucket and membership row.
  """
  @spec accumulate_delivery(Delivery.t(), keyword()) ::
          {:ok, DigestBucket.t() | :noop} | {:error, term()}
  def accumulate_delivery(%Delivery{} = delivery, opts \\ []) when is_list(opts) do
    accumulated_at =
      opts
      |> Keyword.get(:accumulated_at, DateTime.utc_now())
      |> normalize_datetime()

    case Repo.transact(fn ->
           locked_delivery = lock_delivery!(delivery.id)

           if accumulatable?(locked_delivery) do
             {:ok, do_accumulate(locked_delivery, accumulated_at)}
           else
             {:ok, :noop}
           end
         end) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_accumulate(%Delivery{} = delivery, accumulated_at) do
    %{notification: notification, event: event} = load_context!(delivery)
    category = event_category(event)
    digest_key = digest_key(delivery)

    case Digests.find_matching_rule(%{
           channel: delivery.channel,
           notification_key: event.notification_key,
           category: category,
           digest_key: digest_key
         }) do
      nil ->
        :noop

      %DigestRule{} = rule ->
        grouping_value = grouping_value!(rule, event, category, digest_key)
        {window_starts_at, window_ends_at} = derive_window!(rule, accumulated_at)

        bucket =
          upsert_bucket!(
            rule,
            notification.recipient_identity,
            delivery.channel,
            grouping_value,
            window_starts_at,
            window_ends_at
          )

        case insert_membership(bucket, delivery, accumulated_at) do
          :inserted -> refresh_bucket!(bucket.id)
          :existing -> refresh_bucket!(bucket.id)
        end
    end
  end

  defp lock_delivery!(delivery_id) do
    from(d in Delivery, where: d.id == ^delivery_id, lock: "FOR UPDATE")
    |> Repo.one!()
  end

  defp accumulatable?(%Delivery{status: :pending, orchestration_state: :digest_held}), do: true
  defp accumulatable?(_delivery), do: false

  defp load_context!(%Delivery{notification_id: notification_id}) do
    notification = Repo.get!(Notification, notification_id)
    event = Repo.get!(Event, notification.event_id)

    %{notification: notification, event: event}
  end

  defp event_category(%Event{payload: payload}) when is_map(payload) do
    case Map.get(payload, "category") do
      category when is_binary(category) and category != "" -> category
      _ -> nil
    end
  end

  defp event_category(_event), do: nil

  defp digest_key(%Delivery{planning_context: planning_context}) when is_map(planning_context) do
    case Map.get(planning_context, "digest_key") do
      digest_key when is_binary(digest_key) and digest_key != "" -> digest_key
      _ -> nil
    end
  end

  defp digest_key(_delivery), do: nil

  defp grouping_value!(
         %DigestRule{group_by: :notification_key},
         %Event{notification_key: key},
         _,
         _
       ),
       do: key

  defp grouping_value!(%DigestRule{group_by: :category}, _event, category, _)
       when is_binary(category),
       do: category

  defp grouping_value!(%DigestRule{group_by: :digest_key}, _event, _category, digest_key)
       when is_binary(digest_key),
       do: digest_key

  defp grouping_value!(%DigestRule{group_by: group_by}, _event, _category, _digest_key) do
    Repo.rollback({:missing_grouping_value, group_by})
  end

  defp derive_window!(
         %DigestRule{window_kind: :fixed, window_minutes: window_minutes},
         accumulated_at
       ) do
    window_seconds = window_minutes * 60
    start_unix = div(DateTime.to_unix(accumulated_at, :second), window_seconds) * window_seconds
    window_starts_at = DateTime.from_unix!(start_unix, :second)
    window_ends_at = DateTime.add(window_starts_at, window_seconds, :second)

    {window_starts_at, window_ends_at}
  end

  defp derive_window!(
         %DigestRule{
           window_kind: :boundary,
           boundary_hour: boundary_hour,
           boundary_minute: boundary_minute,
           boundary_time_zone: boundary_time_zone
         },
         accumulated_at
       ) do
    {:ok, local_accumulated_at} =
      DateTime.shift_zone(accumulated_at, boundary_time_zone, time_zone_database())

    boundary_date = DateTime.to_date(local_accumulated_at)

    boundary_today =
      local_boundary_to_utc!(boundary_date, boundary_hour, boundary_minute, boundary_time_zone)

    if DateTime.compare(accumulated_at, boundary_today) == :lt do
      previous_boundary =
        boundary_date
        |> Date.add(-1)
        |> local_boundary_to_utc!(boundary_hour, boundary_minute, boundary_time_zone)

      {previous_boundary, boundary_today}
    else
      next_boundary =
        boundary_date
        |> Date.add(1)
        |> local_boundary_to_utc!(boundary_hour, boundary_minute, boundary_time_zone)

      {boundary_today, next_boundary}
    end
  end

  defp upsert_bucket!(
         %DigestRule{} = rule,
         recipient_id,
         channel,
         grouping_value,
         window_starts_at,
         window_ends_at
       ) do
    attrs = %{
      digest_rule_id: rule.id,
      rule_key: rule.rule_key,
      rule_version: rule.rule_version,
      recipient_id: recipient_id,
      channel: channel,
      grouping_mode: rule.group_by,
      grouping_value: grouping_value,
      window_kind: rule.window_kind,
      window_starts_at: window_starts_at,
      window_ends_at: window_ends_at
    }

    %DigestBucket{}
    |> DigestBucket.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: @bucket_conflict_target)

    Repo.get_by!(DigestBucket,
      digest_rule_id: rule.id,
      recipient_id: recipient_id,
      channel: channel,
      grouping_value: grouping_value,
      window_starts_at: window_starts_at,
      window_ends_at: window_ends_at
    )
  end

  defp insert_membership(%DigestBucket{} = bucket, %Delivery{} = delivery, accumulated_at) do
    {inserted_count, _rows} =
      Repo.insert_all(
        DigestMembership,
        [
          %{
            id: Ecto.UUID.generate(),
            digest_bucket_id: bucket.id,
            delivery_id: delivery.id,
            notification_id: delivery.notification_id,
            inserted_at: accumulated_at,
            updated_at: accumulated_at
          }
        ],
        on_conflict: :nothing,
        conflict_target: [:delivery_id]
      )

    if inserted_count == 1 do
      increment_bucket!(bucket.id, accumulated_at)
      :inserted
    else
      :existing
    end
  end

  defp increment_bucket!(bucket_id, accumulated_at) do
    from(b in DigestBucket,
      where: b.id == ^bucket_id,
      update: [
        inc: [member_count: 1],
        set: [
          first_accumulated_at:
            fragment("COALESCE(?, ?)", b.first_accumulated_at, ^accumulated_at),
          last_accumulated_at: ^accumulated_at,
          updated_at: ^accumulated_at
        ]
      ]
    )
    |> Repo.update_all([])
  end

  defp refresh_bucket!(bucket_id), do: Repo.get!(DigestBucket, bucket_id)

  defp local_boundary_to_utc!(date, boundary_hour, boundary_minute, boundary_time_zone) do
    naive_datetime = NaiveDateTime.new!(date, Time.new!(boundary_hour, boundary_minute, 0))

    local_datetime =
      case DateTime.from_naive(naive_datetime, boundary_time_zone, time_zone_database()) do
        {:ok, datetime} -> datetime
        {:ambiguous, _first, second} -> second
        {:gap, _before, first_after_gap} -> first_after_gap
        {:error, reason} -> Repo.rollback({:invalid_boundary_time_zone, reason})
      end

    case DateTime.shift_zone(local_datetime, "Etc/UTC", time_zone_database()) do
      {:ok, datetime} -> normalize_datetime(datetime)
      {:error, reason} -> Repo.rollback({:invalid_boundary_time_zone, reason})
    end
  end

  defp normalize_datetime(%DateTime{} = datetime) do
    %{DateTime.truncate(datetime, :second) | microsecond: {0, 6}}
  end

  defp time_zone_database do
    Application.get_env(:chimeway, :time_zone_database, Calendar.get_time_zone_database())
  end
end
