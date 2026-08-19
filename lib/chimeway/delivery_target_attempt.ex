defmodule Chimeway.DeliveryTargetAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @outcomes [:attempt_started, :provider_accepted, :failed, :ambiguous_handoff]

  schema "chimeway_delivery_target_attempts" do
    field(:tenant_id, :string)
    field(:attempt_number, :integer)
    field(:outcome, Ecto.Enum, values: @outcomes)
    field(:started_at, :utc_datetime_usec)
    field(:finished_at, :utc_datetime_usec)
    field(:source, :string)
    field(:duplicate_risk, :boolean, default: false)
    field(:safe_facts, :map, default: %{})
    belongs_to(:delivery_target, Chimeway.DeliveryTarget)
    belongs_to(:prior_attempt, Chimeway.DeliveryTargetAttempt)
  end

  def changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [
      :tenant_id,
      :delivery_target_id,
      :attempt_number,
      :outcome,
      :started_at,
      :finished_at,
      :source,
      :prior_attempt_id,
      :duplicate_risk,
      :safe_facts
    ])
    |> validate_required([
      :tenant_id,
      :delivery_target_id,
      :attempt_number,
      :outcome,
      :started_at,
      :source,
      :safe_facts
    ])
    |> validate_number(:attempt_number, greater_than: 0)
    |> validate_length(:source, min: 1, max: 64)
    |> unique_constraint(:attempt_number,
      name: :chimeway_delivery_target_attempts_delivery_target_id_attempt_number_index
    )
  end
end
