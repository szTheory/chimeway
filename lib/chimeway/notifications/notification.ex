defmodule Chimeway.Notifications.Notification do
  @moduledoc """
  Durable per-recipient in-app notification record.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Chimeway.Events.Event
  alias Chimeway.Workflows.WorkflowDefinition

  @type t :: %__MODULE__{}

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "chimeway_notifications" do
    belongs_to(:event, Event, type: Ecto.UUID)
    belongs_to(:workflow_definition, WorkflowDefinition)
    has_many(:deliveries, Chimeway.Delivery, foreign_key: :notification_id)
    field(:recipient_identity, :string)
    field(:recipient_type, :string)
    field(:tenant_id, :string)
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
  @insert_required_fields ~w(tenant_id)a
  @optional_fields ~w(seen_at read_at archived_at orchestration workflow_definition_id)a

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, fields_for(notification))
    |> validate_required(required_fields_for(notification))
    |> unique_constraint(:recipient_identity,
      name: :chimeway_notifications_event_recipient_index
    )
  end

  defp fields_for(%__MODULE__{id: nil}),
    do: @required_fields ++ @insert_required_fields ++ @optional_fields

  defp fields_for(%__MODULE__{}), do: @required_fields ++ @optional_fields
  defp required_fields_for(%__MODULE__{id: nil}), do: @required_fields ++ @insert_required_fields
  defp required_fields_for(%__MODULE__{}), do: @required_fields
end
