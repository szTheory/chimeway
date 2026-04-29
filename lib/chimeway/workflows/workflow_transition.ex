defmodule Chimeway.Workflows.WorkflowTransition do
  @moduledoc "Append-only workflow transition row capturing state changes and reasons."

  use Ecto.Schema
  import Ecto.Changeset

  alias Chimeway.Delivery
  alias Chimeway.Workflows.{WorkflowRun, WorkflowStep}

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @state_values [:active, :waiting, :completed, :stopped]

  schema "chimeway_workflow_transitions" do
    belongs_to(:workflow_run, WorkflowRun)
    belongs_to(:workflow_step, WorkflowStep)
    belongs_to(:delivery, Delivery)

    field(:from_state, Ecto.Enum, values: @state_values)
    field(:to_state, Ecto.Enum, values: @state_values)
    field(:reason, :string)
    field(:context, :map, default: %{})

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @required_fields ~w(workflow_run_id to_state reason)a
  @optional_fields ~w(workflow_step_id delivery_id from_state context)a

  def changeset(workflow_transition, attrs) do
    workflow_transition
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:to_state, @state_values)
    |> validate_change(:reason, fn :reason, reason ->
      if is_binary(reason) and String.trim(reason) != "" do
        []
      else
        [reason: "can't be blank"]
      end
    end)
    |> put_default_context()
  end

  defp put_default_context(changeset) do
    case get_field(changeset, :context) do
      nil -> put_change(changeset, :context, %{})
      _context -> changeset
    end
  end
end
