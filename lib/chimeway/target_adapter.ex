defmodule Chimeway.TargetAdapter do
  @moduledoc "Replaceable provider-handoff seam over durable opaque target identity."

  @typedoc """
  The result of handing a durable target to a provider adapter.

  The tagged variants form the durable target lifecycle vocabulary. Only
  `:pre_handoff_retryable` proves the adapter did not cross the provider-request
  boundary. Adapter reasons are intentionally not persisted.
  """
  @type deliver_result ::
          {:ok, map()}
          | {:provider_accepted, map()}
          | {:provider_retryable, map()}
          | {:permanent, map()}
          | {:invalidated, map()}
          | {:expired, map()}
          | {:pre_handoff_retryable, map()}
          | {:possible_handoff, map()}
          | {:error, :pre_handoff, term()}
          | {:error, :possible_handoff, term()}
          | {:error, term()}

  @callback deliver(TargetEnvelope.t(), keyword()) :: deliver_result()

  defmodule TargetEnvelope do
    @moduledoc false
    @enforce_keys [:delivery, :target]
    defstruct [:delivery, :target]
    @type t :: %__MODULE__{delivery: Chimeway.Delivery.t(), target: Chimeway.DeliveryTarget.t()}
  end
end
