defmodule Chimeway.Digests.DigestMembership do
  @moduledoc "Auditable membership row linking one canonical delivery into one digest bucket."

  use Ecto.Schema
  import Ecto.Changeset

  alias Chimeway.Delivery
  alias Chimeway.Digests.DigestBucket
  alias Chimeway.Notifications.Notification

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chimeway_digest_memberships" do
    belongs_to(:digest_bucket, DigestBucket)
    belongs_to(:delivery, Delivery)
    belongs_to(:notification, Notification)
    field(:resolution, Ecto.Enum, values: [:included, :skipped_by_policy, :emitted_immediately])
    field(:resolution_reason, :string)
    field(:resolved_at, :utc_datetime_usec)
    field(:resolved_rule_key, :string)
    field(:resolved_rule_version, :integer)
    field(:resolved_window_starts_at, :utc_datetime_usec)
    field(:resolved_window_ends_at, :utc_datetime_usec)
    belongs_to(:digest_delivery, Chimeway.Delivery)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(digest_bucket_id delivery_id notification_id)a
  @optional_fields ~w(
    resolution
    resolution_reason
    resolved_at
    resolved_rule_key
    resolved_rule_version
    resolved_window_starts_at
    resolved_window_ends_at
    digest_delivery_id
  )a

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:delivery_id,
      name: :chimeway_digest_memberships_delivery_id_index
    )
  end
end
