# chimeway_migration: add_render_channels_to_chimeway_notifications
defmodule Chimeway.Repo.Migrations.AddRenderChannelsToChimewayNotifications do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def up do
    alter chimeway_table(:chimeway_notifications) do
      add(:render_channels, :map, null: false, default: %{})
    end
  end

  def down do
    alter chimeway_table(:chimeway_notifications) do
      remove(:render_channels)
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
