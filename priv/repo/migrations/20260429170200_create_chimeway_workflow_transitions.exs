defmodule Chimeway.Repo.Migrations.CreateChimewayWorkflowTransitions do
  use Ecto.Migration

  def change do
    create table(:chimeway_workflow_transitions, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :workflow_run_id,
        references(:chimeway_workflow_runs, type: :uuid, on_delete: :delete_all), null: false)

      add(
        :workflow_step_id,
        references(:chimeway_workflow_steps, type: :uuid, on_delete: :nilify_all)
      )

      add(:delivery_id, references(:chimeway_deliveries, type: :uuid, on_delete: :nilify_all))
      add(:from_state, :string)
      add(:to_state, :string, null: false)
      add(:reason, :string, null: false)
      add(:context, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:chimeway_workflow_transitions, [:workflow_run_id, :inserted_at]))
    create(index(:chimeway_workflow_transitions, [:workflow_step_id]))
    create(index(:chimeway_workflow_transitions, [:delivery_id]))
    create(index(:chimeway_workflow_transitions, [:reason]))
  end
end
