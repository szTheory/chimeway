defmodule Chimeway.Inbox do
  @moduledoc """
  Inbox query and explicit lifecycle transition APIs.
  """

  import Ecto.Query

  alias Chimeway.Delivery
  alias Chimeway.Inbox.Item
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Signal
  alias Chimeway.Workflows.WorkflowRun

  @read_event "chimeway.notification.read"
  @seen_event "chimeway.notification.seen"

  @spec list_for_recipient(String.t(), keyword()) :: [Notification.t()] | %{items: [map()], has_more: boolean()}
  def list_for_recipient(recipient_identity, opts \\ []) when is_binary(recipient_identity) do
    if paginated?(opts) do
      list_for_recipient_paginated(recipient_identity, opts)
    else
      list_for_recipient_legacy(recipient_identity, opts)
    end
  end

  @spec unread_count(String.t(), keyword()) :: non_neg_integer()
  def unread_count(recipient_identity, opts \\ []) when is_binary(recipient_identity) do
    exclude_archived = exclude_archived?(opts)

    Notification
    |> base_recipient_query(recipient_identity)
    |> where([notification], is_nil(notification.read_at))
    |> maybe_exclude_archived(exclude_archived)
    |> select([notification], count(notification.id))
    |> Repo.one!()
  end

  @spec mark_seen(Ecto.UUID.t(), String.t(), DateTime.t()) :: :ok | {:error, :not_found}
  def mark_seen(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    update_lifecycle_timestamp(notification_id, recipient_identity, :seen_at, at, @seen_event)
  end

  @spec mark_read(Ecto.UUID.t(), String.t(), DateTime.t()) :: :ok | {:error, :not_found}
  def mark_read(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    update_lifecycle_timestamp(notification_id, recipient_identity, :read_at, at, @read_event)
  end

  @spec archive(Ecto.UUID.t(), String.t(), DateTime.t()) :: :ok | {:error, :not_found}
  def archive(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    update_lifecycle_timestamp(notification_id, recipient_identity, :archived_at, at)
  end

  defp list_for_recipient_legacy(recipient_identity, opts) do
    unread_only? = Keyword.get(opts, :unread_only, false)
    exclude_archived = exclude_archived?(opts)

    Notification
    |> base_recipient_query(recipient_identity)
    |> maybe_exclude_archived(exclude_archived)
    |> maybe_filter_unread(unread_only?)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  defp list_for_recipient_paginated(recipient_identity, opts) do
    limit = Keyword.get(opts, :limit, 20)
    unread_only? = Keyword.get(opts, :unread_only, false)
    exclude_archived = exclude_archived?(opts)

    query =
      Notification
      |> base_recipient_query(recipient_identity)
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

  defp base_recipient_query(query, recipient_identity) do
    where(query, [notification], notification.recipient_identity == ^recipient_identity)
  end

  defp exclude_archived?(opts), do: Keyword.get(opts, :exclude_archived, true)

  defp maybe_exclude_archived(query, true),
    do: where(query, [notification], is_nil(notification.archived_at))

  defp maybe_exclude_archived(query, _false), do: query

  defp maybe_filter_unread(query, true),
    do: where(query, [notification], is_nil(notification.read_at))

  defp maybe_filter_unread(query, _false), do: query

  defp update_lifecycle_timestamp(notification_id, recipient_identity, field, at) do
    timestamp = DateTime.truncate(at, :microsecond)

    query =
      Notification
      |> where([notification], notification.id == ^notification_id)
      |> where([notification], notification.recipient_identity == ^recipient_identity)

    case Repo.update_all(query, set: [{field, timestamp}, {:updated_at, timestamp}]) do
      {1, _} -> :ok
      _other -> {:error, :not_found}
    end
  end

  defp update_lifecycle_timestamp(notification_id, recipient_identity, field, at, event_name) do
    timestamp = DateTime.truncate(at, :microsecond)

    first_transition_query =
      Notification
      |> where([n], n.id == ^notification_id)
      |> where([n], n.recipient_identity == ^recipient_identity)
      |> where([n], is_nil(field(n, ^field)))

    case Repo.update_all(first_transition_query, set: [{field, timestamp}, {:updated_at, timestamp}]) do
      {1, _} ->
        maybe_emit_inbox_signal(notification_id, recipient_identity, event_name)
        :ok

      {0, _} ->
        case Repo.get_by(Notification, id: notification_id, recipient_identity: recipient_identity) do
          %Notification{} = notification ->
            if is_nil(Map.get(notification, field)), do: {:error, :not_found}, else: :ok

          nil ->
            {:error, :not_found}
        end
    end
  end

  defp maybe_emit_inbox_signal(notification_id, recipient_identity, event_name) do
    case resolve_tenant_id(notification_id) do
      nil -> :ok
      tenant_id -> emit_inbox_signal(tenant_id, recipient_identity, notification_id, event_name)
    end
  end

  defp resolve_tenant_id(notification_id) do
    workflow_tenant =
      Repo.one(
        from wr in WorkflowRun,
          where: wr.notification_id == ^notification_id,
          select: wr.tenant_id,
          limit: 1
      )

    workflow_tenant ||
      Repo.one(
        from d in Delivery,
          where: d.notification_id == ^notification_id,
          order_by: [asc: d.inserted_at],
          select: d.tenant_id,
          limit: 1
      )
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
