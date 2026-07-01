# chimeway_migration: create_chimeway_category_preferences
defmodule Chimeway.Repo.Migrations.CreateChimewayCategoryPreferences do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def change do
    create chimeway_table(:chimeway_category_preferences, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:recipient_id, :string, null: false)
      add(:notification_category, :string, null: false)
      add(:enabled, :boolean, null: false, default: true)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_unique_index(
        :chimeway_category_preferences,
        [:recipient_id, :notification_category],
        name: :chimeway_category_preferences_recipient_category_index
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
