# chimeway_migration: create_chimeway_webhook_ingress
defmodule InstallerHost.Repo.Migrations.CreateChimewayWebhookIngress do
  use Ecto.Migration

  @chimeway_prefix false

  def change do
    create chimeway_table(:chimeway_webhook_ingress, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:adapter_module, :string, null: false)

      add(
        :delivery_id,
        chimeway_references(:chimeway_deliveries, type: :binary_id, on_delete: :nilify_all)
      )

      add(:provider_message_id, :string)
      add(:provider_event_id, :string)
      add(:normalized_status, :string, null: false)
      add(:ingress_state, :string, null: false, default: "queued")
      add(:ignored_reason, :string)
      add(:processed_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    # Operator query: "what's stuck in :queued?"
    create(chimeway_index(:chimeway_webhook_ingress, [:ingress_state]))

    # Correlation lookup paths from worker.
    create(chimeway_index(:chimeway_webhook_ingress, [:delivery_id]))
    create(chimeway_index(:chimeway_webhook_ingress, [:provider_message_id]))

    # Dedup seam (D-05): provider_event_id is nullable, so the index is partial.
    # Composite on adapter_module to prevent cross-provider id collisions.
    create(
      chimeway_unique_index(
        :chimeway_webhook_ingress,
        [:adapter_module, :provider_event_id],
        name: :chimeway_webhook_ingress_adapter_provider_event_uniq,
        where: "provider_event_id IS NOT NULL"
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

  defp chimeway_index(table_name, columns, opts \\ []) do
    index(table_name, columns, chimeway_prefix_opts(opts))
  end

  defp chimeway_unique_index(table_name, columns, opts \\ []) do
    unique_index(table_name, columns, chimeway_prefix_opts(opts))
  end

  defp chimeway_references(table_name, opts \\ []) do
    references(table_name, chimeway_prefix_opts(opts))
  end
end
