defmodule Chimeway.Preferences do
  @moduledoc """
  Public context for notification preference management.

  Preferences are keyed by (recipient_id, notification_key, channel).
  `recipient_id` is the same string as `recipient_identity` on notification rows.

  Missing preferences default to enabled — channels are opt-in by default.
  """

  alias Chimeway.{Preferences.NotificationPreference, Repo}

  @doc """
  Upserts a preference. On conflict, updates :enabled and :updated_at.
  """
  @spec upsert_preference(map()) :: {:ok, NotificationPreference.t()} | {:error, Ecto.Changeset.t()}
  def upsert_preference(attrs) do
    %NotificationPreference{}
    |> NotificationPreference.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:enabled, :updated_at]},
      conflict_target: [:recipient_id, :notification_key, :channel]
    )
  end

  @doc """
  Fetches the preference row for the given recipient/key/channel, or nil.
  """
  @spec get_preference(String.t(), String.t(), String.t()) :: NotificationPreference.t() | nil
  def get_preference(recipient_id, notification_key, channel) do
    Repo.get_by(NotificationPreference,
      recipient_id: recipient_id,
      notification_key: notification_key,
      channel: channel
    )
  end

  @doc """
  Returns true if the channel is enabled for the recipient/key — defaults to
  true when no preference row exists (opt-in default).
  """
  @spec channel_enabled?(String.t(), String.t(), String.t()) :: boolean()
  def channel_enabled?(recipient_id, notification_key, channel) do
    case get_preference(recipient_id, notification_key, channel) do
      nil -> true
      pref -> pref.enabled
    end
  end
end
