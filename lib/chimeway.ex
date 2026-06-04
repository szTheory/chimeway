defmodule Chimeway do
  @moduledoc """
  Public entrypoint for notification triggering.
  """

  alias Chimeway.Inbox
  alias Chimeway.Deliveries
  alias Chimeway.Rendering.Preview
  alias Chimeway.Trigger

  @doc """
  Triggers a notifier execution with explicit runtime options.
  """
  def trigger(notifier, params, opts \\ []) do
    Trigger.trigger(notifier, params, opts)
  end

  @doc """
  Previews a single channel rendering without persisting rows or dispatching traffic.
  """
  def preview_rendering(notifier, params, opts \\ []) do
    Preview.preview(notifier, params, opts)
  end

  @doc """
  Recovers a persisted event whose notifications exist but dispatch never planned deliveries.

  Safe operator evidence may be supplied with `:source`, `:reason`,
  `:actor_ref`, and `:confirmation_marker`. Raw session, params, payload,
  provider body, token, authorization, and PII values are ignored by the core
  recovery metadata path.
  """
  def recover_event(event_id, opts \\ []) do
    Deliveries.recover_event(event_id, opts)
  end

  @doc """
  Recovers a persisted delivery by re-driving the canonical row through the configured dispatcher.

  Safe operator evidence may be supplied with `:source`, `:reason`,
  `:actor_ref`, and `:confirmation_marker`. Raw session, params, payload,
  provider body, token, authorization, and PII values are ignored by the core
  recovery metadata path.
  """
  def recover_delivery(delivery_id, opts \\ []) do
    Deliveries.recover_delivery(delivery_id, opts)
  end

  @doc """
  Lists notifications for a recipient, newest first.

  Without pagination opts returns `[ %Notification{} ]`. With `:limit`, cursor opts,
  or `:paginate, true`, returns `%{items: [dto_map], has_more: boolean}`.
  """
  def list_for_recipient(recipient_identity, opts \\ []) do
    Inbox.list_for_recipient(recipient_identity, opts)
  end

  @doc """
  Returns the count of unread notifications for a recipient.

  Honors `:exclude_archived` (default `true`).
  """
  def unread_count(recipient_identity, opts \\ []) do
    Inbox.unread_count(recipient_identity, opts)
  end

  @doc """
  Marks a notification as seen for a specific recipient.
  """
  def mark_seen(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    Inbox.mark_seen(notification_id, recipient_identity, at)
  end

  @doc """
  Marks a notification as read for a specific recipient.
  """
  def mark_read(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    Inbox.mark_read(notification_id, recipient_identity, at)
  end

  @doc """
  Archives a notification for a specific recipient.
  """
  def archive(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    Inbox.archive(notification_id, recipient_identity, at)
  end
end
