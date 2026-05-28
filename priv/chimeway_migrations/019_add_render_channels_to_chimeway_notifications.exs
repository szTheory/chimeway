# chimeway_migration: add_render_channels_to_chimeway_notifications
defmodule Chimeway.Repo.Migrations.AddRenderChannelsToChimewayNotifications do
  use Ecto.Migration

  def up do
    alter table(:chimeway_notifications) do
      add(:render_channels, :map, null: false, default: %{})
    end
  end

  def down do
    alter table(:chimeway_notifications) do
      remove(:render_channels)
    end
  end
end
