defmodule Chimeway.TargetAdapter do
  @moduledoc "Replaceable provider-handoff seam over durable opaque target identity."

  @typedoc """
  The result of handing a durable target to a provider adapter.

  Only `:pre_handoff` proves the adapter did not cross the provider-request
  boundary. Every other error shape is treated as a possible provider handoff.
  Adapter reasons are intentionally not persisted.
  """
  @type deliver_result ::
          {:ok, map()}
          | {:error, :pre_handoff, term()}
          | {:error, :possible_handoff, term()}
          | {:error, term()}

  @callback deliver(TargetEnvelope.t(), keyword()) :: deliver_result()

  defmodule TargetEnvelope do
    @enforce_keys [:delivery, :target]
    defstruct [:delivery, :target]
    @type t :: %__MODULE__{delivery: Chimeway.Delivery.t(), target: Chimeway.DeliveryTarget.t()}
  end
end
