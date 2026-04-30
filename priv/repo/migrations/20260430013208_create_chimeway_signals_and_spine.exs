defmodule Chimeway.Repo.Migrations.CreateChimewaySignalsAndSpine do
  use Ecto.Migration

  def change do
    alter table(:chimeway_workflow_runs) do
      add :tenant_id, :string, null: false
      add :suspended_until, :utc_datetime_usec
      add :pending_signals, {:array, :string}, default: []
      add :terminal_reason, :string
    end

    create table(:chimeway_signals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :actor_id, :string, null: false
      add :event_name, :string, null: false
      add :payload, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:chimeway_signals, [:tenant_id, :actor_id])
    create index(:chimeway_signals, [:tenant_id, :event_name])
  end
end
