defmodule Chimeway.Workflows.WorkflowRun do
  @moduledoc "Durable workflow run aggregate row anchored to one notification."

  use Ecto.Schema
  import Ecto.Changeset

  alias Chimeway.Notifications.Notification
  alias Chimeway.Workflows.{WorkflowDefinition, WorkflowStep, WorkflowTransition}

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @state_values [:active, :waiting, :completed, :stopped]

  schema "chimeway_workflow_runs" do
    belongs_to(:notification, Notification)
    belongs_to(:workflow_definition, WorkflowDefinition)
    belongs_to(:current_step, WorkflowStep)
    has_many(:transitions, WorkflowTransition)

    field(:state, Ecto.Enum, values: @state_values, default: :active)
    field(:started_at, :utc_datetime_usec)
    field(:last_transition_at, :utc_datetime_usec)
    field(:status_reason, :string)
    field(:status_context, :map, default: %{})
    field(:tenant_id, :string)
    field(:suspended_until, :utc_datetime_usec)
    field(:pending_signals, {:array, :string}, default: [])
    field(:terminal_reason, :string)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(
    notification_id
    workflow_definition_id
    current_step_id
    state
    started_at
    last_transition_at
    status_reason
    tenant_id
  )a

  @optional_fields ~w(
    status_context
    suspended_until
    pending_signals
    terminal_reason
  )a

  def changeset(workflow_run, attrs) do
    workflow_run
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:state, @state_values)
    |> put_default_status_context()
    |> unique_constraint(:notification_id,
      name: :chimeway_workflow_runs_notification_id_index
    )
  end

  defp put_default_status_context(changeset) do
    case get_field(changeset, :status_context) do
      nil -> put_change(changeset, :status_context, %{})
      _context -> changeset
    end
  end
end
