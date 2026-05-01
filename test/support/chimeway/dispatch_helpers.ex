defmodule Chimeway.Test.DispatchHelpers do
  @moduledoc """
  Factory helpers for async dispatch and delayed fallback tests.
  """

  import Ecto.Query, only: [from: 2]

  alias Chimeway.Delivery
  alias Chimeway.DeliveryAttempt
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Preferences
  alias Chimeway.Repo

  @doc """
  Creates a persisted event + notification pair for dispatcher tests.
  """
  def create_notification(opts \\ []) do
    notification_key = Keyword.get(opts, :notification_key, "test_notifier")
    recipient_identity = Keyword.get(opts, :recipient_identity, "user:#{System.unique_integer()}")
    recipient_type = Keyword.get(opts, :recipient_type, "user")
    payload = Keyword.get(opts, :payload, %{})
    metadata = Keyword.get(opts, :metadata, %{})

    {:ok, event} =
      Repo.insert(%Event{
        notification_key: notification_key,
        notification_version: 1,
        idempotency_key: "test-#{System.unique_integer()}",
        payload: payload
      })

    {:ok, notification} =
      Repo.insert(%Notification{
        event_id: event.id,
        recipient_identity: recipient_identity,
        recipient_type: recipient_type,
        metadata: metadata,
        render_assigns: %{
          "headline" => "test headline",
          "body" => "test body",
          "primary_action" => %{"label" => "test", "url" => "http://test.com"},
          "subject" => "test subject",
          "html_body" => "<p>test</p>",
          "text_body" => "test"
        },
        render_channels: %{
          "email" => %{"render_key" => "test", "render_version" => 1},
          "in_app" => %{"render_key" => "test", "render_version" => 1},
          "sms_custom" => %{"render_key" => "test", "render_version" => 1}
        }
      })

    %{event: event, notification: notification}
  end

  @doc """
  Disables a recipient channel preference for the fixture's event notification_key.
  """
  def disable_channel_preference(%{event: event, notification: notification}, channel \\ :in_app) do
    Preferences.upsert_preference(%{
      recipient_id: notification.recipient_identity,
      notification_key: event.notification_key,
      channel: to_string(channel),
      enabled: false
    })
  end

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
        metadata: %{},
        render_assigns: %{
          "headline" => "test headline",
          "body" => "test body",
          "primary_action" => %{"label" => "test", "url" => "http://test.com"},
          "subject" => "test subject",
          "html_body" => "<p>test</p>",
          "text_body" => "test"
        },
        render_channels: %{
          "email" => %{"render_key" => "test", "render_version" => 1},
          "in_app" => %{"render_key" => "test", "render_version" => 1},
          "sms_custom" => %{"render_key" => "test", "render_version" => 1}
        }
      })

    {:ok, delivery} =
      %Delivery{}
      |> Delivery.changeset(%{
        notification_id: notification.id,
        channel: to_string(channel),
        status: :pending,
        delay_fallback: delay_fallback,
        tenant_id: "default",
        actor_id: "system"
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

  @doc """
  Normalized assertion shape used by sync/Oban parity tests.
  """
  def delivery_signature(%Delivery{} = delivery) do
    attempt_count =
      Repo.aggregate(
        from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id),
        :count,
        :id
      )

    %{
      status: delivery.status,
      suppression_reason: delivery.suppression_reason,
      policy_checkpoint: get_in(delivery.metadata || %{}, ["policy_checkpoint"]),
      attempt_count: attempt_count
    }
  end

  @doc """
  Canonical suppression signature for delayed-fallback already-read outcomes.
  """
  def already_read_suppression_signature do
    %{
      status: :suppressed,
      suppression_reason: "already_read",
      policy_checkpoint: "perform",
      attempt_count: 0
    }
  end
end
