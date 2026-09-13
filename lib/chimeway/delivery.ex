defmodule Chimeway.Delivery do
  @moduledoc """
  Ecto schema for chimeway_deliveries — per-channel delivery record for a notification.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Chimeway.Notifications.Notification
  alias Chimeway.Workflows.{WorkflowRun, WorkflowStep}

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chimeway_deliveries" do
    field(:tenant_id, :string)
    field(:actor_id, :string)
    field(:channel, :string)

    field(:status, Ecto.Enum,
      values: [:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled, :digested],
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

    field(:digest_flush_outcome, Ecto.Enum,
      values: [:digested, :skipped_by_policy, :emitted_immediately]
    )

    field(:digest_flush_reason, :string)
    field(:digest_flush_resolved_at, :utc_datetime_usec)
    field(:delay_fallback, :boolean, default: false)
    field(:metadata, :map)
    field(:render_key, :string)
    field(:render_version, :integer)
    field(:render_data, :map, default: %{})
    field(:recipient_address, :string, virtual: true)

    belongs_to(:notification, Notification)
    belongs_to(:digest_delivery, Chimeway.Delivery)
    belongs_to(:workflow_run, WorkflowRun)
    belongs_to(:workflow_step, WorkflowStep)
    has_many(:attempts, Chimeway.DeliveryAttempt)
    has_many(:targets, Chimeway.DeliveryTarget)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(notification_id channel status tenant_id actor_id)a
  @optional_fields ~w(
    orchestration_state
    next_eligible_at
    planning_reason
    planning_context
    suppression_reason
    digest_flush_outcome
    digest_flush_reason
    digest_flush_resolved_at
    digest_delivery_id
    delay_fallback
    metadata
    render_key
    render_version
    render_data
    workflow_run_id
    workflow_step_id
  )a

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:tenant_id, min: 1)
    |> validate_length(:actor_id, min: 1)
    |> unique_constraint(:channel,
      name: :chimeway_deliveries_notification_channel_index
    )
  end
end
