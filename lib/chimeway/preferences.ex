defmodule Chimeway.Preferences do
  @moduledoc """
  Public context for notification preference management.

  Preferences are keyed by (recipient_id, notification_key, channel).
  `recipient_id` is the same string as `recipient_identity` on notification rows.

  Missing preferences default to enabled — channels are opt-in by default.
  """

  alias Chimeway.{Preferences.CategoryPreference, Preferences.NotificationPreference, Repo}

  @doc """
  Upserts a preference. On conflict, updates :enabled and :updated_at.
  """
  @spec upsert_preference(map()) ::
          {:ok, NotificationPreference.t()} | {:error, Ecto.Changeset.t()}
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

  @doc """
  Upserts a category preference. On conflict, updates :enabled and :updated_at.
  """
  @spec upsert_category_preference(map()) ::
          {:ok, CategoryPreference.t()} | {:error, Ecto.Changeset.t()}
  def upsert_category_preference(attrs) do
    %CategoryPreference{}
    |> CategoryPreference.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:enabled, :updated_at]},
      conflict_target: [:recipient_id, :notification_category]
    )
  end

  @doc """
  Fetches the category preference row for the given recipient/category, or nil.
  """
  @spec get_category_preference(String.t(), String.t()) :: CategoryPreference.t() | nil
  def get_category_preference(recipient_id, notification_category) do
    Repo.get_by(CategoryPreference,
      recipient_id: recipient_id,
      notification_category: notification_category
    )
  end

  @doc """
  Returns true if the category is enabled for the recipient — defaults to true
  when no preference row exists (opt-in default).
  """
  @spec category_enabled?(String.t(), String.t()) :: boolean()
  def category_enabled?(recipient_id, notification_category) do
    case get_category_preference(recipient_id, notification_category) do
      nil -> true
      pref -> pref.enabled
    end
  end
end
