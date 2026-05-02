defmodule DemoHost.Adapters.RawBodyHmacAdapter do
  @moduledoc """
  Fixture adapter that computes HMAC-SHA256 over the raw request body bytes
  and compares against the `x-signature` header. Used by the Phase 33
  verify-before-parse E2E test to assert that `verify_webhook/3` runs on the
  EXACT raw bytes provided by `Plug.Parsers`'s `:body_reader` MFA — BEFORE
  any JSON parsing or re-encoding (D-13 / T-33-RAWBODY).

  The shared secret `@secret` is intentionally a constant for the fixture;
  production adapters MUST source secrets from configuration / Vault and use
  `Plug.Crypto.secure_compare/2` for the comparison. The constant-time
  compare is included here so the fixture demonstrates the correct shape.
  """

  @behaviour Chimeway.Adapter

  @secret "test-secret-rawbody"

  def deliver(_delivery, _config), do: {:ok, %{}}

  def verify_webhook(body, headers, _config) when is_binary(body) do
    expected = :crypto.mac(:hmac, :sha256, @secret, body) |> Base.encode16(case: :lower)

    case Enum.find(headers, fn {k, _} -> String.downcase(k) == "x-signature" end) do
      {_, provided} when is_binary(provided) ->
        if Plug.Crypto.secure_compare(provided, expected) do
          :ok
        else
          {:error, :unauthorized}
        end

      _ ->
        {:error, :unauthorized}
    end
  end

  def resolve_delivery(%{"id" => id}) when is_binary(id), do: {:ok, %{delivery_id: id}}
  def resolve_delivery(_), do: :error

  def normalize_feedback(%{"status" => "ok"}), do: {:ok, %{status: :delivered}}
  def normalize_feedback(%{"status" => "bounce"}), do: {:ok, %{status: :bounced}}
  def normalize_feedback(_), do: :error
end
