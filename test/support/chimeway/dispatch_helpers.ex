defmodule Chimeway.Test.DispatchHelpers do
  @moduledoc """
  Factory helpers for async dispatch and delayed fallback tests.
  """

  alias Chimeway.Delivery
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo

  @doc """
  Creates event + notification + delivery in a ready-to-dispatch state.
  """
  def create_pending_delivery(opts \\ []) do
    notification_key = Keyword.get(opts, :notification_key, "test_notifier")
    recipient_identity = Keyword.get(opts, :recipient_identity, "user:#{System.unique_integer()}")
    channel = Keyword.get(opts, :channel, :in_app)
    delay_fallback = Keyword.get(opts, :delay_fallback, false)

    {:ok, event} =
      Repo.insert(%Event{
        notification_key: notification_key,
        notification_version: 1,
        idempotency_key: "test-#{System.unique_integer()}",
        payload: %{}
      })

    {:ok, notification} =
      Repo.insert(%Notification{
        event_id: event.id,
        recipient_identity: recipient_identity,
        recipient_type: "user",
        metadata: %{}
      })

    {:ok, delivery} =
      %Delivery{}
      |> Delivery.changeset(%{
        notification_id: notification.id,
        channel: to_string(channel),
        status: :pending,
        delay_fallback: delay_fallback
      })
      |> Repo.insert()

    %{event: event, notification: notification, delivery: delivery}
  end

  @doc """
  Sets read_at on a notification to simulate in-app read state.
  """
  def mark_notification_read(%{notification: notification}) do
    {:ok, updated} =
      notification
      |> Ecto.Changeset.change(read_at: DateTime.utc_now() |> DateTime.truncate(:microsecond))
      |> Repo.update()

    updated
  end
end
