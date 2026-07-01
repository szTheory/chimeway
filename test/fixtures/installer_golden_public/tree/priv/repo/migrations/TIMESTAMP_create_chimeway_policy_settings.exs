# chimeway_migration: create_chimeway_policy_settings
defmodule InstallerHost.Repo.Migrations.CreateChimewayPolicySettings do
  use Ecto.Migration

  @chimeway_prefix false

  def change do
    create chimeway_table(:chimeway_policy_settings, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:recipient_id, :string, null: false)
      add(:quiet_hours_start_minute, :integer)
      add(:quiet_hours_end_minute, :integer)
      add(:delivery_cap_count, :integer)
      add(:delivery_cap_window_minutes, :integer)

      timestamps(type: :utc_datetime_usec)
    end

    create(
      chimeway_unique_index(
        :chimeway_policy_settings,
        [:recipient_id],
        name: :chimeway_policy_settings_recipient_index
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
