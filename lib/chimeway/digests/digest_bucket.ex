defmodule Chimeway.Digests.DigestBucket do
  @moduledoc "Durable digest bucket storage keyed by rule, recipient, channel, grouping value, and window."

  use Ecto.Schema
  import Ecto.Changeset

  alias Chimeway.Digests.DigestRule

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @grouping_mode_values [:notification_key, :category, :digest_key]
  @window_kind_values [:fixed, :boundary]

  schema "chimeway_digest_buckets" do
    field(:rule_key, :string)
    field(:rule_version, :integer)
    field(:recipient_id, :string)
    field(:channel, :string)
    field(:grouping_mode, Ecto.Enum, values: @grouping_mode_values)
    field(:grouping_value, :string)
    field(:window_kind, Ecto.Enum, values: @window_kind_values)
    field(:window_starts_at, :utc_datetime_usec)
    field(:window_ends_at, :utc_datetime_usec)
    field(:member_count, :integer, default: 0)
    field(:first_accumulated_at, :utc_datetime_usec)
    field(:last_accumulated_at, :utc_datetime_usec)

    belongs_to(:digest_rule, DigestRule)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(
    digest_rule_id
    rule_key
    rule_version
    recipient_id
    channel
    grouping_mode
    grouping_value
    window_kind
    window_starts_at
    window_ends_at
  )a

  @optional_fields ~w(member_count first_accumulated_at last_accumulated_at)a

  def changeset(bucket, attrs) do
    bucket
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:rule_version, greater_than: 0)
    |> validate_inclusion(:grouping_mode, @grouping_mode_values)
    |> validate_inclusion(:window_kind, @window_kind_values)
    |> validate_number(:member_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:grouping_value, name: :chimeway_digest_buckets_identity_index)
  end
end
