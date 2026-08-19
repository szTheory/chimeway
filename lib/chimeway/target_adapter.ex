defmodule Chimeway.TargetAdapter do
  @moduledoc "Replaceable provider-handoff seam over durable opaque target identity."

  @callback deliver(TargetEnvelope.t(), keyword()) :: {:ok, map()} | {:error, term()}

  defmodule TargetEnvelope do
    @enforce_keys [:delivery, :target]
    defstruct [:delivery, :target]
    @type t :: %__MODULE__{delivery: Chimeway.Delivery.t(), target: Chimeway.DeliveryTarget.t()}
  end
end
