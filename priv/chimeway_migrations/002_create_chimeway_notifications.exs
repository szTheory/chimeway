# chimeway_migration: create_chimeway_notifications
defmodule Chimeway.Repo.Migrations.CreateChimewayNotifications do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def change do
    create chimeway_table(:chimeway_notifications, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:event_id, chimeway_references(:chimeway_events, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:recipient_identity, :string, null: false)
      add(:recipient_type, :string, null: false)
      add(:seen_at, :utc_datetime_usec)
      add(:read_at, :utc_datetime_usec)
      add(:archived_at, :utc_datetime_usec)
      add(:metadata, :map, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_unique_index(:chimeway_notifications, [:event_id, :recipient_identity],
        name: :chimeway_notifications_event_recipient_index
      )
    )

    create(
      chimeway_index(:chimeway_notifications, [:recipient_identity, :read_at, :inserted_at],
        name: :chimeway_notifications_inbox_read_inserted_index
      )
    )
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

  defp chimeway_unique_index(table_name, columns, opts \\ []) do
    unique_index(table_name, columns, chimeway_prefix_opts(opts))
  end

  defp chimeway_references(table_name, opts \\ []) do
    references(table_name, chimeway_prefix_opts(opts))
  end
end
