defmodule Chimeway.Repo.Migrations.CreateChimewayNotifications do
  use Ecto.Migration

  def change do
    create table(:chimeway_notifications, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :event_id, references(:chimeway_events, type: :uuid, on_delete: :delete_all),
        null: false

      add :recipient_identity, :string, null: false
      add :recipient_type, :string, null: false
      add :seen_at, :utc_datetime_usec
      add :read_at, :utc_datetime_usec
      add :archived_at, :utc_datetime_usec
      add :metadata, :map, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:chimeway_notifications, [:event_id, :recipient_identity], name: :chimeway_notifications_event_recipient_index)

    create index(:chimeway_notifications, [:recipient_identity, :read_at, :inserted_at],
             name: :chimeway_notifications_inbox_read_inserted_index
           )
  end
end
