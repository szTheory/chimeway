defmodule DemoHost.Adapters.EchoAdapter do
  @moduledoc """
  Fixture adapter for the Phase 33 E2E proof. Implements the Chimeway.Adapter
  behaviour with the simplest possible verification + correlation logic.

  WARNING: the `verify_webhook/3` clause that pattern-matches a literal
  `[{"signature", "valid"}]` header is acceptable for a fixture/test
  adapter ONLY. Production adapters MUST use `Plug.Crypto.secure_compare/2`
  against an HMAC computed over the raw request body. Do not copy this
  shape into a real adapter — see Phase 33 RESEARCH.md § Security Domain.
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

  def resolve_delivery(%{"id" => id}) when is_binary(id), do: {:ok, %{delivery_id: id}}
  def resolve_delivery(%{"msg_id" => pid}) when is_binary(pid), do: {:ok, %{provider_message_id: pid}}
  def resolve_delivery(_), do: :error

  def normalize_feedback(%{"status" => "bounce"}), do: {:ok, %{status: :bounced}}
  def normalize_feedback(%{"status" => "ok"}), do: {:ok, %{status: :delivered}}
  def normalize_feedback(%{"status" => "fail"}), do: {:ok, %{status: :failed}}
  def normalize_feedback(_), do: :error

  # Optional callback (A4) — exposes provider event id for dedup when present.
  def resolve_provider_event_id(%{"event_id" => id}) when is_binary(id), do: {:ok, id}
  def resolve_provider_event_id(_), do: :none
end
