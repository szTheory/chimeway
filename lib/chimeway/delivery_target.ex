defmodule Chimeway.DeliveryTarget do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @statuses [
    :pending,
    :claimed,
    :provider_accepted,
    :failed,
    :retry_exhausted,
    :expired,
    :invalidated,
    :ambiguous_handoff
  ]

  schema "chimeway_delivery_targets" do
    field(:tenant_id, :string)
    field(:binding_revision_ref, :string)
    field(:apns_request_intent, :map)
    field(:status, Ecto.Enum, values: @statuses, default: :pending)
    field(:claim_token, :string)
    field(:lease_expires_at, :utc_datetime_usec)
    field(:claimed_at, :utc_datetime_usec)
    belongs_to(:delivery, Chimeway.Delivery)
    has_many(:attempts, Chimeway.DeliveryTargetAttempt)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(target, attrs) do
    target
    |> cast(attrs, [
      :tenant_id,
      :delivery_id,
      :binding_revision_ref,
      :apns_request_intent,
      :status,
      :claim_token,
      :lease_expires_at,
      :claimed_at
    ])
    |> validate_required([:tenant_id, :delivery_id, :binding_revision_ref, :status])
    |> validate_length(:binding_revision_ref, min: 4, max: 128)
    |> unique_constraint(:binding_revision_ref,
      name: :chimeway_delivery_targets_delivery_id_binding_revision_ref_index
    )
  end
end
