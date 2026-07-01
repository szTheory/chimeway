# chimeway_migration: add_rendering_contract_fields
defmodule Chimeway.Repo.Migrations.AddRenderingContractFields do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def up do
    alter chimeway_table(:chimeway_notifications) do
      add(:render_assigns, :map, null: false, default: %{})
    end

    alter chimeway_table(:chimeway_deliveries) do
      add(:render_key, :string)
      add(:render_version, :integer)
      add(:render_data, :map, null: false, default: %{})
    end
  end

  def down do
    alter chimeway_table(:chimeway_deliveries) do
      remove(:render_data)
      remove(:render_version)
      remove(:render_key)
    end

    alter chimeway_table(:chimeway_notifications) do
      remove(:render_assigns)
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
