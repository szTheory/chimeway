# chimeway_migration: add_tenant_identity_to_events_and_notifications
defmodule InstallerHost.Repo.Migrations.AddTenantIdentityToEventsAndNotifications do
  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def up do
    alter chimeway_table(:chimeway_events) do
      add(:tenant_id, :string)
    end

    alter chimeway_table(:chimeway_notifications) do
      add(:tenant_id, :string)
    end

    drop_if_exists(
      chimeway_unique_index(:chimeway_events, [:idempotency_key],
        name: :chimeway_events_idempotency_key_index
      )
    )

    create(
      chimeway_unique_index(:chimeway_events, [:tenant_id, :idempotency_key],
        name: :chimeway_events_tenant_id_idempotency_key_index
      )
    )
  end

  def down do
    drop_if_exists(
      chimeway_unique_index(:chimeway_events, [:tenant_id, :idempotency_key],
        name: :chimeway_events_tenant_id_idempotency_key_index
      )
    )

    create(
      chimeway_unique_index(:chimeway_events, [:idempotency_key],
        name: :chimeway_events_idempotency_key_index
      )
    )

    alter chimeway_table(:chimeway_notifications) do
      remove(:tenant_id)
    end

    alter chimeway_table(:chimeway_events) do
      remove(:tenant_id)
    end
  end

  defp chimeway_prefix_opts(opts \\ []) do
    if @chimeway_prefix, do: Keyword.put_new(opts, :prefix, @chimeway_prefix), else: opts
  end

  defp chimeway_table(name, opts \\ []), do: table(name, chimeway_prefix_opts(opts))

  defp chimeway_unique_index(table_name, columns, opts \\ []) do
    unique_index(table_name, columns, chimeway_prefix_opts(opts))
  end
end
