# chimeway_migration: create_chimeway_signals_and_spine
defmodule InstallerHost.Repo.Migrations.CreateChimewaySignalsAndSpine do
  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def change do
    alter chimeway_table(:chimeway_workflow_runs) do
      add(:tenant_id, :string)
      add(:suspended_until, :utc_datetime_usec)
      add(:pending_signals, {:array, :string}, default: [])
      add(:terminal_reason, :string)
    end

    execute(
      "UPDATE #{chimeway_relation(:chimeway_workflow_runs)} SET tenant_id = 'default' WHERE tenant_id IS NULL",
      ""
    )

    execute(
      "UPDATE #{chimeway_relation(:chimeway_workflow_runs)} SET pending_signals = '{}' WHERE pending_signals IS NULL",
      ""
    )

    alter chimeway_table(:chimeway_workflow_runs) do
      modify(:tenant_id, :string, null: false, from: :string)
    end

    create chimeway_table(:chimeway_signals, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:tenant_id, :string, null: false)
      add(:actor_id, :string, null: false)
      add(:event_name, :string, null: false)
      add(:payload, :map, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(chimeway_index(:chimeway_signals, [:tenant_id, :actor_id]))
    create(chimeway_index(:chimeway_signals, [:tenant_id, :event_name]))
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

  defp chimeway_relation(:chimeway_workflow_runs) do
    if @chimeway_prefix do
      ~s("#{@chimeway_prefix}"."chimeway_workflow_runs")
    else
      "chimeway_workflow_runs"
    end
  end
end
