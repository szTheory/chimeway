defmodule Chimeway.Repo.Migrations.AddApnsRequestIntent do
  use Ecto.Migration

  def up do
    alter table(:chimeway_delivery_targets) do
      add(:apns_request_intent, :map)
    end
  end

  def down do
    alter table(:chimeway_delivery_targets) do
      remove(:apns_request_intent)
    end
  end
end
