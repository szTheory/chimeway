# chimeway_migration: create_chimeway_webhook_ingress
defmodule InstallerHost.Repo.Migrations.CreateChimewayWebhookIngress do
  use Ecto.Migration

  def change do
    create table(:chimeway_webhook_ingress, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :adapter_module, :string, null: false
      add :delivery_id, references(:chimeway_deliveries, type: :binary_id, on_delete: :nilify_all)
      add :provider_message_id, :string
      add :provider_event_id, :string
      add :normalized_status, :string, null: false
      add :ingress_state, :string, null: false, default: "queued"
      add :ignored_reason, :string
      add :processed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    # Operator query: "what's stuck in :queued?"
    create index(:chimeway_webhook_ingress, [:ingress_state])

    # Correlation lookup paths from worker.
    create index(:chimeway_webhook_ingress, [:delivery_id])
    create index(:chimeway_webhook_ingress, [:provider_message_id])

    # Dedup seam (D-05): provider_event_id is nullable, so the index is partial.
    # Composite on adapter_module to prevent cross-provider id collisions.
    create unique_index(
      :chimeway_webhook_ingress,
      [:adapter_module, :provider_event_id],
      name: :chimeway_webhook_ingress_adapter_provider_event_uniq,
      where: "provider_event_id IS NOT NULL"
    )
  end
end
