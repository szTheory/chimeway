defmodule Chimeway do
  @moduledoc """
  Public entrypoint for notification triggering.
  """

  @doc """
  Triggers a notifier execution with explicit runtime options.
  """
  def trigger(notifier, params, opts \\ []) do
    Chimeway.Trigger.trigger(notifier, params, opts)
  end

  @doc """
  Lists notifications for a recipient, newest first.
  """
  def list_for_recipient(recipient_identity, opts \\ []) do
    Chimeway.Inbox.list_for_recipient(recipient_identity, opts)
  end

  @doc """
  Marks a notification as seen for a specific recipient.
  """
  def mark_seen(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    Chimeway.Inbox.mark_seen(notification_id, recipient_identity, at)
  end

  @doc """
  Marks a notification as read for a specific recipient.
  """
  def mark_read(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    Chimeway.Inbox.mark_read(notification_id, recipient_identity, at)
  end

  @doc """
  Archives a notification for a specific recipient.
  """
  def archive(notification_id, recipient_identity, at \\ DateTime.utc_now()) do
    Chimeway.Inbox.archive(notification_id, recipient_identity, at)
  end
end
