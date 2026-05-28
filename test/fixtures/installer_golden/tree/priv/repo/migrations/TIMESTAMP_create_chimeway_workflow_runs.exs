# chimeway_migration: create_chimeway_workflow_runs
defmodule InstallerHost.Repo.Migrations.CreateChimewayWorkflowRuns do
  use Ecto.Migration

  def change do
    create table(:chimeway_workflow_runs, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :notification_id,
        references(:chimeway_notifications, type: :uuid, on_delete: :delete_all), null: false)

      add(
        :workflow_definition_id,
        references(:chimeway_workflow_definitions, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(
        :current_step_id,
        references(:chimeway_workflow_steps, type: :uuid, on_delete: :restrict),
        null: false
      )

      add(:state, :string, null: false)
      add(:started_at, :utc_datetime_usec, null: false)
      add(:last_transition_at, :utc_datetime_usec, null: false)
      add(:status_reason, :string, null: false)
      add(:status_context, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(
      unique_index(:chimeway_workflow_runs, [:notification_id],
        name: :chimeway_workflow_runs_notification_id_index
      )
    )

    create(index(:chimeway_workflow_runs, [:workflow_definition_id]))
    create(index(:chimeway_workflow_runs, [:current_step_id]))
    create(index(:chimeway_workflow_runs, [:state]))
  end
end
