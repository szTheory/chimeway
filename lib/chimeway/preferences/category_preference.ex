defmodule Chimeway.Preferences.CategoryPreference do
  @moduledoc "Per-recipient notification preference for a delivery category."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chimeway_category_preferences" do
    field(:recipient_id, :string)
    field(:notification_category, :string)
    field(:enabled, :boolean, default: true)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(recipient_id notification_category enabled)a

  def changeset(pref, attrs) do
    pref
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_length(:recipient_id, min: 1)
    |> validate_length(:notification_category, min: 1)
    |> unique_constraint([:recipient_id, :notification_category],
      name: :chimeway_category_preferences_recipient_category_index
    )
  end
end
