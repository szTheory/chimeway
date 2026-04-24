defmodule Chimeway.Preferences.NotificationPreference do
  @moduledoc "Per-channel notification preference for a recipient and notification key."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chimeway_notification_preferences" do
    field(:recipient_id, :string)
    field(:notification_key, :string)
    field(:channel, :string)
    field(:enabled, :boolean, default: true)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(recipient_id notification_key channel enabled)a

  def changeset(pref, attrs) do
    pref
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:recipient_id, :notification_key, :channel],
      name: :chimeway_notification_preferences_recipient_key_channel_index
    )
  end
end
