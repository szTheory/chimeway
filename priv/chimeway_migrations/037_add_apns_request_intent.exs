# chimeway_migration: add_apns_request_intent
defmodule Chimeway.Repo.Migrations.AddApnsRequestIntent do
  use Ecto.Migration

  @chimeway_prefix __CHIMEWAY_PREFIX__

  def up do
    alter chimeway_table(:chimeway_delivery_targets) do
      add(:apns_request_intent, :map)
    end
  end

  def down do
    alter chimeway_table(:chimeway_delivery_targets) do
      remove(:apns_request_intent)
    end
  end

  defp chimeway_table(name, opts \\ []) do
    prefix_opts =
      if @chimeway_prefix, do: Keyword.put_new(opts, :prefix, @chimeway_prefix), else: opts

    table(name, prefix_opts)
  end
end
