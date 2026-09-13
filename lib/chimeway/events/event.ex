defmodule Chimeway.Events.Event do
  @moduledoc """
  Durable canonical event persisted before outbound side effects.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "chimeway_events" do
    field(:notification_key, :string)
    field(:notification_version, :integer)
    field(:idempotency_key, :string)
    field(:tenant_id, :string)
    field(:payload, :map, default: %{})
    field(:correlation_id, :string)

    has_many(:notifications, Chimeway.Notifications.Notification)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(notification_key notification_version idempotency_key payload)a
  @insert_required_fields ~w(tenant_id)a
  @optional_fields ~w(correlation_id)a

  def changeset(event, attrs) do
    event
    |> cast(attrs, fields_for(event))
    |> validate_required(required_fields_for(event))
    |> validate_number(:notification_version, greater_than: 0)
    |> unique_constraint(:idempotency_key,
      name: :chimeway_events_tenant_id_idempotency_key_index
    )
    |> unique_constraint(:idempotency_key,
      name: :chimeway_events_tenant_id_idempotency_key_idx
    )
  end

  defp fields_for(%__MODULE__{id: nil}),
    do: @required_fields ++ @insert_required_fields ++ @optional_fields

  defp fields_for(%__MODULE__{}), do: @required_fields ++ @optional_fields
  defp required_fields_for(%__MODULE__{id: nil}), do: @required_fields ++ @insert_required_fields
  defp required_fields_for(%__MODULE__{}), do: @required_fields
end
