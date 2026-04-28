defmodule Chimeway.Delivery do
  @moduledoc """
  Ecto schema for chimeway_deliveries — per-channel delivery record for a notification.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Chimeway.Notifications.Notification

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chimeway_deliveries" do
    field(:channel, :string)

    field(:status, Ecto.Enum,
      values: [:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled],
      default: :pending
    )

    field(:orchestration_state, Ecto.Enum,
      values: [:ready, :deferred, :digest_held],
      default: :ready
    )

    field(:next_eligible_at, :utc_datetime_usec)
    field(:planning_reason, :string)
    field(:planning_context, :map)
    field(:suppression_reason, :string)
    field(:delay_fallback, :boolean, default: false)
    field(:metadata, :map)

    belongs_to(:notification, Notification)
    has_many(:attempts, Chimeway.DeliveryAttempt)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(notification_id channel status)a
  @optional_fields ~w(
    orchestration_state
    next_eligible_at
    planning_reason
    planning_context
    suppression_reason
    delay_fallback
    metadata
  )a

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:channel,
      name: :chimeway_deliveries_notification_channel_index
    )
  end
end
