defmodule Chimeway.Workflows.WorkflowDefinition do
  @moduledoc "Durable workflow definition storage keyed by stable workflow identity."

  use Ecto.Schema
  import Ecto.Changeset

  alias Chimeway.Workflows.WorkflowStep

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chimeway_workflow_definitions" do
    field(:workflow_key, :string)
    field(:workflow_version, :integer)
    field(:notification_key, :string)

    has_many(:steps, WorkflowStep)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(workflow_key workflow_version notification_key)a

  def changeset(workflow_definition, attrs) do
    workflow_definition
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_change(:workflow_key, fn :workflow_key, workflow_key ->
      if is_binary(workflow_key) and String.trim(workflow_key) != "" do
        []
      else
        [workflow_key: "can't be blank"]
      end
    end)
    |> validate_change(:notification_key, fn :notification_key, notification_key ->
      if is_binary(notification_key) and String.trim(notification_key) != "" do
        []
      else
        [notification_key: "can't be blank"]
      end
    end)
    |> validate_number(:workflow_version, greater_than: 0)
    |> unique_constraint([:workflow_key, :workflow_version],
      name: :chimeway_workflow_definitions_workflow_key_workflow_version_index
    )
  end
end
