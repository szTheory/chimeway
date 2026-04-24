defmodule Chimeway.Events.Event do
  @moduledoc """
  Durable canonical event persisted before outbound side effects.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "chimeway_events" do
    field :notification_key, :string
    field :notification_version, :integer
    field :idempotency_key, :string
    field :payload, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(notification_key notification_version idempotency_key payload)a

  def changeset(event, attrs) do
    event
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:notification_version, greater_than: 0)
    |> unique_constraint(:idempotency_key, name: :chimeway_events_idempotency_key_index)
  end
end
