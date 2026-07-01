# chimeway_migration: add_delivery_orchestration_fields_to_chimeway_deliveries
defmodule InstallerHost.Repo.Migrations.AddDeliveryOrchestrationFieldsToChimewayDeliveries do
  use Ecto.Migration

  @chimeway_prefix false

  def up do
    alter chimeway_table(:chimeway_deliveries) do
      add(:orchestration_state, :string, null: false, default: "ready")
      add(:next_eligible_at, :utc_datetime_usec)
      add(:planning_reason, :string)
      add(:planning_context, :map)
    end

    create(
      chimeway_index(
        :chimeway_deliveries,
        [:orchestration_state, :next_eligible_at],
        name: :chimeway_deliveries_orchestration_state_next_eligible_at_index
      )
    )
  end

  def down do
    drop(
      chimeway_index(
        :chimeway_deliveries,
        [:orchestration_state, :next_eligible_at],
        name: :chimeway_deliveries_orchestration_state_next_eligible_at_index
      )
    )

    alter chimeway_table(:chimeway_deliveries) do
      remove(:planning_context)
      remove(:planning_reason)
      remove(:next_eligible_at)
      remove(:orchestration_state)
    end
  end

  defp chimeway_prefix_opts(opts \\ []) do
    if @chimeway_prefix do
      Keyword.put_new(opts, :prefix, @chimeway_prefix)
    else
      opts
    end
  end

  defp chimeway_table(name, opts \\ []) do
    table(name, chimeway_prefix_opts(opts))
  end

  defp chimeway_index(table_name, columns, opts \\ []) do
    index(table_name, columns, chimeway_prefix_opts(opts))
  end
end
