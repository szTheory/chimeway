defmodule Chimeway.Inbox do
  @moduledoc """
  Inbox query and explicit lifecycle transition APIs.
  """

  import Ecto.Query

  alias Chimeway.Inbox.Item
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Signal
  alias Chimeway.TenantScope

  @read_event "chimeway.notification.read"
  @seen_event "chimeway.notification.seen"

  def list_for_recipient(recipient_identity, opts \\ []) when is_binary(recipient_identity) do
    with {:ok, tenant_id} <- TenantScope.resolve(opts) do
      if paginated?(opts) do
        list_for_recipient_paginated(recipient_identity, tenant_id, opts)
      else
        list_for_recipient_legacy(recipient_identity, tenant_id, opts)
      end
    end
  end

  def unread_count(recipient_identity, opts \\ []) when is_binary(recipient_identity) do
    with {:ok, tenant_id} <- TenantScope.resolve(opts) do
      exclude_archived = exclude_archived?(opts)

      Notification
      |> base_recipient_query(recipient_identity, tenant_id)
      |> where([notification], is_nil(notification.read_at))
      |> maybe_exclude_archived(exclude_archived)
      |> select([notification], count(notification.id))
      |> Repo.one!()
    end
  end

  def mark_seen(notification_id, recipient_identity),
    do: mark_seen(notification_id, recipient_identity, [])

  def mark_seen(notification_id, recipient_identity, opts) when is_list(opts),
    do: transition(notification_id, recipient_identity, opts, :seen_at, @seen_event)

  def mark_seen(notification_id, recipient_identity, %DateTime{} = at),
    do: transition(notification_id, recipient_identity, [], :seen_at, @seen_event, at)

  def mark_read(notification_id, recipient_identity),
    do: mark_read(notification_id, recipient_identity, [])

  def mark_read(notification_id, recipient_identity, opts) when is_list(opts),
    do: transition(notification_id, recipient_identity, opts, :read_at, @read_event)

  def mark_read(notification_id, recipient_identity, %DateTime{} = at),
    do: transition(notification_id, recipient_identity, [], :read_at, @read_event, at)

  def archive(notification_id, recipient_identity),
    do: archive(notification_id, recipient_identity, [])

  def archive(notification_id, recipient_identity, opts) when is_list(opts),
    do: transition(notification_id, recipient_identity, opts, :archived_at)

  def archive(notification_id, recipient_identity, %DateTime{} = at),
    do: transition(notification_id, recipient_identity, [], :archived_at, nil, at)

  defp transition(notification_id, recipient_identity, opts, field, event_name \\ nil, at \\ nil) do
    with {:ok, tenant_id} <- TenantScope.resolve(opts) do
      at = at || Keyword.get(opts, :at, DateTime.utc_now())

      update_lifecycle_timestamp(
        notification_id,
        recipient_identity,
        tenant_id,
        field,
        at,
        event_name
      )
    end
  end

  defp list_for_recipient_legacy(recipient_identity, tenant_id, opts) do
    unread_only? = Keyword.get(opts, :unread_only, false)
    exclude_archived = exclude_archived?(opts)

    Notification
    |> base_recipient_query(recipient_identity, tenant_id)
    |> maybe_exclude_archived(exclude_archived)
    |> maybe_filter_unread(unread_only?)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  defp list_for_recipient_paginated(recipient_identity, tenant_id, opts) do
    limit = Keyword.get(opts, :limit, 20)
    unread_only? = Keyword.get(opts, :unread_only, false)
    exclude_archived = exclude_archived?(opts)

    query =
      Notification
      |> base_recipient_query(recipient_identity, tenant_id)
      |> maybe_exclude_archived(exclude_archived)
      |> maybe_filter_unread(unread_only?)
      |> order_by([notification], desc: notification.inserted_at, desc: notification.id)
      |> maybe_apply_cursor(opts)
      |> limit(^limit + 1)

    rows = Repo.all(query)
    has_more = length(rows) > limit
    items = rows |> Enum.take(limit) |> Enum.map(&Item.to_map/1)

    %{items: items, has_more: has_more}
  end

  defp paginated?(opts) do
    Keyword.has_key?(opts, :limit) or
      Keyword.has_key?(opts, :before_inserted_at) or
      Keyword.has_key?(opts, :before_id) or
      Keyword.get(opts, :paginate) == true
  end

  defp maybe_apply_cursor(query, opts) do
    with ts when not is_nil(ts) <- Keyword.get(opts, :before_inserted_at),
         id when not is_nil(id) <- Keyword.get(opts, :before_id),
         {:ok, uuid} <- Ecto.UUID.cast(id) do
      truncated_ts = DateTime.truncate(ts, :microsecond)

      where(
        query,
        [notification],
        notification.inserted_at < ^truncated_ts or
          (notification.inserted_at == ^truncated_ts and notification.id < ^uuid)
      )
    else
      _ -> query
    end
  end

  defp base_recipient_query(query, recipient_identity, tenant_id) do
    where(
      query,
      [notification],
      notification.recipient_identity == ^recipient_identity and
        notification.tenant_id == ^tenant_id
    )
  end

  defp exclude_archived?(opts), do: Keyword.get(opts, :exclude_archived, true)

  defp maybe_exclude_archived(query, true),
    do: where(query, [notification], is_nil(notification.archived_at))

  defp maybe_exclude_archived(query, _false), do: query

  defp maybe_filter_unread(query, true),
    do: where(query, [notification], is_nil(notification.read_at))

  defp maybe_filter_unread(query, _false), do: query

  defp update_lifecycle_timestamp(notification_id, recipient_identity, tenant_id, field, at, nil) do
    timestamp = DateTime.truncate(at, :microsecond)

    query =
      Notification
      |> where([notification], notification.id == ^notification_id)
      |> where([notification], notification.recipient_identity == ^recipient_identity)
      |> where([notification], notification.tenant_id == ^tenant_id)

    case Repo.update_all(query, set: [{field, timestamp}, {:updated_at, timestamp}]) do
      {1, _} -> :ok
      _other -> {:error, :not_found}
    end
  end

  defp update_lifecycle_timestamp(
         notification_id,
         recipient_identity,
         tenant_id,
         field,
         at,
         event_name
       ) do
    timestamp = DateTime.truncate(at, :microsecond)

    first_transition_query =
      Notification
      |> where([n], n.id == ^notification_id)
      |> where([n], n.recipient_identity == ^recipient_identity)
      |> where([n], n.tenant_id == ^tenant_id)
      |> where([n], is_nil(field(n, ^field)))

    case Repo.update_all(first_transition_query,
           set: [{field, timestamp}, {:updated_at, timestamp}]
         ) do
      {1, _} ->
        maybe_emit_inbox_signal(notification_id, recipient_identity, tenant_id, event_name)
        :ok

      {0, _} ->
        case Repo.get_by(Notification,
               id: notification_id,
               recipient_identity: recipient_identity,
               tenant_id: tenant_id
             ) do
          %Notification{} = notification ->
            if is_nil(Map.get(notification, field)), do: {:error, :not_found}, else: :ok

          nil ->
            {:error, :not_found}
        end
    end
  end

  defp maybe_emit_inbox_signal(notification_id, recipient_identity, tenant_id, event_name) do
    emit_inbox_signal(tenant_id, recipient_identity, notification_id, event_name)
  end

  defp emit_inbox_signal(tenant_id, recipient_identity, notification_id, event_name) do
    Signal.track(
      tenant_id,
      recipient_identity,
      event_name,
      %{"notification_id" => notification_id}
    )

    :ok
  end
end
