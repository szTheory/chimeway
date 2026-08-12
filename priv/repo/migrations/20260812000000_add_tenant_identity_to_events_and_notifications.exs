defmodule Chimeway.Repo.Migrations.AddTenantIdentityToEventsAndNotifications do
  use Ecto.Migration

  def up do
    alter table(:chimeway_events) do
      add(:tenant_id, :string)
    end

    alter table(:chimeway_notifications) do
      add(:tenant_id, :string)
    end

    drop_if_exists(
      unique_index(:chimeway_events, [:idempotency_key],
        name: :chimeway_events_idempotency_key_index
      )
    )

    create(
      unique_index(:chimeway_events, [:tenant_id, :idempotency_key],
        name: :chimeway_events_tenant_id_idempotency_key_index
      )
    )
  end

  def down do
    drop_if_exists(
      unique_index(:chimeway_events, [:tenant_id, :idempotency_key],
        name: :chimeway_events_tenant_id_idempotency_key_index
      )
    )

    create(
      unique_index(:chimeway_events, [:idempotency_key],
        name: :chimeway_events_idempotency_key_index
      )
    )

    alter table(:chimeway_notifications) do
      remove(:tenant_id)
    end

    alter table(:chimeway_events) do
      remove(:tenant_id)
    end
  end
end
