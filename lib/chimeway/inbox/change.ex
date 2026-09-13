defmodule Chimeway.Inbox.Change do
  @moduledoc """
  Closed reload hint delivered to a host-configured inbox change publisher.

  The hint contains routing scope only. Durable notification state remains the
  authority and consumers must reload it rather than treating this value as a delta.
  """

  alias Chimeway.SafeEvidence

  @events [:created, :seen, :read, :archived]
  @enforce_keys [:version, :event, :tenant_id, :recipient_ref]
  defstruct [:version, :event, :tenant_id, :recipient_ref]

  @type event :: :created | :seen | :read | :archived
  @type t :: %__MODULE__{
          version: 1,
          event: event(),
          tenant_id: String.t(),
          recipient_ref: String.t()
        }

  @spec new(term(), term(), term()) :: {:ok, t()} | {:error, :invalid_change}
  def new(tenant_id, recipient_ref, event)
      when is_binary(tenant_id) and byte_size(tenant_id) in 1..160 and event in @events do
    with normalized when normalized != "" <- String.trim(tenant_id),
         {:ok, opaque_ref} <- SafeEvidence.opaque_ref(:recipient, recipient_ref) do
      {:ok,
       %__MODULE__{
         version: 1,
         event: event,
         tenant_id: normalized,
         recipient_ref: opaque_ref
       }}
    else
      _ -> {:error, :invalid_change}
    end
  end

  def new(_tenant_id, _recipient_ref, _event), do: {:error, :invalid_change}
end
