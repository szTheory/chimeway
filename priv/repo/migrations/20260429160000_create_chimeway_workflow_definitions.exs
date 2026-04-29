defmodule Chimeway.Repo.Migrations.CreateChimewayWorkflowDefinitions do
  use Ecto.Migration

  def change do
    create table(:chimeway_workflow_definitions, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:workflow_key, :string, null: false)
      add(:workflow_version, :integer, null: false)
      add(:notification_key, :string, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      unique_index(:chimeway_workflow_definitions, [:workflow_key, :workflow_version],
        name: :chimeway_workflow_definitions_workflow_key_workflow_version_index
      )
    )

    create(index(:chimeway_workflow_definitions, [:notification_key]))
  end
end
