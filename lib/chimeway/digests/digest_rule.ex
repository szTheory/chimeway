defmodule Chimeway.Digests.DigestRule do
  @moduledoc "Durable digest rule storage for stable identity, grouping mode, and window semantics."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @group_by_values [:notification_key, :category, :digest_key]
  @window_kind_values [:fixed, :boundary]

  schema "chimeway_digest_rules" do
    field(:rule_key, :string)
    field(:rule_version, :integer)
    field(:channel, :string)
    field(:match_notification_key, :string)
    field(:match_category, :string)
    field(:group_by, Ecto.Enum, values: @group_by_values)
    field(:window_kind, Ecto.Enum, values: @window_kind_values)
    field(:window_minutes, :integer)
    field(:boundary_hour, :integer)
    field(:boundary_minute, :integer)
    field(:boundary_time_zone, :string)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(rule_key rule_version channel group_by window_kind)a
  @optional_fields ~w(
    match_notification_key
    match_category
    window_minutes
    boundary_hour
    boundary_minute
    boundary_time_zone
  )a

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:rule_version, greater_than: 0)
    |> validate_inclusion(:group_by, @group_by_values)
    |> validate_inclusion(:window_kind, @window_kind_values)
    |> validate_window_requirements()
    |> validate_boundary_time_zone()
    |> unique_constraint([:rule_key, :rule_version],
      name: :chimeway_digest_rules_rule_key_rule_version_index
    )
  end

  defp validate_window_requirements(changeset) do
    case get_field(changeset, :window_kind) do
      :fixed ->
        changeset
        |> validate_required([:window_minutes])
        |> validate_number(:window_minutes, greater_than: 0)

      :boundary ->
        changeset
        |> validate_required([:boundary_hour, :boundary_minute, :boundary_time_zone])
        |> validate_number(:boundary_hour, greater_than_or_equal_to: 0, less_than: 24)
        |> validate_number(:boundary_minute, greater_than_or_equal_to: 0, less_than: 60)

      _ ->
        changeset
    end
  end

  defp validate_boundary_time_zone(changeset) do
    validate_change(changeset, :boundary_time_zone, fn :boundary_time_zone, time_zone ->
      if valid_time_zone?(time_zone) do
        []
      else
        [boundary_time_zone: "is invalid"]
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
