# chimeway_migration: create_chimeway_category_preferences
defmodule InstallerHost.Repo.Migrations.CreateChimewayCategoryPreferences do
  use Ecto.Migration

  def change do
    create table(:chimeway_category_preferences, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :recipient_id, :string, null: false
      add :notification_category, :string, null: false
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
      :chimeway_category_preferences,
      [:recipient_id, :notification_category],
      name: :chimeway_category_preferences_recipient_category_index
    )
  end
end
