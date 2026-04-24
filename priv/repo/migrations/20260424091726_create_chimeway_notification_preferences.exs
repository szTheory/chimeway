defmodule Chimeway.Repo.Migrations.CreateChimewayNotificationPreferences do
  use Ecto.Migration

  def change do
    create table(:chimeway_notification_preferences, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :recipient_id, :string, null: false
      add :notification_key, :string, null: false
      add :channel, :string, null: false
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
      :chimeway_notification_preferences,
      [:recipient_id, :notification_key, :channel],
      name: :chimeway_notification_preferences_recipient_key_channel_index
    )
  end
end
