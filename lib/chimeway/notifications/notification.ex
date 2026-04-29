defmodule Chimeway.Notifications.Notification do
  @moduledoc """
  Durable per-recipient in-app notification record.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Chimeway.Events.Event

  @type t :: %__MODULE__{}

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "chimeway_notifications" do
    belongs_to(:event, Event, type: Ecto.UUID)
    has_many(:deliveries, Chimeway.Delivery, foreign_key: :notification_id)
    field(:recipient_identity, :string)
    field(:recipient_type, :string)
    field(:seen_at, :utc_datetime_usec)
    field(:read_at, :utc_datetime_usec)
    field(:archived_at, :utc_datetime_usec)
    field(:metadata, :map, default: %{})
    field(:render_assigns, :map, default: %{})
    field(:render_channels, :map, default: %{})
    field(:orchestration, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(event_id recipient_identity recipient_type metadata render_assigns render_channels)a
  @optional_fields ~w(seen_at read_at archived_at orchestration)a

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:recipient_identity,
      name: :chimeway_notifications_event_recipient_index
    )
  end
end
