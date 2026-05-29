defmodule ChimewayAdmin.Redaction do
  @moduledoc """
  View-layer redaction for operator trace surfaces (D-13, D-14).
  """

  @allowed_detail_keys ~w(
    reason outcome event_name step_key adapter status notification_key channel
    workflow_step_key workflow_outcome from_step to_step rule_identity
  )

  @sensitive_key ~r/(password|token|secret|api_key|auth)/i
  @phone ~r/^\+?[0-9][0-9\s().-]{6,}$/

  @doc """
  Masks recipient identity for list/detail display.
  """
  @spec redact_recipient(String.t()) :: String.t()
  def redact_recipient("user:" <> id) do
    suffix =
      if String.length(id) > 3,
        do: String.slice(id, -3..-1//1),
        else: id

    "user:***" <> suffix
  end

  def redact_recipient("webhook:" <> id) do
    "webhook:***" <> opaque_suffix(id)
  end

  def redact_recipient(value) when is_binary(value) do
    cond do
      String.contains?(value, "@") ->
        case String.split(value, "@", parts: 2) do
          [local, domain] when byte_size(local) > 0 ->
            first = String.first(local)
            "#{first}***@#{domain}"

          _ ->
            mask_opaque(value)
        end

      Regex.match?(@phone, value) ->
        mask_opaque(value)

      true ->
        mask_opaque(value)
    end
  end

  @doc """
  Sanitizes provider error classes for summary display.
  """
  @spec safe_error_class(term()) :: String.t()
  def safe_error_class(nil), do: "—"

  def safe_error_class(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" ->
        "—"

      trimmed ->
        cond do
          String.contains?(trimmed, "/") or String.contains?(trimmed, "@") ->
            mask_opaque(trimmed)

          Regex.match?(~r/(password|secret|api_key|private_key)/i, trimmed) ->
            mask_opaque(trimmed)

          true ->
            trimmed
        end
    end
  end

  def safe_error_class(value), do: value |> to_string() |> safe_error_class()

  @doc """
  Returns a whitelisted, non-sensitive subset of timeline `:detail` maps.
  """
  @spec safe_timeline_detail(map()) :: map()
  def safe_timeline_detail(detail) when is_map(detail) do
    detail
    |> Enum.filter(fn {key, _value} ->
      key_str = key |> to_string() |> String.downcase()
      key_str in @allowed_detail_keys and not Regex.match?(@sensitive_key, key_str)
    end)
    |> Map.new()
  end

  def safe_timeline_detail(_), do: %{}

  defp opaque_suffix(id) do
    if String.length(id) > 3,
      do: String.slice(id, -3..-1//1),
      else: id
  end

  defp mask_opaque(value) do
    len = String.length(value)

    cond do
      len <= 4 ->
        "***"

      len <= 8 ->
        String.slice(value, 0, 2) <> "***" <> String.slice(value, -2..-1//1)

      true ->
        String.slice(value, 0, 2) <> "***" <> String.slice(value, -3..-1//1)
    end
  end
end
