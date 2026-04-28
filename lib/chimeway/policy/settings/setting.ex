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
    field(:time_zone, :string)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(recipient_id)a
  @optional_fields ~w(
    quiet_hours_start_minute
    quiet_hours_end_minute
    delivery_cap_count
    delivery_cap_window_minutes
    time_zone
  )a

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:quiet_hours_start_minute, greater_than_or_equal_to: 0, less_than: 1440)
    |> validate_number(:quiet_hours_end_minute, greater_than_or_equal_to: 0, less_than: 1440)
    |> validate_number(:delivery_cap_count, greater_than: 0)
    |> validate_number(:delivery_cap_window_minutes, greater_than: 0)
    |> validate_quiet_hours_pair()
    |> validate_time_zone()
    |> unique_constraint(:recipient_id, name: :chimeway_policy_settings_recipient_index)
  end

  defp validate_quiet_hours_pair(changeset) do
    start_minute = get_field(changeset, :quiet_hours_start_minute)
    end_minute = get_field(changeset, :quiet_hours_end_minute)

    if is_nil(start_minute) == is_nil(end_minute) do
      changeset
    else
      changeset
      |> add_error(:quiet_hours_start_minute, "must be set together with quiet_hours_end_minute")
      |> add_error(:quiet_hours_end_minute, "must be set together with quiet_hours_start_minute")
    end
  end

  defp validate_time_zone(changeset) do
    validate_change(changeset, :time_zone, fn :time_zone, time_zone ->
      if valid_time_zone?(time_zone) do
        []
      else
        [time_zone: "is invalid"]
      end
    end)
  end

  defp valid_time_zone?(time_zone) when is_binary(time_zone) and byte_size(time_zone) > 0 do
    match?({:ok, _}, DateTime.now(time_zone, time_zone_database()))
  end

  defp valid_time_zone?(_time_zone), do: false

  defp time_zone_database do
    Application.get_env(:chimeway, :time_zone_database, Calendar.get_time_zone_database())
  end
end
