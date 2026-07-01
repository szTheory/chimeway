# chimeway_migration: add_time_zone_to_chimeway_policy_settings
defmodule InstallerHost.Repo.Migrations.AddTimeZoneToChimewayPolicySettings do
  use Ecto.Migration

  @chimeway_prefix false

  def change do
    alter chimeway_table(:chimeway_policy_settings) do
      add(:time_zone, :string)
    end
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
end
