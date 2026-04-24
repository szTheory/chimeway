defmodule Chimeway.DeliveryAttempt do
  @moduledoc """
  Ecto schema for chimeway_delivery_attempts — immutable append-only record of each
  provider call for a delivery. No updated_at — attempts are never mutated.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chimeway_delivery_attempts" do
    field(:outcome, Ecto.Enum, values: [:succeeded, :failed, :bounced, :rejected])
    field(:provider_response, :map)
    field(:inserted_at, :utc_datetime_usec)

    belongs_to(:delivery, Chimeway.Delivery)
  end

  @required_fields ~w(delivery_id outcome)a
  @optional_fields ~w(provider_response)a

  def changeset(attempt, attrs) do
    attempt
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> put_inserted_at()
  end

  defp put_inserted_at(changeset) do
    if get_field(changeset, :inserted_at) do
      changeset
    else
      put_change(changeset, :inserted_at, DateTime.utc_now() |> DateTime.truncate(:microsecond))
    end
  end
end
