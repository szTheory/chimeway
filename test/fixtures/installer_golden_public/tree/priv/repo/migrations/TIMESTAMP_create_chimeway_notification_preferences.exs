# chimeway_migration: create_chimeway_notification_preferences
defmodule InstallerHost.Repo.Migrations.CreateChimewayNotificationPreferences do
  use Ecto.Migration

  @chimeway_prefix false

  def change do
    create chimeway_table(:chimeway_notification_preferences, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:recipient_id, :string, null: false)
      add(:notification_key, :string, null: false)
      add(:channel, :string, null: false)
      add(:enabled, :boolean, null: false, default: true)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_unique_index(
        :chimeway_notification_preferences,
        [:recipient_id, :notification_key, :channel],
        name: :chimeway_notification_preferences_recipient_key_channel_index
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

  defp chimeway_unique_index(table_name, columns, opts \\ []) do
    unique_index(table_name, columns, chimeway_prefix_opts(opts))
  end
end
