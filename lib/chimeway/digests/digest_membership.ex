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

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(digest_bucket_id delivery_id notification_id)a

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:delivery_id,
      name: :chimeway_digest_memberships_delivery_id_index
    )
  end
end
