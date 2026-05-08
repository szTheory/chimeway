defmodule Chimeway.Webhooks.Ingress do
  @moduledoc """
  Durable inbound webhook fact: a verified provider callback has been received,
  normalized, and queued for async processing. One ingress row per accepted
  callback; duplicate provider retries with the same `(adapter_module,
  provider_event_id)` collapse to the existing row via the partial unique index.

  Ingress rows are NOT a payload archive (Phase 33 D-04). They store
  explainability-first fields only — adapter identity, correlation keys,
  normalized status, processing state, and (when applicable) an ignored reason.
  Raw provider bodies and headers stay out of this surface by design.

  Replay protection seam (Phase 33 D-05): the partial unique index on
  `(adapter_module, provider_event_id) WHERE provider_event_id IS NOT NULL`
  collapses duplicate provider retries that expose a stable event id.
  Adapters without a stable event id get best-effort dedup only.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Normalized outcome from adapter.normalize_feedback/1.
  @normalized_statuses ~w(delivered bounced failed)
  # Lifecycle of the ingress row itself.
  @ingress_states ~w(queued processed ignored failed)a
  # Reason vocabulary for ingress_state == :ignored. Strict enum; never
  # derived from untrusted input. Mirrors Phase 32 D-16 atom-safety discipline.
  @ignored_reasons ~w(delivery_not_found provider_message_id_not_found)a

  schema "chimeway_webhook_ingress" do
    field(:adapter_module, :string)
    field(:delivery_id, :binary_id)
    field(:provider_message_id, :string)
    field(:provider_event_id, :string)
    field(:normalized_status, :string)
    field(:ingress_state, Ecto.Enum, values: @ingress_states, default: :queued)
    field(:ignored_reason, Ecto.Enum, values: @ignored_reasons)
    field(:processed_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(adapter_module normalized_status ingress_state)a
  @optional_fields ~w(delivery_id provider_message_id provider_event_id ignored_reason processed_at)a

  def changeset(ingress, attrs) do
    ingress
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:adapter_module, min: 1)
    |> validate_inclusion(:normalized_status, @normalized_statuses)
    |> validate_correlation_present()
    |> unique_constraint(
      [:adapter_module, :provider_event_id],
      name: :chimeway_webhook_ingress_adapter_provider_event_uniq
    )
  end

  defp validate_correlation_present(changeset) do
    delivery_id = get_field(changeset, :delivery_id)
    pmid = get_field(changeset, :provider_message_id)
    state = get_field(changeset, :ingress_state)
    reason = get_field(changeset, :ignored_reason)

    cond do
      delivery_id || pmid ->
        changeset

      state == :ignored and reason ->
        changeset

      true ->
        add_error(
          changeset,
          :delivery_id,
          "must be present, or provider_message_id must be present, or ingress must be :ignored with a reason"
        )
    end
  end
end
