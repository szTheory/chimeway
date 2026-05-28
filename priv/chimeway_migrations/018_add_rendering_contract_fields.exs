# chimeway_migration: add_rendering_contract_fields
defmodule Chimeway.Repo.Migrations.AddRenderingContractFields do
  use Ecto.Migration

  def up do
    alter table(:chimeway_notifications) do
      add(:render_assigns, :map, null: false, default: %{})
    end

    alter table(:chimeway_deliveries) do
      add(:render_key, :string)
      add(:render_version, :integer)
      add(:render_data, :map, null: false, default: %{})
    end
  end

  def down do
    alter table(:chimeway_deliveries) do
      remove(:render_data)
      remove(:render_version)
      remove(:render_key)
    end

    alter table(:chimeway_notifications) do
      remove(:render_assigns)
    end
  end
end
