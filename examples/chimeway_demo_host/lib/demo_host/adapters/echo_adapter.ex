defmodule DemoHost.Adapters.EchoAdapter do
  @moduledoc """
  Fixture adapter for the Phase 33 E2E proof. Implements the Chimeway.Adapter
  behaviour with the simplest possible verification + correlation logic.

  WARNING: the `verify_webhook/3` clause that pattern-matches a literal
  `[{"signature", "valid"}]` header is acceptable for a fixture/test
  adapter ONLY. Production adapters MUST use `Plug.Crypto.secure_compare/2`
  against an HMAC computed over the raw request body. Do not copy this
  shape into a real adapter — see Phase 33 RESEARCH.md § Security Domain.

  Note on delivery correlation: this fixture adapter maps the provider's "id"
  field to `provider_message_id` (a plain string — no foreign-key constraint).
  Production adapters that correlate back to a chimeway delivery row MUST
  ensure the `delivery_id` value references an existing `chimeway_deliveries`
  row (FK constraint). Use `provider_message_id` for opaque provider-side
  identifiers; use `delivery_id` only when you have a real delivery UUID.
  """

  @behaviour Chimeway.Adapter

  def deliver(_delivery, _config), do: {:ok, %{}}

  def verify_webhook(_body, headers, _config) do
    if Enum.any?(headers, fn {k, v} -> k == "signature" and v == "valid" end) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  # Maps the provider's "id" to provider_message_id (plain string, no FK).
  # Maps "msg_id" the same way for an alternate fixture shape.
  # Maps "delivery_id" directly to delivery_id (FK — use only with a real delivery row).
  def resolve_delivery(%{"id" => id}) when is_binary(id), do: {:ok, %{provider_message_id: id}}
  def resolve_delivery(%{"msg_id" => pid}) when is_binary(pid), do: {:ok, %{provider_message_id: pid}}
  def resolve_delivery(%{"delivery_id" => did}) when is_binary(did), do: {:ok, %{delivery_id: did}}
  def resolve_delivery(_), do: :error

  def normalize_feedback(%{"status" => "bounce"}), do: {:ok, %{status: :bounced}}
  def normalize_feedback(%{"status" => "ok"}), do: {:ok, %{status: :delivered}}
  def normalize_feedback(%{"status" => "fail"}), do: {:ok, %{status: :failed}}
  def normalize_feedback(_), do: :error

  # Optional callback (A4) — exposes provider event id for dedup when present.
  def resolve_provider_event_id(%{"event_id" => id}) when is_binary(id), do: {:ok, id}
  def resolve_provider_event_id(_), do: :none
end
