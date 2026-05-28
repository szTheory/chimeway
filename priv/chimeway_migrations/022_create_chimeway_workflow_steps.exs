# chimeway_migration: create_chimeway_workflow_steps
defmodule Chimeway.Repo.Migrations.CreateChimewayWorkflowSteps do
  use Ecto.Migration

  def change do
    create table(:chimeway_workflow_steps, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:workflow_definition_id, references(:chimeway_workflow_definitions, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:step_key, :string, null: false)
      add(:step_order, :integer, null: false)
      add(:channel, :string, null: false)
      add(:config, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:chimeway_workflow_steps, [:workflow_definition_id]))

    create(
      unique_index(:chimeway_workflow_steps, [:workflow_definition_id, :step_key],
        name: :chimeway_workflow_steps_definition_id_step_key_index
      )
    )

    create(
      unique_index(:chimeway_workflow_steps, [:workflow_definition_id, :step_order],
        name: :chimeway_workflow_steps_definition_id_step_order_index
      )
    )
  end
end
