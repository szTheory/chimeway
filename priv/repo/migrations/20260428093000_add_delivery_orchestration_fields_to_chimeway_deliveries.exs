defmodule Chimeway.Repo.Migrations.AddDeliveryOrchestrationFieldsToChimewayDeliveries do
  use Ecto.Migration

  def up do
    alter table(:chimeway_deliveries) do
      add(:orchestration_state, :string, null: false, default: "ready")
      add(:next_eligible_at, :utc_datetime_usec)
      add(:planning_reason, :string)
      add(:planning_context, :map)
    end

    create(
      index(
        :chimeway_deliveries,
        [:orchestration_state, :next_eligible_at],
        name: :chimeway_deliveries_orchestration_state_next_eligible_at_index
      )
    )
  end

  def down do
    drop(
      index(
        :chimeway_deliveries,
        [:orchestration_state, :next_eligible_at],
        name: :chimeway_deliveries_orchestration_state_next_eligible_at_index
      )
    )

    alter table(:chimeway_deliveries) do
      remove(:planning_context)
      remove(:planning_reason)
      remove(:next_eligible_at)
      remove(:orchestration_state)
    end
  end
end
