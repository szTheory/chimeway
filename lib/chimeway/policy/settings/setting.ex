defmodule Chimeway.Policy.Settings.Setting do
  @moduledoc "Per-recipient policy settings for quiet hours and delivery caps."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chimeway_policy_settings" do
    field(:recipient_id, :string)
    field(:quiet_hours_start_minute, :integer)
    field(:quiet_hours_end_minute, :integer)
    field(:delivery_cap_count, :integer)
    field(:delivery_cap_window_minutes, :integer)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(recipient_id)a
  @optional_fields ~w(quiet_hours_start_minute quiet_hours_end_minute delivery_cap_count delivery_cap_window_minutes)a

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:quiet_hours_start_minute, greater_than_or_equal_to: 0, less_than: 1440)
    |> validate_number(:quiet_hours_end_minute, greater_than_or_equal_to: 0, less_than: 1440)
    |> validate_number(:delivery_cap_count, greater_than: 0)
    |> validate_number(:delivery_cap_window_minutes, greater_than: 0)
    |> unique_constraint(:recipient_id, name: :chimeway_policy_settings_recipient_index)
  end
end
