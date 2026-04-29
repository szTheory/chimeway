defmodule Chimeway.Workflows.WorkflowStep do
  @moduledoc "Ordered durable workflow step row linked to one workflow definition."

  use Ecto.Schema
  import Ecto.Changeset

  alias Chimeway.Workflows.WorkflowDefinition

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chimeway_workflow_steps" do
    belongs_to(:workflow_definition, WorkflowDefinition)
    field(:step_key, :string)
    field(:step_order, :integer)
    field(:channel, :string)
    field(:config, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(workflow_definition_id step_key step_order channel)a
  @optional_fields ~w(config)a

  def changeset(workflow_step, attrs) do
    workflow_step
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_change(:step_key, fn :step_key, step_key ->
      if is_binary(step_key) and String.trim(step_key) != "" do
        []
      else
        [step_key: "can't be blank"]
      end
    end)
    |> validate_number(:step_order, greater_than: 0)
    |> validate_change(:channel, fn :channel, channel ->
      if is_binary(channel) and String.trim(channel) != "" do
        []
      else
        [channel: "can't be blank"]
      end
    end)
    |> put_default_config()
    |> unique_constraint([:workflow_definition_id, :step_key],
      name: :chimeway_workflow_steps_definition_id_step_key_index
    )
    |> unique_constraint([:workflow_definition_id, :step_order],
      name: :chimeway_workflow_steps_definition_id_step_order_index
    )
  end

  defp put_default_config(changeset) do
    case get_field(changeset, :config) do
      nil -> put_change(changeset, :config, %{})
      _config -> changeset
    end
  end
end
