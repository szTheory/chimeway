# chimeway_migration: add_time_zone_to_chimeway_policy_settings
defmodule Chimeway.Repo.Migrations.AddTimeZoneToChimewayPolicySettings do
  use Ecto.Migration

  def change do
    alter table(:chimeway_policy_settings) do
      add(:time_zone, :string)
    end
  end
end
