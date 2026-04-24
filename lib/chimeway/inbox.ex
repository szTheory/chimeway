defmodule Chimeway.Inbox do
  @moduledoc """
  Inbox query and explicit lifecycle transition APIs.
  """

  import Ecto.Query

  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo

  @spec list_for_recipient(String.t(), keyword()) :: [map()]
  def list_for_recipient(recipient_identity, opts \\ []) when is_binary(recipient_identity) do
    unread_only? = Keyword.get(opts, :unread_only, false)

    Notification
    |> where([notification], notification.recipient_identity == ^recipient_identity)
    |> maybe_filter_unread(unread_only?)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @spec mark_seen(Ecto.UUID.t(), String.t(), DateTime.t()) :: :ok | {:error, :not_found}
  def mark_seen(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    update_lifecycle_timestamp(notification_id, recipient_identity, :seen_at, at)
  end

  @spec mark_read(Ecto.UUID.t(), String.t(), DateTime.t()) :: :ok | {:error, :not_found}
  def mark_read(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    update_lifecycle_timestamp(notification_id, recipient_identity, :read_at, at)
  end

  @spec archive(Ecto.UUID.t(), String.t(), DateTime.t()) :: :ok | {:error, :not_found}
  def archive(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    update_lifecycle_timestamp(notification_id, recipient_identity, :archived_at, at)
  end

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
end
