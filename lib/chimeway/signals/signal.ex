defmodule Chimeway.Signals.Signal do
  @moduledoc """
  Durable host-submitted progression signal.

  Each row records a single fact that a host application reported (e.g. a user
  opened an email, completed a billing task). Signals are the immutable input
  to workflow advancement — `Chimeway.Dispatch.SignalRouterWorker` consumes
  them asynchronously to drive `WorkflowRun` state transitions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "chimeway_signals" do
    field(:tenant_id, :string)
    field(:actor_id, :string)
    field(:event_name, :string)
    field(:payload, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(tenant_id actor_id event_name)a
  @optional_fields ~w(payload)a

  def changeset(signal, attrs) do
    signal
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:tenant_id, min: 1)
    |> validate_length(:actor_id, min: 1)
    |> validate_length(:event_name, min: 1)
  end
end
